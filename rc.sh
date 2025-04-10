#!/bin/bash

start_vlc() {
    vlc --extraintf rc --rc-host 127.0.0.1:4444 noise.mov -f
}

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
    local directory="videos"
    local host="127.0.0.1"
    local port="4444"

    # Clear current playlist
    echo "clear" | nc "$host" "$port"

    # Add noise and seek
    echo "add noise.mov" | nc "$host" "$port"
    sleep "0.$(get_random_number 15 50)"
    echo "seek $(get_random_number 15 50)%" | nc "$host" "$port"
    sleep "$(get_random_number 1 3)"

    # Get and play a random file from the directory
    random_file=$(get_random_file "$directory")
    echo "change to $random_file"
    echo "add $random_file" | nc "$host" "$port"
    sleep 0.2
    
    # Seek to a random position
    command="seek $(get_random_number 1 30)%"
    echo "$command"
    echo "$command" | nc "$host" "$port"

    for((i=0;i<3;i++)); do
        random_file=$(get_random_file "$directory")
        echo "enqueue $random_file" | nc "$host" "$port"
    done
}

nohup start.sh > /dev/null 2>&1 &

# bash start.sh &

# Loop to continuously check for key presses
while true; do
    # Read a single character (including special keys)
    IFS= read -rsn1 key

    # Check if the pressed key is the spacebar
    if [[ "$key" == $'\x20' ]]; then  # $'\x20' is the hexadecimal representation of a space
        play_random_video &
    fi
done
