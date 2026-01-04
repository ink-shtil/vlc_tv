#!/bin/bash
# Remote SSH control for VLC TV hotkey scripts
# Executes hotkey_* scripts on remote Raspberry Pi via SSH
#
# SSH Key Setup (run once before using):
#   ssh-copy-id pda@192.168.0.17
# Or manually add your public key to remote ~/.ssh/authorized_keys
#
# Usage: ./remote_control.sh [next|prev|current|0-9]

REMOTE_HOST="192.168.0.17"
REMOTE_USER="pda"
REMOTE_DIR="/home/pda/vlc_tv"

if [ $# -eq 0 ]; then
    echo "Usage: $0 [next|prev|current|0-9]"
    exit 1
fi

# Check if argument is a number from 0 to 9
if [[ "$1" =~ ^[0-9]$ ]]; then
    ssh "$REMOTE_USER@$REMOTE_HOST" "bash $REMOTE_DIR/choose_channel.sh $1"
    exit 0
fi

case "$1" in
    next)
        ssh "$REMOTE_USER@$REMOTE_HOST" "bash $REMOTE_DIR/hotkey_next.sh"
        ;;
    prev|previous)
        ssh "$REMOTE_USER@$REMOTE_HOST" "bash $REMOTE_DIR/hotkey_prev.sh"
        ;;
    current)
        ssh "$REMOTE_USER@$REMOTE_HOST" "bash $REMOTE_DIR/hotkey_current.sh"
        ;;
    *)
        echo "Error: Invalid command '$1'"
        echo "Usage: $0 [next|prev|current|0-9]"
        exit 1
        ;;
esac

