#!/bin/bash

# Configuration
PID_FILE="/tmp/vlc_tv.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if VLC is running
if [ ! -f "$PID_FILE" ]; then
    log_warn "VLC does not appear to be running (no PID file found)"
    exit 0
fi

# Read PID
VLC_PID=$(cat "$PID_FILE")

# Check if process exists
if ! kill -0 "$VLC_PID" 2>/dev/null; then
    log_warn "VLC process (PID: $VLC_PID) is not running"
    log_info "Cleaning up stale PID file..."
    rm -f "$PID_FILE"
    exit 0
fi

# Stop VLC gracefully
log_info "Stopping VLC (PID: $VLC_PID)..."
kill "$VLC_PID"

# Wait for process to exit (max 5 seconds)
WAIT_COUNT=0
MAX_WAIT=5
while kill -0 "$VLC_PID" 2>/dev/null; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log_warn "VLC did not stop gracefully, forcing..."
        kill -9 "$VLC_PID"
        sleep 1
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

# Verify process is stopped
if kill -0 "$VLC_PID" 2>/dev/null; then
    log_error "Failed to stop VLC process"
    exit 1
fi

# Clean up PID file
rm -f "$PID_FILE"
log_info "VLC stopped successfully"
