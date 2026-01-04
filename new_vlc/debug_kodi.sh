#!/bin/bash
# Step-by-step debug script for KODI remote control
# Tests default port authentication and all player_control.sh commands

USER_HOME="${HOME:-/home/pda}"
PLAYER_CONFIG_FILE="$USER_HOME/vlc_tv/player_config.txt"

# Default values
KODI_HOST="127.0.0.1"
KODI_PORT="8080"
KODI_USER=""
KODI_PASS=""

# Load configuration
if [ -f "$PLAYER_CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        case "$key" in
            KODI_HOST) KODI_HOST="$value" ;;
            KODI_PORT) KODI_PORT="$value" ;;
            KODI_USER) KODI_USER="$value" ;;
            KODI_PASS) KODI_PASS="$value" ;;
        esac
    done < "$PLAYER_CONFIG_FILE"
fi

# Test video file
TEST_VIDEO="/media/pda/SanDisk/videos/05_classic/The_Bank_1915.mp4"

# Function to escape string for JSON
escape_json_string() {
    local str="$1"
    # Escape backslashes first
    str="${str//\\/\\\\}"
    # Escape double quotes
    str="${str//\"/\\\"}"
    echo "$str"
}

# Function to send JSON-RPC command and show response
send_kodi_debug() {
    local method="$1"
    local params="$2"
    local jsonrpc_url="http://${KODI_HOST}:${KODI_PORT}/jsonrpc"
    
    if [ -z "$params" ]; then
        params="{}"
    fi
    
    local json_payload
    json_payload=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "$method",
    "params": $params,
    "id": 1
}
EOF
)
    
    echo "Request:"
    echo "  URL: $jsonrpc_url"
    echo "  Method: $method"
    echo "  Payload:"
    echo "$json_payload" | sed 's/^/    /'
    echo ""
    
    # Build curl command with auth if needed
    local curl_cmd
    local response_file="/tmp/kodi_response_$$.json"
    
    if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
        curl_cmd="curl -s -X POST -u ${KODI_USER}:${KODI_PASS} -H \"Content-Type: application/json\" -d '$json_payload' -w \"\nHTTP_CODE:%{http_code}\" -o \"$response_file\" \"$jsonrpc_url\""
    else
        curl_cmd="curl -s -X POST -H \"Content-Type: application/json\" -d '$json_payload' -w \"\nHTTP_CODE:%{http_code}\" -o \"$response_file\" \"$jsonrpc_url\""
    fi
    
    # Execute curl command
    eval "$curl_cmd" > /dev/null 2>&1
    
    # Extract HTTP code
    local http_code
    http_code=$(tail -n 1 "$response_file" 2>/dev/null | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    
    # Remove HTTP_CODE line from response
    if [ -f "$response_file" ]; then
        sed -i '$ d' "$response_file" 2>/dev/null || sed '$ d' "$response_file" 2>/dev/null
    fi
    
    echo "Response:"
    echo "  HTTP Status: ${http_code:-unknown}"
    if [ -f "$response_file" ] && [ -s "$response_file" ]; then
        echo "  Body:"
        cat "$response_file" | jq '.' 2>/dev/null || cat "$response_file" | sed 's/^/    /'
        rm -f "$response_file"
    else
        echo "  (No response body)"
        rm -f "$response_file"
    fi
    echo ""
    echo "---"
    echo ""
}

# Print header
echo "=========================================="
echo "KODI Step-by-Step Debug Script"
echo "=========================================="
echo "Host: $KODI_HOST"
echo "Port: $KODI_PORT"
if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
    echo "Auth: $KODI_USER:***"
else
    echo "Auth: None"
fi
echo "Test Video: $TEST_VIDEO"
echo "=========================================="
echo ""

# Step 1: Test Default Port Authentication
echo "=== Step 1: Test Default Port Authentication ==="
echo "Testing simple application request (Application.GetProperties)..."
echo ""
send_kodi_debug "Application.GetProperties" '{"properties": ["version"]}'
sleep 1

# Step 2: Test All player_control.sh Commands
echo "=== Step 2: Test All player_control.sh Commands ==="
echo ""

# Convert test video path to file:// URL format
file_url="$TEST_VIDEO"
if [[ ! "$file_url" =~ ^file:// ]] && [[ ! "$file_url" =~ ^http ]]; then
    file_url="file://$file_url"
fi
# Escape special characters for JSON
file_url=$(escape_json_string "$file_url")

echo "Test file URL: $file_url"
echo ""

# Test 1: clear command
echo "Test 1: clear command"
echo "  -> Playlist.Clear + Input.Back"
echo ""
send_kodi_debug "Playlist.Clear" '{"playlistid": 1}'
sleep 1
send_kodi_debug "Input.Back" '{}'
sleep 1

# Test 2: add command
echo "Test 2: add command"
echo "  -> Player.Open with test video"
echo ""
send_kodi_debug "Player.Open" "{\"item\": {\"file\": \"$file_url\"}}"
sleep 2

# Test 3: enqueue command
echo "Test 3: enqueue command"
echo "  -> Playlist.Add with test video"
echo ""
send_kodi_debug "Playlist.Add" "{\"playlistid\": 1, \"item\": {\"file\": \"$file_url\"}}"
sleep 1

# Test 4: next command
echo "Test 4: next command"
echo "  -> Player.GoTo to next"
echo ""
send_kodi_debug "Player.GoTo" '{"playerid": 1, "to": "next"}'
sleep 1

# Test 5: loop on command
echo "Test 5: loop on command"
echo "  -> Player.SetRepeat (all)"
echo ""
send_kodi_debug "Player.SetRepeat" '{"playerid": 1, "repeat": "all"}'
sleep 1

# Test 6: loop off command
echo "Test 6: loop off command"
echo "  -> Player.SetRepeat (off)"
echo ""
send_kodi_debug "Player.SetRepeat" '{"playerid": 1, "repeat": "off"}'
sleep 1

# Test 7: seek command
echo "Test 7: seek command"
echo "  -> Player.Seek (50%)"
echo ""
send_kodi_debug "Player.Seek" '{"playerid": 1, "value": {"percentage": 50}}'
sleep 1

echo "=========================================="
echo "Debug session complete!"
echo "=========================================="
