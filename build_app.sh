#!/bin/bash
set -e

echo "=== Building MacDots Release Binary ==="
swift build -c release

APP_NAME="MacDots.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Creating macOS App Bundle ($APP_NAME) ==="
rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy compiled executable
cp .build/release/MacDots "$MACOS_DIR/MacDots"
chmod +x "$MACOS_DIR/MacDots"

# Copy Icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacDots</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.macdots</string>
    <key>CFBundleName</key>
    <string>MacDots</string>
    <key>CFBundleDisplayName</key>
    <string>MacDots</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc codesign
codesign --force --deep --sign - "$APP_NAME"

echo "=== Successfully built $APP_NAME ==="
ls -ld "$APP_NAME"
