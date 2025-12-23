# IKEA Standing Desk Controller

A smart WiFi-enabled controller for IKEA electric standing desks that adds precise height control, preset positions, and a modern web interface.

<div align="center">
  <img src="screenshot.png" alt="Desk Controller Web Interface" width="600">
</div>

## Features

- 🎯 **Precise Height Control**: Move to exact heights using a VL53L0X distance sensor
- 📱 **Modern Web Interface**: Beautiful, responsive web app accessible from any device
- 💾 **Preset Positions**: Save and recall up to 3 favorite heights (Sit, Stand, Focus, etc.)
- 🛡️ **Safety Limits**: Configurable min/max height limits with automatic stop protection
- ⚡ **Real-time Monitoring**: Live height display updates every 2 seconds
- 🎮 **Multiple Control Methods**:
  - Manual up/down buttons
  - Quick preset buttons
  - Manual height input
- 🔧 **Non-blocking Movement**: Stop preset movements at any time
- 📊 **Smart Movement Detection**: Automatically stops when desk hits physical limits
- 📶 **WiFi Manager**: Easy setup with captive portal - no code editing required!
- 🔄 **Auto-Reconnect**: Automatically reconnects if WiFi drops

## Quick Start

### 1. Upload Firmware
```bash
./upload_esp32.sh
```

### 2. Start Web App
```bash
./start_web_app.sh
```

Then open your browser to `http://localhost:5000`

### 3. Configure WiFi (First Time Only)

**Option A: Automatic Setup (Recommended)**
1. ESP32 will create WiFi network: **"DeskController-Setup"**
2. Connect your phone/computer to this network (password: `setup12345`)
3. Setup page opens automatically in browser
4. Enter your WiFi credentials and connect
5. Note the ESP32 IP address shown
6. Enter this IP in the web app when prompted

**Option B: Manual Configuration**
- If ESP32 already has WiFi credentials saved, it will connect automatically
- Find ESP32 IP address in router admin or serial monitor
- Enter IP in web app Settings → ESP32 Connection

### 4. Adjust Settings
- Configure min/max height limits in Settings page
- Add/edit preset positions
- Change ESP32 IP address if needed (Settings → ESP32 Connection)

## Project Structure

```
Desk Controller/
├── DeskController_ESP32/
│   └── DeskController_ESP32.ino    # ESP32 firmware
├── web_app.py                       # Flask web server
├── upload_esp32.sh                  # Firmware upload script
├── start_web_app.sh                 # Start web app script
├── SETUP_GUIDE.md                   # Detailed setup instructions
└── README.md                        # This file
```

## Requirements

- ESP32 development board
- VL53L0X Time-of-Flight distance sensor
- 2-channel relay module
- IKEA electric standing desk with manual up/down buttons
- Python 3 with Flask
- Arduino CLI (for firmware upload)

## Usage

### Manual Control
- **UP/DOWN buttons**: Hold to move, release to stop
- **STOP button**: Immediately stops any movement

### Presets
Click any preset button to move to that saved height. You can stop the movement at any time using the STOP button.

### Settings
- **Manual Movement**: Enter a specific height (in mm) to move to
- **Manage Presets**: Add, edit, or remove preset positions
- **Safety Limits**: Configure min/max height boundaries
- **ESP32 Connection**: Configure WiFi IP address, test connection, reset WiFi

## Safety Features

- **Emergency stops** at configured limits (minHeight + 10mm, maxHeight - 10mm)
- **Physical limit detection**: Automatically stops when desk can't move further
- **Movement timeout**: 30-second safety timeout
- **Continuous monitoring**: All movement types respect safety limits

## Hardware Integration

The controller uses relays soldered directly to the up/down buttons on the IKEA desk's control panel. The VL53L0X sensor is mounted on the bottom of the desk surface to measure height.

For detailed hardware setup, wiring diagrams, and parts list, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

## Troubleshooting

### Desk not moving
- Check WiFi connection (ESP32 LED should be solid on)
- Verify relay connections
- Check serial monitor for error messages

### Height readings incorrect
- Ensure sensor is mounted securely on desk bottom
- Check sensor wiring (SDA/SCL connections)
- Verify sensor is within range (VL53L0X range: ~30-2000mm)

### Can't connect to web app
- Check ESP32 IP address in Settings → ESP32 Connection
- Use "Test Connection" button to verify connectivity
- If disconnected, web app will show setup page automatically
- Ensure ESP32 and computer are on same network
- Ensure web app is running (`./start_web_app.sh`)

### WiFi Setup Issues
- **ESP32 not creating "DeskController-Setup" network**: 
  - Check serial monitor for errors
  - Try resetting ESP32 or use "Reset WiFi" in Settings
- **Can't access setup page**: 
  - Connect to "DeskController-Setup" WiFi first
  - Open any browser - setup page should open automatically
  - Or manually navigate to `http://192.168.4.1/setup`
- **WiFi connection fails**: 
  - Ensure network is 2.4GHz (ESP32 doesn't support 5GHz)
  - Check password is correct
  - Verify network is in range

## License

This project is open source and available for personal use.

## Contributing

Feel free to submit issues or pull requests if you have improvements!
