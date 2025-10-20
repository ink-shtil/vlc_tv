#!/bin/bash
# Decrease VLC volume via remote control interface

HOST="127.0.0.1"
PORT="4212"

echo "voldown" | nc -q 0 "$HOST" "$PORT"