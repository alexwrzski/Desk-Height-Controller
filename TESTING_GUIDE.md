# WiFi Manager Testing Guide

This guide will help you test the new WiFi Manager functionality step by step.

## Prerequisites

1. ESP32 board connected via USB
2. Computer/phone for WiFi setup
3. Access to your 2.4GHz WiFi network (ESP32 doesn't support 5GHz)

## Test 1: First-Time Setup (AP Mode)

This tests the Access Point mode when no WiFi credentials are saved.

### Step 1: Clear Existing WiFi Credentials (Optional)

If you've already set up WiFi before, you can test the reset:

1. Upload the new firmware:
   ```bash
   ./upload_esp32.sh
   ```

2. Open serial monitor to see the ESP32 output:
   ```bash
   arduino-cli monitor -p /dev/cu.usbserial-0001 -c baudrate=115200
   ```

3. You should see either:
   - "Found saved WiFi credentials" (if credentials exist)
   - "=== WiFi Setup Mode ===" (if no credentials)

### Step 2: Force AP Mode (If Credentials Exist)

If credentials are saved and it connects, you can reset them:

1. Start the web app:
   ```bash
   ./start_web_app.sh
   ```

2. Open `http://localhost:5000` in your browser

3. Click **Settings** → Scroll to **ESP32 Connection** section

4. Click **Reset WiFi** button

5. ESP32 will restart and enter AP mode

### Step 3: Connect to ESP32 Access Point

1. On your phone/computer, open WiFi settings

2. Look for network: **"DeskController-Setup"**

3. Connect with password: **"setup12345"**

4. You should see the ESP32 LED blinking slowly (AP mode indicator)

### Step 4: Access Setup Page

1. Open a web browser on the device connected to "DeskController-Setup"

2. Navigate to: `http://192.168.4.1/setup`

   OR just open `http://192.168.4.1` (should redirect to setup)

3. You should see a WiFi setup form with:
   - WiFi Network (SSID) input field
   - Password input field
   - "Connect to WiFi" button

### Step 5: Enter WiFi Credentials

1. Enter your **2.4GHz WiFi network name** (SSID)

2. Enter your **WiFi password**

3. Click **"Connect to WiFi"**

4. Wait 10-30 seconds for connection

5. You should see either:
   - **Success page** with ESP32's IP address on your network
   - **Error page** if connection failed (check password, 2.4GHz network, etc.)

### Step 6: Note the IP Address

1. If successful, the page will show: **"IP Address: 192.168.x.x"**

2. **Write down this IP address** - you'll need it for the web app

3. The ESP32 LED should now be **solid ON** (connected mode)

## Test 2: Web App Connection

This tests the web app's connection detection and setup page.

### Step 1: Start Web App

```bash
./start_web_app.sh
```

### Step 2: Open Web App

1. Open browser to: `http://localhost:5000`

2. **If ESP32 is not connected**, you should see:
   - Setup page with instructions
   - "First Time Setup" section
   - IP address input field

3. **If ESP32 is connected**, you should see:
   - Normal desk controller interface
   - Current height display
   - Control buttons

### Step 3: Enter ESP32 IP Address

1. If you see the setup page, enter the ESP32 IP address from Test 1

2. Format: `http://192.168.1.100` (use your actual IP)

3. Click **"Connect"**

4. The app should:
   - Test the connection
   - Hide setup page if successful
   - Show normal interface with "Connected" status

### Step 4: Verify Connection

1. Check the status indicator (top of app):
   - Should show **"Connected"** in green
   - Height should display (e.g., "750 mm")

2. Try a command:
   - Click **UP** or **DOWN** button
   - Desk should move (if hardware is connected)

## Test 3: Settings Page WiFi Configuration

This tests the WiFi settings in the Settings page.

### Step 1: Open Settings

1. In the web app, click **"⚙ Settings"** button

2. Scroll down to **"ESP32 Connection"** section

### Step 2: Test Connection Button

1. Click **"Test Connection"** button

2. Status should update:
   - **"✓ Connected"** (green) if working
   - **"✗ Disconnected"** (red) if not

### Step 3: Change IP Address

1. If your ESP32 gets a new IP address (e.g., after router restart):

2. Enter new IP in the **"ESP32 IP Address"** field

3. Click **"Save IP"**

4. Click **"Test Connection"** to verify

5. IP should be saved to localStorage (persists after page refresh)

### Step 4: Reset WiFi

1. Click **"Reset WiFi (Restart Setup Mode)"** button

2. Confirm the dialog

3. ESP32 should:
   - Clear saved WiFi credentials
   - Restart
   - Enter AP mode again

4. You can repeat Test 1 to set up WiFi again

## Test 4: Automatic Reconnection

This tests the ESP32's ability to reconnect after WiFi drops.

### Step 1: Disconnect WiFi

1. Turn off your WiFi router (or disconnect ESP32's network)

2. ESP32 LED should:
   - Turn OFF or start blinking (disconnected)

3. Serial monitor should show:
   - "WiFi disconnected. Attempting to reconnect..."

### Step 2: Reconnect WiFi

1. Turn router back on

2. ESP32 should automatically reconnect within 10-30 seconds

3. LED should become **solid ON** (connected)

4. Serial monitor should show:
   - "WiFi connected! Starting HTTP server..."

## Test 5: Persistence

This verifies that WiFi credentials are saved permanently.

### Step 1: Power Cycle ESP32

1. Unplug ESP32 power/USB

2. Wait 5 seconds

3. Plug back in

### Step 2: Verify Auto-Connect

1. ESP32 should automatically:
   - Load saved WiFi credentials
   - Connect to your network
   - Start server

2. Serial monitor should show:
   - "Found saved WiFi credentials"
   - "Connecting to Wi-Fi: [your SSID]"
   - "✓ Connected!"

3. **No need to enter WiFi credentials again!**

## Troubleshooting

### ESP32 Not Creating AP

- Check serial monitor for error messages
- Verify firmware uploaded successfully
- Try resetting ESP32 (press reset button)

### Can't Connect to "DeskController-Setup"

- Make sure you're looking for **"DeskController-Setup"** (exact name)
- Password is **"setup12345"** (case-sensitive)
- Try forgetting the network and reconnecting
- Check that ESP32 LED is blinking (AP mode active)

### WiFi Connection Fails

- **Most common**: Make sure WiFi is **2.4GHz** (ESP32 doesn't support 5GHz)
- Check password is correct
- Verify network is in range
- Some routers block new devices - check router settings

### Web App Can't Connect

- Verify ESP32 IP address is correct
- Check ESP32 and computer are on same network
- Try pinging ESP32: `ping 192.168.1.100` (use your IP)
- Check ESP32 serial monitor for connection attempts

### Settings Not Saving

- Check browser console for errors (F12)
- Verify localStorage is enabled in browser
- Try clearing browser cache and reloading

## Expected Behavior Summary

| Scenario | ESP32 LED | Serial Output | Web App |
|----------|-----------|---------------|---------|
| No WiFi credentials | Slow blink | "=== WiFi Setup Mode ===" | Setup page |
| AP mode active | Slow blink | "AP IP: 192.168.4.1" | Setup page |
| WiFi connected | Solid ON | "✓ Connected to Wi-Fi!" | Normal interface |
| WiFi disconnected | Fast blink | "WiFi disconnected..." | "Disconnected" status |
| Reconnecting | Fast blink | "Attempting to reconnect..." | "Disconnected" status |

## Success Criteria

✅ **Test 1**: Can connect to "DeskController-Setup" and access setup page  
✅ **Test 2**: Web app detects connection and shows appropriate page  
✅ **Test 3**: Can change IP address and test connection in Settings  
✅ **Test 4**: ESP32 reconnects automatically after WiFi drop  
✅ **Test 5**: WiFi credentials persist after power cycle  

If all tests pass, the WiFi Manager is working correctly! 🎉

