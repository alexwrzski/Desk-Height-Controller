# IKEA Standing Desk Controller

A smart WiFi-enabled controller for IKEA electric standing desks that adds precise height control, preset positions, and a modern web interface.

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

### 3. Configure
- Update WiFi credentials in `DeskController_ESP32.ino` (lines 10-11)
- Update ESP32 IP address in `web_app.py` (line 11)
- Adjust min/max height limits in the Settings page

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
- Verify ESP32 IP address in `web_app.py`
- Check that ESP32 and computer are on same network
- Ensure web app is running (`./start_web_app.sh`)

## License

This project is open source and available for personal use.

## Contributing

Feel free to submit issues or pull requests if you have improvements!
