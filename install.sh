#!/bin/bash
set -e

echo "Installing GoGear FLAC to MP3 Sync..."

# Create local bin and application folders
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications

# Download the main script
curl -fsSL https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.sh -o ~/.local/bin/gogear-sync
chmod +x ~/.local/bin/gogear-sync

# Create a Desktop shortcut so it appears in the app menu
cat << 'EOF' > ~/.local/share/applications/gogear-sync.desktop
[Desktop Entry]
Version=1.0
Name=GoGear Audio Sync
Comment=Convert FLAC to GoGear compatible MP3s
Exec=/home/%u/.local/bin/gogear-sync
Icon=multimedia-audio-player
Terminal=false
Type=Application
Categories=AudioVideo;Audio;
EOF

# Fix the %u variable to match the current user
sed -i "s|/home/%u|$HOME|g" ~/.local/share/applications/gogear-sync.desktop

echo "Installation complete! You can now launch 'GoGear Audio Sync' from your application menu."