#!/bin/bash

set -e

echo "🚀 punff deployment"
echo "──────────────────"

cd "$(dirname "$0")"

# First build the site
echo "🔨 Building site..."
./build.sh

# Check if we should deploy
read -p "Deploy to server? (y/n): " deploy_choice
if [[ "$deploy_choice" != "y" && "$deploy_choice" != "Y" ]]; then
    echo "Skipping deployment."
    exit 0
fi

echo ""
echo "Select deployment method:"
echo "  1) Local copy to /var/www/html"
echo "  2) SSH/SCP to remote server"
echo "  3) Rsync to remote server"
echo ""

read -p "Choice [1]: " method
method=${method:-1}

case $method in
    1)
        # Local deployment
        if [ ! -d "/var/www/html" ]; then
            echo "❌ /var/www/html not found"
            echo "   Make sure web server is installed"
            exit 1
        fi
        
        echo "📤 Copying to /var/www/html..."
        # Copy all necessary files
        files_to_copy="index.html photos-data.json"
        if [ -d "assets" ]; then
            files_to_copy="$files_to_copy assets/"
        fi
        
        sudo cp -r $files_to_copy /var/www/html/ 2>/dev/null || {
            echo "⚠️  Couldn't use sudo, trying without..."
            cp -r $files_to_copy /var/www/html/ 2>/dev/null || {
                echo "❌ Failed to copy to /var/www/html"
                echo "   Check permissions or run with sudo"
                exit 1
            }
        }
        
        echo "✅ Deployed to /var/www/html"
        echo "🌐 Site should be available at http://localhost/"
        ;;
    
    2|3)
        # Remote deployment
        echo ""
        echo "📡 Remote deployment setup"
        echo ""
        
        # Get server details
        read -p "Server hostname [punff.port0.org]: " server_host
        server_host=${server_host:-punff.port0.org}
        
        read -p "Username [marioantunovic13]: " server_user
        server_user=${server_user:-marioantunovic13}
        
        read -p "Remote path [/var/www/html]: " remote_path
        remote_path=${remote_path:-/var/www/html}
        
        echo ""
        echo "🔑 Testing SSH connection..."
        
        # Test SSH connection
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${server_user}@${server_host}" "echo 'SSH connection successful'" 2>/dev/null; then
            echo "❌ SSH connection failed"
            echo "   Make sure:"
            echo "   1. SSH key is set up"
            echo "   2. Server is reachable"
            echo "   3. User has permissions"
            read -p "Continue anyway? (y/n): " continue_choice
            if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
                exit 1
            fi
        fi
        
    if [ "$method" = "2" ]; then
      # SCP method - skip existing photos
      echo "📤 Uploading via SCP (skipping existing photos)..."
      
      # First check what photos exist on server
      echo "🔍 Checking existing photos on server..."
      existing_photos=$(ssh "${server_user}@${server_host}" "find ${remote_path}/assets/photos -type f -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' 2>/dev/null | xargs -I {} basename {} 2>/dev/null || true")
      
      # Upload index.html and photos-data.json first
      scp index.html photos-data.json "${server_user}@${server_host}:${remote_path}/" || {
        echo "❌ Failed to upload HTML/data files"
        exit 1
      }
      
      # Upload only new photos
      echo "📸 Uploading new photos..."
      local_photos=$(find assets/photos -type f -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' 2>/dev/null)
      uploaded_count=0
      skipped_count=0
      
      for photo in $local_photos; do
        filename=$(basename "$photo")
        if echo "$existing_photos" | grep -q "^$filename$"; then
          echo "   ⏭️  Skipping (exists): $filename"
          skipped_count=$((skipped_count + 1))
        else
          echo "   📤 Uploading: $filename"
          scp "$photo" "${server_user}@${server_host}:${remote_path}/assets/photos/" && uploaded_count=$((uploaded_count + 1)) || {
            echo "   ❌ Failed: $filename"
          }
        fi
      done
      
      echo "✅ Upload complete: $uploaded_count new, $skipped_count skipped"
      
    else
      # Rsync method - skip existing files
      echo "📤 Syncing via rsync (skipping existing)..."
      rsync -avz --ignore-existing index.html photos-data.json assets/ "${server_user}@${server_host}:${remote_path}/" || {
        echo "❌ Rsync failed"
        exit 1
      }
    fi
        
        echo "✅ Deployed to ${server_user}@${server_host}:${remote_path}"
        echo "🌐 Site should be available at http://${server_host}/"
        ;;
    
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✨ Deployment complete!"
echo ""
echo "Quick test commands:"
echo "  curl -I http://localhost/  # Local test"
echo "  ssh ${server_user:-user}@${server_host:-host} 'ls -la ${remote_path:-/var/www/html}'  # Remote check"