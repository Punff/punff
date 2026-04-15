#!/bin/bash

set -e

echo "🔨 Building punff feed..."
cd "$(dirname "$0")"

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed"
    echo "Install with: sudo apt install nodejs"
    exit 1
fi

# Run the build script
node scripts/build.js

# Copy to web directory if configured (simple auto-deploy)
if [ -d "/var/www/html" ]; then
    echo "📤 Auto-copying to /var/www/html..."
    # Copy all necessary files
    cp index.html photos-data.json /var/www/html/ 2>/dev/null || echo "⚠️  Could not copy HTML/data files"
    # Copy assets if they exist
    if [ -d "assets" ]; then
        cp -r assets/ /var/www/html/ 2>/dev/null || echo "⚠️  Could not copy assets (permissions?)"
    fi
    echo "✅ Site copied to /var/www/html"
    echo "   For full deployment with photo skipping, run: ./deploy.sh"
fi

echo "✨ Build complete!"
echo "🌐 Open index.html in your browser to view the site"