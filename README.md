# GoGear FLAC → MP3 Sync

A multithreaded GUI tool for Linux that converts and sanitizes modern FLAC libraries into a format perfectly tailored for vintage Philips GoGear MP3 players.

If you own an older MP3 player, you likely know the struggle: they don't support FLAC, they crash if file names contain certain characters (like parentheses), and their firmware chokes on modern ID3v2.4 tags or high-resolution embedded album art.

This tool provides a simple UI to automatically batch-convert, sanitize, and structure your library safely.

## ✨ Features

* **GoGear-Ready Tags:** Forces strict `ID3v2.3` with `UTF-16` encoding, which is required for many older hardware players to read metadata correctly.
* **Deep Filename Sanitization:** Automatically removes parentheses `()` and their inner content, strips Windows-prohibited characters, and trims trailing spaces to prevent file-system crashes on FAT32 players.
* **Automated Playlist Generation:** Automatically generates `.m3u` playlists structured specifically for the GoGear's root directory (`Music/` and `Playlists/`).
* **Multithreaded:** Uses GNU `parallel` to utilize all your CPU cores for incredibly fast batch conversions, with a selectable CPU throttle in the UI.
* **Cover Art Stripping:** Optional toggle to aggressively strip embedded cover art to save space and prevent firmware lag on low-RAM devices.

## 🛠️ Prerequisites

This script relies on standard Linux audio and UI utilities.
For Debian/Ubuntu/Linux Mint:

```bash
sudo apt update && sudo apt install zenity ffmpeg eyed3 parallel

```

## 🚀 Quick Install (One-Liner)

To install the tool and automatically add it to your desktop Application Menu, run this single command in your terminal:

```bash
bash -c "$(curl -fsSL [https://raw.githubusercontent.com/putofixe67/gogear-sync/main/install.sh](https://raw.githubusercontent.com/putofixe67/gogear-sync/main/install.sh))"

```

Once installed, simply open your app launcher and search for **GoGear Audio Sync**.

## 🚀 Manual Usage

If you prefer not to install the desktop shortcut, you can simply download the main script and run it from your terminal:

```bash
wget [https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.sh](https://raw.githubusercontent.com/putofixe67/gogear-sync/main/gogear-sync.sh)
chmod +x gogear-sync.sh
./gogear-sync.sh

```

## License

MIT
