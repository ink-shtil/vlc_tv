#!/usr/bin/env python3
import os
import time
import signal
import subprocess

TV_ROOT = "/media/usb/TV"   # change to your actual mount path
MPV_CMD = [
    "mpv",
    "--fs",
    "--no-osd-bar",
    "--no-input-default-bindings",
    "--loop",
]

CEC_CMD = ["stdbuf", "-oL", "cec-client", "-d", "1"]  # line-buffered output

VIDEO_EXTS = (".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm")
DEBOUNCE_SECONDS = 0.4

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


def play_channel(channels, idx):
    global mpv_proc
    stop_process(mpv_proc)
    path = channels[idx]
    mpv_proc = subprocess.Popen(
        MPV_CMD + [path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    print(f"[TV] Playing channel {idx+1}/{len(channels)}: {os.path.basename(path)}", flush=True)


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
    # Typical line contains: "key pressed: channel up (0x...)"
    l = line.lower()
    if "key pressed:" not in l:
        return None
    if "channel up" in l:
        return "UP"
    if "channel down" in l:
        return "DOWN"
    # You can add mappings here if your remote uses different buttons:
    # if "up" in l: return "UP"
    # if "down" in l: return "DOWN"
    return None


def main():
    global cec_proc, last_key_time

    channels = list_channels(TV_ROOT)
    idx = 0
    play_channel(channels, idx)

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
            play_channel(channels, idx)
        elif key == "DOWN":
            idx = (idx - 1) % len(channels)
            play_channel(channels, idx)


if __name__ == "__main__":
    try:
        main()
    finally:
        stop_process(mpv_proc)
        stop_process(cec_proc)
