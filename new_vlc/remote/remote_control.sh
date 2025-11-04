#!/bin/bash
# Remote SSH control for VLC TV hotkey scripts
# Executes hotkey_* scripts on remote Raspberry Pi via SSH
#
# SSH Key Setup (run once before using):
#   ssh-copy-id pda@192.168.0.12
# Or manually add your public key to remote ~/.ssh/authorized_keys
#
# Usage: ./remote_control.sh [next|prev|current]

REMOTE_HOST="192.168.0.12"
REMOTE_USER="pda"
REMOTE_DIR="/home/pda/vlc_tv"

if [ $# -eq 0 ]; then
    echo "Usage: $0 [next|prev|current]"
    exit 1
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
        echo "Usage: $0 [next|prev|current]"
        exit 1
        ;;
esac

