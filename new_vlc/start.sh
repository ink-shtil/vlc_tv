#!/bin/bash
# Start VLC with remote control interface optimized for TV-like experience
# To enable looping of the playlist, connect to the rc interface (e.g., with nc or telnet) and use the 'loop' command.

# ========== Configuration Mode ==========
# Set to 1 to use advanced configurable options below
# Set to 0 to use simple original command (fast fallback)
USE_ADVANCED_CONFIG=1

# ========== Configuration Variables ==========

# Caching settings (milliseconds)
# Lower values = faster channel switching, but may cause stuttering
# Higher values = smoother playback, but slower channel switching
FILE_CACHE=6000          # Local file caching (default: 300, recommended: 1000-5000)
NETWORK_CACHE=6000       # Network stream caching (default: 300, recommended: 1000-3000)
DISC_CACHE=6000          # DVD/Blu-ray caching (default: 300, recommended: 1000-3000)
LIVE_CACHE=2000          # Live stream caching (default: 300, recommended: 1000-2000)

# Remote control interface settings
RC_HOST="0.0.0.0"        # Listen on all interfaces (use 127.0.0.1 for localhost only)
RC_PORT="4212"           # Remote control port

# Display settings
DISPLAY_NUM=":0"         # X11 display number

# Performance & UI flags (1=enabled, 0=disabled)
#
# GROUP 1: Visual Cleanup (recommended for TV mode)
NO_VIDEO_TITLE=1         # Disable video title overlay at start (cleaner, faster)
NO_SNAPSHOT_PREVIEW=1    # Disable snapshot preview thumbnail
#
# GROUP 2: Interaction Control (prevents popups/dialogs)
NO_INTERACT=1            # Disable interactive error dialogs (prevents interruptions)
QUIET=1                  # Suppress console warnings/messages
#
# GROUP 3: Resource Optimization
NO_MEDIA_LIBRARY=1       # Disable media library (reduces startup overhead)

# Experimental options (1=enabled, 0=disabled) - USE WITH CAUTION
#
# GROUP 4: Experimental Performance (may reduce quality or cause issues)
AUTO_ADJUST_PTS=0        # Auto-adjust presentation timestamp delay (may help sync issues)
AVCODEC_FAST=0           # Fast decoding (lower quality, better performance)
AVCODEC_SKIP_LOOP=0      # Skip loop filter (reduces decoding overhead)

# ========== Build VLC Command ==========

VLC_OPTS=""

# --- Remote Control Interface ---
VLC_OPTS="$VLC_OPTS --rc-host=$RC_HOST:$RC_PORT"

# --- Caching Options (affects channel switch speed vs smoothness) ---
VLC_OPTS="$VLC_OPTS --file-caching=$FILE_CACHE"
VLC_OPTS="$VLC_OPTS --network-caching=$NETWORK_CACHE"
VLC_OPTS="$VLC_OPTS --disc-caching=$DISC_CACHE"
VLC_OPTS="$VLC_OPTS --live-caching=$LIVE_CACHE"

# --- Core Display Options (always enabled) ---
VLC_OPTS="$VLC_OPTS --no-osd"                # Disable on-screen display
VLC_OPTS="$VLC_OPTS --no-keyboard-events"    # Disable VLC keyboard shortcuts
VLC_OPTS="$VLC_OPTS -f"                      # Fullscreen mode
VLC_OPTS="$VLC_OPTS --vout=gl"               # Use OpenGL video output

# NOTE: Playlist loop is controlled dynamically via RC interface (not --loop flag)
# This allows better control when switching channels

# --- GROUP 1: Visual Cleanup ---
[ "$NO_VIDEO_TITLE" = "1" ] && VLC_OPTS="$VLC_OPTS --no-video-title-show"
[ "$NO_SNAPSHOT_PREVIEW" = "1" ] && VLC_OPTS="$VLC_OPTS --no-snapshot-preview"

# --- GROUP 2: Interaction Control ---
[ "$NO_INTERACT" = "1" ] && VLC_OPTS="$VLC_OPTS --no-interact"
[ "$QUIET" = "1" ] && VLC_OPTS="$VLC_OPTS --quiet"

# --- GROUP 3: Resource Optimization ---
[ "$NO_MEDIA_LIBRARY" = "1" ] && VLC_OPTS="$VLC_OPTS --no-media-library"

# --- GROUP 4: Experimental Performance (use with caution) ---
[ "$AUTO_ADJUST_PTS" = "1" ] && VLC_OPTS="$VLC_OPTS --auto-adjust-pts-delay"
[ "$AVCODEC_FAST" = "1" ] && VLC_OPTS="$VLC_OPTS --avcodec-fast"
[ "$AVCODEC_SKIP_LOOP" = "1" ] && VLC_OPTS="$VLC_OPTS --avcodec-skiploopfilter=all"

# ========== Launch VLC ==========

if [ "$USE_ADVANCED_CONFIG" = "1" ]; then
    # Advanced mode: Use configurable options
    # shellcheck disable=SC2086
    DISPLAY=$DISPLAY_NUM cvlc $VLC_OPTS
else
    # Simple mode: Original command (fallback) - loop controlled via RC interface
    DISPLAY=:0 cvlc --rc-host=0.0.0.0:4212 --no-osd --no-keyboard-events --file-caching=3000 --network-caching=3000 -f
fi
