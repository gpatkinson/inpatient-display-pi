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
        openssh-server
    
    # Install Node.js 20.x from NodeSource
    log "Installing Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Verify Node.js and npm versions
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log "Installed Node.js $NODE_VERSION and npm $NPM_VERSION"
    
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

# Install Node.js dependencies
install_dependencies() {
    log "Installing Node.js dependencies..."
    cd "$SETUP_DIR"
    npm install
    log "Dependencies installed"
}

# Configure auto-start
configure_autostart() {
    log "Configuring auto-start..."
    
    # Create autostart directory
    mkdir -p /home/pi/.config/autostart
    
    # Create desktop entry for browser
    cat > /home/pi/.config/autostart/inpatient-display.desktop << EOF
[Desktop Entry]
Type=Application
Name=Inpatient Display
Exec=chromium-browser --kiosk --disable-web-security --user-data-dir=/tmp/chrome-inpatient --no-first-run --no-default-browser-check http://$SERVER_IP:3008/display
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    
    # Set permissions
    chown -R pi:pi /home/pi/.config/autostart
    chmod +x /home/pi/.config/autostart/inpatient-display.desktop
    
    log "Auto-start configured"
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
    "startup_urls": ["http://$SERVER_IP:3008/display"]
  }
}
EOF
    
    chown -R pi:pi /home/pi/.config/chromium
    
    log "Display settings configured"
}

# Install and configure reboot service
setup_reboot_service() {
    log "Setting up reboot service..."
    
    # Check if service file exists
    if [ ! -f "$SETUP_DIR/reboot-service.service" ]; then
        error "Service file not found: $SETUP_DIR/reboot-service.service"
    fi
    
    # Copy service file
    cp "$SETUP_DIR/reboot-service.service" /etc/systemd/system/
    
    # Update service file to run from correct directory
    sed -i 's|ExecStart=/usr/bin/node /usr/local/bin/inpatient-reboot-service|ExecStart=/usr/bin/node /opt/inpatient-display/reboot-service.js|g' /etc/systemd/system/reboot-service.service
    
    # Copy reboot service script (keep for reference)
    if [ ! -f "$SETUP_DIR/reboot-service.js" ]; then
        error "Reboot service script not found: $SETUP_DIR/reboot-service.js"
    fi
    cp "$SETUP_DIR/reboot-service.js" /usr/local/bin/inpatient-reboot-service
    chmod +x /usr/local/bin/inpatient-reboot-service
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable reboot-service.service
    systemctl start reboot-service.service
    
    log "Reboot service configured"
}

# Register Pi with server
register_pi() {
    log "Registering Pi with server..."
    
    # Generate API key if not exists
    if [ ! -f /etc/inpatient-display/api-key ]; then
        API_KEY=$(openssl rand -hex 32)
        echo "$API_KEY" > /etc/inpatient-display/api-key
        chmod 644 /etc/inpatient-display/api-key
        chown pi:pi /etc/inpatient-display/api-key
        log "Generated new API key"
    else
        API_KEY=$(cat /etc/inpatient-display/api-key)
        # Fix permissions if they're wrong
        chmod 644 /etc/inpatient-display/api-key
        chown pi:pi /etc/inpatient-display/api-key
        log "Using existing API key"
    fi
    
    # Get current IP and hostname
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    HOSTNAME=$(hostname)
    
    # Register with server
    cd "$SETUP_DIR"
    node register-pi.js "$API_KEY" "$HOSTNAME" "$CURRENT_IP"
    
    log "Pi registration completed"
}

# Setup periodic registration
setup_periodic_registration() {
    log "Setting up periodic registration..."
    
    # Copy periodic registration script
    cp "$SETUP_DIR/register-pi-periodic.js" /usr/local/bin/
    chmod +x /usr/local/bin/register-pi-periodic.js
    
    # Ensure API key file has correct permissions for pi user
    if [ -f /etc/inpatient-display/api-key ]; then
        chmod 644 /etc/inpatient-display/api-key
        chown pi:pi /etc/inpatient-display/api-key
    fi
    
    # Add to crontab (remove any existing entries first)
    CRON_JOB="*/5 * * * * sudo /usr/bin/node /usr/local/bin/register-pi-periodic.js >> /tmp/pi-registration.log 2>&1"
    
    # Remove existing cron job if it exists
    (crontab -l 2>/dev/null | grep -v "register-pi-periodic.js") | crontab -
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    
    # Verify cron job was added
    if crontab -l 2>/dev/null | grep -q "register-pi-periodic.js"; then
        log "Periodic registration cron job added successfully"
    else
        warn "Failed to add periodic registration cron job"
    fi
    
    log "Periodic registration configured"
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
        
        log "Firewall configured with UFW"
    else
        warn "UFW installation failed, skipping firewall configuration"
        log "You may want to configure firewall manually or install UFW later"
    fi
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

echo "=== Services ==="
systemctl status reboot-service.service --no-pager -l
echo ""

echo "=== Network ==="
echo "IP Address: $(hostname -I)"
echo "Hostname: $(hostname)"
echo ""

echo "=== Registration ==="
if [ -f /etc/inpatient-display/api-key ]; then
    echo "API Key: $(cat /etc/inpatient-display/api-key | cut -c1-8)..."
else
    echo "API Key: Not found"
fi
echo ""

echo "=== Logs ==="
echo "Registration log (last 10 lines):"
tail -10 /tmp/pi-registration.log 2>/dev/null || echo "No registration log found"
echo ""

echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "No cron jobs found"
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
systemctl restart reboot-service.service
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
/tmp/pi-registration.log {
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
    setup_reboot_service
    register_pi
    setup_periodic_registration
    configure_ssh
    configure_firewall
    create_status_script
    create_update_script
    final_setup
    
    log "Setup completed successfully!"
    log "Next steps:"
    log "1. Reboot the Pi: sudo reboot"
    log "2. Check status: inpatient-status"
    log "3. View logs: tail -f /tmp/pi-registration.log"
    log "4. Update system: inpatient-update"
    
    echo ""
    echo -e "${GREEN}Setup completed! Please reboot the Pi to start the display.${NC}"
}

# Run main function
main "$@" 