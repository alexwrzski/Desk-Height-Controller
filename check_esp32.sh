#!/bin/bash
# Quick script to check ESP32 status

echo "=== ESP32 Connection Checker ==="
echo ""

# Check if ESP32 is connected via USB
if [ -e /dev/cu.usbserial-0001 ]; then
    echo "✓ ESP32 found on /dev/cu.usbserial-0001"
else
    echo "✗ ESP32 not found on USB"
    exit 1
fi

echo ""
echo "Reading serial output (wait 10 seconds for WiFi connection)..."
echo "Press Ctrl+C to stop"
echo ""

arduino-cli monitor -p /dev/cu.usbserial-0001 --config baudrate=115200 2>&1 | grep -E "(IP address|Connected|ERROR|Ready)" --line-buffered

