#!/bin/bash

cd "$(dirname "$0")"

# Build
./build.sh

echo "Deploying..."

# Use SSH ControlMaster to reuse connection
SSH_OPTS="-o ControlMaster=auto -o ControlPath=~/.ssh/control-%r@%h:%p -o ControlPersist=10m"

# First connection - will prompt for passphrase
ssh $SSH_OPTS -f -N marioantunovic13@punff.port0.org

# Copy files using the shared connection
scp $SSH_OPTS index.html photos-data.json marioantunovic13@punff.port0.org:/var/www/html/

# Copy only new photos
for photo in assets/photos/*; do
    if [ -f "$photo" ]; then
        filename=$(basename "$photo")
        # Check if photo exists on server
        if ! ssh $SSH_OPTS marioantunovic13@punff.port0.org "test -f /var/www/html/assets/photos/$filename" 2>/dev/null; then
            echo "Copying $filename"
            scp $SSH_OPTS "$photo" marioantunovic13@punff.port0.org:/var/www/html/assets/photos/
        else
            echo "Skipping $filename (already exists)"
        fi
    fi
done

# Close the connection
ssh $SSH_OPTS -O exit marioantunovic13@punff.port0.org 2>/dev/null || true

echo "Done"