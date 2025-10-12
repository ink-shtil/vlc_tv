#!/bin/bash
# Script to play a specified video file using VLC (cvlc) on Raspberry Pi via SSH.
# Usage: ./play_video.sh /path/to/video.mp4
# Plays the video in fullscreen with minimal UI (headless).

if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/video"
  exit 1
fi

VIDEO_PATH="$1"

# Play the video using cvlc (no GUI, suitable for SSH/headless)
# --fullscreen: play in fullscreen
# --no-video-title-show: don't show filename overlay
# --quiet: suppress logs
cvlc --fullscreen --no-video-title-show --quiet "$VIDEO_PATH"
