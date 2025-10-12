#!/bin/bash

# VLC Remote Control Commands Examples
# This script demonstrates various commands to control VLC via HTTP interface

VLC_HOST="localhost"
VLC_PORT="8080"
VLC_PASSWORD="vlcremote"

# Base URL for VLC commands
VLC_URL="http://${VLC_HOST}:${VLC_PORT}/requests/status.xml"

# Function to send VLC command
vlc_cmd() {
    local command="$1"
    echo "Executing: $command"
    curl -s --user ":$VLC_PASSWORD" "${VLC_URL}?command=${command}"
    echo ""
}

# Function to get VLC status
vlc_status() {
    echo "Getting VLC status..."
    curl -s --user ":$VLC_PASSWORD" "${VLC_URL}" | grep -E "(state|position|time|length|volume)"
    echo ""
}

# Show usage
echo "VLC Remote Control Commands"
echo "============================"
echo ""

# PLAYBACK CONTROLS
echo "# Playback Controls"
echo "vlc_cmd 'pl_play'           # Play"
echo "vlc_cmd 'pl_pause'          # Pause/Resume"
echo "vlc_cmd 'pl_stop'           # Stop"
echo "vlc_cmd 'pl_next'           # Next item in playlist"
echo "vlc_cmd 'pl_previous'       # Previous item in playlist"
echo ""

# VOLUME CONTROLS
echo "# Volume Controls"
echo "vlc_cmd 'volume&val=100'    # Set volume to 100"
echo "vlc_cmd 'volume&val=200'    # Set volume to 200 (200%)"
echo "vlc_cmd 'volume&val=+20'    # Increase volume by 20"
echo "vlc_cmd 'volume&val=-20'    # Decrease volume by 20"
echo ""

# PLAYLIST MANAGEMENT
echo "# Playlist Management"
echo "vlc_cmd 'pl_empty'          # Clear playlist"
echo "vlc_cmd 'pl_random'         # Toggle random playback"
echo "vlc_cmd 'pl_loop'           # Toggle loop"
echo "vlc_cmd 'pl_repeat'         # Toggle repeat"
echo ""

# SEEKING
echo "# Seeking"
echo "vlc_cmd 'seek&val=50%'      # Seek to 50% of video"
echo "vlc_cmd 'seek&val=+30'      # Seek forward 30 seconds"
echo "vlc_cmd 'seek&val=-30'      # Seek backward 30 seconds"
echo "vlc_cmd 'seek&val=120'      # Seek to 120 seconds"
echo ""

# FULLSCREEN & ASPECT RATIO
echo "# Display Controls"
echo "vlc_cmd 'fullscreen'        # Toggle fullscreen"
echo "vlc_cmd 'aspectratio&val=16:9'   # Set aspect ratio to 16:9"
echo "vlc_cmd 'aspectratio&val=4:3'    # Set aspect ratio to 4:3"
echo ""

# ADD MEDIA TO PLAYLIST
echo "# Add Media to Playlist"
echo "# URL encode the file path:"
echo "FILE=\"/path/to/video.mp4\""
echo "ENCODED=\$(python3 -c \"import urllib.parse; print(urllib.parse.quote('\$FILE'))\")"
echo "curl -s --user \":\$VLC_PASSWORD\" \"${VLC_URL}?command=in_play&input=file://\${ENCODED}\""
echo ""
echo "# Or add without playing:"
echo "curl -s --user \":\$VLC_PASSWORD\" \"${VLC_URL}?command=in_enqueue&input=file://\${ENCODED}\""
echo ""

# STATUS INFORMATION
echo "# Get Status Information"
echo "vlc_status                  # Get current status"
echo "curl --user \":\$VLC_PASSWORD\" \"${VLC_URL}\" # Full XML status"
echo "curl --user \":\$VLC_PASSWORD\" \"http://${VLC_HOST}:${VLC_PORT}/requests/playlist.xml\" # Playlist info"
echo ""

# INTERACTIVE MODE
echo ""
echo "To execute commands interactively, uncomment the examples below:"
echo ""

# Uncomment to execute commands:
# vlc_cmd "pl_pause"
# sleep 2
# vlc_cmd "pl_play"
# vlc_status
