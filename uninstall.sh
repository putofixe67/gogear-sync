#!/bin/bash
set -euo pipefail

rm -f ~/.local/bin/gogear-sync \
      ~/.local/share/applications/gogear-sync.desktop \
      ~/.local/share/icons/hicolor/scalable/apps/gogear-sync.svg

command -v gtk-update-icon-cache &>/dev/null && gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor &>/dev/null || true
echo "GoGear Audio Sync uninstalled."
