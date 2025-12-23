#!/bin/bash

# Build script for Desk Controller Mac App
# Creates a proper .app bundle that can be double-clicked

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Desk Controller"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

echo "=== Building Mac App ==="
echo ""

# Remove existing app if it exists
if [ -d "$APP_BUNDLE" ]; then
    echo "Removing existing app bundle..."
    rm -rf "$APP_BUNDLE"
fi

# Create app bundle structure
echo "Creating app bundle structure..."
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Copy icon if it exists
if [ -f "$SCRIPT_DIR/desk_icon.icns" ]; then
    echo "Copying icon..."
    cp "$SCRIPT_DIR/desk_icon.icns" "$APP_RESOURCES/AppIcon.icns"
    ICON_FILE="AppIcon.icns"
else
    ICON_FILE=""
fi

# Create the executable script
echo "Creating executable..."
cat > "$APP_MACOS/$APP_NAME" << 'EXECUTABLE'
#!/bin/bash

# Get the script directory (where the .app bundle is located)
# macOS-compatible method to get absolute path
SCRIPT_PATH="$0"
if [ -L "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
fi
APP_DIR="$(cd "$(dirname "$(dirname "$(dirname "$SCRIPT_PATH")")")" && pwd)"
SCRIPT_DIR="$APP_DIR"

# Change to script directory
cd "$SCRIPT_DIR"

# Find Python with PyQt5 installed
# Try system Python first, then fall back to python3
PYTHON_CMD=""
for py in "/usr/bin/python3" "$(which python3)" "python3"; do
    if [ -n "$py" ] && $py -c "import PyQt5.QtWidgets" 2>/dev/null; then
        PYTHON_CMD="$py"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    # Check if any GUI framework is available
    if ! python3 -c "import PySide6.QtWidgets" 2>/dev/null && \
       ! python3 -c "import AppKit" 2>/dev/null; then
        osascript -e 'display dialog "PyQt5 is required. Install with: pip3 install -r requirements.txt" buttons {"OK"} default button "OK" with title "Desk Controller"'
        exit 1
    fi
    PYTHON_CMD=python3
fi

# Run the native app
exec "$PYTHON_CMD" desk_controller_app.py
EXECUTABLE

# Make executable
chmod +x "$APP_MACOS/$APP_NAME"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$APP_CONTENTS/Info.plist" << INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
    <key>CFBundleIdentifier</key>
    <string>com.deskcontroller.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
INFOPLIST

# Set icon if available
if [ -f "$APP_RESOURCES/AppIcon.icns" ]; then
    echo "Setting app icon..."
    # Use fileicon if available, otherwise use sips
    if command -v fileicon &> /dev/null; then
        fileicon set "$APP_BUNDLE" "$APP_RESOURCES/AppIcon.icns" 2>/dev/null || \
        sips -i "$APP_RESOURCES/AppIcon.icns" 2>/dev/null || true
    elif command -v sips &> /dev/null; then
        # Use sips to set icon (built into macOS)
        # Note: This requires additional steps, so we'll just note it
        echo "  Note: Icon file copied. For best results, install 'fileicon' with: brew install fileicon"
    fi
fi

echo ""
echo "✓ Mac app created successfully!"
echo ""
echo "App location: $APP_BUNDLE"
echo ""
echo "You can now:"
echo "  1. Double-click '$APP_NAME.app' to launch"
echo "  2. Drag it to Applications folder"
echo "  3. Add it to Dock for quick access"
echo ""
echo "The app will automatically:"
echo "  - Start the web server"
echo "  - Open your browser to http://localhost:5000"
echo "  - Show a terminal window (you can minimize it)"
echo ""

