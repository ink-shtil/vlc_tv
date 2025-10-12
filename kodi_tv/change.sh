#!/bin/bash

# Function to play a random file from a directory
play_random_file() {
    local directory="$1"
    local KODI_URL="http://localhost:8080/jsonrpc"

    # Check if directory argument is provided
    if [ -z "$directory" ]; then
        echo "Usage: $0 <directory>"
        exit 1
    fi

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Error: Directory does not exist: $directory"
        exit 1
    fi

    # Get all video files in the directory
    local file_count=$(find "$directory" -type f | wc -l | tr -d ' ')

    # Check if any files were found
    if [ "$file_count" -eq 0 ]; then
        echo "Error: No files found in directory: $directory"
        exit 1
    fi

    # Select a random file index
    local random_index=$((RANDOM % file_count + 1))

    # Get the random file
    local random_file=$(find "$directory" -type f | head -n "$random_index" | tail -n 1)

    echo "Selected random file: $random_file"

    # Stop current playback if any
    local playerid=$(curl -s --header "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"Player.GetActivePlayers","id":1}' \
      "$KODI_URL" | grep -o '"playerid":[0-9]*' | head -n1 | grep -o '[0-9]*')

    if [ -n "$playerid" ]; then
        echo "Stopping current playback..."
        curl -s --header "Content-Type: application/json" \
          --data "{\"jsonrpc\":\"2.0\",\"method\":\"Player.Stop\",\"params\":{\"playerid\":$playerid},\"id\":1}" \
          "$KODI_URL" > /dev/null
    fi

    # Clear the playlist
    echo "Clearing playlist..."
    curl -s --header "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"Playlist.Clear","params":{"playlistid":1},"id":1}' \
      "$KODI_URL" > /dev/null

    # Add the random file to the playlist
    echo "Adding file to playlist..."
    curl -s --header "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"$random_file\"}},\"id\":1}" \
      "$KODI_URL" > /dev/null

    # Start playback
    echo "Starting playback..."
    curl -s --header "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"playlistid":1}},"id":1}' \
      "$KODI_URL" > /dev/null

    echo "Done! Playing: $random_file"
}

# Execute the function with the first argument
play_random_file "$1"
