#!/bin/bash

START_LOG="/home/pda/vlc_tv/_start.log"
SWITCH_LOG="/home/pda/vlc_tv/_switch_channel.log"

log_with_time() {
  while IFS= read -r line; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') $line"
  done
}

# unclutter -idle 0 -root

echo "$(date '+%Y-%m-%d %H:%M:%S') Launching VLC in LXTerminal..."
lxterminal -e "bash /home/pda/vlc_tv/start.sh" &

echo "$(date '+%Y-%m-%d %H:%M:%S') Waiting 2 seconds before running switch_channel.sh current..."
sleep 5
echo "$(date '+%Y-%m-%d %H:%M:%S') Starting switch_channel.sh current in background..."
(
  echo "========== switch_channel.sh current started at $(date '+%Y-%m-%d %H:%M:%S') =========="
  bash /home/pda/vlc_tv/switch_channel.sh current 2>&1 | log_with_time
  echo "========== switch_channel.sh current finished at $(date '+%Y-%m-%d %H:%M:%S') =========="
) >> "$SWITCH_LOG" &

echo "$(date '+%Y-%m-%d %H:%M:%S') All background jobs started."

# Optionally, wait for background jobs (remove if not needed)
# wait
