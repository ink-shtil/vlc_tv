#!/bin/bash

set -x  # Enable debug output

# This script configures autostart for the rpd-labwc (Wayland) session on Raspberry Pi OS.
# Labwc uses ~/.config/autostart/ for autostarting applications via .desktop files.
# The old /etc/xdg/lxsession/rpd-x/autostart is not used in this environment.

# Install dependencies
sudo apt-get update
sudo apt-get install -y netcat-traditional unclutter xmlstarlet curl

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

# === Player Configuration ===
PLAYER_CONFIG_FILE="$USER_HOME/vlc_tv/player_config.txt"

# Function to setup KODI keymap
setup_kodi_keymap() {
    local kodi_keymap_dir="$USER_HOME/.kodi/userdata/keymaps"
    local kodi_keymap_file="$kodi_keymap_dir/keyboard.xml"
    
    echo ""
    echo "=== Configuring KODI Keymap ==="
    
    # Create keymaps directory if it doesn't exist
    mkdir -p "$kodi_keymap_dir"
    
    # Backup existing keymap if it exists
    if [ -f "$kodi_keymap_file" ]; then
        cp "$kodi_keymap_file" "${kodi_keymap_file}.bak"
        echo "Backed up existing keymap to ${kodi_keymap_file}.bak"
    fi
    
    # Create keymap XML with arrow key bindings
    cat > "$kodi_keymap_file" <<EOF
<keymap>
  <global>
    <keyboard>
      <right>System.ExecWait($USER_HOME/vlc_tv/hotkey_next.sh)</right>
      <left>System.ExecWait($USER_HOME/vlc_tv/hotkey_prev.sh)</left>
      <up>System.ExecWait($USER_HOME/vlc_tv/hotkey_current.sh)</up>
    </keyboard>
    <remote>
      <right>System.ExecWait($USER_HOME/vlc_tv/hotkey_next.sh)</right>
      <left>System.ExecWait($USER_HOME/vlc_tv/hotkey_prev.sh)</left>
      <up>System.ExecWait($USER_HOME/vlc_tv/hotkey_current.sh)</up>
    </remote>
  </global>
</keymap>
EOF
    
    echo "KODI keymap created at $kodi_keymap_file"
    echo "Mapped keys:"
    echo "  - Right Arrow -> Next Channel"
    echo "  - Left Arrow -> Previous Channel"
    echo "  - Up Arrow -> Current Channel"
    echo ""
    echo "Note: KODI must be restarted for keymap changes to take effect."
}

echo ""
echo "=== Media Player Configuration ==="
echo "Select media player:"
echo "  1) VLC"
echo "  2) KODI (default)"
read -rp "Enter choice [2]: " PLAYER_CHOICE

if [ "$PLAYER_CHOICE" = "1" ]; then
    PLAYER_TYPE="vlc"
    echo "Player type set to: VLC"
elif [ -z "$PLAYER_CHOICE" ] || [ "$PLAYER_CHOICE" = "2" ]; then
    PLAYER_TYPE="kodi"
    echo "Player type set to: KODI"
    
    # KODI-specific configuration
    read -rp "KODI host [127.0.0.1]: " KODI_HOST
    KODI_HOST="${KODI_HOST:-127.0.0.1}"
    
    read -rp "KODI JSON-RPC port [8080]: " KODI_PORT
    KODI_PORT="${KODI_PORT:-8080}"
    
    read -rp "KODI username (leave empty for no auth) [kodi]: " KODI_USER
    KODI_USER="${KODI_USER:-kodi}"
    
    read -rp "KODI password (leave empty for no auth) [kodi]: " KODI_PASS
    KODI_PASS="${KODI_PASS:-kodi}"
else
    echo "Invalid choice, defaulting to KODI"
    PLAYER_TYPE="kodi"
fi

# Save player configuration
mkdir -p "$USER_HOME/vlc_tv"
{
    echo "PLAYER_TYPE=$PLAYER_TYPE"
    if [ "$PLAYER_TYPE" = "kodi" ]; then
        echo "KODI_HOST=$KODI_HOST"
        echo "KODI_PORT=$KODI_PORT"
        echo "KODI_USER=$KODI_USER"
        echo "KODI_PASS=$KODI_PASS"
    fi
} > "$PLAYER_CONFIG_FILE"
echo "Player configuration saved to $PLAYER_CONFIG_FILE"

# Setup KODI keymap if KODI is selected
if [ "$PLAYER_TYPE" = "kodi" ]; then
    setup_kodi_keymap
fi

mkdir -p "$AUTOSTART_DIR"
cp ./*.desktop "$AUTOSTART_DIR/"
echo "All .desktop files copied to $AUTOSTART_DIR"

# === Labwc/Openbox Keybind Setup (rc.xml) with Namespace Handling and No -L ===

LABWC_RC="$USER_HOME/.config/labwc/rc.xml"
NS="ob=http://openbox.org/3.4/rc"

chmod +x "$USER_HOME/vlc_tv/"*.sh
echo "All scripts in $USER_HOME/vlc_tv/ made executable"

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

# Add keybinds for channel numbers (Alt+0 through Alt+9)
add_keybind "A-0" "$USER_HOME/vlc_tv/choose_channel.sh 0" "Channel 0"
add_keybind "A-1" "$USER_HOME/vlc_tv/choose_channel.sh 1" "Channel 1"
add_keybind "A-2" "$USER_HOME/vlc_tv/choose_channel.sh 2" "Channel 2"
add_keybind "A-3" "$USER_HOME/vlc_tv/choose_channel.sh 3" "Channel 3"
add_keybind "A-4" "$USER_HOME/vlc_tv/choose_channel.sh 4" "Channel 4"
add_keybind "A-5" "$USER_HOME/vlc_tv/choose_channel.sh 5" "Channel 5"
add_keybind "A-6" "$USER_HOME/vlc_tv/choose_channel.sh 6" "Channel 6"
add_keybind "A-7" "$USER_HOME/vlc_tv/choose_channel.sh 7" "Channel 7"
add_keybind "A-8" "$USER_HOME/vlc_tv/choose_channel.sh 8" "Channel 8"
add_keybind "A-9" "$USER_HOME/vlc_tv/choose_channel.sh 9" "Channel 9"

echo "All keybinds configured. Please restart Labwc or reload its configuration to apply the new keybinds."

set +x  # Disable debug output
