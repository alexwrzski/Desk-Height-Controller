#!/bin/bash

# Build script for Desk Controller DMG Installer
# Creates a distributable .dmg file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Desk Controller"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME// /_}"
DMG_FILE="$SCRIPT_DIR/${DMG_NAME}.dmg"
TEMP_DMG="$SCRIPT_DIR/${DMG_NAME}_temp.dmg"
VOLUME_NAME="Desk Controller Installer"

echo "=== Building DMG Installer ==="
echo ""

# Check if app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "✗ App bundle not found: $APP_BUNDLE"
    echo ""
    echo "Building standalone app first..."
    if [ -f "$SCRIPT_DIR/build_standalone_app.sh" ]; then
        "$SCRIPT_DIR/build_standalone_app.sh"
    else
        echo "  Please run ./build_standalone_app.sh first"
        exit 1
    fi
    
    # Check again after build
    if [ ! -d "$APP_BUNDLE" ]; then
        echo "✗ App bundle still not found after build"
        exit 1
    fi
fi

# Remove existing DMG if it exists
if [ -f "$DMG_FILE" ]; then
    echo "Removing existing DMG..."
    rm -f "$DMG_FILE"
fi

if [ -f "$TEMP_DMG" ]; then
    rm -f "$TEMP_DMG"
fi

# Create a temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo "Creating DMG structure..."

# Copy app to temp directory
cp -R "$APP_BUNDLE" "$TEMP_DIR/"

# Create Applications symlink (for drag-to-install)
ln -s /Applications "$TEMP_DIR/Applications"

# Calculate size needed (app size + 20MB overhead)
APP_SIZE=$(du -sk "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20480))  # Add 20MB overhead

echo "App size: $((APP_SIZE / 1024))MB"
echo "DMG size: $((DMG_SIZE / 1024))MB"
echo ""

# Create the DMG
echo "Creating disk image..."
hdiutil create -srcfolder "$TEMP_DIR" -volname "$VOLUME_NAME" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}k "$TEMP_DMG"

# Mount the DMG
echo "Mounting disk image..."
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" > /tmp/dmg_mount.txt 2>&1
MOUNT_DIR=$(grep -E "^/dev/" /tmp/dmg_mount.txt | head -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

# Alternative method if above doesn't work
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
    MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" 2>&1 | grep -E "^/dev/" | head -1 | sed 's/.*\(Volumes.*\)/\1/' | xargs -I {} echo "/{}")
fi

# Try one more method
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/$VOLUME_NAME"
fi

if [ ! -d "$MOUNT_DIR" ]; then
    echo "✗ Failed to mount DMG"
    echo "Mount output:"
    cat /tmp/dmg_mount.txt
    rm -f /tmp/dmg_mount.txt
    exit 1
fi

echo "Mounted at: $MOUNT_DIR"

# Wait a moment for mount to complete
sleep 2

# Set volume icon (if available and SetFile command exists)
if [ -f "$SCRIPT_DIR/desk_icon.icns" ] && command -v SetFile &> /dev/null; then
    echo "Setting volume icon..."
    cp "$SCRIPT_DIR/desk_icon.icns" "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# Configure DMG layout using AppleScript
echo "Configuring DMG layout..."
osascript <<EOF
tell application "Finder"
    set theDisk to disk "$VOLUME_NAME"
    open theDisk
    set theWindow to container window of theDisk
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set the bounds of theWindow to {400, 100, 900, 500}
    set opts to icon view options of theWindow
    set arrangement of opts to not arranged
    set icon size of opts to 128
    try
        set position of item "$APP_NAME.app" of theWindow to {150, 200}
        set position of item "Applications" of theWindow to {450, 200}
    end try
    close theWindow
    open theWindow
    update theDisk without registering applications
    delay 2
end tell
EOF

# Unmount the DMG
echo "Unmounting disk image..."
sleep 1
hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || hdiutil detach "$MOUNT_DIR" 2>/dev/null || true
rm -f /tmp/dmg_mount.txt

# Wait a moment for unmount to complete
sleep 2

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FILE"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$TEMP_DIR"

# Set DMG file attributes
if [ -f "$DMG_FILE" ]; then
    # Make it internet-enabled for auto-mounting
    hdiutil internet-enable -yes "$DMG_FILE" 2>/dev/null || true
    
    DMG_SIZE_MB=$(du -h "$DMG_FILE" | cut -f1)
    echo ""
    echo "✓ DMG created successfully!"
    echo ""
    echo "DMG location: $DMG_FILE"
    echo "DMG size: $DMG_SIZE_MB"
    echo ""
    echo "The DMG file is ready for distribution!"
    echo "Users can:"
    echo "  1. Double-click to mount"
    echo "  2. Drag '$APP_NAME.app' to Applications folder"
    echo "  3. Launch from Applications"
    echo ""
else
    echo "✗ Failed to create DMG file"
    exit 1
fi

