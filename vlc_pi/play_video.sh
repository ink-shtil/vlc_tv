#!/bin/bash

# Script to remotely control VLC media player on Raspberry Pi
# Usage: ./play_video.sh <video_file_path>

if [ -z "$1" ]; then
    echo "Usage: $0 <video_file_path>"
    exit 1
fi

VIDEO_PATH="$1"
VLC_HOST="localhost"
VLC_PORT="8080"
VLC_PASSWORD="vlcremote"

# Check if video file exists
if [ ! -f "$VIDEO_PATH" ]; then
    echo "Error: Video file '$VIDEO_PATH' not found"
    exit 1
fi

# Function to send VLC command
vlc_command() {
    local command="$1"
    curl -s --user ":$VLC_PASSWORD" \
        "http://${VLC_HOST}:${VLC_PORT}/requests/status.xml?command=${command}" \
        > /dev/null 2>&1
}

# Function to play a video file
vlc_play() {
    local file="$1"
    # URL encode the file path
    local encoded_path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$file'))")

    curl -s --user ":$VLC_PASSWORD" \
        "http://${VLC_HOST}:${VLC_PORT}/requests/status.xml?command=in_play&input=file://${encoded_path}" \
        > /dev/null 2>&1
}

# Clear playlist
echo "Clearing VLC playlist..."
vlc_command "pl_empty"
sleep 0.5

# Add and play video
echo "Adding and playing: $VIDEO_PATH"
vlc_play "$VIDEO_PATH"
sleep 0.5

# Start playback
vlc_command "pl_play"

echo "Video playback started successfully"
