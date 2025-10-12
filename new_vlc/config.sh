#!/bin/bash
AUTOSTART_DIR="/home/pda/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cp ./*.desktop "$AUTOSTART_DIR/"
echo "All .desktop files copied to $AUTOSTART_DIR"
