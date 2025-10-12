#!/bin/bash
# Script to clear the VLC playlist via rc interface and exit immediately.

VLC_HOST="127.0.0.1"
VLC_PORT=4212

echo "clear" | nc -q 0 $VLC_HOST $VLC_PORT

echo "Sent 'clear' command to VLC rc interface at $VLC_HOST:$VLC_PORT and exited immediately."
