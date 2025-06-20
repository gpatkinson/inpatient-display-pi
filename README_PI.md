# Inpatient Display Pi Client

Raspberry Pi client for the Inpatient Display System. This repository contains all the necessary files to set up a Raspberry Pi as a display client.

> **📖 Complete System Documentation**: For the full system overview, server setup, and detailed architecture, see the [main Inpatient Display System documentation](https://github.com/yourusername/inpatient-display/blob/main/README_CONSOLIDATED.md).

## Quick Start

### Prerequisites
- Raspberry Pi with Raspberry Pi OS 32-bit
- Internet connection
- Server IP address

### One-Command Setup
```bash
# Download and run the setup script
curl -sSL https://raw.githubusercontent.com/yourusername/inpatient-display-pi/main/pi-setup-complete.sh | sudo bash
```

### Manual Setup
0. Initial Prep 
   ```bash
   sudo apt install git
   ```

1. **Clone this repository:**
   ```bash
   sudo git clone git@github.com/gpatkinson/inpatient-display-pi.git /opt/inpatient-display
   cd /opt/inpatient-display
   ```

2. **Edit configuration:**
   ```bash
   sudo nano pi-setup-complete.sh
   # Change SERVER_IP to your server's IP address
   # Change REPO_URL to your actual repository URL
   ```

3. **Run the setup script:**
   ```bash
   sudo chmod +x pi-setup-complete.sh
   sudo ./pi-setup-complete.sh
   ```

4. **Reboot the Pi:**
   ```bash
   sudo reboot
   ```

## What the Setup Script Does

### System Configuration
- ✅ Updates system packages
- ✅ Installs required software (Node.js, Chromium, etc.)
- ✅ Configures auto-start for display
- ✅ Disables screen saver and power management
- ✅ Sets up SSH and firewall

### Display Setup
- ✅ Configures Chromium for kiosk mode
- ✅ Creates auto-start entry
- ✅ Sets up full-screen display
- ✅ Disables notifications and security prompts

### Service Installation
- ✅ Installs reboot service
- ✅ Sets up periodic registration
- ✅ Creates status and update scripts
- ✅ Configures log rotation

### Registration
- ✅ Generates unique API key
- ✅ Registers Pi with server
- ✅ Sets up automatic IP updates

## Files Included

### Core Scripts
- `pi-setup-complete.sh` - Complete setup script
- `register-pi.js` - One-time Pi registration
- `register-pi-periodic.js` - Periodic registration script
- `reboot-service.js` - Local reboot service

### Configuration
- `reboot-service.service` - Systemd service file
- `package.json` - Node.js dependencies
- `README_PI.md` - This file

### Generated Files (after setup)
- `/etc/inpatient-display/api-key` - Pi's API key
- `/usr/local/bin/inpatient-status` - Status script
- `/usr/local/bin/inpatient-update` - Update script
- `/usr/local/bin/inpatient-reboot-service` - Reboot service

## Usage

### Check Status
```bash
inpatient-status
```

### View Logs
```bash
# Registration logs
tail -f /tmp/pi-registration.log

# Reboot service logs
sudo journalctl -u inpatient-reboot -f

# Setup logs
tail -f /tmp/pi-setup.log
```

### Update System
```bash
inpatient-update
```

### Manual Registration
```bash
cd /opt/inpatient-display
node register-pi.js
```

### Manual Reboot
```bash
sudo systemctl restart inpatient-reboot
```

## Configuration

### Server IP Address
Edit the setup script to change the server IP:
```bash
sudo nano /opt/inpatient-display/pi-setup-complete.sh
# Change SERVER_IP="192.168.1.120" to your server's IP
```

### Display URL
The display URL is automatically configured to: `http://SERVER_IP:3008/display`

### Auto-Start Configuration
The display automatically starts on boot. To disable:
```bash
rm /home/pi/.config/autostart/inpatient-display.desktop
```

## Troubleshooting

### Display Not Starting
1. **Check auto-start:**
   ```bash
   ls -la /home/pi/.config/autostart/
   ```

2. **Test browser manually:**
   ```bash
   chromium-browser --kiosk http://SERVER_IP:3008/display
   ```

3. **Check server connectivity:**
   ```bash
   curl http://SERVER_IP:3008/display
   ```

### Registration Issues
1. **Check API key:**
   ```bash
   cat /etc/inpatient-display/api-key
   ```

2. **Test registration manually:**
   ```bash
   cd /opt/inpatient-display
   node register-pi.js
   ```

3. **Check server logs:**
   ```bash
   # On the server
   sudo docker logs inpatient-backend | grep -i register
   ```

### Reboot Service Issues
1. **Check service status:**
   ```bash
   sudo systemctl status inpatient-reboot
   ```

2. **View service logs:**
   ```bash
   sudo journalctl -u inpatient-reboot -f
   ```

3. **Restart service:**
   ```bash
   sudo systemctl restart inpatient-reboot
   ```

### Network Issues
1. **Check IP address:**
   ```bash
   hostname -I
   ```

2. **Test connectivity:**
   ```bash
   ping SERVER_IP
   curl http://SERVER_IP:3009/api/debug/pi-clients
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status
   ```

## Maintenance

### Regular Updates
```bash
inpatient-update
```

### Log Rotation
Logs are automatically rotated daily and kept for 7 days.

### Backup
Important files to backup:
- `/etc/inpatient-display/api-key`
- `/opt/inpatient-display/`

### Reset
To completely reset the Pi:
```bash
sudo rm -rf /opt/inpatient-display
sudo rm -rf /etc/inpatient-display
sudo rm /usr/local/bin/inpatient-*
sudo systemctl disable inpatient-reboot
sudo systemctl stop inpatient-reboot
sudo rm /etc/systemd/system/inpatient-reboot.service
```

## Security

### API Key
- Stored in `/etc/inpatient-display/api-key`
- Permissions: 600 (root only)
- Generated automatically on first setup

### Firewall
- SSH allowed
- HTTP/HTTPS allowed
- All other ports blocked

### SSH
- Enabled by default
- Default password: `raspberry`
- Change password after setup

## Support

For issues:
1. Check the troubleshooting section above
2. View logs for error messages
3. Test individual components
4. Check server connectivity

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Note**: This repository is designed to work with the main Inpatient Display System server. Make sure your server is running and accessible before setting up Pi clients. 