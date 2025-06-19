#!/usr/bin/env node

// register-pi.js
// This script runs on the Raspberry Pi to register its API key with the server

const fs = require('fs');
const { exec } = require('child_process');

// Configuration
const SERVER_URL = process.env.SERVER_URL || 'http://192.168.1.120:3009';

// Get API key from file
function getApiKey() {
  try {
    // First try to get from command line arguments
    if (process.argv[2]) {
      return process.argv[2];
    }
    
    // Then try to read from API key file
    if (fs.existsSync('/etc/inpatient-display/api-key')) {
      return fs.readFileSync('/etc/inpatient-display/api-key', 'utf8').trim();
    }
    
    // Fallback to service file (for backward compatibility)
    const serviceContent = fs.readFileSync('/etc/systemd/system/inpatient-reboot.service', 'utf8');
    const match = serviceContent.match(/REBOOT_API_KEY=([a-f0-9]+)/);
    if (match) {
      return match[1];
    }
  } catch (error) {
    console.error('Error reading API key:', error.message);
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
    console.error('Could not find API key');
    return;
  }

  const { hostname, ip } = await getSystemInfo();
  
  console.log(`Registering Pi: ${hostname} (${ip})`);
  
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
    
    const result = await response.json();
    console.log('Registration result:', result);
    
    if (result.status === 'new') {
      console.log('✅ Pi registered successfully!');
    } else if (result.status === 'updated') {
      console.log('✅ Pi registration updated!');
    }
    
  } catch (error) {
    console.error('❌ Failed to register with server:', error.message);
  }
}

// Run registration
registerWithServer(); 