#!/bin/bash
# Builds a distributable SuperVoiceAssistant.app bundle.
#
# Usage: ./scripts/build-app-bundle.sh [version]
#   version defaults to "dev" (used for CFBundleShortVersionString)
#
# Output: dist/SuperVoiceAssistant.app and dist/SuperVoiceAssistant.zip
#
# The app is ad-hoc signed (no Developer ID), so downloaded copies are
# quarantined by Gatekeeper. Users must either:
#   - System Settings > Privacy & Security > "Open Anyway", or
#   - xattr -d com.apple.quarantine SuperVoiceAssistant.app

set -euo pipefail

VERSION="${1:-dev}"
cd "$(dirname "$0")/.."

echo "Building universal release binary..."
swift build -c release --arch arm64 --arch x86_64 --product SuperVoiceAssistant

PRODUCTS=".build/apple/Products/Release"
APP="dist/SuperVoiceAssistant.app"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$PRODUCTS/SuperVoiceAssistant" "$APP/Contents/MacOS/"
cp AppIcon.icns "$APP/Contents/Resources/"

# SPM resource bundles (Bundle.module looks in Contents/Resources)
for bundle in "$PRODUCTS"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SuperVoiceAssistant</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ykdojo.SuperVoiceAssistant</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SuperVoiceAssistant</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION#v}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION#v}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>SuperVoiceAssistant records audio from your microphone to transcribe your speech.</string>
</dict>
</plist>
EOF

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

echo "Zipping..."
ditto -c -k --keepParent "$APP" dist/SuperVoiceAssistant.zip

echo "Done: $APP"
