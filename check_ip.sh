#!/bin/bash

# Script to check if quarteredcircle.net IP matches current public IP
# If they don't match, sends a notification via marvn.app

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration file location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/check_ip.conf"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please create check_ip.conf in the same directory as this script."
    exit 1
fi

# Source the config file
source "$CONFIG_FILE"

# Convert space-separated domains to array
if [ -n "$DOMAINS" ]; then
    IFS=' ' read -r -a DOMAINS_ARRAY <<< "$DOMAINS"
else
    echo -e "${RED}Error: No domains specified in configuration${NC}"
    exit 1
fi

# Function to refresh the token
refresh_token() {
    echo "Attempting to refresh token..."
    
    REFRESH_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST --location "https://marvn.app/refresh" \
      -H "Content-Type: application/json" \
      -d '{"token": "'"$REFRESH_TOKEN"'"}')
    
    # Split response and HTTP code
    REFRESH_HTTP_CODE=$(echo "$REFRESH_RESPONSE" | tail -n1)
    REFRESH_BODY=$(echo "$REFRESH_RESPONSE" | sed '$d')
    
    echo "DEBUG: Refresh HTTP Code: $REFRESH_HTTP_CODE"
    echo "DEBUG: Refresh Response: $REFRESH_BODY"
    
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
                echo "  New refresh token received"
            fi
            
            # Update config file with new tokens
            update_config_file
            return 0
        else
            echo -e "${RED}✗ Failed to extract new token from response${NC}"
            echo "Response: $REFRESH_BODY"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to refresh token (HTTP $REFRESH_HTTP_CODE)${NC}"
        echo "Response: $REFRESH_BODY"
        return 1
    fi
}

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

# Function to send message
send_message() {
    local message="$1"
    local token="$2"
    
    # Simple and portable JSON escaping
    # Escape backslashes, quotes, and convert newlines to \n
    local escaped_message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '\r' | sed 's/\r/\\n/g')
    
    # Build JSON payload
    local json_payload='{"message": "'"$escaped_message"'", "token": "'"$token"'"}'
    
    # Debug output
    echo "DEBUG: Sending request to https://marvn.app/add_message"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST --location "https://marvn.app/add_message" \
      -H "Content-Type: application/json" \
      -d "$json_payload")
    
    # Split response and HTTP code
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    echo "DEBUG: HTTP Code: $HTTP_CODE"
    echo "DEBUG: Response Body: $BODY"
    
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
        return 0
    else
        return 1
    fi
}

# Allow command-line arguments to override default domains
if [ $# -gt 0 ]; then
    DOMAINS_ARRAY=("$@")
    echo "Using domains from command line: ${DOMAINS_ARRAY[*]}"
else
    echo "Using domains from config: ${DOMAINS_ARRAY[*]}"
fi

# Get current public IP address once
echo "Checking current public IP address..."
CURRENT_IP=$(curl -s ifconfig.me)

# Check if we got a valid IP
if [ -z "$CURRENT_IP" ]; then
    echo -e "${RED}Error: Could not get current public IP${NC}"
    exit 1
fi

echo "Current IP: $CURRENT_IP"
echo ""

# Arrays to track results
declare -a MISMATCHED_DOMAINS
declare -a MATCHED_DOMAINS
declare -a FAILED_DOMAINS

# Check each domain
for DOMAIN in "${DOMAINS_ARRAY[@]}"; do
    echo "Checking $DOMAIN..."
    
    # Get the IP address of the domain
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    
    # Fallback to host command if dig fails
    if [ -z "$DOMAIN_IP" ]; then
        DOMAIN_IP=$(host "$DOMAIN" | grep "has address" | awk '{print $4}' | head -n1)
    fi
    
    # Check if we got a valid IP
    if [ -z "$DOMAIN_IP" ]; then
        echo -e "${RED}  ✗ Could not resolve $DOMAIN${NC}"
        FAILED_DOMAINS+=("$DOMAIN")
    elif [ "$DOMAIN_IP" = "$CURRENT_IP" ]; then
        echo -e "${GREEN}  ✓ $DOMAIN matches ($DOMAIN_IP)${NC}"
        MATCHED_DOMAINS+=("$DOMAIN")
    else
        echo -e "${YELLOW}  ⚠ $DOMAIN does NOT match (Domain: $DOMAIN_IP, Current: $CURRENT_IP)${NC}"
        MISMATCHED_DOMAINS+=("$DOMAIN:$DOMAIN_IP")
    fi
    echo ""
done

# Summary
echo "=========================================="
echo "Summary:"
echo "  Matched: ${#MATCHED_DOMAINS[@]}"
echo "  Mismatched: ${#MISMATCHED_DOMAINS[@]}"
echo "  Failed to resolve: ${#FAILED_DOMAINS[@]}"
echo "=========================================="

# Send notification if there are mismatches
if [ ${#MISMATCHED_DOMAINS[@]} -gt 0 ]; then
    echo ""
    echo "Building notification message..."
    
    MESSAGE="IP Address mismatch detected! Current IP: $CURRENT_IP"$'\n'$'\n'"Mismatched domains:"
    
    for ENTRY in "${MISMATCHED_DOMAINS[@]}"; do
        DOMAIN_NAME="${ENTRY%%:*}"
        DOMAIN_IP="${ENTRY#*:}"
        MESSAGE="$MESSAGE"$'\n'"  - $DOMAIN_NAME: $DOMAIN_IP"
    done
    
    if [ ${#FAILED_DOMAINS[@]} -gt 0 ]; then
        MESSAGE="$MESSAGE"$'\n'$'\n'"Failed to resolve:"
        for DOMAIN in "${FAILED_DOMAINS[@]}"; do
            MESSAGE="$MESSAGE"$'\n'"  - $DOMAIN"
        done
    fi
    
    echo "Sending notification..."
    
    # Try to send message with current token
    if send_message "$MESSAGE" "$MESSAGE_TOKEN"; then
        echo -e "${GREEN}✓ Notification sent successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to send with current token, attempting to refresh...${NC}"
        
        # Refresh token and try again
        if refresh_token; then
            if send_message "$MESSAGE" "$MESSAGE_TOKEN"; then
                echo -e "${GREEN}✓ Notification sent successfully after token refresh${NC}"
            else
                echo -e "${RED}✗ Failed to send notification even after token refresh${NC}"
                exit 1
            fi
        else
            echo -e "${RED}✗ Failed to refresh token, notification not sent${NC}"
            exit 1
        fi
    fi
elif [ ${#FAILED_DOMAINS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warning: Some domains failed to resolve, but all resolvable domains match${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All domains match - No action needed${NC}"
    exit 0
fi
