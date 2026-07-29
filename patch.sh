#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_FILE="$1"
OUT_DIR="${2:-out}"

if [ -z "$ZIP_FILE" ]; then
    echo "Usage: $0 <Terralith_26.1_v2.6.2.zip> [output-dir]"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File not found: $ZIP_FILE"
    exit 1
fi

WORK_DIR=$(mktemp -d /tmp/datapack_patch_XXXXXX)
trap "rm -rf $WORK_DIR" EXIT

echo "Extracting $ZIP_FILE..."
unzip -q "$ZIP_FILE" -d "$WORK_DIR/datapack"

echo "Applying Folia compatibility patch (remove functions)..."
patch -Nt -p1 -d "$WORK_DIR/datapack" < "$SCRIPT_DIR/Terralith.patch" || true

# Remove any files that patch couldn't handle (e.g. files without trailing newlines)
find "$WORK_DIR/datapack" -name '*.rej' -delete 2>/dev/null || true
# Also remove leftover function directories that patch might have missed
find "$WORK_DIR/datapack" -name '*.mcfunction' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -path '*/tags/function/*' -name '*.json' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -type d -empty -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"
BASENAME=$(basename "$ZIP_FILE" .zip)
OUTPUT="$(cd "$OUT_DIR" && pwd)/${BASENAME}-folia.zip"

rm -f "$OUTPUT"
cd "$WORK_DIR/datapack"
zip -r -q "$OUTPUT" .

echo "Done! Output: $OUTPUT"
