#!/bin/bash
# Launcher for Punff Camera Manager (Python version)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$SCRIPT_DIR/punff-camera-manager.py"

# Check if camera is connected
CAMERA_PATH="/run/media/punff/disk/DCIM/101OLYMP/"
if [ -d "$CAMERA_PATH" ]; then
    echo "Camera detected at: $CAMERA_PATH"
    echo "Starting Punff Camera Manager..."
else
    echo "Warning: Camera not detected at expected location: $CAMERA_PATH"
    echo "Starting Punff Camera Manager anyway..."
fi

# Check Python dependencies
echo "Checking Python dependencies..."
if ! python3 -c "import tkinter" 2>/dev/null; then
    echo "Error: tkinter not found. Install with: sudo apt install python3-tk"
    exit 1
fi

if ! python3 -c "import PIL" 2>/dev/null; then
    echo "Error: PIL (Pillow) not found. Install with: pip install Pillow"
    exit 1
fi

# Note about SSH agent for passwordless deployment
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "⚠️  SSH agent not running."
    echo "   Deployment will ask for passphrase multiple times."
    echo "   For passwordless deployment, run in terminal before starting:"
    echo "     eval \"\$(ssh-agent -s)\""
    echo "     ssh-add ~/.ssh/id_ed25519"
    echo "     (enter passphrase once)"
else
    echo "✅ SSH agent is running. Passwordless deployment enabled."
fi

echo ""
# Run the application
cd "$SCRIPT_DIR"
python3 "$APP_PATH"