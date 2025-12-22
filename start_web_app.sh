#!/bin/bash
# Start the Desk Controller Web App

cd "$(dirname "$0")"
echo "Starting Desk Controller Web App..."
echo "ESP32 IP: http://192.168.0.194"
echo ""
echo "Opening browser..."
sleep 2
open http://localhost:5000
echo ""
echo "Web app running at: http://localhost:5000"
echo "Press Ctrl+C to stop"
/Library/Frameworks/Python.framework/Versions/3.12/bin/python3 web_app.py
