# 📺 VLC TV for Raspberry Pi

## 📖 Project Overview
Raspberry Pi system that uses VLC player as a TV-like interface with channel switching capabilities. Channels are subdirectories containing video files, navigated via keyboard shortcuts.

## 🏗️ Architecture

**⚙️ Core Scripts:**
- [start.sh](start.sh) - Launches VLC with remote control interface (port 4212)
- [switch_channel.sh](switch_channel.sh) - Main channel switcher (next/previous/current)
- [switch.sh](switch.sh) - Randomly enqueues videos from selected channel directory
- [config.sh](config.sh) - Initial setup: installs dependencies, configures autostart, sets keybinds

**⌨️ Hotkey Scripts:**
- [hotkey_next.sh](hotkey_next.sh) - Next channel hotkey wrapper
- [hotkey_prev.sh](hotkey_prev.sh) - Previous channel hotkey wrapper
- [hotkey_current.sh](hotkey_current.sh) - Current channel hotkey wrapper
- [hotkey_vol_up.sh](hotkey_vol_up.sh) - Volume up hotkey wrapper
- [hotkey_vol_down.sh](hotkey_vol_down.sh) - Volume down hotkey wrapper

**🛠️ Helper Scripts:**
- [vlc-tv-autostart-wrapper.sh](vlc-tv-autostart-wrapper.sh) - Autostart wrapper with logging

**💾 State Files** (stored in `~/vlc_tv/`):
- `channels_directory.txt` - Base directory for channels
- `current_channel_index.txt` - Current channel index
- `channels.txt` - Generated list of channel subdirectories

## ✨ Key Features
- VLC remote control via netcat on port 4212
- Random video playback from channel directories
- Fullscreen mode with hidden cursor (unclutter)
- Labwc/Openbox keybinds (Alt+Up configured)
- Autostart via .desktop files

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
```

**🎮 VLC Control (via netcat):**
```bash
echo "next" | nc 127.0.0.1 4212
echo "pause" | nc 127.0.0.1 4212
echo "seek 50%" | nc 127.0.0.1 4212
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
- Logs written to `~/vlc_tv/_start.log` and `~/vlc_tv/_switch_channel.log`