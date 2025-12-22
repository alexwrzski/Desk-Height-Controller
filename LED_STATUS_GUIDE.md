# ESP32 LED Status Indicator Guide

## LED Pin
- **GPIO 4** is used for the status LED
- If your ESP32 board doesn't have an LED on GPIO 4, you can:
  1. Connect an external LED with a 220Ω resistor between GPIO 4 and GND
  2. Or change `#define STATUS_LED 4` to your board's built-in LED pin

## LED Status Meanings

### During Upload
- The LED will blink rapidly during firmware upload (this is normal)

### After Upload/Reset

1. **3 Quick Blinks** = Startup/Initialization
   - ESP32 is booting up
   - Sensor initialization

2. **Fast Blinking** = WiFi Connecting
   - ESP32 is trying to connect to "Free WiFi"
   - Blinks every second while connecting
   - Can take up to 30 seconds

3. **Solid ON** = Ready! ✓
   - WiFi connected successfully
   - HTTP server started on port 80
   - Ready to receive commands from the app

4. **Slow Blinking** = WiFi Disconnected, Reconnecting
   - WiFi connection lost
   - ESP32 is trying to reconnect
   - Blinks every 200ms

5. **OFF** = Error/Not Connected
   - WiFi connection failed
   - Check serial monitor for error messages
   - Verify WiFi credentials and network (must be 2.4GHz)

## Troubleshooting

If LED stays OFF or keeps blinking:
- Check serial monitor (115200 baud) for error messages
- Verify "Free WiFi" is a 2.4GHz network (ESP32 doesn't support 5GHz)
- Check WiFi password is correct
- Ensure router allows new device connections
