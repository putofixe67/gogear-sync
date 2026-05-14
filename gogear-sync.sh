#!/bin/bash
# ============================================================
# GoGear FLAC → MP3 Sync (GUI)
# Converts FLAC libraries to a highly specific MP3 format 
# compatible with vintage Philips GoGear players.
# ============================================================
set -euo pipefail

error_exit() {
    if command -v zenity &>/dev/null; then
        zenity --error --text="$1"
    else
        echo "ERROR: $1" >&2
    fi
    exit 1
}

trap 'error_exit "Conversion aborted by user"' INT TERM HUP

# ----- 1. Dependency Check -----
for cmd in zenity ffmpeg ffprobe eyeD3 parallel; do
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "Missing required program: $cmd\n\nInstall with:\nsudo apt install zenity ffmpeg eyed3 parallel"
    fi
done

# ----- 2. Source / Destination Selection -----
SRC=$(zenity --file-selection --directory --title="Select FLAC source folder") || error_exit "Source selection cancelled."
[ -z "$SRC" ] && exit 0

DEST_ROOT=$(zenity --file-selection --directory --title="Select destination folder (will contain Music/ and Playlists/)") || error_exit "Destination selection cancelled."
[ -z "$DEST_ROOT" ] && exit 0

MUSIC_DIR="$DEST_ROOT/Music"
PLAYLISTS_DIR="$DEST_ROOT/Playlists"
mkdir -p "$MUSIC_DIR" "$PLAYLISTS_DIR" || error_exit "Cannot create Music/Playlists folders."

# ----- 3. Quality & CPU Configuration -----
QUALITY=$(zenity --list --title="Choose MP3 quality" \
    --text="Source:      $SRC\nDestination: $DEST_ROOT\n\nSelect MP3 quality:" \
    --width=550 --height=300 \
    --column="Preset" --column="Description" \
    "V0"   "High ~245 kbps VBR" \
    "V2"   "Medium ~190 kbps VBR (recommended)" \
    "V5"   "Low ~130 kbps VBR (space saver)" \
    "128k" "Constant 128 kbps CBR (smallest)") || error_exit "Quality selection cancelled."

[ -z "$QUALITY" ] && exit 0

case "$QUALITY" in
    V0)   QOPT_A="-q:a"; QOPT_B="0" ;;
    V2)   QOPT_A="-q:a"; QOPT_B="2" ;;
    V5)   QOPT_A="-q:a"; QOPT_B="5" ;;
    128k) QOPT_A="-b:a"; QOPT_B="128k" ;;
    *)    error_exit "Invalid quality choice." ;;
esac

CPUS=$(nproc)
CPU_OPT=$(zenity --list --title="CPU usage" \
    --text="How many CPU cores should the conversion use?\n\nMore cores = faster but may slow down the PC." \
    --width=550 --height=300 \
    --column="Option" --column="Description" \
    "1"   "Very slow, PC stays fully responsive" \
    "2"   "Moderate speed, light PC usage" \
    "4"   "Fast, some CPU load" \
    "All" "Fastest – uses all $CPUS cores") || error_exit "CPU selection cancelled."

case "$CPU_OPT" in
    1)   JOBS="-j1" ;;
    2)   JOBS="-j2" ;;
    4)   JOBS="-j4" ;;
    All) JOBS="-j+0" ;;
    *)   error_exit "Invalid CPU choice." ;;
esac

zenity --question --title="Existing MP3 files" --text="OVERWRITE existing MP3 files?" && OVERWRITE=true || OVERWRITE=false
zenity --question --title="Remove album covers" --text="Remove embedded album covers from all MP3s?" && STRIP_COVERS=true || STRIP_COVERS=false

# ----- 4. Pre-flight Check -----
mapfile -d '' FLAC_FILES < <(find "$SRC" -type f -iname "*.flac" -print0) || error_exit "Error scanning source folder."
flac_count=${#FLAC_FILES[@]}
[ "$flac_count" -eq 0 ] && error_exit "No FLAC files found in:\n$SRC"

# ----- 5. Parallel Worker Function -----
do_convert() {
    local f="$1"
    local rel="${f#$SRC/}"
    local dest_dir="$MUSIC_DIR/$(dirname "$rel")"

    local title album
    title=$(ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | head -1)
    album=$(ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | head -1)
    [ -z "$title" ] && title="$(basename "${f%.flac}")"
    [ -z "$album" ] && album="Unknown Album"

    local clean_title
    clean_title=$(echo "$title" | sed -E -e 's/\([^)]*\)//g' -e 's/\(.*$/ /' -e 's/\)//g' -e 's/  +/ /g' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//')
    [ -z "$clean_title" ] && clean_title="$title"

    local file_title
    file_title=$(echo "$clean_title" | tr -d '\000' | sed -e 's/[<>:"/\\|?*]//g' -e 's/^[[:space:].]*//; s/[[:space:].]*$//')
    [ -z "$file_title" ] && file_title="Unknown"

    local out="$dest_dir/${file_title}.mp3"

    if ! $OVERWRITE && [ -f "$out" ]; then
        echo "DONE" >> "$PIPE"
        return 0
    fi

    mkdir -p "$dest_dir"

    ffmpeg -nostdin -v error -y -i "$f" -id3v2_version 3 -map_metadata 0 "$QOPT_A" "$QOPT_B" "$out" </dev/null || true
    [ -f "$out" ] && eyeD3 --to-v2.3 --encoding utf16 -A "$album" "$out" >/dev/null 2>&1 || true

    echo "DONE" >> "$PIPE"
}
export -f do_convert
export SRC MUSIC_DIR OVERWRITE QOPT_A QOPT_B PIPE

# ----- 6. Execution & UI Pipe -----
PIPE=$(mktemp -u /tmp/flac2mp3_pipe.XXXXXX)
mkfifo "$PIPE"
exec 3<> "$PIPE"

{
    printf '%s\0' "${FLAC_FILES[@]}" | parallel --null --env SRC --env MUSIC_DIR --env OVERWRITE --env QOPT_A --env QOPT_B --env PIPE "$JOBS" 'do_convert {}' &

    done=0
    while [ $done -lt $flac_count ]; do
        read -u 3 -r line
        done=$((done + 1))
        echo "# Converting ($done/$flac_count)"
        echo $(( done * 80 / flac_count ))
    done
    wait

    if $STRIP_COVERS; then
        mapfile -d '' MP3S < <(find "$MUSIC_DIR" -type f -iname "*.mp3" -print0)
        total=${#MP3S[@]}
        if [ $total -gt 0 ]; then
            i=0
            for f in "${MP3S[@]}"; do
                i=$((i + 1))
                echo "# Removing covers ($i/$total)"
                eyeD3 --remove-all-images "$f" >/dev/null 2>&1 || true
                echo $(( 80 + i * 15 / total ))
            done
        fi
    fi

    echo "# Creating playlists..."
    echo "95"
    for dir in "$MUSIC_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        find "$dir" -type f -iname "*.mp3" | sort | sed "s|^$MUSIC_DIR/|../Music/|" > "$PLAYLISTS_DIR/${name}.m3u"
        [ -s "$PLAYLISTS_DIR/${name}.m3u" ] || rm -f "$PLAYLISTS_DIR/${name}.m3u"
    done
    find "$MUSIC_DIR" -type f -iname "*.mp3" | sort | sed "s|^$MUSIC_DIR/|../Music/|" > "$PLAYLISTS_DIR/All_Tracks.m3u"

    echo "# Finished"
    echo "100"
} | zenity --progress --title="FLAC → MP3 Mirror" --percentage=0 --auto-close --width=450

exec 3>&-
rm -f "$PIPE"

zenity --info --text="All tasks completed!\n\nMusic mirror:   $MUSIC_DIR\nPlaylists:      $PLAYLISTS_DIR\n\nCopy both folders to your GoGear's root."