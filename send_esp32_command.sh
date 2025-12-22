#!/bin/bash
# Helper script to send commands to ESP32
# This runs in the user's terminal environment where curl works

IP="${1:-192.168.0.194}"
COMMAND="${2:-status}"

# Remove http:// if present
IP=$(echo "$IP" | sed 's|http://||' | sed 's|https://||')

curl -s -m 5 --connect-timeout 5 "http://${IP}/${COMMAND}" 2>/dev/null
