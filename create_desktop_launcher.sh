#!/bin/bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/desk_controller.py"
DESKTOP_PATH="$HOME/Desktop/Desk Controller.command"

# Create a launcher script on the desktop
cat > "$DESKTOP_PATH" << 'LAUNCHER'
#!/bin/bash
cd "$(dirname "$0")/../Documents/Cursor Projects/Desk Controller"
python3 desk_controller.py
LAUNCHER

# Make it executable
chmod +x "$DESKTOP_PATH"

# Get the icon path
ICON_PATH="$SCRIPT_DIR/other icons/desk-icon-new.png"

# Set the icon for the launcher (macOS)
if [ -f "$ICON_PATH" ]; then
    # Convert PNG to ICNS if needed, or use sips to set icon
    # For now, we'll use a simpler approach with fileicon
    if command -v fileicon &> /dev/null; then
        fileicon set "$DESKTOP_PATH" "$ICON_PATH" 2>/dev/null || echo "Note: Install 'fileicon' with 'brew install fileicon' for custom icon"
    else
        echo "Note: Install 'fileicon' with 'brew install fileicon' to set custom icon on launcher"
    fi
fi

echo "✓ Desktop launcher created at: $DESKTOP_PATH"
echo "  Double-click 'Desk Controller.command' on your Desktop to launch the app!"
