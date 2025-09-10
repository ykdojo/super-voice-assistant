#!/bin/bash

# Generate all required icon sizes for macOS app from logo_no_bg_edited.png
# Uses sips (built-in macOS image processing tool)

SOURCE_IMAGE="logos/logo_no_bg_edited.png"
ICON_DIR="Sources/Assets.xcassets/AppIcon.appiconset"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: $SOURCE_IMAGE not found!"
    exit 1
fi

# Create icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

echo "Generating app icons from $SOURCE_IMAGE..."

# Generate each required size
# Format: size@scale -> actual_pixels
declare -a sizes=(
    "16:1:16"      # 16x16@1x = 16px
    "16:2:32"      # 16x16@2x = 32px
    "32:1:32"      # 32x32@1x = 32px
    "32:2:64"      # 32x32@2x = 64px
    "128:1:128"    # 128x128@1x = 128px
    "128:2:256"    # 128x128@2x = 256px
    "256:1:256"    # 256x256@1x = 256px
    "256:2:512"    # 256x256@2x = 512px
    "512:1:512"    # 512x512@1x = 512px
    "512:2:1024"   # 512x512@2x = 1024px
)

for size_info in "${sizes[@]}"; do
    IFS=':' read -r base scale pixels <<< "$size_info"
    
    if [ "$scale" = "1" ]; then
        filename="icon_${base}x${base}.png"
    else
        filename="icon_${base}x${base}@${scale}x.png"
    fi
    
    output_path="$ICON_DIR/$filename"
    
    echo "Creating $filename (${pixels}x${pixels}px)..."
    sips -z $pixels $pixels "$SOURCE_IMAGE" --out "$output_path" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Generated $filename"
    else
        echo "  ✗ Failed to generate $filename"
    fi
done

echo ""
echo "Icon generation complete!"
echo "Icons saved to: $ICON_DIR"

# Verify all required files exist
echo ""
echo "Verifying generated files:"
required_files=(
    "icon_16x16.png"
    "icon_16x16@2x.png"
    "icon_32x32.png"
    "icon_32x32@2x.png"
    "icon_128x128.png"
    "icon_128x128@2x.png"
    "icon_256x256.png"
    "icon_256x256@2x.png"
    "icon_512x512.png"
    "icon_512x512@2x.png"
)

all_present=true
for file in "${required_files[@]}"; do
    if [ -f "$ICON_DIR/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file missing"
        all_present=false
    fi
done

if [ "$all_present" = true ]; then
    echo ""
    echo "✅ All required icon files generated successfully!"
else
    echo ""
    echo "⚠️  Some icon files are missing. Please check the output above."
    exit 1
fi