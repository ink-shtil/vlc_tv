#!/bin/bash

PARENT_DIR="/home/pda/vlc_tv"
CHANNELS_FILE="$PARENT_DIR/channels.txt"
INDEX_FILE="$PARENT_DIR/current_channel_index.txt"
SWITCH_SCRIPT="$PARENT_DIR/switch.sh"
CHANNELS_DIR_FILE="$PARENT_DIR/channels_directory.txt"
EXAMPLE_CHANNELS_DIR="/media/pda/SanDisk/videos/"

usage() {
    echo "Usage: $0 [next|previous|current] [channels_directory]"
    exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

ACTION="$1"

if [ $# -eq 2 ]; then
    CHANNELS_DIR="$2"
else
    # If channels_directory.txt does not exist, create it with the example path
    if [ ! -f "$CHANNELS_DIR_FILE" ]; then
        echo "$EXAMPLE_CHANNELS_DIR" > "$CHANNELS_DIR_FILE"
    fi
    CHANNELS_DIR=$(cat "$CHANNELS_DIR_FILE")
fi

# Regenerate channels.txt from subdirectories of CHANNELS_DIR, sorted by name
find "$CHANNELS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort > "$CHANNELS_FILE"

# Check if channels.txt exists and is not empty
if [ ! -s "$CHANNELS_FILE" ]; then
    echo "Error: $CHANNELS_FILE is missing or empty after scanning $CHANNELS_DIR."
    exit 1
fi

# Read channels into array
mapfile -t channels < "$CHANNELS_FILE"
num_channels=${#channels[@]}

if [ "$num_channels" -eq 0 ]; then
    echo "Error: No channels found in $CHANNELS_FILE after scanning $CHANNELS_DIR."
    exit 1
fi

# Read current index, default to 0 if missing/invalid
if [ -f "$INDEX_FILE" ]; then
    current_index=$(cat "$INDEX_FILE")
    if ! [[ "$current_index" =~ ^[0-9]+$ ]] || [ "$current_index" -ge "$num_channels" ]; then
        current_index=0
    fi
else
    current_index=0
fi

case "$ACTION" in
    next)
        new_index=$(( (current_index + 1) % num_channels ))
        echo "$new_index" > "$INDEX_FILE"
        channel_dir="${channels[$new_index]}"
        ;;
    previous)
        if [ "$current_index" -eq 0 ]; then
            new_index=$((num_channels - 1))
        else
            new_index=$((current_index - 1))
        fi
        echo "$new_index" > "$INDEX_FILE"
        channel_dir="${channels[$new_index]}"
        ;;
    current)
        channel_dir="${channels[$current_index]}"
        ;;
    *)
        usage
        ;;
esac

# Check if directory exists
if [ ! -d "$CHANNELS_DIR/$channel_dir" ]; then
    echo "Error: Channel directory '$CHANNELS_DIR/$channel_dir' does not exist."
    exit 1
fi

# Call switch.sh with the selected channel directory
bash "$SWITCH_SCRIPT" "$CHANNELS_DIR/$channel_dir"
