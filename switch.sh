#!/bin/bash

get_random_file() {
    local directory="$1"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get the total number of files in the directory
    local total_files=$(find "$directory" -type f | wc -l)

    # Check if there are any files in the directory
    if [ "$total_files" -eq 0 ]; then
        echo "No files found in directory: $directory"
        return 1
    fi

    # Generate a random number between 1 and the total number of files
    local random_number=$((RANDOM % total_files + 1))

    # Get the random file using the random number
    local random_file=$(find "$directory" -type f | head -n "$random_number" | tail -n 1)

    # Print the random file name
    echo "$random_file"
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

# Function to control video playback randomly
function play_random_video() {
    local directory="${1:-/vlc_tv/videos/movies}"
    local host="127.0.0.1"
    local port="4444"

    # Clear current playlist
    (echo "clear"; echo "quit") | nc "$host" "$port"

    # Add noise and seek
    random_noise=$(get_random_file "/vlc_tv/videos/noises")
    (echo "add $random_noise"; echo "quit") | nc "$host" "$port"
    sleep "5.$(get_random_number 10 80)"

    # Get and play a random file from the directory
    random_file=$(get_random_file "$directory")
    echo "change to $random_file"
    (echo "add $random_file"; echo "quit") | nc "$host" "$port"
    sleep 0.2
    
    # Seek to a random position
    command="seek $(get_random_number 1 75)%"
    (echo "$command"; echo "quit") | nc "$host" "$port"

    for((i=0;i<20;i++)); do
        random_file=$(get_random_file "$directory")
        (echo "enqueue $random_file"; echo "quit") | nc "$host" "$port"
    done
}

play_random_video $1
