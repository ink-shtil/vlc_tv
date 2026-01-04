# Raspberry Pi TV Simulator (Non-Kodi)

This guide explains how to build a **TV simulator** using:

- Raspberry Pi OS Lite  
- `mpv` video player  
- Python controller  
- HDMI-CEC (TV remote)  

Result:
- ✅ Zero OSD / UI
- ✅ USB folders = TV channels
- ✅ Auto-start on boot
- ✅ Controlled by TV remote

---

## 0. Hardware

- Raspberry Pi 3 / 4 / 5
- HDMI-connected TV (CEC enabled)
- USB flash drive with videos
- SD card (16GB+)
- Network (for SSH)

---

## 1. Install Raspberry Pi OS Lite

1. Download **Raspberry Pi OS Lite (64-bit)**
2. Flash to SD card using **Raspberry Pi Imager**
3. In Imager settings:
   - Enable SSH
   - Set username/password
   - Configure Wi-Fi (optional)

Boot the Pi and connect via SSH:

```bash
ssh pi@raspberrypi.local
```

---

## 2. System setup

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y mpv python3 cec-utils udisks2
```

Verify HDMI-CEC device:

```bash
ls /dev | grep cec
```

Expected:
```
cec0
```

---

## 3. USB channel structure

Format USB as **FAT32 or exFAT**.

Directory layout:

```text
USB/
└── TV/
    ├── 01_News/
    ├── 02_Sports/
    ├── 03_Movies/
```

Each folder = one channel.

USB auto-mounts to:

```text
/media/pi/USB/
```

---

## 4. Test mpv (fullscreen, no OSD)

```bash
mpv --fs --no-osd-bar --no-input-default-bindings --loop /media/pi/USB/TV/01_News
```

You should see:
- No title
- No controls
- No overlays

---

## 5. Python TV controller

Create project directory:

```bash
mkdir -p ~/tv-sim
cd ~/tv-sim
nano tv.py
```

### Minimal controller

```python
import os
import subprocess
import signal

TV_ROOT = "/media/pi/USB/TV"
MPV_CMD = [
    "mpv",
    "--fs",
    "--no-osd-bar",
    "--no-input-default-bindings",
    "--loop",
]

mpv_proc = None
channels = sorted([
    os.path.join(TV_ROOT, d)
    for d in os.listdir(TV_ROOT)
    if os.path.isdir(os.path.join(TV_ROOT, d))
])

current = 0

def play_channel(idx):
    global mpv_proc
    if mpv_proc:
        mpv_proc.send_signal(signal.SIGTERM)

    mpv_proc = subprocess.Popen(
        MPV_CMD + [channels[idx]],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

play_channel(current)
signal.pause()
```

Run manually:

```bash
python3 tv.py
```

---

## 6. HDMI-CEC testing

List CEC devices:

```bash
cec-client -l
```

Monitor remote buttons:

```bash
cec-client
```

Example output:

```
key pressed: channel up
key pressed: channel down
```

---

## 7. Autostart on boot (systemd)

Create service:

```bash
sudo nano /etc/systemd/system/tv.service
```

```ini
[Unit]
Description=TV Simulator
After=network.target

[Service]
User=pi
ExecStart=/usr/bin/python3 /home/pi/tv-sim/tv.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable tv.service
sudo systemctl start tv.service
```

Reboot:

```bash
sudo reboot
```

---

## 8. Optional polish

Disable blinking cursor:

```bash
sudo nano /boot/cmdline.txt
```

Add:

```
vt.global_cursor_default=0
```

Disable HDMI blanking:

```bash
sudo nano /boot/config.txt
```

Add:

```
hdmi_force_hotplug=1
```

---

## Result

- Power ON → video starts automatically
- TV remote switches channels
- No UI, no OSD
- USB folders behave like TV channels

---

## Next ideas

- Channel up/down via CEC
- Shuffle or random start
- Fake static between channels
- Watchdog & auto-restart
- Create a ready-to-flash SD image
