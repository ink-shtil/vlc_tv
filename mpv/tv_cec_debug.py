#!/usr/bin/env python3
"""Simple HDMI-CEC debug helper.

This script is based on mpv/tv.py but strips out all mpv/channel logic
and focuses purely on inspecting cec-client output.

Features:
  * Starts cec-client (with stdbuf for line-buffered output)
  * Prints every line from cec-client with timestamps
  * Optionally highlights any lines that look like key events
  * Allows overriding the cec-client command via the CEC_CMD environment var

Usage (from project root or mpv directory):

  cd mpv
  python3 tv_cec_debug.py

You can experiment with cec-client flags via:

  CEC_CMD="cec-client -d 31" python3 tv_cec_debug.py

"""

import os
import sys
import time
import subprocess
from typing import Optional, List

try:
    # Reuse channel logic from the main TV script if available
    from tv import list_channels, TV_ROOT
except Exception:
    list_channels = None  # type: ignore
    TV_ROOT = None  # type: ignore


# Default cec-client command. Adjust if needed for your environment.
#
# We use a verbose mode by default so that key events such as
# "user control pressed" / "key pressed" / "key released" appear
# in the log output, similar to running `cec-client -f` manually.
DEFAULT_CEC_CMD: List[str] = [
	"stdbuf", "-oL", "cec-client", "-f",
]

# If set, this completely overrides DEFAULT_CEC_CMD.
# Example:
#   export CEC_CMD="cec-client -d 31 -t p -b 5"
ENV_CEC_CMD: Optional[str] = os.getenv("CEC_CMD")


def build_cec_cmd() -> List[str]:
    """Build the command used to start cec-client.

    If CEC_CMD env var is set, use that (shell-split). Otherwise fallback
    to DEFAULT_CEC_CMD.
    """

    if ENV_CEC_CMD:
        import shlex
        try:
            cmd = shlex.split(ENV_CEC_CMD)
            if not cmd:
                raise ValueError("CEC_CMD is empty after parsing")
            return cmd
        except Exception as e:
            print(f"[CEC-DEBUG] Failed to parse CEC_CMD env var: {e}", flush=True)

    return list(DEFAULT_CEC_CMD)


def start_cec() -> subprocess.Popen:
    """Start cec-client and optionally send an initial 'scan' command."""

    cmd = build_cec_cmd()
    print(f"[CEC-DEBUG] Starting cec-client: {' '.join(cmd)}", flush=True)

    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,  # line-buffered
    )

    # Try to send an initial scan to wake things up (if supported)
    try:
        if proc.stdin:
            proc.stdin.write("scan\n")
            proc.stdin.flush()
            print("[CEC-DEBUG] Sent initial 'scan' command", flush=True)
    except Exception as e:
        print(f"[CEC-DEBUG] Failed to send initial scan: {e}", flush=True)

    return proc


def parse_key(line: str) -> Optional[str]:
    """Parse a cec-client log line and return a logical key name.

    Returns values like "UP", "DOWN", "LEFT", "RIGHT", "OK", etc.,
    or None if the line does not correspond to a key press.
    """

    l = line.lower()

    # Prefer "key pressed:" entries, which contain the button name.
    if "key pressed:" in l:
        # Example: "... key pressed: up (1) current(ff) duration(0)"
        after = l.split("key pressed:", 1)[1].strip()
        # Take the first token as the key name ("up" in the example above)
        key_name = after.split()[0]

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

        # Fallback: return the raw key name uppercased
        return key_name.upper()

    # As a fallback, recognize generic user control messages if present
    if "user control pressed" in l:
        return "USER_CONTROL"

    return None


def main() -> int:
    """Main loop: listen for CEC key presses and simulate channel changes.

    By default only prints high-level key + channel info, not raw CEC lines.
    To see everything, run with CEC_DEBUG_RAW=1.
    """

    raw_debug = os.getenv("CEC_DEBUG_RAW") == "1"

    # Try to load real channels from tv.py if available
    channels: Optional[List[str]] = None
    current_idx = 0

    # Simple debounce so that multiple "key pressed" lines for
    # a single physical press only move the channel once.
    DEBOUNCE_SECONDS = 0.3
    last_key_name: Optional[str] = None
    last_key_time: float = 0.0

    if list_channels and TV_ROOT:
        try:
            channels = list_channels(TV_ROOT)
            if channels:
                print(
                    f"[CEC-DEBUG] Loaded {len(channels)} channels from {TV_ROOT}",
                    flush=True,
                )
        except Exception as e:
            print(f"[CEC-DEBUG] Could not load channels for debug: {e}", flush=True)
            channels = None

    if channels is None:
        print("[CEC-DEBUG] Channel list unavailable; will only log key presses.", flush=True)

    proc = start_cec()
    print("[CEC-DEBUG] Listening to cec-client output. Press Ctrl+C to stop.", flush=True)

    try:
        while True:
            line = proc.stdout.readline()

            # If cec-client died, restart after a short delay
            if not line:
                print("[CEC-DEBUG] cec-client exited, restarting in 1s...", flush=True)
                try:
                    proc.terminate()
                except Exception:
                    pass
                time.sleep(1)
                proc = start_cec()
                continue

            line = line.rstrip("\n")
            ts = time.strftime("%H:%M:%S")

            if raw_debug:
                print(f"[{ts}] RAW: {line}", flush=True)

            key = parse_key(line)
            if not key:
                continue

            # Debounce repeated identical keys within a short window
            now = time.time()
            if key == last_key_name and (now - last_key_time) < DEBOUNCE_SECONDS:
                continue
            last_key_name = key
            last_key_time = now

            # Always show a concise key line
            print(f"[{ts}] KEY: {key}", flush=True)

            # If we have a real channel list, simulate channel switching
            if channels:
                if key == "UP":
                    current_idx = (current_idx + 1) % len(channels)
                elif key == "DOWN":
                    current_idx = (current_idx - 1) % len(channels)
                else:
                    # Only UP/DOWN affect channel index for now
                    continue

                chan_path = channels[current_idx]
                chan_name = os.path.basename(chan_path)
                print(
                    f"[{ts}] CHANNEL -> {current_idx + 1}/{len(channels)}: {chan_name}",
                    flush=True,
                )

    except KeyboardInterrupt:
        print("\n[CEC-DEBUG] Stopping due to KeyboardInterrupt", flush=True)
        return 0
    except Exception as e:
        print(f"[CEC-DEBUG] Fatal error: {e}", flush=True)
        return 1
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())
