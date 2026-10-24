#!/usr/bin/env bash
# Builds the Windows release zip: StereopsisVR.exe + assets/ + musica/ + launcher + docs.
# Usage: GODOT=/path/to/godot tools/package.sh   (needs Godot 4.7.2 export templates installed)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/export/windows"
NAME="StereopsisVR-windows"
rm -rf "$OUT" && mkdir -p "$OUT"
touch "$ROOT/export/.gdignore"   # keep Godot from importing the copies made here
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$OUT/StereopsisVR.exe"
cp -r assets musica "$OUT/"
cp "dist/Start Stereopsis VR.cmd" "$OUT/"
sed 's/$/\r/' LICENSE > "$OUT/LICENSE.txt"
sed 's/$/\r/' dist/README.txt > "$OUT/README.txt"
rm -f "$OUT"/*.console.exe 2>/dev/null || true
find "$OUT" -name "*.import" -delete
cd "$ROOT/export"
rm -rf "$NAME" "$NAME.zip"
mv windows "$NAME"
zip -qr "$NAME.zip" "$NAME"
mv "$NAME" windows
ls -la "$ROOT/export/$NAME.zip"
