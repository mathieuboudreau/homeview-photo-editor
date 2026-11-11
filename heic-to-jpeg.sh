#!/bin/bash
# heic-to-jpeg.sh: make a Chrome-friendly copy of a photo folder for Square Frame.
#
#   ./heic-to-jpeg.sh "/path/to/Photos" "/path/to/Photos (JPEG)"
#
# - HEIC/HEIF files are converted to high-quality JPEG with macOS's built-in
#   `sips`, which keeps the date taken, camera info, location and the
#   Display P3 color profile.
# - Other photos (JPEG, PNG, ...) are copied with `cp -c`, which on APFS makes
#   an instant clone that takes no extra disk space.
# - Videos, Live Photo .MOV files, .AAE sidecars and hidden files are skipped.
# - The folder structure is kept. Re-running only processes new files.
#
# It never writes to, moves, or deletes anything in the source folder.

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 SOURCE_FOLDER DESTINATION_FOLDER" >&2
  exit 1
fi

SRC="$(cd "$1" && pwd -P)"
mkdir -p "$2"
DST="$(cd "$2" && pwd -P)"

case "$DST/" in
  "$SRC"/*) echo "The destination can't be inside the source folder." >&2; exit 1 ;;
esac
if [ "$SRC" = "$DST" ]; then echo "Source and destination must differ." >&2; exit 1; fi

converted=0; copied=0; skipped=0; failed=0

while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"
  dir="$(dirname "$rel")"
  base="$(basename "$rel")"
  name="${base%.*}"
  ext="$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    heic|heif)
      mkdir -p "$DST/$dir"
      out="$DST/$dir/$name.jpg"
      # Don't clobber a real JPEG with the same name that's also in the folder.
      if [ -e "$SRC/$dir/$name.jpg" ] || [ -e "$SRC/$dir/$name.JPG" ]; then out="$DST/$dir/$name (heic).jpg"; fi
      # Already converted (and the HEIC hasn't changed since)? Skip it.
      if [ -e "$out" ] && [ ! "$f" -nt "$out" ]; then skipped=$((skipped+1)); continue; fi
      if sips -s format jpeg -s formatOptions 92 "$f" --out "$out" >/dev/null 2>&1; then
        touch -r "$f" "$out"   # keep the original file date too
        converted=$((converted+1))
      else
        echo "  could not convert: $rel" >&2; failed=$((failed+1))
      fi
      ;;
    jpg|jpeg|png|webp|gif|bmp|avif)
      mkdir -p "$DST/$dir"
      out="$DST/$rel"
      if [ -e "$out" ]; then skipped=$((skipped+1)); continue; fi
      cp -c -p "$f" "$out" 2>/dev/null || cp -p "$f" "$out"
      copied=$((copied+1))
      ;;
    *) continue ;;
  esac
  total=$((converted+copied+skipped+failed))
  if [ $((total % 50)) -eq 0 ]; then echo "  … $total photos ($converted converted)"; fi
done < <(find "$SRC" -type f ! -name '.*' ! -path '*/.*' -print0)

echo "Done: $converted HEIC converted, $copied copied, $skipped already there, $failed failed."
echo "Open this folder in Square Frame: $DST"
