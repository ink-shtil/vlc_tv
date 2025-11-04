#!/bin/bash
# Debug script for KODI channel switching
# Tests each JSON-RPC command individually to identify issues

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


# Send JSON-RPC command and show response
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
    
    echo "URL: $jsonrpc_url"
    echo "Payload:"
    echo "$json_payload" | jq '.' 2>/dev/null || echo "$json_payload"
    echo ""
    echo "Response:"
    
    # Build and execute curl command with verbose output
    local response_file="/tmp/kodi_response_$$.json"
    local stderr_file="/tmp/kodi_stderr_$$.txt"
    
    if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
        curl -v -X POST -u "${KODI_USER}:${KODI_PASS}" \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            -w "\nHTTP_CODE:%{http_code}" \
            -o "$response_file" \
            "$jsonrpc_url" 2>"$stderr_file"
    else
        curl -v -X POST \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            -w "\nHTTP_CODE:%{http_code}" \
            -o "$response_file" \
            "$jsonrpc_url" 2>"$stderr_file"
    fi
    
    # Show curl verbose output (connection info)
    echo "Curl verbose output:"
    cat "$stderr_file" 2>/dev/null || echo "(No verbose output)"
    rm -f "$stderr_file"
    
    # Extract HTTP code
    local http_code
    http_code=$(tail -n 1 "$response_file" 2>/dev/null | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    
    # Remove HTTP_CODE line from response
    if [ -f "$response_file" ]; then
        sed -i '$ d' "$response_file" 2>/dev/null || sed '$ d' "$response_file" 2>/dev/null
    fi
    
    echo ""
    echo "HTTP Status Code: ${http_code:-unknown}"
    echo ""
    
    # Show response body if any
    if [ -f "$response_file" ] && [ -s "$response_file" ]; then
        echo "Response body:"
        cat "$response_file" | jq '.' 2>/dev/null || cat "$response_file"
        rm -f "$response_file"
    else
        echo "(No response body)"
        rm -f "$response_file"
    fi
    echo ""
    echo "---"
    echo ""
}

# Print header
echo "=========================================="
echo "KODI Channel Switching Debug Tool"
echo "=========================================="
echo "Host: $KODI_HOST"
echo "Port: $KODI_PORT"
if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
    echo "Auth: $KODI_USER:***"
else
    echo "Auth: None"
fi
echo "=========================================="
echo ""

# Test if jq is available (for pretty JSON)
if ! command -v jq >/dev/null 2>&1; then
    echo "Note: jq not found - JSON output will not be formatted"
    echo ""
fi

# Pre-flight checks
echo "=== Pre-flight Checks ==="
echo "1. Testing if KODI is accessible on $KODI_HOST:$KODI_PORT..."
if command -v nc >/dev/null 2>&1 || command -v netcat >/dev/null 2>&1; then
    if nc -z -w 2 "$KODI_HOST" "$KODI_PORT" 2>/dev/null || netcat -z -w 2 "$KODI_HOST" "$KODI_PORT" 2>/dev/null; then
        echo "✓ Port $KODI_PORT is open on $KODI_HOST"
    else
        echo "✗ ERROR: Port $KODI_PORT is NOT accessible on $KODI_HOST"
        echo ""
        echo "Possible issues:"
        echo "  - KODI is not running"
        echo "  - KODI JSON-RPC is disabled"
        echo "  - Wrong port (check KODI settings -> Services -> Control -> Allow remote control)"
        echo "  - Wrong host (if remote, check firewall)"
        echo ""
        echo "Checking for KODI processes..."
        ps aux | grep -i kodi | grep -v grep || echo "No KODI processes found"
        echo ""
        echo "To enable JSON-RPC in KODI:"
        echo "  Settings -> Services -> Control -> Enable HTTP and set port"
        echo ""
        read -p "Press Enter to continue anyway, or Ctrl+C to exit..."
    fi
else
    echo "Note: nc/netcat not available, skipping port check"
fi
echo ""

# Step 1: Test Basic Connectivity
echo "=== Step 1: Test Basic Connectivity ==="
echo "Testing JSON-RPC accessibility..."
send_kodi_debug "JSONRPC.Ping" "{}"

echo "Getting active players..."
send_kodi_debug "Player.GetActivePlayers" "{}"

echo "Getting application properties..."
send_kodi_debug "Application.GetProperties" '{"properties": ["version"]}'

# Step 2: Test File Path Handling (interactive)
echo "=== Step 2: Test File Path Handling ==="
echo "Enter a test video file path to test (or press Enter to skip):"
read -r test_file

if [ -n "$test_file" ] && [ -f "$test_file" ]; then
    echo "Testing with file: $test_file"
    echo ""
    
    # Convert to file:// URL with proper encoding
    file_url="file://$test_file"
    # URL encode: spaces -> %20, # -> %23, etc.
    # For now, just handle spaces (bash native encoding)
    file_url="${file_url// /%20}"
    file_url="${file_url//#/%23}"
    
    echo "Original path: $test_file"
    echo "File URL (encoded): $file_url"
    echo "Note: If file has special chars, you may need to test manual encoding"
    echo ""
    
    # Test with Playlist.Add
    echo "Testing Playlist.Add..."
    send_kodi_debug "Playlist.Add" "{\"playlistid\": 1, \"item\": {\"file\": \"$file_url\"}}"
    
    # Test with Player.Open
    echo "Testing Player.Open..."
    send_kodi_debug "Player.Open" "{\"item\": {\"file\": \"$file_url\"}}"
else
    echo "Skipping file path test (no file provided or file not found)"
fi
echo ""

# Step 3: Test Playlist.Clear
echo "=== Step 3: Test Playlist.Clear ==="
send_kodi_debug "Playlist.Clear" '{"playlistid": 1}'

# Step 4: Test Playlist.GetItems (check playlist state)
echo "=== Step 4: Check Playlist State ==="
send_kodi_debug "Playlist.GetItems" '{"playlistid": 1}'

# Step 5: Test with example file path (if provided)
if [ -n "$test_file" ] && [ -f "$test_file" ]; then
    echo "=== Step 5: Test Complete Flow ==="
    
    file_url="file://$test_file"
    file_url="${file_url// /%20}"
    
    # Clear playlist
    echo "1. Clearing playlist..."
    send_kodi_debug "Playlist.Clear" '{"playlistid": 1}'
    sleep 1
    
    # Add first file with Player.Open (should auto-play)
    echo "2. Opening first file with Player.Open..."
    send_kodi_debug "Player.Open" "{\"item\": {\"file\": \"$file_url\"}}"
    sleep 2
    
    # Check active players
    echo "3. Checking active players..."
    send_kodi_debug "Player.GetActivePlayers" "{}"
    sleep 1
    
    # Get player properties to see if playing
    echo "4. Getting player properties..."
    send_kodi_debug "Player.GetProperties" '{"playerid": 1, "properties": ["time", "totaltime", "speed"]}'
    sleep 1
    
    # Test Player.GoNext
    echo "5. Testing Player.GoNext..."
    send_kodi_debug "Player.GoNext" '{"playerid": 1, "to": "next"}'
    sleep 1
    
    # Test Player.SetRepeat
    echo "6. Testing Player.SetRepeat (all)..."
    send_kodi_debug "Player.SetRepeat" '{"playerid": 1, "repeat": "all"}'
    sleep 1
    
    echo "7. Getting repeat status..."
    send_kodi_debug "Player.GetProperties" '{"playerid": 1, "properties": ["repeat"]}'
fi

echo ""
echo "=========================================="
echo "Debug session complete!"
echo "=========================================="

