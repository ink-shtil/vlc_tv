#!/bin/bash

set -x  # Enable debug output

# This script configures autostart for the rpd-labwc (Wayland) session on Raspberry Pi OS.
# Labwc uses ~/.config/autostart/ for autostarting applications via .desktop files.
# The old /etc/xdg/lxsession/rpd-x/autostart is not used in this environment.

# Install dependencies
sudo apt-get update
sudo apt-get install -y netcat-traditional unclutter xmlstarlet

USER_HOME="/home/pda"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
CHANNELS_DIR_FILE="$USER_HOME/vlc_tv/channels_directory.txt"
INDEX_FILE="$USER_HOME/vlc_tv/current_channel_index.txt"
DEFAULT_VIDEO_DIR="/media/pda/SanDisk/videos/"

echo "Default video folder is: $DEFAULT_VIDEO_DIR"
read -rp "Press Enter to use the default, or type a new path: " USER_INPUT

if [ -z "$USER_INPUT" ]; then
    VIDEO_DIR="$DEFAULT_VIDEO_DIR"
else
    VIDEO_DIR="$USER_INPUT"
fi

echo "$VIDEO_DIR" > "$CHANNELS_DIR_FILE"
echo "Video folder set to $VIDEO_DIR in $CHANNELS_DIR_FILE"

# Reset channel index
echo "0" > "$INDEX_FILE"
echo "Channel index reset to 0 in $INDEX_FILE"

mkdir -p "$AUTOSTART_DIR"
cp ./*.desktop "$AUTOSTART_DIR/"
echo "All .desktop files copied to $AUTOSTART_DIR"

# === Labwc/Openbox Keybind Setup (rc.xml) with Namespace Handling and No -L ===

KEYBIND_SCRIPT_SRC="$(pwd)/hello_world_terminal.sh"
KEYBIND_SCRIPT_DEST="$USER_HOME/vlc_tv/hello_world_terminal.sh"
LABWC_RC="$USER_HOME/.config/labwc/rc.xml"
NS="ob=http://openbox.org/3.4/rc"

# Copy the script and make it executable
if [ -f "$KEYBIND_SCRIPT_SRC" ]; then
    mkdir -p "$USER_HOME/vlc_tv"
    cp "$KEYBIND_SCRIPT_SRC" "$KEYBIND_SCRIPT_DEST"
    chmod +x "$KEYBIND_SCRIPT_DEST"
    echo "hello_world_terminal.sh copied to $KEYBIND_SCRIPT_DEST and made executable"
    # Make all scripts in the VLC TV directory executable
    if compgen -G "$USER_HOME/vlc_tv/*.sh" > /dev/null; then
        chmod +x "$USER_HOME/vlc_tv/"*.sh
        echo "All scripts in $USER_HOME/vlc_tv/ made executable"
    fi
else
    echo "WARNING: $KEYBIND_SCRIPT_SRC not found. Skipping script copy."
fi

# Ensure rc.xml exists
mkdir -p "$USER_HOME/.config/labwc"
if [ ! -f "$LABWC_RC" ]; then
    echo '<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
  </keyboard>
</openbox_config>' > "$LABWC_RC"
    echo "Created new $LABWC_RC"
fi

# Ensure <keyboard> section exists (with namespace)
if ! xmlstarlet sel -N $NS -t -v "/ob:openbox_config/ob:keyboard" "$LABWC_RC" | grep -q .; then
    xmlstarlet ed -N $NS -s "/ob:openbox_config" -t elem -n "keyboard" -v "" "$LABWC_RC" > "$LABWC_RC.tmp" && mv "$LABWC_RC.tmp" "$LABWC_RC"
    echo "Added <keyboard> section to $LABWC_RC"
fi

# Function to add a keybind
add_keybind() {
    local key="$1"
    local script="$2"
    local description="$3"

    if xmlstarlet sel -N $NS -t -v "/ob:openbox_config/ob:keyboard/ob:keybind[@key='$key']" "$LABWC_RC" 2>/dev/null | grep -q .; then
        echo "Keybind for $key already present in $LABWC_RC"
    else
        cp "$LABWC_RC" "$LABWC_RC.bak"
        xmlstarlet ed -N $NS \
            -s "/ob:openbox_config/ob:keyboard" -t elem -n "keybindTMP" -v "" \
            -i "/ob:openbox_config/ob:keyboard/keybindTMP" -t attr -n "key" -v "$key" \
            -s "/ob:openbox_config/ob:keyboard/keybindTMP" -t elem -n "action" -v "" \
            -i "/ob:openbox_config/ob:keyboard/keybindTMP/action" -t attr -n "name" -v "Execute" \
            -i "/ob:openbox_config/ob:keyboard/keybindTMP/action" -t attr -n "command" -v "$script" \
            -r "/ob:openbox_config/ob:keyboard/keybindTMP" -v "keybind" \
            "$LABWC_RC" > "$LABWC_RC.tmp" && mv "$LABWC_RC.tmp" "$LABWC_RC"
        if [ $? -eq 0 ]; then
            echo "Keybind for $key ($description) added to $LABWC_RC"
        else
            echo "ERROR: Failed to add keybind for $key to $LABWC_RC"
        fi
    fi
}

# Add keybinds for channel switching
add_keybind "A-Right" "$USER_HOME/vlc_tv/hotkey_next.sh" "Next Channel"
add_keybind "A-Left" "$USER_HOME/vlc_tv/hotkey_prev.sh" "Previous Channel"
add_keybind "A-Up" "$USER_HOME/vlc_tv/hotkey_current.sh" "Current Channel"

# Add keybinds for volume control
add_keybind "A-plus" "$USER_HOME/vlc_tv/hotkey_vol_up.sh" "Volume Up"
add_keybind "A-minus" "$USER_HOME/vlc_tv/hotkey_vol_down.sh" "Volume Down"

echo "All keybinds configured. Please restart Labwc or reload its configuration to apply the new keybinds."

set +x  # Disable debug output
