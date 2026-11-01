#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_FILE="$1"
OUT_DIR="${2:-out}"

if [ -z "$ZIP_FILE" ]; then
    echo "Usage: $0 <datapack.zip> [output-dir]"
    exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File not found: $ZIP_FILE"
    exit 1
fi

# Extract version from filename (handle formats like Terralith_26.1_v2.6.2.zip)
VERSION=$(basename "$ZIP_FILE" | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
DATAPACK_NAME="Terralith"

WORK_DIR=$(mktemp -d /tmp/datapack_patch_XXXXXX)
trap "rm -rf $WORK_DIR" EXIT

echo "Extracting $ZIP_FILE..."
unzip -q "$ZIP_FILE" -d "$WORK_DIR/datapack"

echo "Normalizing line endings..."
find "$WORK_DIR/datapack" \( -name '*.mcfunction' -o -name '*.json' \) -exec sed -i 's/\r$//' {} \;

# Find patch file
PATCH_FILE="$SCRIPT_DIR/Terralith_v${VERSION}_folia_Fix.patch"
if [ -f "$PATCH_FILE" ]; then
    echo "Applying patch: $(basename "$PATCH_FILE")..."
    patch -Nt -p0 -d "$WORK_DIR/datapack" < "$PATCH_FILE" || true
fi

# Add manual fixes here if needed
echo "Applying manual fixes..."
# Remove leftover function directories that patch might have missed
find "$WORK_DIR/datapack" -name '*.mcfunction' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -path '*/tags/function/*' -name '*.json' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -type d -empty -delete 2>/dev/null || true

# Cleanup
find "$WORK_DIR/datapack" -name '*.rej' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -name '*.orig' -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"
OUTPUT="$(cd "$OUT_DIR" && pwd)/Terralith_v${VERSION}_folia.zip"

rm -f "$OUTPUT"
cd "$WORK_DIR/datapack"
zip -r -q "$OUTPUT" .

echo "Done! Output: $OUTPUT"
