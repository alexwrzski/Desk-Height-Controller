#!/bin/bash

# ESP32 Upload Script
PORT="/dev/cu.usbserial-0001"
SKETCH_DIR="DeskController_ESP32"
BOARD="esp32:esp32:esp32"

echo "=== ESP32 Firmware Uploader ==="
echo ""

# Check if port exists
if [ ! -e "$PORT" ]; then
    echo "✗ ESP32 not found at $PORT"
    echo "  Please connect ESP32 via USB and try again"
    echo ""
    echo "Available ports:"
    ls -1 /dev/cu.* 2>/dev/null | grep -i usb || echo "  None found"
    exit 1
fi

echo "✓ Found ESP32 at $PORT"
echo ""

# Check if sketch exists
if [ ! -f "$SKETCH_DIR/DeskController_ESP32.ino" ]; then
    echo "✗ Sketch not found at $SKETCH_DIR/DeskController_ESP32.ino"
    exit 1
fi

echo "Uploading firmware..."
echo "  Board: $BOARD"
echo "  Port: $PORT"
echo "  Sketch: $SKETCH_DIR"
echo ""

# Compile and upload
arduino-cli compile --fqbn $BOARD $SKETCH_DIR && \
arduino-cli upload -p $PORT --fqbn $BOARD $SKETCH_DIR

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Upload successful!"
    echo ""
    echo "The ESP32 will now:"
    echo "  1. Connect to 'Free WiFi' (2.4GHz)"
    echo "  2. Start HTTP server on port 80"
    echo "  3. Display IP address in serial monitor"
    echo ""
    echo "To view serial output:"
    echo "  arduino-cli monitor -p $PORT -c baudrate=115200"
else
    echo ""
    echo "✗ Upload failed. Check:"
    echo "  1. ESP32 is connected via USB"
    echo "  2. Correct board is selected"
    echo "  3. Port is correct"
fi
