# Build Instructions for Desk Controller Swift App

## Prerequisites

- macOS 11.0 (Big Sur) or later
- Xcode 13.0 or later
- ESP32 device running DeskController firmware

## Building the App

1. **Open the Project**
   ```bash
   cd "Desk Controller - Swift"
   open DeskController.xcodeproj
   ```

2. **Configure the Project**
   - Select the "DeskController" scheme
   - Choose your Mac as the destination
   - Ensure the deployment target is set to macOS 11.0 or later

3. **Build and Run**
   - Press ⌘R or click the Run button
   - The app will build and launch

## Project Structure

The Swift app consists of:

- **DeskControllerApp.swift** - Main app entry point using SwiftUI
- **ContentView.swift** - Main UI with height display, controls, and presets
- **SettingsView.swift** - Settings modal with all configuration options
- **AppState.swift** - Observable state management and business logic
- **ESP32Client.swift** - HTTP client for communicating with ESP32

## First Run

1. Launch the app
2. Open Settings (⚙ button)
3. Enter your ESP32 IP address (default: `http://192.168.4.1`)
4. Click "Test Connection" to verify connectivity
5. Click "Save IP" to save the configuration

## Features Implemented

✅ Real-time height display (updates every 2 seconds)
✅ Up/Down/Stop controls with hold-to-move functionality
✅ Preset buttons (up to 3 presets)
✅ Settings modal with:
   - Manual height input
   - Preset management (add/edit/delete)
   - Safety limits configuration
   - ESP32 IP configuration
   - Connection testing
   - WiFi reset functionality
✅ Data persistence (presets, IP, limits saved to UserDefaults)
✅ Validation for height limits and presets
✅ Error handling and user feedback

## Troubleshooting

### App won't build
- Ensure you're using Xcode 13.0 or later
- Check that all Swift files are included in the target
- Clean build folder (⌘ShiftK) and rebuild

### Can't connect to ESP32
- Verify ESP32 and Mac are on the same WiFi network
- Check ESP32 IP address in Settings
- Use "Test Connection" button to verify connectivity
- Ensure ESP32 firmware is running and accessible

### Buttons not responding
- Check console for error messages
- Verify ESP32 is connected and responding
- Try restarting the app

## Next Steps

- Test all functionality with your ESP32 device
- Customize UI colors/styling if desired
- Add any additional features as needed
- Code sign for distribution (if distributing to others)

