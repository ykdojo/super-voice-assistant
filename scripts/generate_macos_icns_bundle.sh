#!/bin/bash

# Generate ICNS file for macOS from the logo
# This creates a proper .icns file that can be used as the app icon

SOURCE_IMAGE="logos/logo_no_bg_edited.png"
ICONSET_DIR="AppIcon.iconset"
OUTPUT_ICNS="AppIcon.icns"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: $SOURCE_IMAGE not found!"
    exit 1
fi

# Create temporary iconset directory
rm -rf "$ICONSET_DIR"
mkdir "$ICONSET_DIR"

echo "Generating ICNS file from $SOURCE_IMAGE..."

# Generate all required sizes for iconset
# macOS iconset requires specific naming convention
declare -a icon_sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for size_info in "${icon_sizes[@]}"; do
    IFS=':' read -r pixels filename <<< "$size_info"
    
    echo "Creating $filename (${pixels}x${pixels}px)..."
    sips -z $pixels $pixels "$SOURCE_IMAGE" --out "$ICONSET_DIR/$filename" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Generated $filename"
    else
        echo "  ✗ Failed to generate $filename"
    fi
done

echo ""
echo "Converting iconset to ICNS..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

if [ $? -eq 0 ]; then
    echo "✅ Successfully created $OUTPUT_ICNS"
    
    # Clean up temporary iconset directory
    rm -rf "$ICONSET_DIR"
    
    echo ""
    echo "You can now use $OUTPUT_ICNS as your app icon by:"
    echo "1. Adding it to your Xcode project"
    echo "2. Setting it in your app's Info.plist"
    echo "3. Or using it with your Swift Package executable"
else
    echo "❌ Failed to create ICNS file"
    exit 1
fi