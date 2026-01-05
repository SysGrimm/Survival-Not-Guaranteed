# Build System Documentation

**Version:** 2.0  
**Last Updated:** January 5, 2026  
**Script Location:** `build.sh`

## Overview

The build system is a sophisticated automation tool that generates Modrinth modpack (.mrpack) files with 100% external downloads (no embedded mods), automatic version detection, content change tracking, and seamless integration with the smart update system.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Version Management](#version-management)
3. [Content Hash System](#content-hash-system)
4. [Mod Scanning and Processing](#mod-scanning-and-processing)
5. [NeoForge Version Management](#neoforge-version-management)
6. [Manifest Generation](#manifest-generation)
7. [Integration with Update System](#integration-with-update-system)
8. [Configuration Options](#configuration-options)

---

## Architecture Overview

### Build System Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Configuration Loading                                    │
│  - Read MINECRAFT_VERSION, NEOFORGE_VERSION                 │
│  - Set MODS_DIR, output paths                               │
│  - Load environment variables                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Version Detection                                        │
│  - Check for OVERRIDE_VERSION (CI)                          │
│  - Query GitHub releases API                                │
│  - Query Modrinth API                                       │
│  - Find highest version as base                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Content Change Detection                                 │
│  - Check for mods/.updated marker (from update script)      │
│  - Generate content hash (mods + config + other)            │
│  - Compare with stored hash                                 │
│  - Determine change type (mod/config/infrastructure)        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Version Increment                                        │
│  - If changes detected OR marker present:                   │
│    - Increment version based on change type                 │
│    - Store new content hash                                 │
│  - Else: Use base version                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  5. NeoForge Version Detection                              │
│  - Check AUTO_DETECT_NEOFORGE setting                       │
│  - Query NeoForge API for latest version                    │
│  - Or use configured NEOFORGE_VERSION                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Mod Scanning and Processing                             │
│  - Scan MODS_DIR for .jar files                            │
│  - Calculate SHA-512 hash for each mod                      │
│  - Query Modrinth API with hash                             │
│  - Classify as client/server/universal                      │
│  - Generate modrinth.index.json entries                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Manifest Generation                                      │
│  - Create modrinth.index.json                               │
│  - Add game version, loader version                         │
│  - Include all mod file entries                             │
│  - Add dependency information                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Modpack Packaging                                        │
│  - Create temporary staging directory                       │
│  - Copy modrinth.index.json                                 │
│  - Copy config files                                        │
│  - Copy resourcepacks, shaderpacks (if present)             │
│  - Zip into .mrpack file                                    │
│  - Clean up temporary files                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  9. Output and Verification                                  │
│  - Display modpack filename                                 │
│  - Show file size                                           │
│  - List included components                                 │
│  - Provide installation instructions                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Version Management

### Version Detection Strategy

The build system uses a multi-source approach to determine the correct version:

**Priority Order:**
1. **CI Override** - `OVERRIDE_VERSION` environment variable (highest priority)
2. **GitHub Releases** - Latest tag from GitHub API
3. **Modrinth Releases** - Latest version from Modrinth API
4. **Default Fallback** - 3.5.15 (if no releases found)

### Version Sources

#### 1. CI Override

Used in automated CI/CD pipelines to force specific versions.

```bash
if [ -n "$OVERRIDE_VERSION" ]; then
  CURRENT_VERSION="$OVERRIDE_VERSION"
  return
fi
```

**Usage:**
```bash
OVERRIDE_VERSION="3.15.0" ./build.sh
```

#### 2. GitHub Releases API

```bash
GITHUB_REPO="Manifesto2147/Survival-Not-Guaranteed"

github_response=$(curl -s \
  "https://api.github.com/repos/$GITHUB_REPO/releases/latest")

LATEST_GITHUB_VERSION=$(echo "$github_response" | jq -r '.tag_name')
```

**Response Format:**
```json
{
  "tag_name": "v3.14.3",
  "name": "Release 3.14.3",
  "published_at": "2026-01-04T12:00:00Z"
}
```

#### 3. Modrinth API

```bash
MODRINTH_PROJECT="your-project-slug"

modrinth_versions=$(curl -s \
  "https://api.modrinth.com/v2/project/$MODRINTH_PROJECT/version")

LATEST_MODRINTH_VERSION=$(echo "$modrinth_versions" | jq -r '.[0].version_number')
```

**Response Format:**
```json
[
  {
    "version_number": "3.14.3",
    "date_published": "2026-01-04T12:00:00Z"
  }
]
```

### Version Comparison

**Semantic Version Comparison:**
```bash
is_version_higher() {
  local v1="$1"  # version to test
  local v2="$2"  # base version
  
  # Convert versions to comparable numbers
  # Format: x.y.z → xyz000 (padded)
  local v1_num=$(echo "$v1" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  local v2_num=$(echo "$v2" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  
  [ "$v1_num" -gt "$v2_num" ]
}
```

**Example:**
```
3.14.3 → 003014003
3.15.0 → 003015000
3.15.0 > 3.14.3 ✓
```

### Version Increment Logic

**Change Types:**
- `mod` - Mod updates, additions, or removals
- `config` - Configuration file changes
- `infrastructure` - Build script, docs, .gitignore changes
- `other` - servers.dat or miscellaneous files

**Increment Rules:**
```bash
increment_version() {
  local version="$1"
  local change_type="$2"
  
  IFS='.' read -r major minor patch <<< "$version"
  
  case "$change_type" in
    mod)
      # Increment minor version for mod changes
      minor=$((minor + 1))
      patch=0
      ;;
    config|infrastructure|other)
      # Increment patch for config/infrastructure changes
      patch=$((patch + 1))
      ;;
  esac
  
  echo "$major.$minor.$patch"
}
```

**Examples:**
```
Base: 3.14.3
Mod change:            3.14.3 → 3.14.4
Config change:         3.14.3 → 3.14.4 (if first change)
Infrastructure change: 3.14.3 → 3.14.4 (if first change)
```

---

## Content Hash System

### Purpose

The content hash system detects changes between builds to determine if a version bump is needed.

### Hash Components

**Three-Part Hash:**
1. **MOD Hash** - All .jar files in mods/
2. **CONFIG Hash** - All files in config/
3. **OTHER Hash** - servers.dat and other tracked files

### Hash Generation

```bash
generate_content_hash() {
  # Mod files hash
  local mod_hash=$(find mods/ -name "*.jar" -type f 2>/dev/null | \
    sort | xargs sha256sum 2>/dev/null | sha256sum | awk '{print $1}')
  
  # Config files hash
  local config_hash=$(find config/ -type f 2>/dev/null | \
    sort | xargs sha256sum 2>/dev/null | sha256sum | awk '{print $1}')
  
  # Other files hash (servers.dat, etc.)
  local other_hash=$(find . -maxdepth 1 -name "servers.dat" 2>/dev/null | \
    xargs sha256sum 2>/dev/null | sha256sum | awk '{print $1}')
  
  echo "MOD:$mod_hash|CONFIG:$config_hash|OTHER:$other_hash"
}
```

**Example Output:**
```
MOD:a1b2c3d4e5f6|CONFIG:1a2b3c4d5e6f|OTHER:9z8y7x6w5v4u
```

### Hash Storage

**Location:** `.content_hash` (in project root)

**Format:** Plain text file containing the hash string

```bash
# Save hash
echo "$current_hash" > .content_hash

# Load hash
stored_hash=$(cat .content_hash)
```

### Change Detection

```bash
# Generate current hash
current_hash=$(generate_content_hash)

# Compare with stored hash
if [ "$current_hash" != "$stored_hash" ]; then
  # Changes detected
  
  # Parse components
  current_mod_hash=$(echo "$current_hash" | sed 's/.*MOD:\([^|]*\).*/\1/')
  stored_mod_hash=$(echo "$stored_hash" | sed 's/.*MOD:\([^|]*\).*/\1/')
  
  # Determine what changed
  if [ "$current_mod_hash" != "$stored_mod_hash" ]; then
    change_type="mod"
  fi
fi
```

---

## Integration with Update System

### Update Marker Mechanism

**Purpose:** Signal to build script that mods were updated by the smart update system.

**How It Works:**

1. **Update Script Creates Marker:**
```bash
# In smart-dependency-update.sh Phase 7
if [[ $DOWNLOAD_SUCCESS -gt 0 ]]; then
  touch "$MODS_DIR/.updated"
  log_info "Created update marker for build script"
fi
```

2. **Build Script Detects Marker:**
```bash
# In build.sh version detection
local force_version_bump=false
if [ -f "$MODS_DIR/.updated" ]; then
  echo "- Update marker detected: mods were updated"
  force_version_bump=true
  rm -f "$MODS_DIR/.updated"  # Clear the marker
fi
```

3. **Force Version Bump:**
```bash
# Include marker in change detection
if [ "$current_hash" != "$stored_hash" ] || [ "$force_version_bump" = true ]; then
  # Content changed or marker present
  change_type="mod"
  CURRENT_VERSION=$(increment_version "$base_version" "mod")
fi
```

### Why This Is Necessary

**Problem:** Content hash might not change immediately after mod updates because:
- Hash calculation happens before mod processing
- File timestamps don't affect SHA-256 hashes
- Build script needs explicit signal for version bump

**Solution:** Marker file provides explicit signal that mods changed, ensuring version always increments after updates.

### Workflow Example

```
1. Run update script:
   DRY_RUN=false ./tools/smart-dependency-update.sh
   → Downloads 5 mods
   → Creates mods/.updated

2. Run build script:
   ./build.sh
   → Detects mods/.updated marker
   → Forces version bump: 3.14.3 → 3.14.4
   → Removes marker
   → Builds: Survival Not Guaranteed-3.14.4.mrpack

3. Future builds without updates:
   ./build.sh
   → No marker present
   → No hash changes
   → Uses version 3.14.4 (no increment)
```

---

## Mod Scanning and Processing

### Scanning Process

**Discovery:**
```bash
MODS_DIR="mods"
mod_files=$(find "$MODS_DIR" -name "*.jar" -type f 2>/dev/null | sort)
mod_count=$(echo "$mod_files" | wc -l)

echo "Scanning mods in: $MODS_DIR ($mod_count mod files found)"
```

### Hash-Based Identification

**Why SHA-512?**
- Modrinth API supports SHA-512 lookups
- More secure than SHA-256
- Provides unique identification

**Implementation:**
```bash
# Calculate hash
file_hash=$(sha512sum "$mod_file" | awk '{print $1}')

# Query Modrinth API
version_info=$(curl -s --max-time 10 \
  "https://api.modrinth.com/v2/version_file/$file_hash?algorithm=sha512")

# Extract metadata
project_id=$(echo "$version_info" | jq -r '.project_id')
version_number=$(echo "$version_info" | jq -r '.version_number')
mod_name=$(echo "$version_info" | jq -r '.name')
```

### Side Detection

**Purpose:** Classify mods as client-only, server-only, or universal.

**Detection Logic:**
```bash
# Get project info
project_info=$(curl -s "https://api.modrinth.com/v2/project/$project_id")

# Extract side information
client_side=$(echo "$project_info" | jq -r '.client_side')
server_side=$(echo "$project_info" | jq -r '.server_side')

# Classify
if [[ "$client_side" == "required" && "$server_side" == "unsupported" ]]; then
  side="client"
  echo "  → Client-only mod detected"
elif [[ "$server_side" == "required" && "$client_side" == "unsupported" ]]; then
  side="server"
  echo "  → Server-only mod detected"
else
  side="both"
  echo "  → Universal mod (client + server)"
fi
```

**Side Values:**
- `client` - Client-only (e.g., OptiFine, JEI)
- `server` - Server-only (e.g., server management tools)
- `both` - Universal (most mods)

### CDN URL Generation

**Modrinth CDN Format:**
```
https://cdn.modrinth.com/data/{project_id}/versions/{version_id}/{filename}
```

**Generation:**
```bash
version_id=$(echo "$version_info" | jq -r '.id')
filename=$(echo "$version_info" | jq -r '.files[0].filename')

cdn_url="https://cdn.modrinth.com/data/$project_id/versions/$version_id/$filename"
```

**Example:**
```
Project: create
Version ID: abc123xyz
Filename: create-1.21-0.5.1.jar
URL: https://cdn.modrinth.com/data/create/versions/abc123xyz/create-1.21-0.5.1.jar
```

---

## NeoForge Version Management

### Configuration

**Location:** Line 33 in build.sh

```bash
NEOFORGE_VERSION="21.1.215"
```

### Auto-Detection vs Manual

**Auto-Detection:**
```bash
AUTO_DETECT_NEOFORGE=false  # Currently disabled
```

**Why Disabled?**
- Smart update system handles this automatically
- Scans all mods for NeoForge requirements
- Updates build.sh when needed
- No need for duplicate detection

**Manual Update Flow:**
```
1. Smart update script scans all mods
2. Finds highest NeoForge requirement (e.g., 21.1.215)
3. Updates build.sh: NEOFORGE_VERSION="21.1.215"
4. Build script uses updated version
```

### Version Format

**NeoForge Versioning:**
```
Format: MAJOR.MINOR.PATCH
Example: 21.1.215

MAJOR: Minecraft major version (21 = 1.21.x)
MINOR: Minecraft minor version (1 = 1.21.1)
PATCH: NeoForge build number (215 = build 215)
```

### Dependency Declaration

**In modrinth.index.json:**
```json
{
  "dependencies": {
    "minecraft": "1.21.1",
    "neoforge": "21.1.215"
  }
}
```

---

## Manifest Generation

### modrinth.index.json Structure

**Complete Format:**
```json
{
  "formatVersion": 1,
  "game": "minecraft",
  "versionId": "3.14.4",
  "name": "Survival Not Guaranteed",
  "summary": "A comprehensive survival modpack...",
  "files": [
    {
      "path": "mods/create-1.21-0.5.1.jar",
      "hashes": {
        "sha512": "abc123...",
        "sha1": "def456..."
      },
      "env": {
        "client": "required",
        "server": "required"
      },
      "downloads": [
        "https://cdn.modrinth.com/data/create/versions/xyz789/create-1.21-0.5.1.jar"
      ],
      "fileSize": 15234567
    }
  ],
  "dependencies": {
    "minecraft": "1.21.1",
    "neoforge": "21.1.215"
  }
}
```

### File Entry Generation

**For Each Mod:**
```bash
# Create file entry
cat >> modrinth.index.json <<EOF
    {
      "path": "mods/$filename",
      "hashes": {
        "sha512": "$file_hash",
        "sha1": "$sha1_hash"
      },
      "env": {
        "client": "$([ "$side" = "client" ] && echo "required" || echo "optional")",
        "server": "$([ "$side" = "server" ] && echo "required" || echo "optional")"
      },
      "downloads": [
        "$cdn_url"
      ],
      "fileSize": $file_size
    }
EOF
```

### Environment Fields

**Client/Server Requirements:**
```json
"env": {
  "client": "required",    // required | optional | unsupported
  "server": "required"     // required | optional | unsupported
}
```

**Combinations:**
- `client: required, server: required` - Universal mod
- `client: required, server: unsupported` - Client-only
- `client: unsupported, server: required` - Server-only
- `client: optional, server: optional` - Works anywhere

---

## Configuration Options

### Environment Variables

**OVERRIDE_VERSION:**
```bash
OVERRIDE_VERSION="3.15.0" ./build.sh
```
Forces specific version (used in CI/CD).

**GITHUB_TOKEN:**
```bash
GITHUB_TOKEN="ghp_abc123..." ./build.sh
```
Increases GitHub API rate limit from 60 to 5000 requests/hour.

**DRY_RUN:**
```bash
DRY_RUN=true ./build.sh
```
Preview build without creating files (if supported).

### Script Configuration

**Key Settings:**
```bash
# Lines 28-35
MINECRAFT_VERSION="1.21.1"
MODS_DIR="mods"
GITHUB_REPO="Manifesto2147/Survival-Not-Guaranteed"
MODRINTH_PROJECT="your-project-slug"
NEOFORGE_VERSION="21.1.215"
AUTO_DETECT_NEOFORGE=false
```

### Output Configuration

**Filename Format:**
```bash
output_file="Survival Not Guaranteed-${CURRENT_VERSION}.mrpack"
```

**Example:** `Survival Not Guaranteed-3.14.4.mrpack`

---

## Build Output

### Successful Build

```
═══════════════════════════════════════════════════════════
 Minecraft Modpack Builder (Modrinth Format)
═══════════════════════════════════════════════════════════

- Detecting version...
- Checking GitHub releases...
- Found Modrinth version: 3.14.3
+ Using highest version as base: 3.14.3
- Update marker detected: mods were updated
- Content changes detected, analyzing change type...
- Mod changes detected
+ New version: 3.14.4

- Using configured NeoForge version: 21.1.215

- Generating manifest from mod scan...
Scanning mods in: mods (142 mod files found)

[Processing 142 mods...]

+ Modrinth index generated with 142 mods

- Packaging modpack...
+ Creating clean staging directory
+ Copying modrinth.index.json
+ Copying config directory
+ Creating mrpack archive

═══════════════════════════════════════════════════════════
Modpack built successfully!
═══════════════════════════════════════════════════════════
Output: Survival Not Guaranteed-3.14.4.mrpack
Size: 45 MB
Version: 3.14.4
Mods: 142
NeoForge: 21.1.215
═══════════════════════════════════════════════════════════
```

### Error Handling

**Common Errors:**

1. **No mods found:**
```
[ERROR] No mod files found in mods/
```

2. **API timeout:**
```
[WARN] Failed to identify: some-mod.jar (API timeout)
```

3. **Invalid hash:**
```
[WARN] Mod not found on Modrinth: unknown-mod.jar
```

---

## Testing and Validation

### Pre-Build Checks

```bash
# Verify mods directory
ls -la mods/*.jar | wc -l

# Verify config directory
ls -la config/ | head

# Check for markers
ls -la mods/.updated
```

### Post-Build Validation

```bash
# Check output file
ls -lh "Survival Not Guaranteed-*.mrpack"

# Verify contents
unzip -l "Survival Not Guaranteed-3.14.4.mrpack"

# Test manifest
unzip -p "Survival Not Guaranteed-3.14.4.mrpack" modrinth.index.json | jq .
```

### Integration Testing

**Full Workflow Test:**
```bash
# 1. Update mods
DRY_RUN=false ./tools/smart-dependency-update.sh

# 2. Build modpack
./build.sh

# 3. Verify version increment
ls -l *.mrpack | tail -1

# 4. Test in Minecraft
# (install via PrismLauncher or Modrinth App)
```

---

## Maintenance

### Regular Tasks

**Weekly:**
- Check for build script updates
- Verify API endpoints still work
- Test full build workflow

**Monthly:**
- Review and clean old .mrpack files
- Update documentation
- Check for deprecated API usage

### Troubleshooting

**Build fails with "No version detected":**
```bash
# Manual version override
OVERRIDE_VERSION="3.14.4" ./build.sh
```

**Marker not detected:**
```bash
# Manually create marker
touch mods/.updated
./build.sh
```

**Hash mismatch:**
```bash
# Reset content hash
rm .content_hash
./build.sh
```

---

## Performance

**Build Times (142 mods):**
- Version detection: ~5 seconds
- Mod scanning: ~60 seconds (API queries)
- Manifest generation: ~2 seconds
- Packaging: ~5 seconds
- **Total: ~72 seconds**

**Optimization:**
- Parallel hash calculation (not yet implemented)
- API response caching
- Incremental manifest updates

---

## Future Enhancements

1. **Parallel Mod Processing**
   - Use GNU parallel for faster scanning
   - Target: 50% faster builds

2. **Manifest Caching**
   - Cache mod metadata between builds
   - Only rescan changed mods

3. **Incremental Builds**
   - Only rebuild if content changed
   - Skip packaging if hash matches

4. **Multi-Format Support**
   - CurseForge format export
   - MultiMC format export

---

## Credits

**Integration:** AI-assisted development  
**APIs Used:** Modrinth API v2, GitHub API, NeoForge API  
**Environment:** Bazzite Linux, bash 5.3+
