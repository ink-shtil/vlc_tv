#!/bin/bash

# Load player abstraction layer
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/player_control.sh"

random_file_or_directory() {
    local command="$1"
    local directory="$2"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get the total number of files and directories in the directory
    local total_items=$(find "$directory" -mindepth 1 -maxdepth 1 | wc -l)

    # Check if there are any items in the directory
    if [ "$total_items" -eq 0 ]; then
        echo "No files or directories found in directory: $directory"
        return 1
    fi

    # Generate a random number between 1 and the total number of items
    local random_number=$((RANDOM % total_items + 1))

    # Get the random item using the random number
    local random_item=$(find "$directory" -mindepth 1 -maxdepth 1 | head -n "$random_number" | tail -n 1)

    # Check if the random item is a directory
    if [ -d "$random_item" ]; then
        # Enqueue or add all files from the directory
        enqueue_all_files_from_directory "$command" "$random_item"
    else
        # Enqueue or add the file
        echo "->>> $command $random_item"
        send_command "$command" "$random_item"
    fi
}

# Function to get a random number between a and b
get_random_number() {
  local a=$1
  local b=$2

  # Ensure a is less than or equal to b
  if [ "$a" -gt "$b" ]; then
    echo "Error: a must be less than or equal to b"
    return 1
  fi

  # Generate a random number between a and b
  local range=$((b - a + 1))
  local random_number=$((RANDOM % range + a))

  echo "$random_number"
}

# Function to enqueue or add all files from a directory
enqueue_all_files_from_directory() {
    local command="$1"
    local directory="$2"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get all files in the directory (handles whitespaces)
    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        echo "->>> $command $file"
        send_command "$command" "$file"
    done

    # Check if any files were processed
    if [ -z "$(find "$directory" -type f -print0 | head -c 1)" ]; then
        echo "No files found in directory: $directory"
        return 1
    fi
}

# Function to control video playback randomly
function play_random_video() {
    local directory="${1:-/home/pda/vlc_tv/noises}"

    # Clear playlist and add initial video
    send_command "clear"
    random_file_or_directory "add" "/home/pda/vlc_tv/noises"

    # Build playlist with up to 20 unique random videos (no duplicates)
    # Collect all available items and shuffle them
    local total_items
    total_items=$(find "$directory" -mindepth 1 -maxdepth 1 | wc -l)
    
    if [ "$total_items" -eq 0 ]; then
        echo "No items found in directory: $directory"
        return 1
    fi
    
    # Determine how many items to add (up to 20, or all if fewer)
    local items_to_add=20
    if [ "$total_items" -lt 20 ]; then
        items_to_add=$total_items
    fi
    
    # Shuffle items and add unique ones
    find "$directory" -mindepth 1 -maxdepth 1 | shuf | head -n "$items_to_add" | while IFS= read -r item; do
        if [ -z "$item" ]; then
            continue
        fi
        # Check if the item is a directory
        if [ -d "$item" ]; then
            # Enqueue all files from the directory
            enqueue_all_files_from_directory "enqueue" "$item"
        else
            # Enqueue the file
            echo "->>> enqueue $item"
            send_command "enqueue" "$item"
        fi
    done

    # Enable loop for continuous playback
    send_command "loop" "on"

    sleep "$(get_random_number 2 5)"

    # Start playback and seek to random position
    send_command "next"
    # local seek_percent=$(get_random_number 10 60)
    # send_command "seek" "${seek_percent}%"
}

play_random_video "$1"
