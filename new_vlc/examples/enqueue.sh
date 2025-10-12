#!/bin/bash
# Script to enqueue a media file to a running VLC rc interface playlist.
# Usage: ./vlc_remote_play.sh /path/to/media.mp4
# Assumes VLC is running with rc interface enabled (default port 4212).
# 'enqueue' adds the file to the end of the current playlist without interrupting playback.
# (In contrast, 'add' replaces the playlist and starts playing the new file immediately.)

VLC_HOST="127.0.0.1"
VLC_PORT=4212

if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/media"
  exit 1
fi

MEDIA_PATH="$1"

# Send the 'enqueue' command to VLC rc interface to add the file to the playlist
echo "enqueue $MEDIA_PATH" | nc $VLC_HOST $VLC_PORT

echo "Sent enqueue command for '$MEDIA_PATH' to VLC rc interface at $VLC_HOST:$VLC_PORT."
