#!/usr/bin/env python3
import os
import time
import signal
import subprocess
import random
import json
import socket

TV_ROOT = "/media/usb/videos"   # change to your actual mount path
MPV_IPC_SOCKET = "/tmp/tv-mpv.sock"
MPV_CMD = [
    "mpv",
    "--fs",
    "--no-osd-bar",
    "--no-input-default-bindings",
    "--loop",
    "--ao=alsa",
    "--audio-device=alsa/hdmi:CARD=vc4hdmi0,DEV=0",
    "--idle=yes",  # stay running with no file loaded
    f"--input-ipc-server={MPV_IPC_SOCKET}",
]

# Use verbose cec-client mode, same as in tv_cec_debug.py
CEC_CMD = ["stdbuf", "-oL", "cec-client", "-f"]  # line-buffered output

VIDEO_EXTS = (".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm")
DEBOUNCE_SECONDS = 0.4

# Playlist behaviour
PLAYLIST_SIZE = 20
PLAYLIST_PATH = "/tmp/tv_playlist.m3u"

mpv_proc = None
cec_proc = None
last_key_time = 0.0


def list_channels(root: str):
    if not os.path.isdir(root):
        raise FileNotFoundError(f"TV_ROOT not found: {root}")
    chans = []
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d)
        if os.path.isdir(p):
            # optional: require at least one playable file
            has_media = any(
                f.lower().endswith(VIDEO_EXTS)
                for f in os.listdir(p)
                if os.path.isfile(os.path.join(p, f))
            )
            if has_media:
                chans.append(p)
    if not chans:
        raise RuntimeError(f"No channels with media found under: {root}")
    return chans
 

def list_videos(channel_path: str):
    """Return all playable video files in a channel directory."""

    files = []
    for name in os.listdir(channel_path):
        full = os.path.join(channel_path, name)
        if os.path.isfile(full) and name.lower().endswith(VIDEO_EXTS):
            files.append(full)
    if not files:
        raise RuntimeError(f"No videos found in channel: {channel_path}")
    return files


def build_playlist(channel_path: str) -> str:
    """Create a random playlist file for the given channel and return its path."""

    videos = list_videos(channel_path)
    n = min(PLAYLIST_SIZE, len(videos))
    chosen = random.sample(videos, n)

    with open(PLAYLIST_PATH, "w", encoding="utf-8") as f:
        for path in chosen:
            f.write(path + "\n")

    # Debug: show what we wrote to the playlist
    print(f"[TV] Playlist -> {PLAYLIST_PATH} ({len(chosen)} items)", flush=True)
    for p in chosen[:5]:
        print(f"[TV]  - {p}", flush=True)

    return PLAYLIST_PATH


def stop_process(p):
    if not p:
        return
    try:
        p.terminate()
        p.wait(timeout=2)
    except Exception:
        try:
            p.kill()
        except Exception:
            pass


def ensure_mpv() -> bool:
    """Ensure the persistent mpv process with IPC is running.

    Starts mpv if needed and waits briefly for the IPC socket to appear.
    Returns True on success, False otherwise.
    """

    global mpv_proc

    # If we already have a running mpv, nothing to do
    if mpv_proc is not None and mpv_proc.poll() is None:
        return True

    try:
        print("[TV] Starting persistent mpv with IPC...", flush=True)
        # Keep stdout/stderr visible for debugging
        mpv_proc = subprocess.Popen(MPV_CMD)
    except Exception as e:
        print(f"[TV] Failed to start mpv: {e}", flush=True)
        mpv_proc = None
        return False

    # Wait for the IPC socket to appear
    for _ in range(50):  # ~5 seconds total
        if os.path.exists(MPV_IPC_SOCKET):
            print("[TV] mpv IPC socket is ready", flush=True)
            return True
        time.sleep(0.1)

    print("[TV] mpv IPC socket did not appear in time", flush=True)
    return False


def mpv_ipc_send(command):
    """Send a command list to mpv's IPC socket.

    Example: mpv_ipc_send(["loadlist", PLAYLIST_PATH, "replace"])
    """

    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(1.0)
        sock.connect(MPV_IPC_SOCKET)
        msg = json.dumps({"command": command}) + "\n"
        sock.sendall(msg.encode("utf-8"))
        # We don't strictly need the reply, but reading avoids broken pipe
        try:
            _ = sock.recv(4096)
        except Exception:
            pass
        finally:
            sock.close()
    except Exception as e:
        print(f"[TV] mpv IPC error ({command}): {e}", flush=True)


def switch(channels, idx):
    """Main switch function.

    - Chooses the channel at index ``idx``
    - Builds a random playlist (up to PLAYLIST_SIZE unique videos)
    - Starts mpv with that playlist.
    """

    channel_path = channels[idx]
    playlist = build_playlist(channel_path)

    # Ensure the persistent mpv with IPC is running
    if not ensure_mpv():
        print("[TV] Cannot switch channel because mpv is not running", flush=True)
        return

    # Use mpv IPC to replace the current playlist with our new one
    print(f"[TV] Sending playlist to mpv via IPC: {playlist}", flush=True)
    mpv_ipc_send(["playlist-clear"])
    mpv_ipc_send(["loadlist", playlist, "replace"])
    # Make sure playback is not paused
    mpv_ipc_send(["set", "pause", False])
    print(
        f"[TV] Channel {idx+1}/{len(channels)}: {os.path.basename(channel_path)} "
        f"-> random playlist ({PLAYLIST_SIZE} max)",
        flush=True,
    )


def start_cec():
    # Feed an initial command so cec-client starts properly in non-interactive mode
    # Some setups benefit from sending "scan"
    p = subprocess.Popen(
        CEC_CMD,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,   # line-buffered in python
    )
    try:
        p.stdin.write("scan\n")
        p.stdin.flush()
    except Exception:
        pass
    return p


def parse_key(line: str):
    """Parse a cec-client log line and return a logical key name.

    Returns values like "UP", "DOWN", "LEFT", "RIGHT", "OK", or None.
    Mirrors the logic used in tv_cec_debug.py.
    """

    l = line.lower()
    if "key pressed:" not in l:
        return None

    after = l.split("key pressed:", 1)[1].strip()
    key_name = after.split()[0]  # e.g. "up", "down", "left", "right", "ok"

    if key_name == "up":
        return "UP"
    if key_name == "down":
        return "DOWN"
    if key_name == "left":
        return "LEFT"
    if key_name == "right":
        return "RIGHT"
    if key_name in ("ok", "select", "enter"):
        return "OK"

    return None


def main():
    global cec_proc, last_key_time

    channels = list_channels(TV_ROOT)
    idx = 0
    switch(channels, idx)

    cec_proc = start_cec()
    print("[TV] Listening for HDMI-CEC keys...", flush=True)

    while True:
        line = cec_proc.stdout.readline()
        if not line:
            # cec-client died, restart it
            stop_process(cec_proc)
            time.sleep(0.5)
            cec_proc = start_cec()
            continue

        key = parse_key(line)
        if not key:
            continue

        now = time.time()
        if now - last_key_time < DEBOUNCE_SECONDS:
            continue
        last_key_time = now

        if key == "UP":
            idx = (idx + 1) % len(channels)
            switch(channels, idx)
        elif key == "DOWN":
            idx = (idx - 1) % len(channels)
            switch(channels, idx)
        elif key in ("LEFT", "RIGHT", "OK"):
            # Same channel, but reshuffle playlist (change videos)
            switch(channels, idx)


if __name__ == "__main__":
    try:
        main()
    finally:
        stop_process(mpv_proc)
        stop_process(cec_proc)
