#!/usr/bin/env node

// reboot-service.js
// This service runs on the Raspberry Pi to handle reboot requests from the server

const express = require('express');
const fs = require('fs');

// Configuration
const PORT = process.env.PORT || 3001;
const API_KEY_FILE = process.env.REBOOT_API_KEY_FILE || '/etc/inpatient-display/api-key';

// Get API key from file
function getApiKey() {
  try {
    if (fs.existsSync(API_KEY_FILE)) {
      return fs.readFileSync(API_KEY_FILE, 'utf8').trim();
    }
  } catch (error) {
    console.error('Error reading API key file:', error.message);
  }
  return null;
}

const app = express();
app.use(express.json());

// Middleware to check API key
function authenticateApiKey(req, res, next) {
  const providedKey = req.headers['x-api-key'] || req.query.apiKey;
  const expectedKey = getApiKey();
  
  if (!expectedKey) {
    console.error('No API key configured');
    return res.status(500).json({ error: 'API key not configured' });
  }
  
  if (!providedKey || providedKey !== expectedKey) {
    console.error('Invalid API key provided');
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  next();
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    apiKeyConfigured: !!getApiKey()
  });
});

// Reboot endpoint
app.post('/reboot', authenticateApiKey, (req, res) => {
  console.log('Reboot request received');
  
  // Send immediate response
  res.json({ 
    status: 'rebooting',
    timestamp: new Date().toISOString()
  });
  
  // Execute reboot after a short delay
  setTimeout(() => {
    console.log('Executing reboot...');
    const { exec } = require('child_process');
    exec('sudo reboot', (error) => {
      if (error) {
        console.error('Reboot failed:', error);
      } else {
        console.log('Reboot command executed successfully');
      }
    });
  }, 1000);
});

// Start server
app.listen(PORT, () => {
  console.log(`Reboot service started on port ${PORT}`);
  console.log(`API key file: ${API_KEY_FILE}`);
  console.log(`API key configured: ${!!getApiKey()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  process.exit(0);
}); 