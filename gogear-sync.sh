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
if command -v dnf &>/dev/null; then
    PKG_HINT="sudo dnf install zenity ffmpeg-free python3-eyed3"
else
    PKG_HINT="sudo apt install zenity ffmpeg eyed3"
fi
for cmd in zenity ffmpeg ffprobe eyeD3; do
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "Missing required program: $cmd\n\nInstall with:\n$PKG_HINT"
    fi
done

# ----- 2. Source / Destination Selection -----
SRC=$(zenity --file-selection --directory --title="Select FLAC source folder") || error_exit "Source selection cancelled."

DEST_ROOT=$(zenity --file-selection --directory --title="Select destination folder (will contain Music/ and Playlists/)") || error_exit "Destination selection cancelled."

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

case "$QUALITY" in
    V0)   QOPT="-q:a 0" ;;
    V2)   QOPT="-q:a 2" ;;
    V5)   QOPT="-q:a 5" ;;
    128k) QOPT="-b:a 128k" ;;
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

JOBS="${CPU_OPT/All/$CPUS}"

zenity --question --title="Existing MP3 files" --text="OVERWRITE existing MP3 files?" && OVERWRITE=true || OVERWRITE=false
zenity --question --title="Remove album covers" --text="Remove embedded album covers from all MP3s?" && STRIP_COVERS=true || STRIP_COVERS=false

# Skip embedding covers during conversion when they'd be stripped right after
if $STRIP_COVERS; then COVER_OPT="-vn"; else COVER_OPT=""; fi

# ----- 4. Pre-flight Check -----
# Sorted so duplicate numbering is deterministic across runs
mapfile -d '' FLAC_FILES < <(find "$SRC" -type f -iname "*.flac" -print0 | sort -z)
flac_count=${#FLAC_FILES[@]}
[ "$flac_count" -eq 0 ] && error_exit "No FLAC files found in:\n$SRC"

# ----- 5. Helpers & Parallel Workers -----
sanitize_title() {
    local t
    t=$(echo "$1" | sed -E -e 's/\([^)]*\)//g' -e 's/\(.*$/ /' -e 's/\)//g' -e 's/  +/ /g' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//')
    [ -z "$t" ] && t="$1"
    t=$(echo "$t" | iconv -c -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | sed -e 's/[<>:"/\\|?*]//g' -e 's/^[[:space:].]*//; s/[[:space:].]*$//')
    [ -z "$t" ] && t="Unknown"
    printf '%s\n' "$t"
}

# Emits one "file US title US album NUL" record (US = 0x1f unit separator)
probe_one() {
    local key value title="" album=""
    while IFS='=' read -r key value; do
        case "${key,,}" in
            tag:title) [ -z "$title" ] && title="$value" ;;
            tag:album) [ -z "$album" ] && album="$value" ;;
        esac
    done < <(ffprobe -v error -show_entries format_tags=title,album -of default=noprint_wrappers=1 "$1" 2>/dev/null)
    printf '%s\x1f%s\x1f%s\0' "$1" "$title" "$album"
    echo "DONE" >> "$PIPE"
}

do_convert() {
    local f="$1" out="$2" album="$3"

    if ! $OVERWRITE && [ -f "$out" ]; then
        echo "DONE" >> "$PIPE"
        return 0
    fi

    mkdir -p "$(dirname "$out")"
    ffmpeg -nostdin -v error -y -i "$f" -id3v2_version 3 -map_metadata 0 $COVER_OPT $QOPT "$out" </dev/null || true
    [ -f "$out" ] && eyeD3 --to-v2.3 --encoding utf16 -A "$album" "$out" >/dev/null 2>&1 || true

    echo "DONE" >> "$PIPE"
}

strip_covers() {
    eyeD3 --remove-all-images "$1" >/dev/null 2>&1 || true
    echo "DONE" >> "$PIPE"
}

write_playlist() {
    local dir="$1" prefix="$2" out="$3" p
    find "$dir" -type f -iname "*.mp3" -print0 | sort -z |
        while IFS= read -r -d '' p; do
            printf '%s%s\n' "$prefix" "${p#"$dir"/}"
        done > "$out"
    [ -s "$out" ] || rm -f "$out"
}

# Reads one DONE from fd 3 per finished job and maps it onto a progress-bar span
progress_loop() {
    local count="$1" label="$2" base="$3" span="$4" i=0
    while [ "$i" -lt "$count" ]; do
        read -r -u 3 _
        i=$((i + 1))
        echo "# $label ($i/$count)"
        echo $(( base + i * span / count ))
    done
}

export -f probe_one do_convert strip_covers

# ----- 6. Execution & UI Pipe -----
PIPE=$(mktemp -u /tmp/flac2mp3_pipe.XXXXXX)
mkfifo "$PIPE"
TAGFILE=$(mktemp /tmp/flac2mp3_tags.XXXXXX)
trap 'rm -f "$PIPE" "$TAGFILE"' EXIT
exec 3<> "$PIPE"

export OVERWRITE QOPT COVER_OPT PIPE

{
    # Phase 1: read tags from all files in parallel
    printf '%s\0' "${FLAC_FILES[@]}" | xargs -0 -n1 -P "$JOBS" bash -c 'probe_one "$1"' _ > "$TAGFILE" &
    worker_pid=$!
    # If the progress dialog is closed, stop the workers instead of orphaning them
    trap 'kill "$worker_pid" 2>/dev/null; exit 1' PIPE
    progress_loop "$flac_count" "Scanning tags" 0 15

    wait "$worker_pid" || true
    declare -A TITLES ALBUMS
    while IFS= read -r -d '' rec; do
        f="${rec%%$'\x1f'*}"
        rec="${rec#*$'\x1f'}"
        TITLES[$f]="${rec%%$'\x1f'*}"
        ALBUMS[$f]="${rec#*$'\x1f'}"
    done < "$TAGFILE"

    # Phase 2: assign output names, numbering duplicates ("Song.mp3", "Song 2.mp3", ...)
    # Keys are lowercased because FAT32 is case-insensitive
    echo "# Resolving file names..."
    declare -A taken
    TASKS=()
    for ((i = 0; i < flac_count; i++)); do
        f="${FLAC_FILES[i]}"
        title="${TITLES[$f]:-}"
        album="${ALBUMS[$f]:-}"
        if [ -z "$title" ]; then
            title=$(basename "$f")
            title="${title%.*}"
        fi
        [ -z "$album" ] && album="Unknown Album"

        file_title=$(sanitize_title "$title")
        dest_dir="$MUSIC_DIR/$(dirname "${f#"$SRC"/}")"

        candidate="$file_title"
        n=1
        key="${dest_dir,,}/${candidate,,}"
        while [ -n "${taken[$key]:-}" ]; do
            n=$((n + 1))
            candidate="$file_title $n"
            key="${dest_dir,,}/${candidate,,}"
        done
        taken[$key]=1

        TASKS+=("$f" "$dest_dir/$candidate.mp3" "$album")
    done

    # Phase 3: convert
    printf '%s\0' "${TASKS[@]}" | xargs -0 -n3 -P "$JOBS" bash -c 'do_convert "$@"' _ &
    worker_pid=$!
    progress_loop "$flac_count" "Converting" 15 65
    wait "$worker_pid" || true

    # Phase 4: strip covers from any pre-existing MP3s
    if $STRIP_COVERS; then
        mapfile -d '' MP3S < <(find "$MUSIC_DIR" -type f -iname "*.mp3" -print0)
        total=${#MP3S[@]}
        if [ "$total" -gt 0 ]; then
            printf '%s\0' "${MP3S[@]}" | xargs -0 -n1 -P "$JOBS" bash -c 'strip_covers "$1"' _ &
            worker_pid=$!
            progress_loop "$total" "Removing covers" 80 15
            wait "$worker_pid" || true
        fi
    fi

    # Phase 5: playlists
    echo "# Creating playlists..."
    echo "95"
    for dir in "$MUSIC_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        write_playlist "${dir%/}" "../Music/$name/" "$PLAYLISTS_DIR/${name}.m3u"
    done
    write_playlist "$MUSIC_DIR" "../Music/" "$PLAYLISTS_DIR/All_Tracks.m3u"

    echo "# Finished"
    echo "100"
} | zenity --progress --title="FLAC → MP3 Mirror" --percentage=0 --auto-close --width=450 || error_exit "Conversion cancelled."

exec 3>&-

zenity --info --text="All tasks completed!\n\nMusic mirror:   $MUSIC_DIR\nPlaylists:      $PLAYLISTS_DIR\n\nCopy both folders to your GoGear's root."
