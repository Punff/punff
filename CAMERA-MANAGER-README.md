# Punff Camera Manager

A unified GUI application for managing photos from an Olympus EPL-2 camera with Tinder-like interface, automatic site rebuild, and SSH deployment.

## Features

- **Auto-detection**: Automatically starts when camera is connected via USB
- **Tinder-like interface**: Swipe-style photo management with arrow key controls
- **Raw file handling**: Automatically manages Olympus .ORF raw files
  - **Edit**: Moves both JPEG and raw .ORF to edit directory
  - **Other actions**: Moves JPEG and trashes raw .ORF file
- **Photo rotation**: Rotate photos 90° clockwise with R key or button
- **Warm orange theme**: Matches punff site aesthetic (#ff8c00 on #0a0a0a)
- **Keyboard shortcuts**: Full keyboard control for efficient workflow
- **Undo functionality**: Revert any action (including rotation) with Ctrl+Z
- **Integrated build/deploy**: One-click site rebuild and SSH deployment
- **Photo organization**: Automatic sorting into trash/archive/edit/post folders

## Installation

### Dependencies

```bash
# Install tkinter (GUI toolkit)
sudo pacman -S tk

# Install Pillow (Python imaging library)
pip install Pillow
```

### Setup

1. Make scripts executable:
   ```bash
   chmod +x launch-camera-manager-py.sh test-camera-manager.sh
   ```

2. For auto-start when camera is connected (optional):
   ```bash
   # Copy systemd service file
   sudo cp punff-camera-manager-py.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now punff-camera-manager-py.service
   ```

3. For desktop shortcut (optional):
   ```bash
   cp punff-camera-manager-py.desktop ~/.local/share/applications/
   ```

## Usage

### Starting the Application

**From terminal menu:**
```bash
./new.sh
# Select option 2: "camera manager (GUI)"
```

**Direct launch:**
```bash
./launch-camera-manager-py.sh
```

**Test mode (without camera):**
```bash
./test-camera-manager.sh
```

**For passwordless deployment**, start SSH agent first:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Interface Controls

#### Keyboard Shortcuts:
- **← Left arrow**: Move photo to trash
- **↓ Down arrow**: Archive photo (don't post)
- **↑ Up arrow**: Mark for editing
- **→ Right arrow**: Post to website + archive copy
- **R key**: Rotate photo 90° clockwise
- **Ctrl+Z**: Undo last action (including rotation)
- **Ctrl+B**: Build site
- **Ctrl+D**: Deploy site
- **Esc**: Quit application

#### Mouse Controls:
- Click buttons at bottom of window (including "↻ Rotate" button)
- Use settings gear (⚙) for SSH configuration

### Workflow

1. Connect Olympus EPL-2 camera via USB
2. Application auto-detects camera at: `/run/media/punff/disk/DCIM/101OLYMP/`
3. Use arrow keys to process each photo:
   - **→ Post**: Copies JPEG to `assets/photos/` and `archive/`, trashes raw .ORF
   - **↑ Edit**: Moves both JPEG and raw .ORF to `to-edit/` folder
   - **↓ Archive**: Moves JPEG to `archive/`, trashes raw .ORF
   - **← Trash**: Moves JPEG to `trash/`, trashes raw .ORF
   - **R key**: Rotate photo 90° clockwise (permanently modifies file)
4. Click "Build Site" or press Ctrl+B to rebuild website
5. Click "Deploy" or press Ctrl+D to deploy via SSH

### Configuration

Settings are saved to `~/.punff-camera-manager.json`:

```json
{
  "ssh_host": "punff@punff.com",
  "ssh_path": "/home/punff/punff-site/",
  "auto_deploy": true,
  "theme": "warm_orange"
}
```

### Deployment

The camera manager supports multiple deployment methods:

1. **Automatic SSH Deployment** (Recommended):
   - Configure SSH host and path in settings (⚙ button)
   - Click "Deploy" or press Ctrl+D
   - Automatically builds site and deploys via SCP

2. **Interactive deploy.sh**:
   - If no SSH settings are configured
   - Runs the existing `deploy.sh` script
   - Provides interactive menu for deployment options

3. **Manual Build + Deploy**:
   - Click "Build Site" or press Ctrl+B to rebuild
   - Then deploy using your preferred method

**Deployment:**

The camera manager uses `deploy.sh` for deployment, which handles:
- SSH connection testing
- Permission checking  
- Path selection
- Interactive prompts

**For passwordless deployment (no passphrase prompts):**
```bash
# Start SSH agent (once per session)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
# Enter passphrase once

# Then run camera manager
./launch-camera-manager-py.sh
```

**Without SSH agent:** Deployment will ask for passphrase for each file transfer.

The launcher script shows SSH agent status on startup.

**Deployment Files:**
- `index.html` - Main site file
- `photos-data.json` - Photo metadata
- `assets/` - Photos and other assets
- `build.sh` - Build script (automatically called)
- `deploy.sh` - Interactive deployment script (fallback)

## File Structure

```
punff-site/
├── punff-camera-manager.py      # Optimized Python GUI application
├── launch-camera-manager-py.sh  # Launcher script
├── CAMERA-MANAGER-README.md     # This documentation
│
├── assets/photos/               # Posted photos (for website)
├── to-edit/                     # Photos marked for editing
│
├── build.sh                     # Site build script
└── deploy.sh                    # Deployment script

**Note:** Trash uses system trash (`~/.local/share/Trash/files`)
**Note:** Archive uses `~/Documents/kamera-backup`

## Integration with Existing Workflow

The camera manager integrates seamlessly with the existing punff site:

1. **Photo storage**: Posted photos go to `assets/photos/` (same as manual workflow)
2. **Build system**: Calls existing `build.sh` script
3. **Deployment**: Uses existing `deploy.sh` or direct SSH
4. **Terminal menu**: Added as option 2 in `new.sh`

## Troubleshooting

### Camera Not Detected
- Ensure camera is connected via USB and powered on
- Check mount path: `/run/media/punff/disk/DCIM/101OLYMP/`
- Application will prompt to browse for photos if camera not found

### GUI Doesn't Start
- Verify tkinter is installed: `python3 -c "import tkinter"`
- Verify Pillow is installed: `python3 -c "import PIL"`
- Check display: Ensure you're in a graphical session

### Permission Issues
- Ensure user has write access to photo directories
- Check SSH key configuration for deployment

### Test Mode
Use `./test-camera-manager.sh` to test without a camera. It creates a test directory with sample images.

## Development

The application is written in Python 3 using:
- **tkinter**: GUI framework
- **Pillow (PIL)**: Image processing
- **Standard libraries**: os, shutil, subprocess, json, threading

To modify:
1. Edit `punff-camera-manager.py`
2. Test with `./test-camera-manager.sh`
3. Update documentation if needed

## License

Part of the punff photo sharing website project.