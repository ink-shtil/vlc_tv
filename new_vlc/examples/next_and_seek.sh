#!/bin/bash
# Script to send "next" and "seek 50%" commands to VLC rc interface and exit immediately.

VLC_HOST="127.0.0.1"
VLC_PORT=4212

# Send "next" and "seek 50%" in one connection, close immediately after sending
echo "next" | nc -q 1 $VLC_HOST $VLC_PORT
echo "seek 50%" | nc -q 0 $VLC_HOST $VLC_PORT

echo "Sent 'next' and 'seek 50%' commands to VLC rc interface at $VLC_HOST:$VLC_PORT and exited immediately."
