# 📺 VLC TV for Raspberry Pi

## 📖 Project Overview
Raspberry Pi system that uses VLC player as a TV-like interface with channel switching capabilities. Channels are subdirectories containing video files, navigated via keyboard shortcuts.

## 🏗️ Architecture

**⚙️ Core Scripts:**
- [start.sh](start.sh) - Launches VLC with remote control interface (port 4212)
- [switch_channel.sh](switch_channel.sh) - Main channel switcher (next/previous/current)
- [switch.sh](switch.sh) - Randomly enqueues videos from selected channel directory (no duplicates)
- [choose_channel.sh](choose_channel.sh) - Direct channel selection by number (0-9, where 0 = random 1-8)
- [config.sh](config.sh) - Initial setup: installs dependencies, configures autostart, sets keybinds

**⌨️ Hotkey Scripts:**
- [hotkey_next.sh](hotkey_next.sh) - Next channel hotkey wrapper
- [hotkey_prev.sh](hotkey_prev.sh) - Previous channel hotkey wrapper
- [hotkey_current.sh](hotkey_current.sh) - Current channel hotkey wrapper
- [hotkey_vol_up.sh](hotkey_vol_up.sh) - Volume up hotkey wrapper
- [hotkey_vol_down.sh](hotkey_vol_down.sh) - Volume down hotkey wrapper

**🛠️ Helper Scripts:**
- [vlc-tv-autostart-wrapper.sh](vlc-tv-autostart-wrapper.sh) - Autostart wrapper with logging (uses random channel 0)
- [remote/remote_control.sh](remote/remote_control.sh) - Remote SSH control for VLC TV (from macOS/other hosts)

**💾 State Files** (stored in `~/vlc_tv/`):
- `channels_directory.txt` - Base directory for channels
- `current_channel_index.txt` - Current channel index
- `channels.txt` - Generated list of channel subdirectories

## ✨ Key Features
- VLC remote control via netcat on port 4212
- Random video playback from channel directories (no duplicates in playlist)
- Direct channel selection: Alt+1 through Alt+9 (channels 1-9)
- Random channel selection: Channel 0 selects random channel from 1-8
- Fullscreen mode with hidden cursor (unclutter)
- Labwc/Openbox keybinds (Alt+Up, Alt+Left/Right, Alt+1-9 configured)
- Autostart via .desktop files (starts with random channel)
- Remote control via SSH and macOS AppleScript apps (MiraBox compatible)

## 🚀 Common Tasks

**📦 Initial Setup:**
```bash
bash config.sh
```

**📺 Manual Channel Switch:**
```bash
bash switch_channel.sh next
bash switch_channel.sh previous
bash switch_channel.sh current
bash choose_channel.sh 1    # Switch to channel 1
bash choose_channel.sh 0    # Random channel (1-8)
```

**🎮 VLC Control (via netcat):**
```bash
echo "next" | nc 127.0.0.1 4212
echo "pause" | nc 127.0.0.1 4212
echo "seek 50%" | nc 127.0.0.1 4212
```

**📱 Remote Control (from macOS via SSH):**
```bash
# Direct SSH control
./remote/remote_control.sh next
./remote/remote_control.sh prev
./remote/remote_control.sh current
./remote/remote_control.sh 0    # Random channel
./remote/remote_control.sh 1-9  # Direct channel selection

# macOS AppleScript apps (for MiraBox)
# Located in remote/apps/:
# - remote_next.app
# - remote_prev.app
# - remote_current.app
# - remote_channel_0.app (random channel)
# - remote_channel_1.app through remote_channel_9.app
# These can be assigned to MiraBox buttons for one-click remote control
```

## 📁 Project Structure Assumptions
- Video channels stored as subdirectories (e.g., `/media/pda/SanDisk/videos/channel1/`, `/media/pda/SanDisk/videos/channel2/`)
- Each channel subdirectory contains video files or nested subdirectories
- Scripts installed to `~/vlc_tv/`
- Raspberry Pi OS with Labwc (Wayland) desktop environment

## 📦 Dependencies
- `vlc` (cvlc)
- `netcat-traditional`
- `unclutter`
- `xmlstarlet`
- `lxterminal`

## 📝 Notes
- Hardcoded paths assume user `pda` - update `USER_HOME` in scripts if different
- VLC caching set to 3000ms for both file and network (configurable in [start.sh](start.sh:5))
- Random video selection uses `RANDOM` bash variable
- Playlist building prevents duplicate videos using `shuf` command
- Channel 0 = random selection from channels 1-8 (useful for autostart)
- Logs written to `~/vlc_tv/_start.log` and `~/vlc_tv/_switch_channel.log`

## 🍎 Remote Control (macOS)
The `remote/` directory contains:
- **remote_control.sh** - SSH-based remote control script
- **AppleScript files** (`.applescript`) - Source files for macOS automation
- **Compiled apps** (`remote/apps/*.app`) - Ready-to-use macOS applications

**Setup for Remote Control:**
1. Ensure SSH key-based authentication is set up:
   ```bash
   ssh-copy-id pda@192.168.0.17
   ```
2. Use compiled `.app` files from `remote/apps/` with MiraBox or other automation tools
3. Each app executes the corresponding remote control command via SSH

**Available Remote Controls:**
- Navigation: `next`, `prev`, `current`
- Channel selection: `0` (random), `1-9` (direct channels)