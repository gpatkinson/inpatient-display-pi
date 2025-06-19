#!/usr/bin/env node

// reboot-service.js
// This service runs on Raspberry Pi clients to handle reboot commands
// Run with: sudo node reboot-service.js

const express = require('express');
const { exec } = require('child_process');
const cors = require('cors');

const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

// Simple authentication (you might want to make this more secure)
const API_KEY = process.env.REBOOT_API_KEY || 'your-reboot-api-key';

const authenticate = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname()
  });
});

// API key endpoint (for frontend registration)
app.get('/api-key', (req, res) => {
  res.json({ 
    apiKey: process.env.REBOOT_API_KEY || API_KEY
  });
});

// Reboot endpoint
app.post('/reboot', authenticate, (req, res) => {
  console.log('Reboot command received:', req.body);
  
  // Send immediate response
  res.json({ 
    message: 'Reboot command received, system will reboot in 10 seconds',
    timestamp: new Date().toISOString()
  });
  
  // Execute reboot after 10 seconds
  setTimeout(() => {
    console.log('Executing reboot...');
    exec('sudo reboot', (error, stdout, stderr) => {
      if (error) {
        console.error('Reboot error:', error);
        return;
      }
      console.log('Reboot command executed successfully');
    });
  }, 10000);
});

// Graceful shutdown endpoint
app.post('/shutdown', authenticate, (req, res) => {
  console.log('Shutdown command received');
  
  res.json({ 
    message: 'Shutdown command received, system will shutdown in 10 seconds',
    timestamp: new Date().toISOString()
  });
  
  setTimeout(() => {
    console.log('Executing shutdown...');
    exec('sudo shutdown -h now', (error, stdout, stderr) => {
      if (error) {
        console.error('Shutdown error:', error);
        return;
      }
      console.log('Shutdown command executed successfully');
    });
  }, 10000);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Reboot service listening on port ${PORT}`);
  console.log(`Hostname: ${require('os').hostname()}`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('Reboot service shutting down...');
  process.exit(0);
}); 