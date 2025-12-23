#!/bin/bash

# Build script for standalone Desk Controller Mac App
# Creates a self-contained app bundle with all dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Desk Controller"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"

echo "=== Building Standalone Mac App ==="
echo ""

# Check if PyInstaller is installed
if ! python3 -c "import PyInstaller" 2>/dev/null; then
    echo "Installing PyInstaller..."
    pip3 install pyinstaller
fi

# Check if PyQt5 is installed
if ! python3 -c "import PyQt5.QtWidgets" 2>/dev/null; then
    echo "Installing dependencies..."
    pip3 install -r requirements.txt
fi

# Remove old builds
echo "Cleaning old builds..."
rm -rf "$DIST_DIR" "$BUILD_DIR" "$APP_BUNDLE"

# Create PyInstaller spec file
echo "Creating PyInstaller spec..."
cat > "$SCRIPT_DIR/desk_controller.spec" << 'SPEC'
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['desk_controller_app.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        'PyQt5.QtCore',
        'PyQt5.QtGui',
        'PyQt5.QtWidgets',
        'PyQt5.QtWebEngineWidgets',
        'flask',
        'werkzeug',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='Desk Controller',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # No console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='Desk Controller.app',
    icon='desk_icon.icns',
    bundle_identifier='com.deskcontroller.app',
    info_plist={
        'NSHighResolutionCapable': 'True',
        'LSMinimumSystemVersion': '10.13',
        'CFBundleShortVersionString': '1.0',
        'CFBundleVersion': '1',
    },
)
SPEC

# Build with PyInstaller
echo "Building standalone app with PyInstaller..."
echo "This may take a few minutes..."
python3 -m PyInstaller desk_controller.spec --clean --noconfirm

# Check if build was successful in dist folder
if [ -d "$DIST_DIR/$APP_NAME.app" ]; then
    # Copy from dist to main directory
    if [ -d "$APP_BUNDLE" ]; then
        rm -rf "$APP_BUNDLE"
    fi
    cp -R "$DIST_DIR/$APP_NAME.app" "$APP_BUNDLE"
    echo ""
    echo "✓ Standalone app created successfully!"
    echo ""
    echo "App location: $APP_BUNDLE"
    echo "App size: $(du -sh "$APP_BUNDLE" | cut -f1)"
    echo ""
    echo "The app is now self-contained with all dependencies!"
    echo "Users can run it without installing Python or any packages."
    echo ""
    echo "Next step: Run ./build_dmg.sh to create a distributable DMG"
    echo ""
else
    echo ""
    echo "✗ Build failed. Check the output above for errors."
    exit 1
fi

