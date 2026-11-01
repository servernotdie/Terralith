# AI Agent Instructions - Minecraft Datapack Folia Patcher

## Purpose
Automatically create patches to fix incompatibility issues between Minecraft datapacks and Folia servers.

## Directory Structure

```
work/
├── base/                              # Original datapacks (.zip)
├── out/                               # Patched datapacks (.zip)
├── <name>_v<version>_folia_Fix.patch # Patch file
├── patch_v<version>.sh               # Patch application script
└── AGENTS.md                          # This file
```

**Note:** This structure applies to any datapack patching project. Adapt paths accordingly.

---

## Workflow

### Step 1: Analyze Current State

Check existing files in the directory:
```bash
ls -1 base/*.zip
ls -1 out/*.zip
ls -1 *.patch
ls -1 patch*.sh
```

### Step 2: Determine Action

#### Case 1: All files exist for same version
**Conditions:**
- `base/<name> v<X.X.X>.zip` exists
- `out/<name>_v<X.X.X>_folia.zip` exists
- `<name>_v<X.X.X>_folia_Fix.patch` exists
- `patch_v<X.X.X>.sh` exists

**Action:**
- ✅ Ask user what they want to do:
  - Re-test the patch?
  - Create patch for different version?
  - Modify existing patch?

#### Case 2: New version in base/
**Conditions:**
- `base/<name> v<Y.Y.Y>.zip` exists (new version)
- BUT no `<name>_v<Y.Y.Y>_folia_Fix.patch`

**Action:**
- ⚙️ Automatically create new patch for version Y.Y.Y
- Follow process below

#### Case 3: Old files with wrong format
**Conditions:**
- Has `<name>.patch` (no version)
- Has `patch.sh` (no version)

**Action:**
- 🔄 Rename and refactor:
  - `<name>.patch` → `<name>_v<X.X.X>_folia_Fix.patch`
  - `patch.sh` → `patch_v<X.X.X>.sh`
  - Update script code to match standard format

---

## Process for Creating New Patch

### Step 1: Extract and Analyze Errors

```bash
# Extract datapack
WORK_DIR=$(mktemp -d /tmp/datapack_analyze_XXXXXX)
unzip -q "base/<name> v<X.X.X>.zip" -d "$WORK_DIR"
cd "$WORK_DIR"

# Find common Folia incompatibilities
echo "=== Finding data modify ==="
grep -r "data modify" data/*/function/ 2>/dev/null || echo "None found"

echo "=== Finding data remove ==="
grep -r "data remove" data/*/function/ 2>/dev/null || echo "None found"

echo "=== Finding run return ==="
grep -r "run return" data/*/function/ 2>/dev/null || echo "None found"

echo "=== Finding attribute get without base ==="
grep -rE "attribute.*get[^_]" data/*/function/ 2>/dev/null || echo "None found"
```

### Step 2: Create Patch File

**Standard format:**
```
<datapack_name>_v<version>_folia_Fix.patch
```

**Examples:**
- `Dungeons_and_Taverns_v6.1.0_folia_Fix.patch`
- `Incendium_v5.4.12_folia_Fix.patch`
- `Terralith_v2.6.2_folia_Fix.patch`

**Patch content:**
```patch
diff --git data/namespace/function/file.mcfunction data/namespace/function/file.mcfunction
--- data/namespace/function/file.mcfunction
+++ data/namespace/function/file.mcfunction
@@ -1,3 +1,2 @@
 command 1
-data modify entity @s active_effects append value {...}
+effect give @s minecraft:regeneration 1 6 true
```

### Step 3: Create Patch Script

**Standard format:**
```bash
patch_v<version>.sh
```

**Template:**
```bash
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

# Extract version from filename
VERSION=$(basename "$ZIP_FILE" | grep -oP 'v?\K[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "unknown")
DATAPACK_NAME=$(basename "$ZIP_FILE" .zip | sed -E 's/ v?[0-9]+\.[0-9]+(\.[0-9]+)?//')

WORK_DIR=$(mktemp -d /tmp/datapack_patch_XXXXXX)
trap "rm -rf $WORK_DIR" EXIT

echo "Extracting $ZIP_FILE..."
unzip -q "$ZIP_FILE" -d "$WORK_DIR/datapack"

echo "Normalizing line endings..."
find "$WORK_DIR/datapack" \( -name '*.mcfunction' -o -name '*.json' \) -exec sed -i 's/\r$//' {} \;

# Find patch file
PATCH_FILE="$SCRIPT_DIR/${DATAPACK_NAME}_v${VERSION}_folia_Fix.patch"
if [ -f "$PATCH_FILE" ]; then
    echo "Applying patch: $(basename "$PATCH_FILE")..."
    patch -Nt -p0 -d "$WORK_DIR/datapack" < "$PATCH_FILE" || true
fi

# Add manual fixes here if needed
echo "Applying manual fixes..."
# Example:
# FILE="$WORK_DIR/datapack/data/namespace/function/file.mcfunction"
# if [ -f "$FILE" ]; then
#     echo "Fixing specific file..."
#     cat > "$FILE" << 'EOF'
# command 1
# command 2
# EOF
# fi

# Cleanup
find "$WORK_DIR/datapack" -name '*.rej' -delete 2>/dev/null || true
find "$WORK_DIR/datapack" -name '*.orig' -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"
OUTPUT="$(cd "$OUT_DIR" && pwd)/${DATAPACK_NAME}_v${VERSION}_folia.zip"

rm -f "$OUTPUT"
cd "$WORK_DIR/datapack"
zip -r -q "$OUTPUT" .

echo "Done! Output: $OUTPUT"
```

### Step 4: Test Patch

**IMPORTANT:** Always test the patch before considering it complete!

```bash
# Run script
chmod +x patch_v<version>.sh
./patch_v<version>.sh "base/<name> v<version>.zip"

# Check if output was created
ls -lh out/<name>_v<version>_folia.zip

# Extract and verify changes
VERIFY_DIR=$(mktemp -d /tmp/verify_XXXXXX)
unzip -q "out/<name>_v<version>_folia.zip" -d "$VERIFY_DIR"
cd "$VERIFY_DIR"

# Check specific fixed files
echo "=== Checking patched files ==="
cat data/*/function/<fixed_file>.mcfunction

# Verify no remaining issues
echo "=== Checking for remaining data modify ==="
grep -r "data modify" data/*/function/ 2>/dev/null || echo "✓ None found"

echo "=== Checking for remaining data remove ==="
grep -r "data remove" data/*/function/ 2>/dev/null || echo "✓ None found"
```

### Step 5: Check for Problematic Enchantments/Functions

After patching, verify no problematic enchantments or functions remain:

```bash
cd "$VERIFY_DIR"

# Check enchantments directory
if [ -d "data/*/enchantment" ]; then
    echo "=== Checking enchantments ==="
    find data/*/enchantment -name "*.json" -exec grep -l '"weight": 0' {} \; 2>/dev/null || echo "✓ No weight:0 enchantments"
    
    # List all enchantments for review
    find data/*/enchantment -name "*.json" | while read f; do
        echo "$(basename "$f"): $(grep -o '"weight": [0-9]*' "$f" 2>/dev/null || echo 'no weight')"
    done
fi

# Check for remaining incompatible functions
echo "=== Checking for incompatible function commands ==="
grep -r "data modify.*active_effects\|data modify.*Motion\|data modify.*Owner\|data remove" data/*/function/ 2>/dev/null && echo "⚠ Found issues - update patch!" || echo "✓ All clear"
```

**If issues found:** Update the patch to delete problematic enchantments or fix remaining function issues.

---

## Common Folia Errors and Fixes

### 1. `data modify` entity data
**Error:**
```mcfunction
data modify entity @s active_effects append value {id:"minecraft:regeneration",...}
```

**Fix:**
```mcfunction
effect give @s minecraft:regeneration 1 6 true
```

### 2. `data modify` motion/owner
**Error:**
```mcfunction
data modify entity @n[...] Motion set from entity @s Motion
data modify entity @n[...] Owner set from entity @s Owner
```

**Fix:** Remove entirely (or replace with alternative approach)

### 3. `data remove`
**Error:**
```mcfunction
data remove entity @s Owner
```

**Fix:** Delete file or comment out

### 4. `run return` without value
**Error:**
```mcfunction
execute ... run locate structure ... run return 1
```

**Fix:**
```mcfunction
execute ... run locate structure ...
```

### 5. `attribute get` missing `base`
**Error:**
```mcfunction
attribute @s minecraft:max_health get
```

**Fix:**
```mcfunction
attribute @s minecraft:max_health base get
```

### 6. `data modify` Health
**Error:**
```mcfunction
data modify entity @s Health set value 50.0f
```

**Fix:**
```mcfunction
attribute @s minecraft:max_health base set 50
```

### 7. Invalid enchantment weight
**Error:**
```json
{
  "weight": 0,
  "supported_items": "minecraft:air"
}
```

**Fix:** Delete the entire enchantment file (weight:0 crashes registry loading)

---

## Checklist Before Completion

- [ ] Patch file named correctly: `<name>_v<version>_folia_Fix.patch`
- [ ] Script named correctly: `patch_v<version>.sh`
- [ ] Script has execute permission: `chmod +x patch_v<version>.sh`
- [ ] **Script tested and runs successfully**
- [ ] Output file created in `out/`
- [ ] **Verified patched files are correct**
- [ ] **No remaining `data modify/remove` issues**
- [ ] **No `weight: 0` enchantments**
- [ ] **No incompatible function commands**

---

## AI Agent Tips

### Always analyze before acting:
- List all existing files
- Identify versions present
- Check file format compliance

### When creating new patch:
- Extract and grep for errors first
- Create patch incrementally, test each step
- Use manual fixes in script for complex cases
- **Always test the final script**
- **Verify no issues remain after patching**

### When refactoring old files:
- Backup old files first
- Rename to standard format
- Re-test after refactoring

### Always ask user when:
- Uncertain which version needs patching
- Multiple fix approaches possible
- Patch becomes too complex

### Automate when:
- File format is standardized
- Clear template exists
- Errors match previous versions

---

## Example Session

### User adds new datapack

**Input:**
```
base/Incendium v5.5.0.zip
```

**AI Agent response:**
```
Found new version: Incendium v5.5.0

Currently have:
- base/Incendium v5.4.12.zip ✓
- Incendium_v5.4.12_folia_Fix.patch ✓
- patch_v5.4.12.sh ✓

Options:
1. Create new patch for v5.5.0 (based on v5.4.12)?
2. Extract and analyze errors first?
3. Copy v5.4.12 patch and try applying?
```

---

## Error Handling

### Patch fails
1. Check line endings (CRLF vs LF)
2. Review .rej files for failure reasons
3. Add manual fixes to script
4. Re-test

### Script fails
1. Check file paths
2. Check execute permissions
3. Check bash syntax
4. Test manually step by step

### Output is incorrect
1. Extract and verify each file
2. Compare with original
3. Check for missing files
4. Test in-game or on server

---

## Important Notes

- Each datapack has different structure
- Each version may need different fixes
- Always test thoroughly before delivering
- This AGENTS.md works for any similar datapack patching project
- Keep format consistent across versions
- **Never skip the testing and verification steps**
