# marvn.sh - Simple Message Sender

A simple utility to send messages via marvn.app using the same config file as check_ip.sh.

## Setup

1. Ensure `marvn.sh` and `check_ip.conf` are in the same directory
2. Make it executable:
   ```bash
   chmod +x marvn.sh
   ```

## Usage

### Basic Message
```bash
./marvn.sh "Hello from the command line!"
```

### Multi-line Message
```bash
./marvn.sh "Line 1
Line 2
Line 3"
```

### Using Variables
```bash
HOSTNAME=$(hostname)
./marvn.sh "Server $HOSTNAME is online"
```

### From Scripts
```bash
#!/bin/bash
if [ -f /var/log/error.log ]; then
    ERROR_COUNT=$(wc -l < /var/log/error.log)
    ./marvn.sh "Error log has $ERROR_COUNT entries"
fi
```

## Examples

### System Monitoring
```bash
# Disk space alert
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
./marvn.sh "Disk usage: $DISK_USAGE"

# Memory usage
MEM_USAGE=$(free -h | grep Mem | awk '{print $3 "/" $2}')
./marvn.sh "Memory usage: $MEM_USAGE"

# System uptime
UPTIME=$(uptime -p)
./marvn.sh "System uptime: $UPTIME"
```

### Backup Notifications
```bash
#!/bin/bash
# backup.sh
if tar -czf backup.tar.gz /important/data; then
    ./marvn.sh "✓ Backup completed successfully"
else
    ./marvn.sh "✗ Backup failed!"
fi
```

### Cron Job Notifications
```bash
# In crontab:
0 0 * * * /path/to/backup.sh && /path/to/marvn.sh "Daily backup completed"
```

## Token Management

The script automatically:
- Uses MESSAGE_TOKEN from check_ip.conf
- Refreshes token if message fails to send
- Updates check_ip.conf with new tokens
- Shares token configuration with check_ip.sh

## Output

### Success
```
Sending message...
✓ Message sent successfully
```

### With Token Refresh
```
Sending message...
⚠ Failed to send with current token, attempting to refresh...
Attempting to refresh token...
✓ Token refreshed successfully
Updating configuration file...
✓ Configuration file updated
✓ Message sent successfully after token refresh
```

### Error
```
Sending message...
⚠ Failed to send with current token, attempting to refresh...
Attempting to refresh token...
✗ Failed to refresh token (HTTP 401)
✗ Failed to refresh token, message not sent
```

## Integration Ideas

### Web Server Monitoring
```bash
# Check if web server is responding
if ! curl -s --head http://localhost | grep "200 OK" > /dev/null; then
    ./marvn.sh "⚠ Web server is not responding!"
fi
```

### Database Backup
```bash
# After database dump
if mysqldump -u user -p database > backup.sql; then
    SIZE=$(du -h backup.sql | cut -f1)
    ./marvn.sh "Database backup complete: $SIZE"
fi
```

### Git Push Notification
```bash
# After successful git push
git push && ./marvn.sh "Code pushed to repository"
```

### Temperature Monitoring
```bash
# Check CPU temperature (Raspberry Pi example)
TEMP=$(vcgencmd measure_temp | cut -d'=' -f2)
if [[ ${TEMP%\'*} -gt 70 ]]; then
    ./marvn.sh "⚠ CPU Temperature high: $TEMP"
fi
```

## Tips

- Quote your messages to handle spaces and special characters
- Use `\n` for line breaks in single-line strings
- Messages are automatically escaped for JSON
- Exit code 0 = success, 1 = failure (useful for conditionals)
- Works with both check_ip.conf in the same directory

## Troubleshooting

### "Configuration file not found"
- Ensure check_ip.conf is in the same directory as marvn.sh

### "No message provided"
- Usage: `./marvn.sh "Your message"`
- Don't forget the quotes!

### Message fails to send
- Script will automatically try to refresh token
- Check that REFRESH_TOKEN in config is still valid
