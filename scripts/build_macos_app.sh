#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

swift build --product SuperVoiceAssistant
bin_dir="$(swift build --show-bin-path)"
app="$repo_root/.build/SuperVoiceAssistant.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/SuperVoiceAssistant" "$app/Contents/MacOS/SuperVoiceAssistant"
cp "$repo_root/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"

for bundle in \
    SuperVoiceAssistant_SuperVoiceAssistant.bundle \
    KeyboardShortcuts_KeyboardShortcuts.bundle \
    swift-transformers_Hub.bundle
do
    cp -R "$bin_dir/$bundle" "$app/$bundle"
done

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>SuperVoiceAssistant</string>
    <key>CFBundleIdentifier</key><string>com.supervoiceassistant.app</string>
    <key>CFBundleName</key><string>Super Voice Assistant</string>
    <key>CFBundleDisplayName</key><string>Super Voice Assistant</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Super Voice Assistant uses the microphone to record audio for transcription.</string>
</dict>
</plist>
PLIST

plutil -lint "$app/Contents/Info.plist"
printf 'Built app: %s\n' "$app"
