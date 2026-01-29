# IP Monitor Setup Guide

## Overview
This script monitors domain IP addresses and notifies you when they don't match your current public IP. Perfect for dynamic DNS monitoring.

## Files
- `check_ip.sh` - Main monitoring script
- `check_ip.conf` - Configuration file (tokens and domains)

## Setup

### 1. Place Files Together
Both files MUST be in the same directory:
```bash
mkdir ~/ip-monitor
cd ~/ip-monitor
# Copy check_ip.sh and check_ip.conf here
```

### 2. Make Script Executable
```bash
chmod +x check_ip.sh
```

### 3. Edit Configuration
Edit `check_ip.conf` to add your domains:
```bash
nano check_ip.conf
```

Change the DOMAINS line:
```bash
DOMAINS="quarteredcircle.net example.com mysite.org"
```

### 4. Test It
```bash
./check_ip.sh
```

## Configuration File

The `check_ip.conf` file contains:

- **MESSAGE_TOKEN** - Automatically refreshed by script
- **REFRESH_TOKEN** - Used to get new tokens (should rarely change)
- **DOMAINS** - Space-separated list of domains to monitor

### Example:
```bash
MESSAGE_TOKEN="eyJ..."
REFRESH_TOKEN="eyJ..."
DOMAINS="domain1.com domain2.com domain3.com"
```

## Usage

### Run Manually
```bash
./check_ip.sh
```

### Check Specific Domains (Override Config)
```bash
./check_ip.sh example.com test.com
```

### Automated Monitoring with Cron

Edit crontab:
```bash
crontab -e
```

Add one of these lines:

**Check every 5 minutes:**
```bash
*/5 * * * * /path/to/ip-monitor/check_ip.sh >> /var/log/ip_check.log 2>&1
```

**Check every hour:**
```bash
0 * * * * /path/to/ip-monitor/check_ip.sh >> /var/log/ip_check.log 2>&1
```

**Check every day at 8 AM:**
```bash
0 8 * * * /path/to/ip-monitor/check_ip.sh >> /var/log/ip_check.log 2>&1
```

## How Token Refresh Works

1. Script tries to send notification with current MESSAGE_TOKEN
2. If that fails, it calls the refresh endpoint with REFRESH_TOKEN
3. Receives new MESSAGE_TOKEN (and possibly new REFRESH_TOKEN)
4. **Automatically updates check_ip.conf with new tokens**
5. Retries sending the notification

The tokens persist between runs, so you don't need to refresh every time!

## Output

### All Domains Match
```
Checking current public IP address...
Current IP: 123.45.67.89

Checking quarteredcircle.net...
  ✓ quarteredcircle.net matches (123.45.67.89)

==========================================
Summary:
  Matched: 1
  Mismatched: 0
  Failed to resolve: 0
==========================================
✓ All domains match - No action needed
```

### Mismatch Detected
```
Checking current public IP address...
Current IP: 123.45.67.89

Checking example.com...
  ⚠ example.com does NOT match (Domain: 93.184.216.34, Current: 123.45.67.89)

==========================================
Summary:
  Matched: 0
  Mismatched: 1
  Failed to resolve: 0
==========================================

Building notification message...
Sending notification...
DEBUG: HTTP Code: 201
DEBUG: Response Body: {"message":"Message added successfully."}
✓ Notification sent successfully
```

## Troubleshooting

### Config File Not Found
```
Error: Configuration file not found: /path/to/check_ip.conf
```
**Solution:** Ensure check_ip.conf is in the same directory as check_ip.sh

### No Domains Specified
```
Error: No domains specified in configuration
```
**Solution:** Add domains to the DOMAINS line in check_ip.conf

### Token Refresh Failed
- Check that your REFRESH_TOKEN is still valid
- You may need to get a new refresh token from marvn.app

## Support

For issues or questions, check the debug output when running the script. The script shows:
- HTTP response codes
- Response bodies
- Token refresh attempts

All output is color-coded:
- 🟢 Green = Success
- 🟡 Yellow = Warning
- 🔴 Red = Error
