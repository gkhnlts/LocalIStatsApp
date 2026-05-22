#!/bin/bash

# Exit on error
set -e

APP_NAME="LocalIStats"
BUNDLE_DIR="${APP_NAME}.app"

echo "=== 1. Compiling Swift Package ==="
swift build -c release

echo "=== 2. Creating .app Bundle Structure ==="
# Clean old bundle
if [ -d "$BUNDLE_DIR" ]; then
    rm -rf "$BUNDLE_DIR"
fi

mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

echo "=== 3. Copying Binary ==="
cp ".build/release/${APP_NAME}" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

echo "=== 4. Creating Info.plist ==="
cat <<EOF > "${BUNDLE_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.gokhan.LocalIStats</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "=== 5. Code Signing App Bundle (Ad-hoc) ==="
# Ad-hoc sign is required for running compiled apps on Apple Silicon macOS
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo "=== Build Successful: ${BUNDLE_DIR} ==="
echo "To run the app: open ${BUNDLE_DIR}"
