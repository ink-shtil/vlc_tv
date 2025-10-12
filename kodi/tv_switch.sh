#!/bin/bash

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

sh /media/SanDisk/tv/kodi/switch.sh $1
echo "sleep..."
sleep "$(get_random_number 15 20)"
seek_percent=$(get_random_number 5 60)
echo "->>> seek pl $seek_percent"
curl -s --header "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"Player.Seek\",\"params\":{\"playerid\":1,\"value\":{\"percentage\":$seek_percent}},\"id\":1}" \
  "http://localhost:8080/jsonrpc" > /dev/null