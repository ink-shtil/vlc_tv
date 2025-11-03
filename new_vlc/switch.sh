#!/bin/bash

random_file_or_directory() {
    local command="$1"
    local directory="$2"
    local host="127.0.0.1"
    local port="4212"

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
        echo "$command $random_item" | nc -q 0 "$host" "$port"
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
    local host="127.0.0.1"
    local port="4212"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get all files in the directory (handles whitespaces)
    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        echo "->>> $command $file"
        echo "$command $file" | nc -q 0 "$host" "$port"
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
    local host="127.0.0.1"
    local port="4212"

    # Clear playlist and add initial video
    echo "clear" | nc -q 0 "$host" "$port"
    random_file_or_directory "add" "/home/pda/vlc_tv/noises"

    # Build playlist with 20 random videos
    for((i=0;i<20;i++)); do
        random_file_or_directory "enqueue" "$directory"
    done

    # Enable loop for continuous playback
    echo "loop on" | nc -q 0 "$host" "$port"

    sleep "$(get_random_number 2 5)"

    # Start playback and seek to random position
    echo "next" | nc -q 1 "$host" "$port"
    echo "seek $(get_random_number 10 60)%" | nc -q 0 "$host" "$port"
}

play_random_video "$1"
