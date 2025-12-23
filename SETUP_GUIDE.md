# IKEA Standing Desk Controller - Detailed Setup Guide

Complete guide for building and setting up your smart IKEA standing desk controller.

## Table of Contents
- [Parts List](#parts-list)
- [Hardware Overview](#hardware-overview)
- [Wiring Diagram](#wiring-diagram)
- [Assembly Instructions](#assembly-instructions)
- [Software Setup](#software-setup)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Parts List

### Required Components

| Component | Quantity | Notes |
|-----------|----------|-------|
| ESP32 Development Board | 1 | Any ESP32 board (ESP32-DevKitC, NodeMCU-32S, etc.) |
| VL53L0X Time-of-Flight Sensor | 1 | Adafruit VL53L0X or compatible |
| 2-Channel Relay Module | 1 | 5V relay module (active LOW) |
| IKEA Electric Standing Desk | 1 | Any IKEA desk with motorized height adjustment |
| Jumper Wires | Various | For connections |
| USB Cable | 1 | For ESP32 programming and power |
| Power Supply | 1 | 5V for relay module (if not powered via USB) |

### Optional Components
- Status LED (built into ESP32 or external)
- Enclosure/box for ESP32 and relay
- Small breadboard or perfboard
- Wire strippers and soldering iron (for desk button connections)

## Hardware Overview

The system consists of three main components:

1. **ESP32**: Main microcontroller running the WiFi server and control logic
2. **VL53L0X Sensor**: Measures distance from desk bottom to floor (gives desk height)
3. **Relay Module**: Controls desk movement by simulating button presses on IKEA controller

### System Architecture

```
                    WiFi Network
    ┌──────────────────────────────────────┐
    │                                      │
    │  ┌─────────────┐         ┌──────────────┐         ┌─────────────┐
    │  │   Web App   │◄──WiFi──►│    ESP32     │◄──I2C───►│  VL53L0X    │
    │  │  (Browser)  │         │  Microcontroller│      │   Sensor    │
    │  │ localhost   │         │              │         │  (mounted   │
    │  │  :5000      │         │              │         │  on desk)   │
    │  └─────────────┘         │              │         └─────────────┘
    │                          │              │
    │                          │              │◄──GPIO───►┌─────────────┐
    │                          │              │           │  2-Channel  │
    │                          └──────────────┘           │   Relay     │
    │                                                      │   Module    │
    │                                                      │             │
    │                                                      │             │◄──Solder──►┌──────────────┐
    │                                                      │             │    Wires   │  IKEA Desk   │
    │                                                      └─────────────┘            │  Controller  │
    │                                                                                  │  (Up/Down    │
    │                                                                                  │   Buttons)   │
    └──────────────────────────────────────────────────────────────────────────────────└──────────────┘
```

### Physical Layout

```
                    Desk Surface
    ────────────────────────────────────────────
                          │
                          │ VL53L0X Sensor
                          │ (mounted underneath)
                          │
                          │
    ┌───────────────────────────────────────────┐
    │                                           │
    │          IKEA Desk Controller             │
    │  ┌──────────────┐                        │
    │  │ [UP] [DOWN]  │  ◄── Relay wires       │
    │  └──────────────┘     soldered here      │
    │                                           │
    └───────────────────────────────────────────┘
                          │
                          │
    ┌───────────────────────────────────────────┐
    │        ESP32 + Relay Module Enclosure     │
    │                                           │
    │  ┌──────────┐      ┌─────────────┐      │
    │  │  ESP32   │◄────►│   Relay     │      │
    │  │  Board   │ GPIO │   Module    │      │
    │  └──────────┘      └─────────────┘      │
    │                                           │
    └───────────────────────────────────────────┘
                          │
                          │ USB Power/Cable
```

## Wiring Diagram

### ESP32 Connections

```
ESP32 Board                  External Component
───────────                  ──────────────────
GPIO 16  ──────────────────► Relay Channel 1 (UP)
GPIO 17  ──────────────────► Relay Channel 2 (DOWN)
GPIO 4   ──────────────────► Status LED (optional)
3.3V     ──────────────────► VL53L0X VCC
GND      ──────────────────► VL53L0X GND
GPIO 21  ──────────────────► VL53L0X SDA (I2C)
GPIO 22  ──────────────────► VL53L0X SCL (I2C)
GND      ──────────────────► Relay Module GND
```

### VL53L0X Sensor Connections

```
VL53L0X Pin    ESP32 Pin
────────────   ──────────
VCC       ────► 3.3V
GND       ────► GND
SDA       ────► GPIO 21 (I2C SDA)
SCL       ────► GPIO 22 (I2C SCL)
```

### Relay Module Connections

```
Relay Module   ESP32 Pin          IKEA Controller
────────────   ──────────         ────────────────
IN1        ────► GPIO 16          ────► UP Button (solder to button terminals)
IN2        ────► GPIO 17          ────► DOWN Button (solder to button terminals)
VCC        ────► 5V or USB power
GND        ────► GND
```

**Important Notes:**
- Most relay modules are **active LOW**, meaning LOW signal = relay ON
- The relay contacts are wired in parallel with the desk's up/down buttons
- When relay closes, it simulates a button press on the IKEA controller

### IKEA Desk Controller Integration

#### Opening the IKEA Controller
1. Carefully remove the controller panel from your IKEA desk
2. Open the enclosure to access the internal circuit board
3. Locate the UP and DOWN button connections on the PCB

#### Connecting Relays to Buttons

**Button Terminal Layout:**
```
IKEA Controller PCB (Top View)
─────────────────────────────────────────
┌──────────────────────────────────────┐
│                                      │
│   [UP Button]      [DOWN Button]    │
│      ║                  ║            │
│   ┌──┴──┐           ┌──┴──┐         │
│   │  A  │           │  C  │  Terminal 1
│   │     │           │     │
│   └──┬──┘           └──┬──┘
│      ║                 ║
│   ┌──┴──┐           ┌──┴──┐
│   │  B  │           │  D  │  Terminal 2
│   └──┬──┘           └──┬──┘
│      ║                 ║
│                                      │
└──────────────────────────────────────┘
```

**Relay Wiring:**
```
Relay Channel 1 (UP)              Relay Channel 2 (DOWN)
┌─────────────┐                   ┌─────────────┐
│    NO       │───────────────────┼──► A (UP)   │
│  (Normally  │                   │             │
│   Open)     │                   │             │
│             │                   │             │
│    COM      │───────────────────┼──► B (UP)   │
└─────────────┘                   └─────────────┘

┌─────────────┐                   ┌─────────────┐
│    NO       │───────────────────┼──► C (DOWN) │
│  (Normally  │                   │             │
│   Open)     │                   │             │
│             │                   │             │
│    COM      │───────────────────┼──► D (DOWN) │
└─────────────┘                   └─────────────┘
```

**How It Works:**
- When ESP32 sets GPIO LOW, relay closes (NO contacts connect)
- This creates a connection across the button terminals (simulates button press)
- IKEA controller thinks button is being pressed
- Desk starts moving
- When ESP32 sets GPIO HIGH, relay opens (button "released")

**Wiring Steps:**
1. Identify the two terminals of the UP button on the IKEA controller PCB
2. Solder two wires from these terminals to the NO (Normally Open) contacts of Relay Channel 1
3. Repeat for DOWN button → Relay Channel 2
4. **Important**: The relay acts as a switch across the button - when closed, it simulates pressing the button

**Safety Note:**
- Ensure the desk is unplugged before soldering
- Use appropriate wire gauge (22-24 AWG is typical)
- Secure wires to prevent shorts
- Consider using heat shrink tubing or electrical tape for insulation

## Assembly Instructions

### Step 1: Mount the VL53L0X Sensor

The sensor should be mounted on the **bottom of the desk surface**, pointing downward toward the floor.

```
                    Side View
    ────────────────────────────────────────
                                    ║
    ┌───────────────────────────────║──────┐ Desk Surface
    │                               ║      │ (Top)
    │                               ║      │
    │                    ┌──────────▼─────┐│
    │                    │  VL53L0X       ││ Sensor
    │                    │  Sensor        ││ (mounted)
    │                    │  (pointing ↓)  ││
    │                    └────────────────┘│
    │                                      │
    └──────────────────────────────────────┘ Desk Bottom
                                    │
                                    │
                                    │  Distance = Height
                                    │  (sensor reads this)
                                    │
                                    │
    ────────────────────────────────────────── Floor
                                    ║
```

**Mounting Steps:**
1. Choose a location on the underside of the desk (typically near the center)
2. Secure the sensor using double-sided tape, screws, or mounting bracket
3. Ensure the sensor has a clear line of sight to the floor
4. Sensor range: ~30mm to 2000mm

**Mounting Tips:**
- Avoid mounting directly over desk legs or mechanisms
- Ensure sensor face is parallel to floor for accurate readings
- Keep sensor away from edges where objects might interfere
- Mount sensor so it moves with the desk (on the desktop, not on a leg)

**How Height Measurement Works:**
- Sensor measures distance from sensor to floor
- Since sensor is attached to desk bottom, this distance IS the desk height
- When desk goes up → sensor goes up → distance increases → height reading increases
- When desk goes down → sensor goes down → distance decreases → height reading decreases

### Step 2: Wire ESP32 and Components

1. Connect VL53L0X to ESP32 (I2C bus):
   - VCC → 3.3V
   - GND → GND  
   - SDA → GPIO 21
   - SCL → GPIO 22

2. Connect Relay Module:
   - IN1 → GPIO 16
   - IN2 → GPIO 17
   - VCC → 5V (or USB power if relay supports 5V)
   - GND → GND

3. Connect Status LED (optional):
   - LED anode → GPIO 4 (through 220Ω resistor)
   - LED cathode → GND

### Step 3: Integrate with IKEA Controller

1. **Disconnect desk power** completely
2. Open the IKEA desk controller housing
3. Identify UP and DOWN button terminals on PCB
4. Solder relay wires to button terminals:
   - Relay Channel 1 NO contacts → UP button terminals
   - Relay Channel 2 NO contacts → DOWN button terminals
5. Secure all wires and close controller housing
6. Test continuity with multimeter before powering on

### Step 4: Enclosure (Optional)

Consider placing ESP32 and relay module in a small enclosure:
- Protects components from dust and damage
- Provides mounting points
- Use enclosure with ventilation if components generate heat
- Ensure USB cable can reach for programming/updates

## Software Setup

### Prerequisites

1. **Install Arduino CLI**:
   ```bash
   # macOS
   brew install arduino-cli
   
   # Or download from: https://arduino.github.io/arduino-cli/
   ```

2. **Install ESP32 Board Support**:
   ```bash
   arduino-cli core update-index
   arduino-cli core install esp32:esp32
   ```

3. **Install Required Libraries**:
   ```bash
   arduino-cli lib install "WiFi"
   arduino-cli lib install "Adafruit VL53L0X"
   ```

4. **Install Python Dependencies**:
   ```bash
   pip3 install flask
   ```

### Firmware Configuration

Edit `DeskController_ESP32/DeskController_ESP32.ino`:

```cpp
// Update WiFi credentials (line 10-11)
const char* ssid = "YOUR_WIFI_SSID";      // 2.4GHz only!
const char* password = "YOUR_WIFI_PASSWORD";

// Adjust default limits if needed (line 17-18)
int minHeight = 575;   // Minimum desk height in mm
int maxHeight = 1185;  // Maximum desk height in mm
```

**Important**: ESP32 only supports 2.4GHz WiFi networks, not 5GHz!

### Web App Configuration

Edit `web_app.py`:

```python
# Update ESP32 IP address (line 11)
ESP32_IP = "http://192.168.0.194"  # Replace with your ESP32's IP
```

To find ESP32 IP address:
1. Upload firmware
2. Open serial monitor: `arduino-cli monitor -p /dev/cu.usbserial-0001 -c baudrate=115200`
3. Look for: `IP address: 192.168.x.x`

### Upload Firmware

```bash
chmod +x upload_esp32.sh
./upload_esp32.sh
```

### Start Web App

```bash
chmod +x start_web_app.sh
./start_web_app.sh
```

Then open browser to `http://localhost:5000`

## Configuration

### Initial Setup

1. **Find ESP32 IP Address**:
   - Check serial monitor after upload
   - Or check your router's connected devices list

2. **Test Basic Movement**:
   - Use UP/DOWN buttons in web app
   - Verify desk moves correctly
   - Check STOP button works

3. **Calibrate Height Limits**:
   - Move desk to lowest position
   - Note the height reading
   - Move desk to highest position
   - Note the height reading
   - Set min/max limits in Settings (add 10mm buffer)

4. **Configure Presets**:
   - Move desk to desired "Sit" height
   - Note the height value
   - Repeat for "Stand" and other presets
   - Enter values in Settings → Manage Presets
   - Click "Save All Changes"

### Height Calibration

The VL53L0X sensor measures distance from sensor to floor. Since the sensor is mounted on the desk bottom:

- **Desk Height = Sensor Reading** (directly)

The sensor reading in millimeters IS the desk height. No conversion needed.

### Safety Limits

Set limits in Settings:
- **Min Height**: Lowest safe position (typically 575mm + buffer)
- **Max Height**: Highest safe position (typically 1185mm - buffer)

The system automatically stops movement at:
- `minHeight + 10mm` (when going down)
- `maxHeight - 10mm` (when going up)

This 10mm buffer prevents overshoot.

## Troubleshooting

### Desk Won't Move

**Symptoms**: Pressing buttons does nothing

**Solutions**:
1. Check relay wiring connections
2. Verify relay module is powered (LED should be on)
3. Test relay manually (check continuity when GPIO goes LOW)
4. Verify IKEA controller button connections are correct
5. Check serial monitor for error messages

### Height Readings Are Wrong

**Symptoms**: Displayed height doesn't match actual desk height

**Solutions**:
1. Verify sensor is mounted securely on desk bottom
2. Ensure sensor has clear view of floor
3. Check I2C wiring (SDA/SCL connections)
4. Test sensor with serial monitor - should show readings
5. Sensor range is ~30-2000mm - ensure within range

### Can't Connect to Web App

**Symptoms**: Browser shows "Connecting..." or connection error

**Solutions**:
1. Verify ESP32 IP address in `web_app.py` is correct
2. Check ESP32 and computer are on same WiFi network
3. Ping ESP32: `ping 192.168.0.194` (use your ESP32 IP)
4. Check ESP32 serial monitor - should show "Server started"
5. Verify web app is running: `./start_web_app.sh`
6. Try accessing ESP32 directly: `http://192.168.0.194/status`

### Desk Stops Before Reaching Target

**Symptoms**: Preset movement stops early (e.g., stops at 900mm when target is 1180mm)

**Solutions**:
1. Check serial monitor for debug messages
2. Verify sensor readings are updating correctly
3. Check if hitting physical limits (sensor should show this)
4. Verify min/max limits aren't set too restrictive
5. Check for sensor interference or obstruction

### Desk Won't Stop at Limits

**Symptoms**: Desk continues moving past configured limits

**Solutions**:
1. Verify limits are saved to ESP32 (check Settings)
2. Check serial monitor for "EMERGENCY STOP" messages
3. Ensure sensor readings are accurate (calibrate if needed)
4. Check that limits are reasonable for your desk model

### WiFi Connection Issues

**Symptoms**: ESP32 won't connect to WiFi

**Solutions**:
1. **Most common**: ESP32 only supports 2.4GHz WiFi, not 5GHz
2. Verify SSID and password are correct (case-sensitive)
3. Check WiFi signal strength (move ESP32 closer to router)
4. Check router settings (some routers block new devices)
5. Look at serial monitor for connection status messages

## LED Status Guide

The ESP32 status LED indicates system state:

- **Solid ON**: Connected to WiFi, server running, ready
- **Fast Blink**: Connecting to WiFi
- **Slow Blink**: WiFi disconnected, attempting reconnect
- **OFF**: WiFi connection failed or ESP32 not powered

See [LED_STATUS_GUIDE.md](LED_STATUS_GUIDE.md) for more details.

## Technical Details

### Communication Protocol

The ESP32 runs an HTTP server on port 80. Commands are sent as HTTP GET requests:

- `/up` - Move desk up
- `/down` - Move desk down  
- `/stop` - Stop movement
- `/goto0`, `/goto1`, `/goto2` - Move to preset 0, 1, or 2
- `/height<mm>` - Move to specific height (e.g., `/height750`)
- `/status` - Get current status and height
- `/limits` - Get height limits
- `/setmin<mm>` - Set minimum height
- `/setmax<mm>` - Set maximum height
- `/set0 <mm>`, `/set1 <mm>`, `/set2 <mm>` - Set preset heights

### Movement Control

The system uses non-blocking movement control:
- Movement is state-driven and handled in the main loop
- Preset movements can be stopped at any time
- Sensor readings are checked every 100ms
- Safety limits are enforced continuously
- Physical limit detection stops movement when desk can't move further

### Safety Features

1. **Emergency stops** at configured boundaries
2. **Movement timeout** (30 seconds maximum)
3. **Physical limit detection** (stops when height stable for 0.8 seconds)
4. **Limit checking** for all movement types (manual, presets, height commands)
5. **Consecutive reading confirmation** (3 readings within tolerance before stopping)

## Advanced Configuration

### Adjusting Movement Sensitivity

Edit movement thresholds in `DeskController_ESP32.ino`:

```cpp
// Tolerance for reaching target (line ~223)
if (difference <= 15) {  // Adjust this value (default: 15mm)

// Stability detection threshold (line ~186)
if (abs(filteredHeight - lastMovementHeight) <= 5) {  // Adjust this (default: 5mm)

// Stability confirmation count (line ~188)
if (stableHeightCount >= 8) {  // Adjust this (default: 8 checks = 0.8 seconds)
```

### Changing Update Frequency

```cpp
// Movement check interval (line ~176)
if (millis() - lastMovementCheck >= 100) {  // Default: 100ms

// Height update interval (in web app)
setInterval(updateHeight, 2000);  // Default: 2 seconds
```

## Support

For issues, questions, or contributions:
- Check the troubleshooting section above
- Review serial monitor output for error messages
- Verify all wiring connections
- Test components individually (sensor, relay, ESP32)

## Safety Disclaimer

⚠️ **Important Safety Notes:**

- Always disconnect power before working on electrical connections
- Test relay connections before final installation
- Verify safety limits are correctly configured
- The 10mm buffer on limits is important - don't remove it
- Regularly check that emergency stops are working
- Keep emergency STOP button accessible at all times

This project involves modifying electrical equipment. Work safely and at your own risk.

