# GoGear FLAC → MP3 Sync

A multithreaded GUI tool for Linux that converts and sanitizes modern FLAC libraries into a format perfectly tailored for vintage Philips GoGear MP3 players.

This tool provides a simple UI to automatically batch-convert, sanitize, and structure your library safely.

## ✨ Features

* **GoGear-Ready Tags:** Forces strict `ID3v2.3` with `UTF-16` encoding, which is required for many older hardware players to read metadata correctly.
* **Deep Filename Sanitization:** Automatically removes parentheses `()` and their inner content, strips Windows-prohibited characters, transliterates accented characters to plain ASCII (`ö` → `o`, `é` → `e`, `ç` → `c`), and trims trailing spaces to prevent file-system crashes on FAT32 players.
* **Automated Playlist Generation:** Automatically generates `.m3u` playlists structured specifically for the GoGear's root directory (`Music/` and `Playlists/`).
* **Multithreaded:** Runs conversions on all your CPU cores for incredibly fast batch conversions, with a selectable CPU throttle in the UI.
* **Cover Art Stripping:** Optional toggle to aggressively strip embedded cover art to save space and prevent firmware lag on low-RAM devices.

## 🛠️ Prerequisites

This script relies on standard Linux audio and UI utilities.

For Debian/Ubuntu/Linux Mint:

```bash
sudo apt update && sudo apt install zenity ffmpeg eyed3
```

For Fedora:

```bash
sudo dnf install zenity ffmpeg-free python3-eyed3
```

> **Note (Fedora):** if `ffmpeg-free` on your release lacks the MP3 encoder, install the full `ffmpeg` from [RPM Fusion](https://rpmfusion.org/Configuration) instead.

## 🚀 Quick Install (One-Liner)

To install the tool and automatically add it to your desktop Application Menu, run this single command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/putofixe67/gogear-sync/main/install.sh)"

```

Once installed, simply open your app launcher and search for **GoGear Audio Sync**.

## 🚀 Manual Usage

If you prefer not to install the desktop shortcut, you can simply download the main script and run it from your terminal:

```bash
wget https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.sh
chmod +x gogear-sync.sh
./gogear-sync.sh
```
## 🗑️ Uninstall

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/putofixe67/gogear-sync/main/uninstall.sh)"
```

Or simply remove the two installed files yourself:

```bash
rm -f ~/.local/bin/gogear-sync ~/.local/share/applications/gogear-sync.desktop
```

## 🤖 Acknowledgments

This project was vibe coded. I defined the logic, hardware constraints, and requirements, while AI assisted with generating the bash syntax.

## License

MIT
