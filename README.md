# Desk Controller - Swift Native App

A native macOS application for controlling an IKEA standing desk via ESP32, built entirely in Swift using SwiftUI.

## Features

- 🎯 **Precise Height Control**: Move to exact heights using a VL53L0X distance sensor
- 📱 **Native macOS Interface**: Beautiful, native SwiftUI interface
- 💾 **Preset Positions**: Save and recall up to 3 favorite heights (Sit, Stand, Focus, etc.)
- 🛡️ **Safety Limits**: Configurable min/max height limits with automatic stop protection
- ⚡ **Real-time Monitoring**: Live height display updates every 2 seconds
- 🎮 **Multiple Control Methods**:
  - Manual up/down buttons (hold to move)
  - Quick preset buttons
  - Manual height input
- 🔧 **Non-blocking Movement**: Stop preset movements at any time
- 📶 **WiFi Manager**: Easy setup with ESP32 connection management

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode 13.0 or later
- ESP32 device running DeskController firmware
- ESP32 and Mac on the same WiFi network

## Building

1. Open `DeskController.xcodeproj` in Xcode
2. Select your target (DeskController)
3. Build and run (⌘R)

## Usage

### First Time Setup

1. **Configure ESP32 WiFi** (if not already done):
   - ESP32 will create WiFi network: **"DeskController-Setup"**
   - Connect your phone/computer to this network (password: `setup12345`)
   - Open setup page at `http://192.168.4.1/setup`
   - Enter your WiFi credentials and connect
   - Note the ESP32 IP address shown

2. **Configure App**:
   - Launch the app
   - Open Settings (⚙ button)
   - Enter ESP32 IP address in "ESP32 Connection" section
   - Click "Test Connection" to verify
   - Click "Save IP" to save

### Controls

- **UP/DOWN buttons**: Hold to move, release to stop
- **STOP button**: Immediately stops any movement
- **Preset buttons**: Click to move to saved height
- **Settings**: Configure presets, limits, and ESP32 connection

### Settings

- **Manual Movement**: Enter a specific height (in mm) to move to
- **Manage Presets**: Add, edit, or remove preset positions
- **Safety Limits**: Configure min/max height boundaries
- **ESP32 Connection**: Configure WiFi IP address, test connection, reset WiFi

## Project Structure

```
Desk Controller - Swift/
├── DeskController/
│   ├── DeskControllerApp.swift    # Main SwiftUI app entry point
│   ├── ContentView.swift          # Main UI view
│   ├── SettingsView.swift         # Settings modal
│   ├── AppState.swift             # Observable state management
│   ├── ESP32Client.swift          # HTTP client for ESP32
│   ├── Info.plist                 # App configuration
│   └── Assets.xcassets/           # App icons
├── DeskController_ESP32/          # ESP32 firmware (shared)
└── README.md                      # This file
```

## Architecture

The app uses:
- **SwiftUI** for the user interface
- **Combine** for reactive state management
- **URLSession** for HTTP communication with ESP32
- **UserDefaults** for local storage (presets, IP address, limits)

## ESP32 Communication

The app communicates with the ESP32 via HTTP GET requests:
- `/status` - Get current height
- `/up` - Move up
- `/down` - Move down
- `/stop` - Stop movement
- `/goto{N}` - Go to preset N
- `/height{height}` - Move to specific height
- `/limits` - Get min/max limits
- `/setmin{value}` - Set min limit
- `/setmax{value}` - Set max limit
- `/set{N} {height}` - Set preset N
- `/resetwifi` - Reset WiFi settings

## License

This project is open source and available for personal use.
