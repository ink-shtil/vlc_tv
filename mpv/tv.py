#!/usr/bin/env python3
import os
import time
import signal
import subprocess
import random
import json
import socket

# Default/fallback TV root (used only if auto-detection fails)
TV_ROOT = "/media/usb/videos"   # change to your actual mount path if needed

# Where we remember the last detected TV root directory
TV_ROOT_CACHE = "/tmp/tv_root_path.txt"

# Candidate base directories to search for mounted USB sticks
CANDIDATE_BASE_DIRS = [
    "/media",
    "/mnt",
    "/media/pi",
    "/media/usb",
    "/run/media",
    "/run/media/pi",
]

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


def find_tv_root_in_mounts():
    """Search existing mountpoints for a dir named 'videos' or 'channels'.

    Returns an absolute path to that dir, or None if not found.
    """

    target_names = {"videos", "channels"}

    for base in CANDIDATE_BASE_DIRS:
        if not os.path.isdir(base):
            continue
        for entry in os.listdir(base):
            mp = os.path.join(base, entry)
            if not os.path.isdir(mp):
                continue
            # Look for /.../videos or /.../channels
            for name in target_names:
                candidate = os.path.join(mp, name)
                if os.path.isdir(candidate):
                    print(f"[TV] Found TV root in mounts: {candidate}", flush=True)
                    return candidate
    return None


def _iter_lsblk_parts(dev):
    """Yield partition entries from an lsblk JSON blockdevice tree."""

    if dev.get("type") == "part":
        yield dev
    for ch in dev.get("children") or []:
        for part in _iter_lsblk_parts(ch):
            yield part


def mount_candidate_usb_and_find_root():
    """Try to mount a removable USB partition and then find TV root.

    Uses `lsblk -J` to detect removable partitions. Requires mount privileges.
    Returns the detected TV root path, or None on failure.
    """

    try:
        out = subprocess.check_output(
            ["lsblk", "-J", "-o", "NAME,MOUNTPOINT,RM,TYPE,LABEL"],
            text=True,
        )
        info = json.loads(out)
    except Exception as e:
        print(f"[TV] lsblk failed: {e}", flush=True)
        return None

    for dev in info.get("blockdevices") or []:
        for part in _iter_lsblk_parts(dev):
            # Only consider removable partitions that are not yet mounted
            rm = str(part.get("rm", "0"))
            if rm not in ("1", "True", "true"):
                continue
            if part.get("mountpoint"):
                continue  # already mounted; find_tv_root_in_mounts() should handle it

            name = part.get("name")  # e.g. "sda1"
            if not name:
                continue

            mountpoint = f"/mnt/tv_usb_{name}"
            os.makedirs(mountpoint, exist_ok=True)

            devpath = f"/dev/{name}"
            print(f"[TV] Mounting {devpath} -> {mountpoint}", flush=True)
            res = subprocess.run(["mount", devpath, mountpoint])
            if res.returncode != 0:
                print(f"[TV] mount failed for {devpath} (code {res.returncode})", flush=True)
                continue

            # After mounting, see if we now have videos/channels
            root = find_tv_root_in_mounts()
            if root:
                return root

    return None


def get_tv_root():
    """Get the TV root directory, auto-detecting a USB with videos/channels.

    1) If cache file exists and path is valid, use it.
    2) Otherwise search existing mounts.
    3) If still not found, try to mount a removable USB and search again.
    4) Cache the result in TV_ROOT_CACHE.
    5) If everything fails, fall back to TV_ROOT constant.
    """

    # 1) Use cached path if valid
    if os.path.isfile(TV_ROOT_CACHE):
        try:
            with open(TV_ROOT_CACHE, "r", encoding="utf-8") as f:
                cached = f.read().strip()
            if cached and os.path.isdir(cached):
                print(f"[TV] Using cached TV root: {cached}", flush=True)
                return cached
        except Exception as e:
            print(f"[TV] Failed to read cache {TV_ROOT_CACHE}: {e}", flush=True)

    # 2) Search existing mounts
    root = find_tv_root_in_mounts()
    if not root:
        # 3) Try to mount removable USB and search again
        root = mount_candidate_usb_and_find_root()

    if not root:
        # 5) Fall back to static TV_ROOT if it exists
        if os.path.isdir(TV_ROOT):
            print(f"[TV] Falling back to static TV_ROOT: {TV_ROOT}", flush=True)
            root = TV_ROOT
        else:
            raise RuntimeError(
                "Could not find USB with 'videos' or 'channels' directory, "
                f"and fallback TV_ROOT does not exist: {TV_ROOT}"
            )

    # 4) Cache the discovered path
    try:
        with open(TV_ROOT_CACHE, "w", encoding="utf-8") as f:
            f.write(root + "\n")
    except Exception as e:
        print(f"[TV] Failed to write cache file {TV_ROOT_CACHE}: {e}", flush=True)

    print(f"[TV] Using TV root: {root}", flush=True)
    return root


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

        # Remove stale IPC socket if it exists from a previous run
        if os.path.exists(MPV_IPC_SOCKET):
            try:
                os.remove(MPV_IPC_SOCKET)
                print("[TV] Removed stale mpv IPC socket", flush=True)
            except Exception as e:
                print(f"[TV] Failed to remove stale IPC socket: {e}", flush=True)

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

    global mpv_proc

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
        # Mark mpv as dead so the next switch() call restarts it
        mpv_proc = None


def shutdown_mpv():
    """Gracefully stop mpv and clean up the IPC socket."""

    # Try to ask mpv to quit via IPC (ignore errors)
    try:
        mpv_ipc_send(["quit"])
    except Exception:
        pass

    # Then force-stop the process if still running
    stop_process(mpv_proc)

    # Finally, remove any leftover socket
    if os.path.exists(MPV_IPC_SOCKET):
        try:
            os.remove(MPV_IPC_SOCKET)
        except Exception:
            pass


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
        shutdown_mpv()
        stop_process(cec_proc)
