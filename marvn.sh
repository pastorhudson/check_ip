#!/bin/bash

# Simple utility to send messages via marvn.app
# Usage: ./marvn.sh "Your message here"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration file location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/check_ip.conf"

# Check for message argument
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No message provided${NC}"
    echo "Usage: $0 \"Your message here\""
    exit 1
fi

MESSAGE="$1"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please create check_ip.conf in the same directory as this script."
    exit 1
fi

# Source the config file
source "$CONFIG_FILE"

# Function to update config file with new tokens
update_config_file() {
    echo "Updating configuration file..."
    
    # Create temporary file
    TEMP_CONFIG="${CONFIG_FILE}.tmp"
    
    # Read current config and update tokens
    while IFS= read -r line; do
        if [[ $line =~ ^MESSAGE_TOKEN= ]]; then
            echo "MESSAGE_TOKEN=\"$MESSAGE_TOKEN\""
        elif [[ $line =~ ^REFRESH_TOKEN= ]]; then
            echo "REFRESH_TOKEN=\"$REFRESH_TOKEN\""
        else
            echo "$line"
        fi
    done < "$CONFIG_FILE" > "$TEMP_CONFIG"
    
    # Atomically replace config file
    if mv "$TEMP_CONFIG" "$CONFIG_FILE"; then
        echo -e "${GREEN}✓ Configuration file updated${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update configuration file${NC}"
        rm -f "$TEMP_CONFIG"
        return 1
    fi
}

# Function to refresh the token
refresh_token() {
    echo "Attempting to refresh token..."
    
    REFRESH_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST --location "https://marvn.app/refresh" \
      -H "Content-Type: application/json" \
      -d '{"token": "'"$REFRESH_TOKEN"'"}')
    
    # Split response and HTTP code
    REFRESH_HTTP_CODE=$(echo "$REFRESH_RESPONSE" | tail -n1)
    REFRESH_BODY=$(echo "$REFRESH_RESPONSE" | sed '$d')
    
    if [ "$REFRESH_HTTP_CODE" -eq 200 ] || [ "$REFRESH_HTTP_CODE" -eq 201 ]; then
        # Extract new tokens from response
        NEW_MESSAGE_TOKEN=$(echo "$REFRESH_BODY" | grep -o '"token":"[^"]*' | head -1 | cut -d'"' -f4)
        NEW_REFRESH_TOKEN=$(echo "$REFRESH_BODY" | grep -o '"refresh_token":"[^"]*' | head -1 | cut -d'"' -f4)
        
        if [ -n "$NEW_MESSAGE_TOKEN" ]; then
            echo -e "${GREEN}✓ Token refreshed successfully${NC}"
            MESSAGE_TOKEN="$NEW_MESSAGE_TOKEN"
            
            # Update refresh token if provided
            if [ -n "$NEW_REFRESH_TOKEN" ]; then
                REFRESH_TOKEN="$NEW_REFRESH_TOKEN"
            fi
            
            # Update config file with new tokens
            update_config_file
            return 0
        else
            echo -e "${RED}✗ Failed to extract new token from response${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to refresh token (HTTP $REFRESH_HTTP_CODE)${NC}"
        return 1
    fi
}

# Function to send message
send_message() {
    local message="$1"
    local token="$2"
    
    # Simple and portable JSON escaping
    # Escape backslashes, quotes, and convert newlines to \n
    local escaped_message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '\r' | sed 's/\r/\\n/g')
    
    # Build JSON payload
    local json_payload='{"message": "'"$escaped_message"'", "token": "'"$token"'"}'
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST --location "https://marvn.app/add_message" \
      -H "Content-Type: application/json" \
      -d "$json_payload")
    
    # Split response and HTTP code
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
echo "Sending message..."

# Try to send message with current token
if send_message "$MESSAGE" "$MESSAGE_TOKEN"; then
    echo -e "${GREEN}✓ Message sent successfully${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Failed to send with current token, attempting to refresh...${NC}"
    
    # Refresh token and try again
    if refresh_token; then
        if send_message "$MESSAGE" "$MESSAGE_TOKEN"; then
            echo -e "${GREEN}✓ Message sent successfully after token refresh${NC}"
            exit 0
        else
            echo -e "${RED}✗ Failed to send message even after token refresh${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Failed to refresh token, message not sent${NC}"
        exit 1
    fi
fi
