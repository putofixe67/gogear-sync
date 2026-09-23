#!/bin/bash
set -euo pipefail

echo "Installing GoGear FLAC to MP3 Sync..."

# Create local bin and application folders
mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/scalable/apps

# Download the main script
curl -fsSL https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.sh -o ~/.local/bin/gogear-sync
chmod +x ~/.local/bin/gogear-sync

# Download the app icon
curl -fsSL https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.svg -o ~/.local/share/icons/hicolor/scalable/apps/gogear-sync.svg

# Create a Desktop shortcut so it appears in the app menu
cat << EOF > ~/.local/share/applications/gogear-sync.desktop
[Desktop Entry]
Version=1.0
Name=GoGear Audio Sync
Comment=Convert FLAC to GoGear compatible MP3s
Exec=$HOME/.local/bin/gogear-sync
Icon=gogear-sync
Terminal=false
Type=Application
Categories=AudioVideo;Audio;
EOF

# Refresh the icon cache so the logo shows up right away
command -v gtk-update-icon-cache &>/dev/null && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor &>/dev/null || true

echo "Installation complete! You can now launch 'GoGear Audio Sync' from your application menu."
