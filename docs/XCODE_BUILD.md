# Building Desk Controller with Xcode

This project includes a native macOS app built with Swift and Xcode.

## Prerequisites

1. **Xcode** (not just command line tools) - Download from the Mac App Store
2. **Python 3** with Flask installed (the app will use the system Python)

## Building the App

### Option 1: Using Xcode GUI

1. Open `DeskController.xcodeproj` in Xcode:
   ```bash
   open DeskController.xcodeproj
   ```

2. Select the "DeskController" scheme and "My Mac" as the destination

3. Press `Cmd+B` to build, or `Cmd+R` to build and run

4. The built app will be in: `build/Build/Products/Release/DeskController.app`

### Option 2: Using Command Line

```bash
./build_xcode.sh
```

This will build the app and show you where it's located.

## How It Works

- The Swift app creates a native macOS window with a `WKWebView`
- It automatically starts the Flask server (`web_app.py`) in the background
- The web interface loads in the native window at `http://localhost:5000`
- When you quit the app, it automatically stops the Flask server

## Notes

- The app bundles `web_app.py` and `requirements.txt` as resources
- It uses the system Python (checks common locations)
- Make sure Flask is installed: `pip3 install flask`
- The app window is 420x800 pixels, matching the web interface design

## Troubleshooting

**"Could not connect to Desk Controller server"**
- Make sure Flask is installed: `pip3 install flask`
- Check that Python 3 is available at `/usr/bin/python3` or update the path in `AppDelegate.swift`

**Build errors**
- Make sure you have Xcode (not just command line tools)
- Open the project in Xcode and check for any missing files



