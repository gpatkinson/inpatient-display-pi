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
REPO_URL="https://github.com/yourusername/inpatient-display-pi.git"  # Change this
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
        nodejs \
        npm \
        cron \
        screen \
        htop \
        vim \
        nginx \
        openssh-server
    
    # Update npm to latest version
    npm install -g npm@latest
    
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
    
    # Disable screen saver
    cat > /etc/xdg/lxsession/LXDE-pi/autostart << EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 0.1 -root
EOF
    
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
    
    # Copy service file
    cp "$SETUP_DIR/reboot-service.service" /etc/systemd/system/
    
    # Copy reboot service script
    cp "$SETUP_DIR/reboot-service.js" /usr/local/bin/inpatient-reboot-service
    chmod +x /usr/local/bin/inpatient-reboot-service
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable inpatient-reboot
    systemctl start inpatient-reboot
    
    log "Reboot service configured"
}

# Register Pi with server
register_pi() {
    log "Registering Pi with server..."
    
    # Generate API key if not exists
    if [ ! -f /etc/inpatient-display/api-key ]; then
        API_KEY=$(openssl rand -hex 32)
        echo "$API_KEY" > /etc/inpatient-display/api-key
        chmod 600 /etc/inpatient-display/api-key
        log "Generated new API key"
    else
        API_KEY=$(cat /etc/inpatient-display/api-key)
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
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/node /usr/local/bin/register-pi-periodic.js >> /tmp/pi-registration.log 2>&1") | crontab -
    
    log "Periodic registration configured"
}

# Configure SSH (optional)
configure_ssh() {
    log "Configuring SSH..."
    
    # Enable SSH
    systemctl enable ssh
    systemctl start ssh
    
    # Optional: Change default password
    echo "pi:raspberry" | chpasswd
    
    log "SSH configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS for display
    ufw allow 80
    ufw allow 443
    
    # Enable firewall
    ufw --force enable
    
    log "Firewall configured"
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
systemctl status inpatient-reboot --no-pager -l
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
systemctl restart inpatient-reboot
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