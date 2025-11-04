#!/bin/bash
# Player abstraction layer for VLC and KODI remote control
# Provides unified interface for controlling different media players

# Determine script directory and find config files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME:-/home/pda}"
PLAYER_CONFIG_FILE="$USER_HOME/vlc_tv/player_config.txt"

# Default player settings
PLAYER_TYPE="${PLAYER_TYPE:-vlc}"
VLC_HOST="${VLC_HOST:-127.0.0.1}"
VLC_PORT="${VLC_PORT:-4212}"
KODI_HOST="${KODI_HOST:-127.0.0.1}"
KODI_PORT="${KODI_PORT:-8080}"
KODI_USER="${KODI_USER:-}"
KODI_PASS="${KODI_PASS:-}"

# Load player configuration if file exists
if [ -f "$PLAYER_CONFIG_FILE" ]; then
    # Source the config file safely
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove any quotes from value
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        
        # Export the variable
        export "$key=$value"
    done < "$PLAYER_CONFIG_FILE"
fi

# Validate player type
if [ "$PLAYER_TYPE" != "vlc" ] && [ "$PLAYER_TYPE" != "kodi" ]; then
    echo "Error: Invalid PLAYER_TYPE '$PLAYER_TYPE'. Must be 'vlc' or 'kodi'." >&2
    exit 1
fi

# Function to send command to VLC via netcat
send_vlc_command() {
    local cmd="$1"
    echo "$cmd" | nc -q 0 "$VLC_HOST" "$VLC_PORT" 2>/dev/null
}

# Function to escape string for JSON
escape_json_string() {
    local str="$1"
    # Escape backslashes first
    str="${str//\\/\\\\}"
    # Escape double quotes
    str="${str//\"/\\\"}"
    echo "$str"
}

# Function to send JSON-RPC command to KODI via curl
send_kodi_command() {
    local method="$1"
    shift
    local params="$*"
    
    local jsonrpc_url="http://${KODI_HOST}:${KODI_PORT}/jsonrpc"
    local curl_auth=""
    
    # Build authentication if credentials provided
    if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
        curl_auth="-u ${KODI_USER}:${KODI_PASS}"
    fi
    
    # Build JSON-RPC request
    # If params is empty, use empty object
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
    
    curl -s -X POST $curl_auth \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "$jsonrpc_url" > /dev/null 2>&1
}

# Main function to send player-agnostic commands
send_command() {
    local command="$1"
    shift
    local args="$*"
    
    if [ "$PLAYER_TYPE" = "vlc" ]; then
        case "$command" in
            clear)
                send_vlc_command "clear"
                ;;
            add)
                if [ -n "$args" ]; then
                    send_vlc_command "add $args"
                else
                    echo "Error: 'add' command requires a file path" >&2
                    return 1
                fi
                ;;
            enqueue)
                if [ -n "$args" ]; then
                    send_vlc_command "enqueue $args"
                else
                    echo "Error: 'enqueue' command requires a file path" >&2
                    return 1
                fi
                ;;
            next)
                send_vlc_command "next"
                ;;
            loop)
                if [ "$args" = "on" ]; then
                    send_vlc_command "loop on"
                elif [ "$args" = "off" ]; then
                    send_vlc_command "loop off"
                fi
                ;;
            seek)
                if [ -n "$args" ]; then
                    send_vlc_command "seek $args"
                else
                    echo "Error: 'seek' command requires a percentage" >&2
                    return 1
                fi
                ;;
            *)
                echo "Error: Unknown VLC command '$command'" >&2
                return 1
                ;;
        esac
    elif [ "$PLAYER_TYPE" = "kodi" ]; then
        case "$command" in
            clear)
                # Clear the current playlist
                send_kodi_command "Playlist.Clear" '{"playlistid": 1}'
                # Hide OSD by sending back action (closes any open OSD menus/overlays)
                send_kodi_command "Input.Back" '{}'
                ;;
            add)
                if [ -n "$args" ]; then
                    # Convert file path to file:// URL format and escape for JSON
                    local file_url="$args"
                    if [[ ! "$file_url" =~ ^file:// ]] && [[ ! "$file_url" =~ ^http ]]; then
                        # Convert absolute path to file:// URL
                        file_url="file://$file_url"
                    fi
                    # Escape special characters for JSON
                    file_url=$(escape_json_string "$file_url")
                    # Open and play file immediately (replaces current playlist)
                    send_kodi_command "Player.Open" "{\"item\": {\"file\": \"$file_url\"}}"
                else
                    echo "Error: 'add' command requires a file path" >&2
                    return 1
                fi
                ;;
            enqueue)
                if [ -n "$args" ]; then
                    # Convert file path to file:// URL format and escape for JSON
                    local file_url="$args"
                    if [[ ! "$file_url" =~ ^file:// ]] && [[ ! "$file_url" =~ ^http ]]; then
                        file_url="file://$file_url"
                    fi
                    # Escape special characters for JSON
                    file_url=$(escape_json_string "$file_url")
                    # Add to playlist without interrupting playback
                    send_kodi_command "Playlist.Add" "{\"playlistid\": 1, \"item\": {\"file\": \"$file_url\"}}"
                else
                    echo "Error: 'enqueue' command requires a file path" >&2
                    return 1
                fi
                ;;
            next)
                # Go to next item in playlist
                send_kodi_command "Player.GoTo" '{"playerid": 1, "to": "next"}'
                ;;
            loop)
                if [ "$args" = "on" ]; then
                    # Set repeat mode to all (loop entire playlist)
                    send_kodi_command "Player.SetRepeat" '{"playerid": 1, "repeat": "all"}'
                elif [ "$args" = "off" ]; then
                    send_kodi_command "Player.SetRepeat" '{"playerid": 1, "repeat": "off"}'
                fi
                ;;
            seek)
                if [ -n "$args" ]; then
                    # Parse percentage (e.g., "50%" -> 50)
                    local percent="${args%%%}"
                    if [[ "$percent" =~ ^[0-9]+$ ]]; then
                        # KODI requires value as object with percentage key
                        send_kodi_command "Player.Seek" "{\"playerid\": 1, \"value\": {\"percentage\": $percent}}"
                    else
                        echo "Error: Invalid seek percentage '$args'" >&2
                        return 1
                    fi
                else
                    echo "Error: 'seek' command requires a percentage" >&2
                    return 1
                fi
                ;;
            *)
                echo "Error: Unknown KODI command '$command'" >&2
                return 1
                ;;
        esac
    fi
}

