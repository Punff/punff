#!/usr/bin/env python3
"""
Punff Camera Manager - Python GUI for Olympus EPL-2 photo management
Warm orange theme matching punff site aesthetic
"""

import os
import sys
import shutil
import subprocess
import threading
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from PIL import Image, ImageTk
import json

# Raw file extensions (Olympus raw format)
RAW_EXTENSIONS = {'.orf', '.ORF'}

# Configuration
CONFIG_FILE = os.path.expanduser("~/.punff-camera-manager.json")
CAMERA_PATH = "/run/media/punff/disk/DCIM/101OLYMP/"
SITE_ROOT = os.path.dirname(os.path.abspath(__file__))
PHOTOS_DIR = os.path.join(SITE_ROOT, "assets", "photos")
TRASH_DIR = os.path.expanduser("~/.local/share/Trash/files")  # System trash
ARCHIVE_DIR = os.path.expanduser("~/Documents/kamera-backup")  # Backup location
EDIT_DIR = os.path.join(SITE_ROOT, "to-edit")

# Warm orange theme colors
BG_COLOR = "#0a0a0a"
FG_COLOR = "#ff8c00"
ACCENT_COLOR = "#ffa500"
BUTTON_BG = "#1a1a1a"
BUTTON_ACTIVE = "#2a2a2a"

class CameraManager:
    def __init__(self, root):
        self.root = root
        self.root.title("Punff Camera Manager")
        self.root.configure(bg=BG_COLOR)
        
        # Load config
        self.config = self.load_config()
        
        # State
        self.photos = []
        self.current_index = 0
        self.undo_stack = []
        self.rotation_angle = 0  # Current rotation angle for displayed photo
        
        # Create directories if they don't exist
        for dir_path in [PHOTOS_DIR, TRASH_DIR, ARCHIVE_DIR, EDIT_DIR]:
            os.makedirs(dir_path, exist_ok=True)
        
        # Setup GUI
        self.setup_gui()
        
        # Check for camera
        self.check_camera()
    
    def load_config(self):
        """Load configuration from file"""
        default_config = {
            "ssh_host": "marioantunovic13@punff.port0.org",
            "ssh_path": "~/punff-site",  # Changed to home directory path
            "auto_deploy": True,
            "theme": "warm_orange"
        }
        
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return {**default_config, **json.load(f)}
            except:
                return default_config
        return default_config
    
    def save_config(self):
        """Save configuration to file"""
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def setup_gui(self):
        """Setup the GUI layout"""
        # Main container
        main_frame = tk.Frame(self.root, bg=BG_COLOR)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        status_bar = tk.Label(main_frame, textvariable=self.status_var, 
                             bg=BG_COLOR, fg=FG_COLOR, font=("Monospace", 10))
        status_bar.pack(side=tk.BOTTOM, fill=tk.X, pady=(10, 0))
        
        # Photo display area
        photo_frame = tk.Frame(main_frame, bg=BG_COLOR)
        photo_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 20))
        
        # Photo info
        info_frame = tk.Frame(photo_frame, bg=BG_COLOR)
        info_frame.pack(side=tk.TOP, fill=tk.X, pady=(0, 10))
        
        self.photo_info = tk.Label(info_frame, text="No photos", 
                                  bg=BG_COLOR, fg=FG_COLOR, font=("Monospace", 12))
        self.photo_info.pack(side=tk.LEFT)
        
        self.photo_count = tk.Label(info_frame, text="0/0", 
                                   bg=BG_COLOR, fg=ACCENT_COLOR, font=("Monospace", 12))
        self.photo_count.pack(side=tk.RIGHT)
        
        # Photo canvas
        self.photo_canvas = tk.Canvas(photo_frame, bg=BG_COLOR, highlightthickness=0)
        self.photo_canvas.pack(fill=tk.BOTH, expand=True)
        
        self.photo_image = None
        self.photo_item = None
        
        # Action buttons frame
        button_frame = tk.Frame(main_frame, bg=BG_COLOR)
        button_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=(10, 0))
        
        # Action buttons
        button_configs = [
            ("← Trash", self.trash_photo, "#ff4444"),
            ("↓ Archive", self.archive_photo, "#44ff44"),
            ("↑ Edit", self.edit_photo, "#4444ff"),
            ("→ Post", self.post_photo, FG_COLOR),
        ]
        
        for text, command, color in button_configs:
            btn = tk.Button(button_frame, text=text, command=command,
                          bg=BUTTON_BG, fg=color, activebackground=BUTTON_ACTIVE,
                          font=("Monospace", 12, "bold"), padx=20, pady=10,
                          relief=tk.FLAT, borderwidth=2)
            btn.pack(side=tk.LEFT, expand=True, padx=5)
        
        # Control buttons frame
        control_frame = tk.Frame(main_frame, bg=BG_COLOR)
        control_frame.pack(side=tk.BOTTOM, fill=tk.X, pady=(10, 0))
        
        # Undo button
        undo_btn = tk.Button(control_frame, text="↶ Undo", command=self.undo_action,
                           bg=BUTTON_BG, fg=FG_COLOR, activebackground=BUTTON_ACTIVE,
                           font=("Monospace", 10), padx=15, pady=5,
                           relief=tk.FLAT)
        undo_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Rotate button
        rotate_btn = tk.Button(control_frame, text="↻ Rotate (R)", command=self.rotate_photo,
                             bg=BUTTON_BG, fg=ACCENT_COLOR, activebackground=BUTTON_ACTIVE,
                             font=("Monospace", 10), padx=15, pady=5,
                             relief=tk.FLAT)
        rotate_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Build button
        build_btn = tk.Button(control_frame, text="Build Site", command=self.build_site,
                            bg=BUTTON_BG, fg=FG_COLOR, activebackground=BUTTON_ACTIVE,
                            font=("Monospace", 10), padx=15, pady=5,
                            relief=tk.FLAT)
        build_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Deploy button
        deploy_btn = tk.Button(control_frame, text="Deploy", command=self.deploy_site,
                             bg=BUTTON_BG, fg=FG_COLOR, activebackground=BUTTON_ACTIVE,
                             font=("Monospace", 10), padx=15, pady=5,
                             relief=tk.FLAT)
        deploy_btn.pack(side=tk.LEFT)
        
        # SSH Agent button
        ssh_agent_btn = tk.Button(control_frame, text="🔑", command=self.setup_ssh_agent,
                                bg=BUTTON_BG, fg="#ffff00", activebackground=BUTTON_ACTIVE,
                                font=("Monospace", 12), padx=10, pady=5,
                                relief=tk.FLAT)
        ssh_agent_btn.pack(side=tk.RIGHT, padx=(0, 10))
        
        # Settings button
        settings_btn = tk.Button(control_frame, text="⚙", command=self.open_settings,
                               bg=BUTTON_BG, fg=FG_COLOR, activebackground=BUTTON_ACTIVE,
                               font=("Monospace", 12), padx=10, pady=5,
                               relief=tk.FLAT)
        settings_btn.pack(side=tk.RIGHT)
        
        # Keyboard shortcuts
        self.root.bind('<Left>', lambda e: self.trash_photo())
        self.root.bind('<Down>', lambda e: self.archive_photo())
        self.root.bind('<Up>', lambda e: self.edit_photo())
        self.root.bind('<Right>', lambda e: self.post_photo())
        self.root.bind('<Control-z>', lambda e: self.undo_action())
        self.root.bind('<Control-b>', lambda e: self.build_site())
        self.root.bind('<Control-d>', lambda e: self.deploy_site())
        self.root.bind('<Escape>', lambda e: self.root.quit())
        self.root.bind('r', lambda e: self.rotate_photo())
        self.root.bind('R', lambda e: self.rotate_photo())
    
    def check_camera(self):
        """Check if camera is connected and load photos"""
        if os.path.exists(CAMERA_PATH):
            self.load_photos_from_camera()
        else:
            self.status_var.set("Camera not connected. Connect Olympus EPL-2 via USB")
            # Ask if user wants to load from another directory
            if messagebox.askyesno("Camera Not Found", 
                                  "Camera not found at expected location.\n"
                                  f"Expected: {CAMERA_PATH}\n"
                                  "Would you like to browse for photos?"):
                self.browse_for_photos()
    
    def load_photos_from_camera(self, path=CAMERA_PATH):
        """Load photos from camera directory, skipping raw files"""
        self.photos = []
        try:
            # Use list comprehension for faster loading
            photo_extensions = ('.jpg', '.jpeg', '.png', '.gif')
            self.photos = sorted([
                os.path.join(path, f) for f in os.listdir(path)
                if f.lower().endswith(photo_extensions)
            ])
            
            if self.photos:
                self.status_var.set(f"Loaded {len(self.photos)} photos")
                self.current_index = 0
                self.show_current_photo()
            else:
                self.status_var.set("No photos found in camera")
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load photos: {e}")
    
    def browse_for_photos(self):
        """Browse for photos in a directory"""
        directory = filedialog.askdirectory(title="Select photo directory")
        if directory:
            self.load_photos_from_camera(directory)
    
    def find_raw_file(self, photo_path):
        """Find raw .ORF file associated with a processed photo"""
        base_name = os.path.splitext(os.path.basename(photo_path))[0]
        photo_dir = os.path.dirname(photo_path)
        
        # Check for .ORF files with same base name
        for ext in RAW_EXTENSIONS:
            raw_path = os.path.join(photo_dir, f"{base_name}{ext}")
            if os.path.exists(raw_path):
                return raw_path
        
        # Also check for .ORF files with similar names (common in camera naming)
        for file in os.listdir(photo_dir):
            file_lower = file.lower()
            if file_lower.endswith('.orf') and base_name in file:
                return os.path.join(photo_dir, file)
        
        return None
    
    def move_file_with_unique_name(self, src_path, dest_dir, copy=False):
        """Move or copy file to destination with unique name if needed"""
        filename = os.path.basename(src_path)
        dest_path = os.path.join(dest_dir, filename)
        counter = 1
        
        while os.path.exists(dest_path):
            name, ext = os.path.splitext(filename)
            dest_path = os.path.join(dest_dir, f"{name}_{counter}{ext}")
            counter += 1
        
        if copy:
            shutil.copy2(src_path, dest_path)
        else:
            shutil.move(src_path, dest_path)
        return dest_path
    
    def show_current_photo(self):
        """Display the current photo efficiently"""
        if not self.photos or self.current_index >= len(self.photos):
            self.photo_info.config(text="No photos")
            self.photo_count.config(text="0/0")
            if self.photo_item:
                self.photo_canvas.delete(self.photo_item)
            return
        
        photo_path = self.photos[self.current_index]
        filename = os.path.basename(photo_path)
        
        # Update info
        rotation_text = f" ↻{self.rotation_angle}°" if self.rotation_angle != 0 else ""
        self.photo_info.config(text=f"{filename}{rotation_text}")
        self.photo_count.config(text=f"{self.current_index + 1}/{len(self.photos)}")
        
        # Load and display image with error handling
        try:
            with Image.open(photo_path) as img:
                # Apply rotation if needed
                if self.rotation_angle != 0:
                    img = img.rotate(self.rotation_angle, expand=True)
                
                # Resize to fit canvas
                canvas_width = max(self.photo_canvas.winfo_width() - 40, 10)
                canvas_height = max(self.photo_canvas.winfo_height() - 40, 10)
                
                img.thumbnail((canvas_width, canvas_height), Image.Resampling.LANCZOS)
                self.photo_image = ImageTk.PhotoImage(img)
                
                # Clear previous and display new
                if self.photo_item:
                    self.photo_canvas.delete(self.photo_item)
                
                x = (self.photo_canvas.winfo_width() - self.photo_image.width()) // 2
                y = (self.photo_canvas.winfo_height() - self.photo_image.height()) // 2
                self.photo_item = self.photo_canvas.create_image(x, y, anchor=tk.NW, image=self.photo_image)
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load image: {e}")
    
    def rotate_photo(self):
        """Rotate the current photo 90 degrees clockwise"""
        if not self.photos or self.current_index >= len(self.photos):
            return
        
        photo_path = self.photos[self.current_index]
        filename = os.path.basename(photo_path)
        
        try:
            # Open and rotate the image
            with Image.open(photo_path) as img:
                # Rotate 90 degrees clockwise
                rotated_img = img.rotate(-90, expand=True)
                
                # Save rotated image back to file
                rotated_img.save(photo_path)
                
                # Update rotation angle for display
                self.rotation_angle = (self.rotation_angle - 90) % 360
                
                # Save undo info
                self.undo_stack.append({
                    'action': 'rotate',
                    'photo_path': photo_path,
                    'rotation_change': -90,  # Negative for clockwise rotation
                    'index': self.current_index
                })
                
                # Refresh display
                self.show_current_photo()
                self.status_var.set(f"Rotated: {filename}")
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to rotate image: {e}")
    
    def next_photo(self):
        """Move to next photo"""
        if self.photos and self.current_index < len(self.photos) - 1:
            self.current_index += 1
            self.rotation_angle = 0  # Reset rotation for new photo
            self.show_current_photo()
    
    def perform_action(self, action_type, dest_dir):
        """Perform photo action (move to directory)"""
        if not self.photos or self.current_index >= len(self.photos):
            return
        
        photo_path = self.photos[self.current_index]
        filename = os.path.basename(photo_path)
        
        try:
            # Move photo
            dest_path = self.move_file_with_unique_name(photo_path, dest_dir)
            
            # Handle raw file if exists
            raw_file = self.find_raw_file(photo_path)
            if raw_file:
                if action_type == 'edit':
                    # Move raw to edit directory
                    self.move_file_with_unique_name(raw_file, dest_dir)
                    self.status_var.set(f"Moved to {action_type}: {filename} + raw")
                else:
                    # Trash raw file
                    self.move_file_with_unique_name(raw_file, TRASH_DIR)
                    self.status_var.set(f"Moved to {action_type}: {filename}, raw trashed")
            else:
                self.status_var.set(f"Moved to {action_type}: {filename}")
            
            # Save undo info
            self.undo_stack.append({
                'action': action_type,
                'src': photo_path,
                'dest': dest_path,
                'index': self.current_index
            })
            
            # Remove from list and show next
            self.photos.pop(self.current_index)
            if self.current_index >= len(self.photos) and self.photos:
                self.current_index = len(self.photos) - 1
            
            self.rotation_angle = 0
            self.show_current_photo()
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to process: {e}")
    
    def trash_photo(self):
        """Move photo to trash"""
        self.perform_action("trash", TRASH_DIR)
    
    def archive_photo(self):
        """Move photo to archive"""
        self.perform_action("archive", ARCHIVE_DIR)
    
    def edit_photo(self):
        """Move photo to edit folder"""
        self.perform_action("edit", EDIT_DIR)
    
    def post_photo(self):
        """Post photo to website"""
        if not self.photos or self.current_index >= len(self.photos):
            return
        
        photo_path = self.photos[self.current_index]
        filename = os.path.basename(photo_path)
        
        try:
            # Copy to website and archive
            dest_photos = self.move_file_with_unique_name(photo_path, PHOTOS_DIR, copy=True)
            dest_archive = self.move_file_with_unique_name(photo_path, ARCHIVE_DIR, copy=True)
            
            # Remove original
            os.remove(photo_path)
            
            # Handle raw file
            raw_file = self.find_raw_file(photo_path)
            if raw_file:
                self.move_file_with_unique_name(raw_file, TRASH_DIR)
                self.status_var.set(f"Posted: {filename} (raw trashed)")
            else:
                self.status_var.set(f"Posted: {filename}")
            
            # Save undo info
            self.undo_stack.append({
                'action': 'post',
                'src': photo_path,
                'dest_photos': dest_photos,
                'dest_archive': dest_archive,
                'index': self.current_index
            })
            
            # Remove from list and show next
            self.photos.pop(self.current_index)
            if self.current_index >= len(self.photos) and self.photos:
                self.current_index = len(self.photos) - 1
            
            self.rotation_angle = 0
            self.show_current_photo()
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to post: {e}")
    
    def undo_action(self):
        """Undo last action (simplified - basic undo only)"""
        if not self.undo_stack:
            self.status_var.set("Nothing to undo")
            return
        
        action = self.undo_stack.pop()
        
        try:
            if action['action'] == 'post':
                # Remove posted copies
                for key in ['dest_photos', 'dest_archive']:
                    if key in action and os.path.exists(action[key]):
                        os.remove(action[key])
                # Restore original
                self.photos.insert(action['index'], action['src'])
                
            elif action['action'] == 'rotate':
                # Rotate back
                with Image.open(action['photo_path']) as img:
                    img.rotate(-action['rotation_change'], expand=True).save(action['photo_path'])
                    self.rotation_angle = (self.rotation_angle - action['rotation_change']) % 360
                self.current_index = action['index']
                
            else:
                # Move file back for other actions
                if os.path.exists(action['dest']):
                    shutil.move(action['dest'], action['src'])
                    self.photos.insert(action['index'], action['src'])
                self.current_index = action['index']
            
            self.show_current_photo()
            self.status_var.set(f"Undid {action['action']}")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to undo: {e}")
    
    def build_site(self):
        """Build the website"""
        build_script = os.path.join(SITE_ROOT, "build.sh")
        
        if not os.path.exists(build_script):
            messagebox.showerror("Error", f"Build script not found: {build_script}")
            return
        
        def run_build():
            try:
                self.status_var.set("Building site...")
                result = subprocess.run([build_script], capture_output=True, text=True, cwd=SITE_ROOT)
                
                if result.returncode == 0:
                    self.status_var.set("Build completed successfully")
                    messagebox.showinfo("Build Complete", "Site built successfully!")
                else:
                    self.status_var.set("Build failed")
                    messagebox.showerror("Build Failed", f"Build error:\n{result.stderr}")
                    
            except Exception as e:
                messagebox.showerror("Error", f"Failed to run build: {e}")
        
        # Run in thread to avoid blocking GUI
        threading.Thread(target=run_build, daemon=True).start()
    
    def deploy_site(self):
        """Deploy the website - just runs deploy.sh with defaults"""
        deploy_script = os.path.join(SITE_ROOT, "deploy.sh")
        
        if not os.path.exists(deploy_script):
            messagebox.showerror("Error", "deploy.sh not found")
            return
        
        def run_deploy():
            try:
                self.status_var.set("Running deploy.sh...")
                # Run deploy.sh with auto-answers: y (deploy), 2 (SCP method), defaults for rest
                result = subprocess.run(
                    [deploy_script], 
                    capture_output=True, 
                    text=True, 
                    cwd=SITE_ROOT,
                    input="y\n2\n\n\n\n"
                )
                
                if result.returncode == 0:
                    self.status_var.set("Deployment completed")
                    messagebox.showinfo("Deploy Complete", "Site deployed successfully!")
                else:
                    self.status_var.set("Deployment failed")
                    # Show error message
                    error_msg = result.stderr if result.stderr else result.stdout
                    messagebox.showerror("Deploy Failed", f"Deploy error:\n{error_msg[:500]}")
                    
            except Exception as e:
                messagebox.showerror("Error", f"Failed to run deploy.sh: {e}")
        
        # Run in thread to avoid blocking GUI
        threading.Thread(target=run_deploy, daemon=True).start()
    
    def deploy_site_direct(self):
        """Alternative direct deployment (kept for compatibility)"""
        # Warn about SSH agent
        if 'SSH_AUTH_SOCK' not in os.environ:
            response = messagebox.askyesno(
                "SSH Agent Not Running",
                "SSH agent is not running. Each file transfer will ask for passphrase.\n\n"
                "For passwordless deployment, start SSH agent first.\n\n"
                "Use deploy.sh instead (recommended)?"
            )
            if response:
                self.deploy_site()
                return
        
        ssh_host = self.config.get('ssh_host', '')
        ssh_path = self.config.get('ssh_path', '')
        
        if ssh_host and ssh_path:
            def run_direct():
                try:
                    self.status_var.set(f"Deploying to {ssh_host}...")
                    success = self.deploy_via_ssh(ssh_host, ssh_path)
                    
                    if success:
                        self.status_var.set("Deployment completed")
                        messagebox.showinfo("Deploy Complete", f"Site deployed to {ssh_host}!")
                    else:
                        # Fall back to deploy.sh
                        self.status_var.set("Direct deploy failed, trying deploy.sh...")
                        self.run_interactive_deploy()
                except Exception as e:
                    messagebox.showerror("Error", f"Failed to deploy: {e}")
            
            threading.Thread(target=run_direct, daemon=True).start()
        else:
            # No settings, use deploy.sh
            self.deploy_site()
    
    def run_interactive_deploy(self):
        """Run the interactive deploy.sh script"""
        try:
            self.status_var.set("Running deploy.sh...")
            result = subprocess.run(
                [os.path.join(SITE_ROOT, "deploy.sh")], 
                capture_output=True, 
                text=True, 
                cwd=SITE_ROOT,
                input="y\n2\n\n\n\n"  # Auto-answers for deploy.sh
            )
            
            if result.returncode == 0:
                self.status_var.set("Deployment completed")
                messagebox.showinfo("Deploy Complete", "Site deployed successfully!")
            else:
                self.status_var.set("Deployment failed")
                messagebox.showerror("Deploy Failed", f"Deploy error:\n{result.stderr[:500]}")
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to run deploy.sh: {e}")
    
    def setup_ssh_agent(self):
        """Setup SSH agent for passwordless deployment"""
        if 'SSH_AUTH_SOCK' in os.environ:
            messagebox.showinfo("SSH Agent", "SSH agent is already running.")
            return
        
        # Simple instructions - GUI apps can't easily start SSH agent
        messagebox.showinfo(
            "SSH Agent Setup",
            "To enable passwordless deployment:\n\n"
            "1. Open a terminal\n"
            "2. Run: eval \"$(ssh-agent -s)\"\n"
            "3. Run: ssh-add ~/.ssh/id_ed25519\n"
            "4. Enter your passphrase once\n\n"
            "Then restart the camera manager for passwordless deployment."
        )
    
    def deploy_via_ssh(self, ssh_host, remote_path):
        """Deploy site via SCP - matches deploy.sh logic"""
        try:
            # Build site first
            self.status_var.set("Building site...")
            build_script = os.path.join(SITE_ROOT, "build.sh")
            
            if not os.path.exists(build_script):
                messagebox.showerror("Error", f"Build script not found: {build_script}")
                return False
            
            build_result = subprocess.run([build_script], capture_output=True, text=True, cwd=SITE_ROOT)
            if build_result.returncode != 0:
                messagebox.showerror("Build Failed", f"Build failed:\n{build_result.stderr}")
                return False
            
            # Check existing photos on server (like deploy.sh)
            self.status_var.set("Checking existing photos...")
            try:
                find_cmd = f"ssh -o BatchMode=yes {ssh_host} 'find {remote_path}/assets/photos -type f -name \"*.jpg\" -o -name \"*.jpeg\" -o -name \"*.png\" -o -name \"*.gif\" -o -name \"*.webp\" 2>/dev/null | xargs -I {{}} basename {{}} 2>/dev/null || true'"
                result = subprocess.run(find_cmd, shell=True, capture_output=True, text=True)
                existing_photos = set(result.stdout.strip().split('\n')) if result.stdout else set()
            except:
                existing_photos = set()
            
            # Upload index.html and photos-data.json first
            self.status_var.set("Uploading HTML and data files...")
            for file in ["index.html", "photos-data.json"]:
                src_path = os.path.join(SITE_ROOT, file)
                if os.path.exists(src_path):
                    # Try to create remote directory first
                    mkdir_cmd = f"ssh -o BatchMode=yes {ssh_host} 'mkdir -p {remote_path} 2>/dev/null || true'"
                    subprocess.run(mkdir_cmd, shell=True, capture_output=True)
                    
                    # Try upload
                    scp_cmd = f"scp -o BatchMode=yes {src_path} {ssh_host}:{remote_path}/"
                    scp_result = subprocess.run(scp_cmd, shell=True, capture_output=True, text=True)
                    
                    if scp_result.returncode != 0:
                        # Try without trailing slash
                        scp_cmd = f"scp -o BatchMode=yes {src_path} {ssh_host}:{remote_path}"
                        scp_result = subprocess.run(scp_cmd, shell=True, capture_output=True, text=True)
                        
                        if scp_result.returncode != 0:
                            messagebox.showerror(
                                "SCP Error", 
                                f"Failed to upload {file} to {remote_path}:\n\n"
                                f"{scp_result.stderr}\n\n"
                                f"Check:\n"
                                f"1. Remote path exists: {remote_path}\n"
                                f"2. You have write permissions\n"
                                f"3. Try a different path like ~/punff-site/"
                            )
                            return False
            
            # Upload only new photos
            self.status_var.set("Uploading new photos...")
            photos_dir = os.path.join(SITE_ROOT, "assets", "photos")
            uploaded_count = 0
            skipped_count = 0
            
            if os.path.exists(photos_dir):
                for filename in os.listdir(photos_dir):
                    photo_path = os.path.join(photos_dir, filename)
                    if os.path.isfile(photo_path) and filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.webp')):
                        if filename in existing_photos:
                            skipped_count += 1
                            continue
                        
                        # Upload new photo
                        scp_cmd = f"scp -o BatchMode=yes {photo_path} {ssh_host}:{remote_path}/assets/photos/"
                        scp_result = subprocess.run(scp_cmd, shell=True, capture_output=True, text=True)
                        
                        if scp_result.returncode == 0:
                            uploaded_count += 1
                        else:
                            messagebox.showwarning("Upload Warning", f"Failed to upload {filename}")
            
            # Upload other assets
            self.status_var.set("Uploading other assets...")
            assets_dir = os.path.join(SITE_ROOT, "assets")
            if os.path.exists(assets_dir):
                for root, dirs, files in os.walk(assets_dir):
                    if "photos" in root:
                        continue
                    
                    for file in files:
                        file_path = os.path.join(root, file)
                        rel_path = os.path.relpath(file_path, SITE_ROOT)
                        
                        # Ensure remote directory exists
                        dest_dir = os.path.dirname(rel_path)
                        if dest_dir:
                            mkdir_cmd = f"ssh -o BatchMode=yes {ssh_host} 'mkdir -p {remote_path}/{dest_dir}'"
                            subprocess.run(mkdir_cmd, shell=True, capture_output=True)
                        
                        # Upload file
                        scp_cmd = f"scp -o BatchMode=yes {file_path} {ssh_host}:{remote_path}/{rel_path}"
                        scp_result = subprocess.run(scp_cmd, shell=True, capture_output=True, text=True)
                        
                        if scp_result.returncode != 0:
                            messagebox.showwarning("Upload Warning", f"Failed to upload {rel_path}")
            
            self.status_var.set(f"Deployed: {uploaded_count} new, {skipped_count} skipped")
            return True
            
        except Exception as e:
            messagebox.showerror("Error", f"Deployment failed: {e}")
            return False
    
    def test_ssh_connection(self, ssh_host, remote_path):
        """Test SSH connection and path accessibility"""
        try:
            # Test basic SSH connection
            test_cmd = f"ssh -o BatchMode=yes -o ConnectTimeout=5 {ssh_host} 'echo SSH connection successful'"
            result = subprocess.run(test_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                messagebox.showerror(
                    "SSH Connection Failed",
                    f"Cannot connect to {ssh_host}:\n\n{result.stderr}\n\n"
                    "Make sure:\n"
                    "1. SSH key is set up\n"
                    "2. Server is reachable\n"
                    "3. SSH agent is running for passwordless login"
                )
                return False
            
            # Test if we can write to the path
            test_file = f"{remote_path}/.punff_test_{os.getpid()}"
            test_cmd = f"ssh -o BatchMode=yes {ssh_host} 'touch {test_file} 2>/dev/null && rm -f {test_file} && echo write_ok || echo write_failed'"
            result = subprocess.run(test_cmd, shell=True, capture_output=True, text=True)
            
            if "write_ok" not in result.stdout:
                response = messagebox.askyesno(
                    "Permission Issue",
                    f"Cannot write to {remote_path} on {ssh_host}.\n\n"
                    f"Error: {result.stderr}\n\n"
                    "Possible solutions:\n"
                    "1. Use a different path (e.g., ~/punff-site/)\n"
                    "2. Check permissions on remote server\n"
                    "3. Use sudo if required\n\n"
                    "Try with current path anyway?"
                )
                return response  # True to continue, False to stop
            
            return True
            
        except Exception as e:
            messagebox.showerror("Test Error", f"SSH test failed: {e}")
            return False
    
    def open_settings(self):
        """Open settings dialog"""
        settings_win = tk.Toplevel(self.root)
        settings_win.title("Settings")
        settings_win.configure(bg=BG_COLOR)
        settings_win.transient(self.root)
        settings_win.grab_set()
        
        # Center the window
        settings_win.geometry("400x300")
        x = self.root.winfo_x() + (self.root.winfo_width() - 400) // 2
        y = self.root.winfo_y() + (self.root.winfo_height() - 300) // 2
        settings_win.geometry(f"400x300+{x}+{y}")
        
        # Settings content
        content = tk.Frame(settings_win, bg=BG_COLOR)
        content.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # SSH settings
        tk.Label(content, text="SSH Host:", bg=BG_COLOR, fg=FG_COLOR, 
                font=("Monospace", 10)).grid(row=0, column=0, sticky=tk.W, pady=5)
        
        ssh_host_var = tk.StringVar(value=self.config.get('ssh_host', ''))
        ssh_host_entry = tk.Entry(content, textvariable=ssh_host_var, 
                                 bg=BUTTON_BG, fg=FG_COLOR, insertbackground=FG_COLOR,
                                 font=("Monospace", 10))
        ssh_host_entry.grid(row=0, column=1, sticky=tk.EW, pady=5, padx=(10, 0))
        
        tk.Label(content, text="SSH Path:", bg=BG_COLOR, fg=FG_COLOR,
                font=("Monospace", 10)).grid(row=1, column=0, sticky=tk.W, pady=5)
        
        ssh_path_var = tk.StringVar(value=self.config.get('ssh_path', ''))
        ssh_path_entry = tk.Entry(content, textvariable=ssh_path_var,
                                 bg=BUTTON_BG, fg=FG_COLOR, insertbackground=FG_COLOR,
                                 font=("Monospace", 10))
        ssh_path_entry.grid(row=1, column=1, sticky=tk.EW, pady=5, padx=(10, 0))
        
        # Auto-deploy checkbox
        auto_deploy_var = tk.BooleanVar(value=self.config.get('auto_deploy', True))
        auto_deploy_cb = tk.Checkbutton(content, text="Auto-deploy after posting",
                                       variable=auto_deploy_var, bg=BG_COLOR, fg=FG_COLOR,
                                       selectcolor=BUTTON_BG, activebackground=BG_COLOR,
                                       activeforeground=FG_COLOR, font=("Monospace", 10))
        auto_deploy_cb.grid(row=2, column=0, columnspan=2, sticky=tk.W, pady=10)
        
        # Save button
        def save_settings():
            self.config['ssh_host'] = ssh_host_var.get()
            self.config['ssh_path'] = ssh_path_var.get()
            self.config['auto_deploy'] = auto_deploy_var.get()
            self.save_config()
            settings_win.destroy()
            self.status_var.set("Settings saved")
        
        save_btn = tk.Button(content, text="Save", command=save_settings,
                           bg=BUTTON_BG, fg=FG_COLOR, activebackground=BUTTON_ACTIVE,
                           font=("Monospace", 10), padx=20, pady=5)
        save_btn.grid(row=3, column=0, columnspan=2, pady=20)
        
        # Configure grid weights
        content.columnconfigure(1, weight=1)
    
    def on_resize(self, event):
        """Handle window resize"""
        self.show_current_photo()

def main():
    root = tk.Tk()
    
    # Set window size and position
    root.geometry("800x600")
    root.minsize(600, 400)
    
    # Create application
    app = CameraManager(root)
    
    # Bind resize event
    root.bind('<Configure>', app.on_resize)
    
    # Start main loop
    root.mainloop()

if __name__ == "__main__":
    main()