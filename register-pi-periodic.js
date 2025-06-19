#!/usr/bin/env node

// register-pi-periodic.js
// This script runs periodically (via cron) to ensure the Pi stays registered with the server
// It's designed to be safe to run frequently and will update registration if needed

const fs = require('fs');
const { exec } = require('child_process');

// Configuration
const SERVER_URL = process.env.SERVER_URL || 'http://192.168.1.120:3009';
const LOG_FILE = '/tmp/pi-registration.log';

// Simple logging function
function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  console.log(logMessage.trim());
  
  // Also write to log file
  try {
    fs.appendFileSync(LOG_FILE, logMessage);
  } catch (error) {
    console.error('Failed to write to log file:', error.message);
  }
}

// Get API key from systemd service file
function getApiKey() {
  try {
    const serviceContent = fs.readFileSync('/etc/systemd/system/inpatient-reboot.service', 'utf8');
    const match = serviceContent.match(/REBOOT_API_KEY=([a-f0-9]+)/);
    if (match) {
      return match[1];
    }
  } catch (error) {
    log(`Error reading service file: ${error.message}`);
  }
  return null;
}

// Get system info
function getSystemInfo() {
  return new Promise((resolve) => {
    exec('hostname', (error, hostname) => {
      if (error) {
        resolve({ hostname: 'unknown', ip: 'unknown' });
        return;
      }
      
      exec('hostname -I', (error, ipOutput) => {
        const ip = ipOutput ? ipOutput.trim().split(' ')[0] : 'unknown';
        resolve({ 
          hostname: hostname.trim(), 
          ip: ip 
        });
      });
    });
  });
}

// Register with server
async function registerWithServer() {
  const apiKey = getApiKey();
  if (!apiKey) {
    log('ERROR: Could not find API key in service file');
    return false;
  }

  const { hostname, ip } = await getSystemInfo();
  
  if (ip === 'unknown') {
    log('ERROR: Could not determine IP address');
    return false;
  }
  
  log(`Registering Pi: ${hostname} (${ip})`);
  
  try {
    const response = await fetch(`${SERVER_URL}/api/register-pi`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        apiKey,
        hostname,
        ip
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const result = await response.json();
    log(`Registration result: ${result.status}`);
    
    if (result.status === 'new') {
      log('SUCCESS: Pi registered successfully!');
    } else if (result.status === 'updated') {
      log('SUCCESS: Pi registration updated!');
    }
    
    return true;
    
  } catch (error) {
    log(`ERROR: Failed to register with server: ${error.message}`);
    return false;
  }
}

// Main execution
async function main() {
  log('Starting periodic Pi registration...');
  
  const success = await registerWithServer();
  
  if (success) {
    log('Periodic registration completed successfully');
  } else {
    log('Periodic registration failed');
    process.exit(1);
  }
}

// Run the script
main().catch(error => {
  log(`FATAL ERROR: ${error.message}`);
  process.exit(1);
}); 