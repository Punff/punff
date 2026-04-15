#!/bin/bash

# Launcher for punff Camera Manager
# Auto-starts when camera is connected

echo "📸 punff Camera Manager"
echo "──────────────────────"

# Check if we're in punff-site directory
if [ ! -d "assets/photos" ]; then
    echo "❌ Error: Must run from punff-site directory"
    echo "   cd /home/punff/punff-site"
    exit 1
fi

# Check if camera is connected
CAMERA_PATH="/run/media/punff/disk/DCIM/101OLYMP"
if [ ! -d "$CAMERA_PATH" ]; then
    echo "❌ Camera not connected"
    echo "   Connect Olympus EPL-2 via USB and turn it on"
    echo ""
    echo "Waiting for camera..."
    
    # Wait for camera to be connected
    while [ ! -d "$CAMERA_PATH" ]; do
        sleep 2
        echo -n "."
    done
    echo ""
    echo "✅ Camera detected!"
fi

# Count photos
PHOTO_COUNT=$(find "$CAMERA_PATH" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.JPG" -o -name "*.png" -o -name "*.PNG" \) | wc -l)
echo "📊 Found $PHOTO_COUNT photos"
echo ""

# Create necessary directories
echo "📁 Setting up directories..."
mkdir -p trash archive to-edit

echo ""
echo "🚀 Launching Camera Manager..."
echo "   Use:"
echo "   ← or 🗑️  = Move to trash"
echo "   ↓ or 📁 = Archive (don't post)"
echo "   → or 📸 = Post to website"
echo "   ↑ or ✏️  = Mark for editing"
echo "   Space = Skip to next"
echo "   ↶ = Undo last action"
echo ""

# Launch the app
./punff-camera-manager/punff-camera-manager