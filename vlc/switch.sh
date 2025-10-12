#!/bin/bash

enqueue_random_file_or_directory() {
    local directory="$1"

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
        # Enqueue all files from the directory
        enqueue_all_files_from_directory "$random_item"
    else
        # Enqueue the file
        echo "->>> add $random_item";
        (echo "enqueue $random_item"; echo "quit") | nc "$host" "$port"
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

# Function to enqueue all files from a directory
enqueue_all_files_from_directory() {
    local directory="$1"
    local host="127.0.0.1"
    local port="4444"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get all files in the directory (handles whitespaces)
    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        echo "->>> add $file"
        (echo "enqueue $file"; echo "quit") | nc "$host" "$port"
    done

    # Check if any files were processed
    if [ -z "$(find "$directory" -type f -print0 | head -c 1)" ]; then
        echo "No files found in directory: $directory"
        return 1
    fi
}

# Function to control video playback randomly
function play_random_video() {
    local directory="${1:-/vlc_tv/videos/movies}"
    local host="127.0.0.1"
    local port="4444"

    # Clear current playlist
    (echo "clear"; echo "quit") | nc "$host" "$port"

    # Add noise and seek
    enqueue_random_file_or_directory "/vlc_tv/videos/noises"
    (echo "next"; echo "quit") | nc "$host" "$port"
    sleep "$(get_random_number 6 9)"

    for((i=0;i<20;i++)); do
        enqueue_random_file_or_directory "$directory"
    done

    sleep 1

    (echo "next"; echo "quit") | nc "$host" "$port"

    sleep 1.5

    # Seek to a random position
    command="seek $(get_random_number 5 75)%"
    (echo "$command"; echo "quit") | nc "$host" "$port"
}

play_random_video $1
