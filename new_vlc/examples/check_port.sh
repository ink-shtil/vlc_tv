#!/bin/bash
# Script to check if a port is open/listening on a host (default: localhost).
# Usage: ./check_port.sh <port> [host]
# Example: ./check_port.sh 4212
#          ./check_port.sh 80 192.168.0.12

PORT="${1:-4212}"
HOST="${2:-127.0.0.1}"

# Try with nc (netcat)
if command -v nc >/dev/null 2>&1; then
  nc -z -w 2 "$HOST" "$PORT"
  if [ $? -eq 0 ]; then
    echo "Port $PORT is OPEN on $HOST."
    exit 0
  else
    echo "Port $PORT is CLOSED on $HOST."
    exit 1
  fi
fi

# Fallback to ss
if command -v ss >/dev/null 2>&1; then
  if ss -tuln | grep -q ":$PORT "; then
    echo "Port $PORT is OPEN (listening) on $HOST."
    exit 0
  else
    echo "Port $PORT is CLOSED on $HOST."
    exit 1
  fi
fi

# Fallback to netstat
if command -v netstat >/dev/null 2>&1; then
  if netstat -tuln | grep -q ":$PORT "; then
    echo "Port $PORT is OPEN (listening) on $HOST."
    exit 0
  else
    echo "Port $PORT is CLOSED on $HOST."
    exit 1
  fi
fi

echo "No suitable tool found (nc, ss, or netstat required)."
exit 2
