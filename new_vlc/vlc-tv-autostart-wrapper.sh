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

echo "$(date '+%Y-%m-%d %H:%M:%S') Waiting 2 seconds before running choose_channel.sh 0..."
sleep 5
echo "$(date '+%Y-%m-%d %H:%M:%S') Starting choose_channel.sh 0 (random channel) in background..."
(
  echo "========== choose_channel.sh 0 started at $(date '+%Y-%m-%d %H:%M:%S') =========="
  bash /home/pda/vlc_tv/choose_channel.sh 0 2>&1 | log_with_time
  echo "========== choose_channel.sh 0 finished at $(date '+%Y-%m-%d %H:%M:%S') =========="
) >> "$SWITCH_LOG" &

echo "$(date '+%Y-%m-%d %H:%M:%S') All background jobs started."

# Optionally, wait for background jobs (remove if not needed)
# wait
