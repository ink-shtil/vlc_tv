#!/bin/bash

# Use a temporary file to store playlist files
PLAYLIST_TEMP_FILE=$(mktemp)

cleanup() {
    rm -f "$PLAYLIST_TEMP_FILE"
}
trap cleanup EXIT

# Collect a random file or all files from a random directory in the given directory
collect_random_file_or_directory() {
    local directory="$1"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get the total number of files and directories in the directory
    local total_items
    total_items=$(find "$directory" -mindepth 1 -maxdepth 1 | wc -l)

    # Check if there are any items in the directory
    if [ "$total_items" -eq 0 ]; then
        echo "No files or directories found in directory: $directory"
        return 1
    fi

    # Generate a random number between 1 and the total number of items
    local random_number=$((RANDOM % total_items + 1))

    # Get the random item using the random number
    local random_item
    random_item=$(find "$directory" -mindepth 1 -maxdepth 1 | head -n "$random_number" | tail -n 1)

    # Check if the random item is a directory
    if [ -d "$random_item" ]; then
        # Collect all files from the directory
        collect_all_files_from_directory "$random_item"
    else
        # Collect the file
        echo "$random_item" >> "$PLAYLIST_TEMP_FILE"
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

# Collect all files from a directory (recursively)
collect_all_files_from_directory() {
    local directory="$1"

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Directory does not exist: $directory"
        return 1
    fi

    # Get all files in the directory (handles whitespaces)
    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        echo "$file" >> "$PLAYLIST_TEMP_FILE"
    done
}

# Add a list of files to the Kodi playlist
add_files_to_kodi_playlist() {
    local KODI_URL="$1"
    while IFS= read -r file; do
        echo "->>> add $file"
        curl -s --header "Content-Type: application/json" \
          --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"$file\"}},\"id\":1}" \
          "$KODI_URL" > /dev/null
    done < "$PLAYLIST_TEMP_FILE"
}

# Main function to control video playback randomly
play_random_video() {
    local directory="${1:-/vlc_tv/videos/movies}"
    local KODI_URL="http://localhost:8080/jsonrpc"
    : > "$PLAYLIST_TEMP_FILE"  # Truncate temp file

    # 1. Collect playlist items (noise + 20 random movies)
    # Add noise as the first item
    collect_random_file_or_directory "/media/SanDisk/tv/noises"

    # Add movies as the next items
    local i=0
    while [ $i -lt 20 ]; do
        collect_random_file_or_directory "$directory"
        i=$((i + 1))
    done

    # 2. Stop playback and clear playlist
    playerid=$(curl -s --header "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"Player.GetActivePlayers","id":1}' \
      "$KODI_URL" | grep -o '"playerid":[0-9]*' | head -n1 | grep -o '[0-9]*')
    if [ -n "$playerid" ]; then
      echo "->>> stopping current playback"
      curl -s --header "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"Player.Stop\",\"params\":{\"playerid\":$playerid},\"id\":1}" \
        "$KODI_URL"
    fi
    echo "->>> clear pl"
    curl -s --header "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Clear\",\"params\":{\"playlistid\":1},\"id\":1}" \
      "$KODI_URL" > /dev/null

    # 3. Add all files to the playlist
    add_files_to_kodi_playlist "$KODI_URL"

    echo "->>> open pl"
    # 4. Start playback from the beginning (noise)
    curl -s --header "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"playlistid":1}},"id":1}' \
      "$KODI_URL"

    # 5. Sleep and seek
    # echo "->>> sleep and seek"

    # sleep "$(get_random_number 15 20)"

    # # # Seek to a random position
    # seek_percent=$(get_random_number 5 60)
    # echo "->>> seek pl $seek_percent"
    # curl -s --header "Content-Type: application/json" \
    #   --data "{\"jsonrpc\":\"2.0\",\"method\":\"Player.Seek\",\"params\":{\"playerid\":1,\"value\":{\"percentage\":$seek_percent}},\"id\":1}" \
    #   "http://localhost:8080/jsonrpc" > /dev/null

}

play_random_video "$1"
