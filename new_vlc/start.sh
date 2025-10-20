#!/bin/bash
# Start VLC with remote control interface and enqueue the same file three times.
# To enable looping of the playlist, connect to the rc interface (e.g., with nc or telnet) and use the 'loop' command.

DISPLAY=:0 cvlc --rc-host=0.0.0.0:4212 --no-osd --no-keyboard-events --file-caching=5000 -f
