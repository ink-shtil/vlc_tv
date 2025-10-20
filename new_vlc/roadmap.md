# VLC TV Roadmap

A list of planned features and improvements for the VLC TV project.

## Planned High-Priority Features

### 1. Channel Number Display/OSD Overlay
- Brief automatic popup when switching channels (e.g., "Channel 3: Comedy")
- Display for 2-3 seconds then auto-dismiss
- Implementation: notify-send or custom overlay script
- Shows channel index and directory name

### 2. Volume Control with Visual Feedback
- Keybinds: Alt+Plus (volume up), Alt+Minus (volume down)
- Brief visual volume bar (TV-like indicator)
- VLC commands: `volup`, `voldown` via netcat
- Optional: notify-send for volume percentage display

### 3. Reduce Cache Time
- Change from 5000ms to 3000ms (3 seconds)
- File: [start.sh](start.sh:5)
- Improves channel switch responsiveness
- Balance between speed and streaming stability

### 4. Smart Repeat Prevention (Video History)
- Track played videos to avoid recent repeats
- Store in `~/vlc_tv/video_history.txt`
- Circular buffer (e.g., last 100 videos)
- Modify [switch.sh](switch.sh) to check history before random selection
- Option to clear history manually

### 5. Channel Guide/Menu
- Interactive full-channel listing (Alt+G keybind)
- Shows all channels with numbers and names
- Implementation: `zenity` or `yad` GUI overlay
- Allows quick navigation to any channel
- Displays channel index for favorite hotkey reference

### 6. Favorite Channels Hotkeys
- Direct channel access: Alt+1 through Alt+0 (10 channels)
- Store favorites in `~/vlc_tv/favorites.txt`
- Format: channel_index per line (0-9 mapping to Alt+1 through Alt+0)
- Quick-switch without cycling through all channels
- Config script helper to set favorites

### 7. Video Metadata Display
- Keybind to show current video filename/info (e.g., Alt+I)
- Implementation: notify-send with file path/name
- Query VLC for currently playing file via rc interface
- VLC command: `status` or `get_title`
- Parse and display in readable format

### 8. Error Handling & Recovery
- Auto-restart VLC if it crashes
- Watchdog script monitoring VLC process (systemd or custom loop)
- Resume playback automatically on restart
- Log errors to `~/vlc_tv/_error.log` for debugging
- Health check: verify rc interface responds
- Restart threshold: 3 failures = alert user

### 9. Multi-User Support (Portability)
- Replace hardcoded `/home/pda` with `$HOME` variable
- Make scripts portable across different users
- Dynamic path detection in all scripts:
  - [start.sh](start.sh)
  - [switch_channel.sh](switch_channel.sh)
  - [switch.sh](switch.sh)
  - [config.sh](config.sh)
  - All helper scripts
- Update autostart desktop files with `${HOME}` substitution

### 10. Faster Channel Transitions
- Optimize channel switch speed (reduce perceived delay)
- Ideas to explore:
  - Fine-tune cache settings (balance speed vs stability)
  - Send `clear` command before enqueueing to reduce playlist processing
  - Add `play` command immediately after first video enqueued
  - Investigate `--network-caching` vs `--file-caching` optimization
  - Test VLC's `--start-paused` with immediate play for instant start
  - Minimize sleep delays in [switch.sh](switch.sh) (currently 2-5 seconds random)
  - Consider `--no-video-title-show` to skip title display delay
- Goal: Near-instant channel changes (under 1 second perceived delay)
- Benchmark current vs optimized transition times

---

## Planned Features & Improvements

- [X] Add keybinds for additional operations.
- [X] Start VLC with hotkeys disabled.
- [X] Run VLC in no-OSD (On Screen Display) mode.

- [ ] Use a short caching interval (e.g., 3 seconds) for improved performance.
- [ ] Enable auto-start when switching channels.
- [ ] Implement endless repeat for the current playlist and test it.
- [ ] Store video history to support "Do Not Repeat Yourself" functionality.
