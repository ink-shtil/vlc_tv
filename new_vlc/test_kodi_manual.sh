#!/bin/bash
# Manual KODI test commands - copy and paste these individually
# Useful for debugging specific issues

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME:-/home/pda}"
PLAYER_CONFIG_FILE="$USER_HOME/vlc_tv/player_config.txt"

KODI_HOST="127.0.0.1"
KODI_PORT="8080"
KODI_USER=""
KODI_PASS=""

if [ -f "$PLAYER_CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        value="${value%\"}"
        value="${value#\"}"
        case "$key" in
            KODI_HOST) KODI_HOST="$value" ;;
            KODI_PORT) KODI_PORT="$value" ;;
            KODI_USER) KODI_USER="$value" ;;
            KODI_PASS) KODI_PASS="$value" ;;
        esac
    done < "$PLAYER_CONFIG_FILE"
fi

# Build auth string
AUTH=""
if [ -n "$KODI_USER" ] && [ -n "$KODI_PASS" ]; then
    AUTH="-u ${KODI_USER}:${KODI_PASS}"
fi

BASE_URL="http://${KODI_HOST}:${KODI_PORT}/jsonrpc"

echo "=========================================="
echo "KODI Manual Test Commands"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "Auth: ${AUTH:-None}"
echo ""
echo "Copy and paste these commands:"
echo ""
echo "--- 1. Test Connection (Ping) ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"JSONRPC.Ping\",\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 2. Get Active Players ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.GetActivePlayers\",\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 3. Clear Playlist (Video) ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Clear\",\"params\":{\"playlistid\":1},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 4. Get Playlist Items ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.GetItems\",\"params\":{\"playlistid\":1},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 5. Open File (Replace TEST_FILE_PATH) ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.Open\",\"params\":{\"item\":{\"file\":\"file:///path/to/video.mp4\"}},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 6. Add to Playlist (Replace TEST_FILE_PATH) ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"file:///path/to/video.mp4\"}},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 7. Start Playback (if player exists) ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.PlayPause\",\"params\":{\"playerid\":1},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 8. Go Next ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.GoNext\",\"params\":{\"playerid\":1,\"to\":\"next\"},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 9. Set Repeat Mode ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.SetRepeat\",\"params\":{\"playerid\":1,\"repeat\":\"all\"},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "--- 10. Get Player Properties ---"
echo "curl -s -X POST $AUTH -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"method\":\"Player.GetProperties\",\"params\":{\"playerid\":1,\"properties\":[\"time\",\"totaltime\",\"speed\",\"repeat\"]},\"id\":1}' \"$BASE_URL\" | jq '.'"
echo ""
echo "=========================================="
echo ""
echo "For file paths with spaces, encode them:"
echo "  file:///path/to/file%20with%20spaces.mp4"
echo ""
echo "Example:"
echo "  file:///media/pda/SanDisk/videos/channel1/video%20file.mp4"
echo ""

