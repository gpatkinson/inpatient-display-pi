#!/bin/bash

# Inpatient Display Pi Setup Script
# This script sets up a Raspberry Pi for the inpatient display system
# Run this after installing Raspberry Pi OS 32-bit

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="192.168.1.120"  # Change this to your server IP
SERVER_PORT="3009"
REPO_URL="https://github.com/gpatkinson/inpatient-display-pi.git"  # Change this
SETUP_DIR="/opt/inpatient-display"
LOG_FILE="/tmp/pi-setup.log"

# Reboot configuration (set to empty string to disable auto-reboot)
AUTO_REBOOT_TIME="07:45"  # 24-hour format, e.g., "02:00" for 2 AM, or "" to disable

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Update system
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
    log "System update completed"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    # Essential packages
    apt install -y \
        curl \
        wget \
        git \
        unclutter \
        xdotool \
        chromium-browser \
        cron \
        screen \
        htop \
        vim \
        nginx \
        openssh-server \
        lightdm
    
    #NODE NOT REQUIRED IF REBOOT IS MANAGED THROUGH CRON
    # Install Node.js 20.x from NodeSource
    #log "Installing Node.js 20.x..."
    #curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    #apt install -y nodejs
    
    # Verify Node.js and npm versions
    #NODE_VERSION=$(node --version)
    #NPM_VERSION=$(npm --version)
    #log "Installed Node.js $NODE_VERSION and npm $NPM_VERSION"
    
    log "Package installation completed"
}

# Create setup directory
create_directories() {
    log "Creating setup directories..."
    mkdir -p "$SETUP_DIR"
    mkdir -p /var/log/inpatient-display
    mkdir -p /etc/inpatient-display
    log "Directories created"
}

# Clone repository
clone_repository() {
    log "Cloning Pi setup repository..."
    if [ -d "$SETUP_DIR/.git" ]; then
        log "Repository already exists, pulling latest changes..."
        cd "$SETUP_DIR"
        git pull origin main
    else
        git clone "$REPO_URL" "$SETUP_DIR"
    fi
    log "Repository setup completed"
}

# NOT REQUIRED IF REBOOT IS MANAGED THROUGH CRON
# Install Node.js dependencies
#install_dependencies() {
#    log "Installing Node.js dependencies..."
#    cd "$SETUP_DIR"
#    npm install
#    log "Dependencies installed"
#}

# Configure auto-start
configure_autostart() {
    log "Configuring auto-start..."
    
    # Create autostart directory
    mkdir -p /home/pi/.config/autostart
    
    # Create the proven start script based on README configuration
    log "Creating proven Chromium start script..."
    cat > /home/pi/start-display.sh << 'EOF'
#!/bin/bash
sleep 10

# Force X11 mode (not Wayland)
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
unset WAYLAND_DISPLAY

# Kill any existing processes
pkill -f chromium
pkill -f unclutter

# Hide cursor and disable screen blanking (with error handling)
unclutter -idle 0 -root &
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Start Chromium with proven configuration and correct URL
chromium-browser \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --noerrdialogs \
  --disable-infobars \
  --disable-features=TranslateUI \
  --disable-component-update \
  --disable-default-apps \
  --disable-features=OptimizationHints \
  --kiosk \
  --enable-touch-events \
  --enable-touch-drag-drop \
  --force-enable-touch-events \
  --disable-features=VizDisplayCompositor \
  --user-data-dir=/tmp/chromium-kiosk \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --touch-events=enabled \
  --enable-logging \
  --v=1 \
  --enable-features=TouchEventFeatureDetection \
  --disable-features=UseOzonePlatform \
  --ozone-platform=x11 \
  http://SERVER_IP:3008?cache=$(date +%s)
EOF

    # Replace SERVER_IP placeholder with actual IP
    sed -i "s/SERVER_IP/$SERVER_IP/g" /home/pi/start-display.sh
    
    chmod +x /home/pi/start-display.sh
    chown pi:pi /home/pi/start-display.sh
    
    # Create desktop entry for the start script
    cat > /home/pi/.config/autostart/inpatient-display.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Inpatient Display
Exec=/home/pi/start-display.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    
    # Set permissions
    chown -R pi:pi /home/pi/.config/autostart
    chmod +x /home/pi/.config/autostart/inpatient-display.desktop
    
    log "Auto-start configured with proven Chromium configuration"
}

# Configure display settings
configure_display() {
    log "Configuring display settings..."
    
    # Create autostart directory if it doesn't exist
    mkdir -p /etc/xdg/lxsession/LXDE-pi/
    
    # Disable screen saver - try multiple locations for different Pi OS versions
    AUTOSTART_FILES=(
        "/etc/xdg/lxsession/LXDE-pi/autostart"
        "/etc/xdg/lxsession/LXDE/autostart"
        "/home/pi/.config/lxsession/LXDE-pi/autostart"
    )
    
    for autostart_file in "${AUTOSTART_FILES[@]}"; do
        if [ -d "$(dirname "$autostart_file")" ]; then
            log "Configuring autostart at: $autostart_file"
            cat > "$autostart_file" << EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 0.1 -root
/home/pi/start-display.sh
EOF
            chown pi:pi "$autostart_file" 2>/dev/null || true
            break
        fi
    done
    
    # Also configure for the pi user specifically
    mkdir -p /home/pi/.config/lxsession/LXDE-pi/
    cat > /home/pi/.config/lxsession/LXDE-pi/autostart << EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 0.1 -root
/home/pi/start-display.sh
EOF
    chown -R pi:pi /home/pi/.config/lxsession/
    
    # Configure Chromium for kiosk mode
    mkdir -p /home/pi/.config/chromium/Default
    cat > /home/pi/.config/chromium/Default/Preferences << EOF
{
  "profile": {
    "default_content_setting_values": {
      "notifications": 2
    },
    "exit_type": "Normal",
    "exited_cleanly": true
  },
  "session": {
    "restore_on_startup": 4
  },
  "startup": {
    "startup_urls": ["http://$SERVER_IP:3008"]
  }
}
EOF
    
    chown -R pi:pi /home/pi/.config/chromium
    
    log "Display settings configured"
}

# Install and configure reboot service
setup_reboot_service() {
    log "Setting up simple cron-based reboot service..."
    
    # Create reboot script
    cat > /usr/local/bin/inpatient-reboot << 'EOF'
#!/bin/bash

# Simple reboot script for inpatient display Pi
# This script is called by cron to reboot the Pi

echo "$(date): Inpatient Display Pi - Scheduled reboot initiated" >> /var/log/inpatient-display/reboot.log

# Wait a moment for log to be written
sleep 2

# Execute reboot
/sbin/reboot
EOF
    
    chmod +x /usr/local/bin/inpatient-reboot
    
    # Set up cron job if reboot time is configured
    if [ -n "$AUTO_REBOOT_TIME" ]; then
        log "Setting up daily reboot at $AUTO_REBOOT_TIME"
        
        # Parse time into hour and minute
        HOUR=$(echo "$AUTO_REBOOT_TIME" | cut -d: -f1)
        MINUTE=$(echo "$AUTO_REBOOT_TIME" | cut -d: -f2)
        
        # Remove any existing reboot cron job
        (crontab -l 2>/dev/null | grep -v "inpatient-reboot") | crontab -
        
        # Add new cron job
        (crontab -l 2>/dev/null; echo "$MINUTE $HOUR * * * /usr/local/bin/inpatient-reboot") | crontab -
        
        # Verify cron job was added
        if crontab -l 2>/dev/null | grep -q "inpatient-reboot"; then
            log "✅ Daily reboot cron job added successfully at $AUTO_REBOOT_TIME"
        else
            warn "❌ Failed to add reboot cron job"
        fi
    else
        log "Auto-reboot disabled (AUTO_REBOOT_TIME is empty)"
        
        # Remove any existing reboot cron job
        (crontab -l 2>/dev/null | grep -v "inpatient-reboot") | crontab -
    fi
    
    # Create log directory
    mkdir -p /var/log/inpatient-display
    chown pi:pi /var/log/inpatient-display
    
    log "Simple reboot service configured"
}

# Register Pi with server
register_pi() {
    log "Pi registration not needed for simple cron-based reboot system"
    log "Reboot functionality is now handled locally via cron"
}

# Setup periodic registration
setup_periodic_registration() {
    log "Periodic registration not needed for simple cron-based reboot system"
    log "No server communication required for local cron reboots"
}

# Configure SSH (optional)
configure_ssh() {
    log "Configuring SSH..."
    
    # Enable SSH
    systemctl enable ssh
    systemctl start ssh
    
    # Optional: Change default password
    # echo "pi:raspberry" | chpasswd
    
    log "SSH configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Check if UFW is available
    if ! command -v ufw &> /dev/null; then
        log "UFW not found, installing..."
        apt install -y ufw
    fi
    
    # Check if UFW installation was successful
    if command -v ufw &> /dev/null; then
        # Allow SSH
        ufw allow ssh
        
        # Allow HTTP/HTTPS for display
        ufw allow 80
        ufw allow 443
        
        # Enable firewall
        ufw --force enable
        
        log "Firewall configured with UFW (SSH, HTTP, HTTPS allowed)"
    else
        warn "UFW installation failed, skipping firewall configuration"
        log "You may want to configure firewall manually or install UFW later"
    fi
}

# Test connectivity to server
test_connectivity() {
    log "Testing connectivity to server..."
    
    # Test ping to server
    if ping -c 1 "$SERVER_IP" >/dev/null 2>&1; then
        log "✅ Server is reachable via ping"
    else
        warn "❌ Server is not reachable via ping"
    fi
    
    # Test connection to backend port
    if timeout 5 nc -zv "$SERVER_IP" "$SERVER_PORT" >/dev/null 2>&1; then
        log "✅ Backend port $SERVER_PORT is accessible"
    else
        warn "❌ Backend port $SERVER_PORT is not accessible"
    fi
    
    # Test connection to frontend port
    if timeout 5 nc -zv "$SERVER_IP" 3008 >/dev/null 2>&1; then
        log "✅ Frontend port 3008 is accessible"
    else
        warn "❌ Frontend port 3008 is not accessible"
    fi
    
    log "Connectivity tests completed"
}

# Create status script
create_status_script() {
    log "Creating status script..."
    
    cat > /usr/local/bin/inpatient-status << 'EOF'
#!/bin/bash

echo "=== Inpatient Display Pi Status ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo ""

echo "=== Network ==="
echo "IP Address: $(hostname -I)"
echo "Hostname: $(hostname)"
echo ""

echo "=== Auto-Reboot Configuration ==="
if crontab -l 2>/dev/null | grep -q "inpatient-reboot"; then
    echo "✅ Auto-reboot is configured"
    echo "   Cron job: $(crontab -l 2>/dev/null | grep inpatient-reboot)"
else
    echo "❌ Auto-reboot is not configured"
fi
echo ""

echo "=== Reboot Logs ==="
if [ -f /var/log/inpatient-display/reboot.log ]; then
    echo "Last 5 reboot entries:"
    tail -5 /var/log/inpatient-display/reboot.log
else
    echo "No reboot logs found"
fi
echo ""

echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "No cron jobs found"
echo ""

echo "=== Firewall Status ==="
if command -v ufw >/dev/null 2>&1; then
    echo "UFW Status:"
    ufw status | head -10
else
    echo "UFW not installed"
fi
EOF
    
    chmod +x /usr/local/bin/inpatient-status
    
    log "Status script created"
}

# Create update script
create_update_script() {
    log "Creating update script..."
    
    cat > /usr/local/bin/inpatient-update << 'EOF'
#!/bin/bash

cd /opt/inpatient-display
git pull origin main
npm install
echo "Update completed. Consider rebooting if needed."
EOF
    
    chmod +x /usr/local/bin/inpatient-update
    
    log "Update script created"
}

# Final configuration
final_setup() {
    log "Performing final configuration..."
    
    # Set proper permissions
    chown -R pi:pi "$SETUP_DIR"
    
    # Create log rotation
    cat > /etc/logrotate.d/inpatient-display << EOF
/var/log/inpatient-display/reboot.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 pi pi
}
EOF
    
    log "Final configuration completed"
}

# Configure autologin
configure_autologin() {
    log "Configuring autologin..."
    
    # Enable desktop autologin (B4 = Desktop Autologin)
    raspi-config nonint do_boot_behaviour B4
    
    # Configure lightdm autologin
    if [ -f /etc/lightdm/lightdm.conf ]; then
        log "Configuring lightdm autologin..."
        
        # Backup original config
        cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
        
        # Create or update lightdm.conf with autologin settings
        cat > /etc/lightdm/lightdm.conf << EOF
[SeatDefaults]
autologin-user=pi
autologin-user-timeout=0
user-session=LXDE
session-wrapper=/etc/X11/Xsession

[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=LXDE
session-wrapper=/etc/X11/Xsession
EOF
        
        log "Lightdm autologin configured"
    else
        warn "Lightdm config file not found"
    fi
    
    # Ensure LXDE session is available
    if [ ! -f /usr/share/xsessions/LXDE.desktop ]; then
        log "Creating LXDE session file..."
        cat > /usr/share/xsessions/LXDE.desktop << EOF
[Desktop Entry]
Name=LXDE
Comment=Lightweight X11 Desktop Environment
Exec=lxsession
Type=Application
EOF
    fi
    
    # Create user session configuration
    mkdir -p /home/pi/.config/lxsession/LXDE
    cat > /home/pi/.config/lxsession/LXDE/desktop.conf << EOF
[GTK]
sNet/ThemeName=Adwaita
sNet/IconThemeName=Adwaita
sGtk/FontName=Sans 12
sGtk/MenuFontName=Sans 12
sGtk/ToolbarFontName=Sans 12
sGtk/ButtonFontName=Sans 12
EOF
    
    chown -R pi:pi /home/pi/.config/lxsession/
    
    # Verify autologin is enabled
    if [ "$(raspi-config nonint get_autologin)" = "0" ]; then
        log "Autologin enabled successfully"
    else
        warn "Failed to enable autologin"
    fi
    
    log "Autologin configured"
}

# Main execution
main() {
    log "Starting Inpatient Display Pi setup..."
    log "Server IP: $SERVER_IP"
    log "Setup directory: $SETUP_DIR"
    
    check_root
    update_system
    install_packages
    create_directories
    clone_repository
    install_dependencies
    configure_autostart
    configure_display
    configure_autologin
    setup_reboot_service
    register_pi
    setup_periodic_registration
    configure_ssh
    configure_firewall
    test_connectivity
    create_status_script
    create_update_script
    final_setup
    
    log "Setup completed successfully!"
    log "Next steps:"
    log "1. Reboot the Pi: sudo reboot"
    log "2. Check status: inpatient-status"
    log "3. View reboot logs: tail -f /var/log/inpatient-display/reboot.log"
    log "4. Update system: inpatient-update"
    if [ -n "$AUTO_REBOOT_TIME" ]; then
        log "5. Auto-reboot is configured for $AUTO_REBOOT_TIME daily"
    else
        log "5. Auto-reboot is disabled (set AUTO_REBOOT_TIME to enable)"
    fi
    
    echo ""
    echo -e "${GREEN}Setup completed! Please reboot the Pi to start the display.${NC}"
    if [ -n "$AUTO_REBOOT_TIME" ]; then
        echo -e "${GREEN}Auto-reboot is configured for $AUTO_REBOOT_TIME daily.${NC}"
    else
        echo -e "${GREEN}Auto-reboot is disabled. Set AUTO_REBOOT_TIME in the script to enable.${NC}"
    fi
}

# Run main function
main "$@" 