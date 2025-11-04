#!/bin/bash
# Choose channel by number prefix (01*, 02*, etc.)
# Usage: ./choose_channel.sh <number>
# Example: ./choose_channel.sh 1  (selects directory starting with "01")

PARENT_DIR="/home/pda/vlc_tv"
CHANNELS_DIR_FILE="$PARENT_DIR/channels_directory.txt"
SWITCH_SCRIPT="$PARENT_DIR/switch.sh"
EXAMPLE_CHANNELS_DIR="/media/pda/SanDisk/videos/"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <channel_number>"
    echo "Example: $0 1  (selects directory starting with '01')"
    exit 1
fi

CHANNEL_NUM="$1"

# Validate input is a number
if ! [[ "$CHANNEL_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Channel number must be a positive integer"
    exit 1
fi

# Format as zero-padded (01, 02, etc.)
PREFIX=$(printf "%02d" "$CHANNEL_NUM")

# Read channels directory
if [ ! -f "$CHANNELS_DIR_FILE" ]; then
    echo "$EXAMPLE_CHANNELS_DIR" > "$CHANNELS_DIR_FILE"
fi
CHANNELS_DIR=$(cat "$CHANNELS_DIR_FILE")

# Find directory matching prefix
MATCH_DIR=$(find "$CHANNELS_DIR" -mindepth 1 -maxdepth 1 -type d -name "${PREFIX}*" | head -n 1)

if [ -z "$MATCH_DIR" ]; then
    echo "Error: No channel directory found with prefix '${PREFIX}'"
    exit 1
fi

# Get just the directory name (not full path)
CHANNEL_NAME=$(basename "$MATCH_DIR")

# Switch to the channel
bash "$SWITCH_SCRIPT" "$CHANNELS_DIR/$CHANNEL_NAME"

