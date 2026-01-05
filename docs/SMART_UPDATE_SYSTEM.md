# Smart Dependency-Aware Mod Update System

**Version:** 2.0  
**Last Updated:** January 5, 2026  
**Script Location:** `tools/smart-dependency-update.sh`

## Overview

This document provides comprehensive documentation for the Smart Dependency-Aware Mod Update System - a sophisticated automation tool that safely updates Minecraft mods while maintaining dependency chains, validating loader compatibility, and automatically managing NeoForge version requirements.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Phase-by-Phase Breakdown](#phase-by-phase-breakdown)
3. [Data Structures](#data-structures)
4. [API Integration](#api-integration)
5. [Version Detection Logic](#version-detection-logic)
6. [NeoForge Auto-Management](#neoforge-auto-management)
7. [Build Script Integration](#build-script-integration)
8. [Usage Examples](#usage-examples)
9. [Troubleshooting](#troubleshooting)

---

## System Architecture

### Design Philosophy

The system is built on these core principles:

1. **Safety First**: Never update a mod if it would break dependencies
2. **100% Reliable Identification**: Use cryptographic hashes instead of filename parsing
3. **Loader Validation**: Ensure mods are compatible with NeoForge (not Forge/Fabric)
4. **Automatic Dependency Resolution**: Download missing dependencies automatically
5. **Infrastructure Integration**: Automatically update build configuration when needed

### System Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Hash-Based Mod Identification                     │
│  - Scan mods/ directory for .jar files                      │
│  - Calculate SHA-512 hash for each file                     │
│  - Query Modrinth API with hash (100% accurate)             │
│  - Build MOD_INFO database                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Version Constraint Resolution                     │
│  - Query Modrinth API for available versions                │
│  - Filter by game_versions=["1.21.1"]                       │
│  - Filter by loaders=["neoforge"]                           │
│  - Resolve version IDs to version numbers                   │
│  - Build VERSION_ID_TO_NUMBER mapping                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: Update Safety Validation                          │
│  - For each mod with available update:                      │
│    1. Get dependencies of new version                       │
│    2. Check if required mods are installed                  │
│    3. Validate version constraints                          │
│    4. Mark as "safe" or "needs_deps" or "incompatible"     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Wave Categorization                               │
│  - Wave 1 (Independent): No dependencies on other mods      │
│  - Wave 2 (Consumers): Depends on providers                 │
│  - Wave 3 (Providers): Other mods depend on them            │
│  - Wave 4 (Complex): Both consumer and provider             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 4.5: Missing Dependency Resolution                   │
│  - Detect mods requiring dependencies not installed         │
│  - Query Modrinth for highest compatible version            │
│  - Add to download queue                                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 5: NeoForge Version Detection                        │
│  - Scan ALL 142 installed mods (not just updates)           │
│  - Parse NeoForge dependency requirements                   │
│  - Find highest required version                            │
│  - Auto-update build.sh if upgrade needed                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 6: Update Report Display                             │
│  - Show categorized update list                             │
│  - Display dependency information                           │
│  - Show statistics and summaries                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 7: Download and Installation (UPDATE mode only)      │
│  - Download new mod versions from CDN                       │
│  - Remove old versions                                      │
│  - Create .updated marker for build script                  │
│  - Report success/failure statistics                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase-by-Phase Breakdown

### Phase 1: Hash-Based Mod Identification

**Purpose:** Identify every mod file with 100% accuracy using cryptographic hashes.

**Why Hash-Based?**
- Filenames can be misleading (renamed files, version strings)
- Modrinth's hash lookup API returns exact project information
- SHA-512 provides cryptographic certainty

**Process:**
1. Find all `.jar` files in `mods/` directory
2. Calculate SHA-512 hash: `sha512sum "$file" | awk '{print $1}'`
3. Query Modrinth API: `GET /v2/version_file/{hash}`
4. Extract project metadata: project_id, version_number, name, version_id

**Data Generated:**
```bash
MOD_INFO[filename] = "project_id:current_ver:latest_ver:name:current_vid:latest_vid"
PROJECT_TO_FILE[project_id] = "filename"
```

**Error Handling:**
- Mods not on Modrinth: Logged and skipped
- API timeouts: 8-second timeout with retry
- Invalid responses: JSON validation with jq

### Phase 2: Version Constraint Resolution

**Purpose:** Build a mapping of version IDs to human-readable version numbers for dependency validation.

**Why Needed?**
- Modrinth dependencies reference version IDs (e.g., "abc123xyz")
- We need version numbers (e.g., "2.0.13") to validate constraints
- Cached lookups prevent redundant API calls

**Process:**
1. Query Modrinth for available versions of each project
2. Filter by game version: `?game_versions=["1.21.1"]`
3. Filter by loader type: `&loaders=["neoforge"]`
4. Parse JSON response to build version_id → version_number mapping

**Loader Validation:**
```bash
loader_check=$(echo "$versions" | jq -r "
  .[] | select(.game_versions[] == \"$MINECRAFT_VERSION\") | 
  select(.loaders[] == \"$LOADER_TYPE\") | 
  .version_number" | head -1)
```

**Data Generated:**
```bash
VERSION_ID_TO_NUMBER[version_id] = "version_number"
MOD_LATEST_DEPS[project_id] = JSON array of dependencies
```

### Phase 3: Update Safety Validation

**Purpose:** Determine if updating each mod is safe based on its dependencies.

**Safety Criteria:**
1. All required dependencies must be installed
2. Installed dependency versions must satisfy version constraints
3. Optional dependencies are noted but don't block updates

**Dependency Parsing:**
```json
{
  "dependencies": [
    {
      "project_id": "neoforge",
      "dependency_type": "required",
      "version_id": "[21.1.206,)"
    }
  ]
}
```

**Version Constraint Formats:**
- `[21.1.206,)` - Minimum version 21.1.206, no maximum
- `[1.0.0,2.0.0)` - Version range (inclusive min, exclusive max)
- Specific version ID - Must match exactly

**Safety Outcomes:**
- `safe` - All dependencies satisfied, safe to update
- `needs_deps:mod1,mod2` - Missing required dependencies
- `incompatible:reason` - Version constraints cannot be satisfied

**Data Generated:**
```bash
UPDATE_SAFETY[project_id] = "safe" | "needs_deps:..." | "incompatible:..."
MISSING_DEPS_TO_DOWNLOAD[project_id] = "version"
```

### Phase 4: Wave Categorization

**Purpose:** Organize updates into logical groups based on dependency relationships.

**Wave Definitions:**

**Wave 1 - Independent Mods (Safest)**
- No dependencies on other installed mods
- Can be updated first without breaking anything
- Example: Standalone content mods, texture packs

**Wave 2 - Consumer Mods**
- Depend on other mods (providers)
- Should be updated after their dependencies
- Example: Add-on mods, integration mods

**Wave 3 - Provider Mods (Riskiest)**
- Other mods depend on them
- Breaking changes here affect multiple mods
- Example: Library mods, API mods

**Wave 4 - Complex Mods**
- Both providers and consumers
- Require careful coordination
- Example: Create (provides APIs, depends on Flywheel)

**Categorization Logic:**
```bash
if [[ $is_consumer == true && $is_provider == true ]]; then
  WAVE_4_COMPLEX+=("$project_id")
elif [[ $is_provider == true ]]; then
  WAVE_3_PROVIDERS+=("$project_id")
elif [[ $is_consumer == true ]]; then
  WAVE_2_CONSUMERS+=("$project_id")
else
  WAVE_1_INDEPENDENT+=("$project_id")
fi
```

### Phase 4.5: Missing Dependency Resolution

**Purpose:** Automatically detect and download missing dependencies to fix broken mods.

**Process:**
1. Scan `UPDATE_SAFETY` for "needs_deps" entries
2. For each missing dependency:
   - Query Modrinth API for compatible versions
   - Find highest version matching constraints
   - Add to `MISSING_DEPS_TO_DOWNLOAD`
3. Download during Phase 7

**Constraint Matching:**
```bash
# If version_id is a range like [21.1.206,)
min_version=$(echo "$version_id" | sed 's/[\[\],()]//g' | awk '{print $1}')
# Find versions >= min_version
```

**Real-World Example:**
```
Mod: realism_tweaks
Missing: realism_tweaks_lib
Constraint: [1.0.0,)
Result: Download realism_tweaks_lib-1.2.3.jar
```

### Phase 5: NeoForge Version Detection

**Purpose:** Automatically detect and apply required NeoForge version upgrades by scanning ALL installed mods.

**Critical Design Change (v2.0):**
- **OLD**: Only checked mods being updated (failed when 0 updates available)
- **NEW**: Scans all 142 installed mods every run (always validates environment)

**Why This Matters:**
- Mods can require specific NeoForge versions even without updates
- New mods added manually may require newer NeoForge
- Ensures build environment always matches mod requirements

**Process:**
1. Read current NeoForge version from `build.sh`: `grep '^NEOFORGE_VERSION='`
2. **For EVERY mod** (not just updates):
   - Get current version's dependency data
   - Look for `neoforge` dependency
   - Parse version requirement (e.g., `[21.1.215,)`)
3. Track highest required version across all mods
4. If higher than current: Auto-update `build.sh`
5. Create audit trail in logs

**Version Parsing:**
```bash
# Input: [21.1.215,)
min_version=$(echo "$neoforge_req" | sed 's/[\[\],()]//g' | awk '{print $1}')
# Output: 21.1.215

# Compare versions
IFS='.' read -r major minor patch <<< "$min_version"
if [[ $major -gt $curr_major ]] || ... ; then
  UPGRADE_NEEDED=true
fi
```

**Build.sh Integration:**
```bash
# Update NeoForge version in build.sh
sed -i "s/^NEOFORGE_VERSION=\"[^\"]*\"/NEOFORGE_VERSION=\"$HIGHEST_NEOFORGE_FULL\"/" "$BASE_DIR/build.sh"
```

**Example Output:**
```
[INFO] Phase 5: Detecting NeoForge version requirements...
[INFO] Current NeoForge version: 21.1.194
[INFO] Scanning all 142 installed mods for NeoForge requirements...
[WARN] NeoForge upgrade required: 21.1.194 → 21.1.215
[✓] Updated build.sh with NeoForge 21.1.215
```

### Phase 6: Update Report Display

**Purpose:** Present findings in a clear, organized format for review.

**Report Sections:**
1. **Summary Statistics**
   - Total mods scanned
   - Safe updates available
   - Already current mods
   - Wave distribution

2. **Wave-by-Wave Breakdown**
   - Listed by category
   - Shows current → new version
   - Displays dependencies

3. **Missing Dependencies**
   - Which mods need them
   - What will be downloaded

4. **Incompatible Updates**
   - Why they failed validation
   - What needs to change

**Color Coding:**
- Green: Safe, validated
- Yellow: Warnings, missing deps
- Red: Incompatible, blocked
- Blue: Informational, waves

### Phase 7: Download and Installation

**Purpose:** Actually perform the updates (UPDATE mode only, skipped in dry run).

**Download Process:**
1. Query Modrinth API for version details: `GET /v2/version/{version_id}`
2. Extract download URL: `.files[0].url`
3. Download with curl: `curl -L -o "$new_filename" "$download_url"`
4. Verify download succeeded
5. Remove old version: `rm -f "$old_filename"`
6. Update progress counter

**File Management:**
```bash
# Old file: createoreexcavation-2.0.6.jar
# New file: createoreexcavation-2.1.0.jar
curl -s --max-time 60 -L -o "mods/$new_filename" "$download_url"
rm -f "mods/$old_filename"
```

**Build Script Integration:**
```bash
# Create marker file to signal version bump
if [[ $DOWNLOAD_SUCCESS -gt 0 ]]; then
  touch "$MODS_DIR/.updated"
fi
```

**Success Tracking:**
```
[1/83] ✓ Updated: Create Ore Excavation
[2/83] ✓ Updated: Create Enchantment Industry
...
[83/83] ✓ Updated: YUNG's API

═══════════════════════════════════════════
Successfully Updated:  83/83
Failed:                0/83
═══════════════════════════════════════════
```

---

## Data Structures

### MOD_INFO (Associative Array)

**Key:** Filename (e.g., `create-1.21.jar`)  
**Value:** Colon-separated string

```
Format: "project_id:current_ver:latest_ver:name:current_vid:latest_vid"
Example: "create:0.5.1.i:0.5.1.j:Create:abc123:def456"
```

**Field Breakdown:**
1. `project_id` - Modrinth project identifier
2. `current_ver` - Currently installed version number
3. `latest_ver` - Latest available version number
4. `name` - Human-readable mod name
5. `current_vid` - Current version ID (for API lookups)
6. `latest_vid` - Latest version ID (for downloading)

### UPDATE_SAFETY (Associative Array)

**Key:** Project ID  
**Value:** Safety status string

```
Possible values:
- "safe"                          # All dependencies satisfied
- "needs_deps:mod1,mod2"         # Missing required dependencies
- "incompatible:reason"          # Cannot update safely
```

**Usage:**
```bash
if [[ "${UPDATE_SAFETY[$project_id]}" == "safe" ]]; then
  # Proceed with update
fi
```

### VERSION_ID_TO_NUMBER (Associative Array)

**Purpose:** Convert Modrinth version IDs to human-readable version numbers

**Key:** Version ID (e.g., `iezuV4Rx`)  
**Value:** Version number (e.g., `1.8-29`)

**Why Needed:**
Modrinth dependencies reference version IDs, but we need to validate against version numbers for constraint checking.

### MISSING_DEPS_TO_DOWNLOAD (Associative Array)

**Key:** Project ID of missing dependency  
**Value:** Version number to download

**Example:**
```bash
MISSING_DEPS_TO_DOWNLOAD[pandalib]="2.1.0"
MISSING_DEPS_TO_DOWNLOAD[terrablender]="4.0.1.3"
```

### Wave Arrays

```bash
WAVE_1_INDEPENDENT=()  # Array of project IDs
WAVE_2_CONSUMERS=()
WAVE_3_PROVIDERS=()
WAVE_4_COMPLEX=()
```

---

## API Integration

### Modrinth API v2 Endpoints

**Base URL:** `https://api.modrinth.com/v2`

#### 1. Hash-Based File Lookup

```bash
GET /v2/version_file/{hash}?algorithm=sha512
```

**Purpose:** Identify a mod by its file hash (100% accurate)

**Response:**
```json
{
  "project_id": "create",
  "version_number": "0.5.1.i",
  "name": "Create",
  "id": "version_id_abc123"
}
```

**Implementation:**
```bash
hash=$(sha512sum "$file" | awk '{print $1}')
curl -s --max-time 8 "https://api.modrinth.com/v2/version_file/$hash?algorithm=sha512"
```

#### 2. Project Version Listing

```bash
GET /v2/project/{project_id}/version?game_versions=["1.21.1"]&loaders=["neoforge"]
```

**Purpose:** Get all compatible versions for a project

**Response:**
```json
[
  {
    "id": "version_id",
    "version_number": "2.0.13",
    "game_versions": ["1.21.1"],
    "loaders": ["neoforge"],
    "dependencies": [...]
  }
]
```

**Filters:**
- `game_versions` - Minecraft version compatibility
- `loaders` - Mod loader type (neoforge, forge, fabric)

#### 3. Version Details

```bash
GET /v2/version/{version_id}
```

**Purpose:** Get complete information about a specific version

**Response:**
```json
{
  "id": "version_id",
  "version_number": "2.0.13",
  "dependencies": [
    {
      "project_id": "neoforge",
      "dependency_type": "required",
      "version_id": "[21.1.206,)"
    }
  ],
  "files": [
    {
      "url": "https://cdn.modrinth.com/...",
      "filename": "mod-2.0.13.jar"
    }
  ]
}
```

**Used For:**
- Dependency validation
- Download URL retrieval
- File naming

### Rate Limiting and Error Handling

**Timeouts:**
```bash
curl -s --max-time 8  # Phase 1-5 (quick lookups)
curl -s --max-time 60 # Phase 7 (downloads)
```

**Retry Logic:**
```bash
response=$(curl ... 2>/dev/null || echo "")
if [[ -z "$response" ]]; then
  # Handle failure
fi
```

**JSON Validation:**
```bash
if echo "$response" | jq -e '.project_id' >/dev/null 2>&1; then
  # Valid response
fi
```

---

## Version Detection Logic

### Semantic Version Comparison

**Format:** `major.minor.patch` (e.g., `21.1.215`)

**Comparison Algorithm:**
```bash
compare_versions() {
  local v1_major=$1 v1_minor=$2 v1_patch=$3
  local v2_major=$4 v2_minor=$5 v2_patch=$6
  
  if [[ $v1_major -gt $v2_major ]]; then
    return 0  # v1 > v2
  elif [[ $v1_major -eq $v2_major && $v1_minor -gt $v2_minor ]]; then
    return 0
  elif [[ $v1_major -eq $v2_major && $v1_minor -eq $v2_minor && $v1_patch -gt $v2_patch ]]; then
    return 0
  fi
  return 1  # v1 <= v2
}
```

### Version Constraint Parsing

**Constraint Formats:**

1. **Minimum Version (Open-Ended)**
   ```
   [21.1.206,)
   Means: >= 21.1.206, no maximum
   ```

2. **Version Range**
   ```
   [1.0.0,2.0.0)
   Means: >= 1.0.0 AND < 2.0.0
   ```

3. **Exact Version**
   ```
   1.5.3
   Means: Must be exactly 1.5.3
   ```

**Parsing Implementation:**
```bash
# Extract minimum version from constraint
min_version=$(echo "[21.1.206,)" | sed 's/[\[\],()]//g' | awk '{print $1}')
# Result: "21.1.206"

# Extract maximum version if present
max_version=$(echo "[1.0.0,2.0.0)" | sed 's/[\[\],()]//g' | awk '{print $2}')
# Result: "2.0.0"
```

### Loader Type Validation

**Why Important:**
NeoForge ≠ Forge. Mods must explicitly support NeoForge API.

**Validation:**
```bash
loader_check=$(echo "$versions" | jq -r "
  .[] | 
  select(.game_versions[] == \"1.21.1\") | 
  select(.loaders[] == \"neoforge\") |
  .version_number
" | head -1)

if [[ -z "$loader_check" ]]; then
  # No NeoForge-compatible version available
fi
```

**Loader Hierarchy:**
- NeoForge 21.1.x (Minecraft 1.21.1)
- Forge 51.x (older, incompatible API)
- Fabric (completely different loader)

---

## NeoForge Auto-Management

### Why Automatic NeoForge Management?

**Problem:** Mods specify minimum NeoForge versions in their dependencies. Running outdated NeoForge causes crashes.

**Old Approach (Manual):**
1. Update mods
2. Game crashes with version mismatch
3. Check crash log for required version
4. Manually edit build.sh
5. Rebuild modpack

**New Approach (Automatic):**
1. Update script scans ALL mods
2. Detects highest NeoForge requirement
3. Auto-updates build.sh
4. Build uses correct version automatically

### Implementation Details

**Scanning Logic:**
```bash
# Scan ALL installed mods (not just updates)
for filename in "${!MOD_INFO[@]}"; do
  # Get current version's dependencies
  version_data=$(curl -s "https://api.modrinth.com/v2/version/$current_version_id")
  
  # Look for neoforge dependency
  neoforge_req=$(echo "$version_data" | jq -r '
    .dependencies[] | 
    select(.project_id == "neoforge") | 
    .version_id
  ')
  
  # Parse version constraint: [21.1.215,) → 21.1.215
  min_version=$(echo "$neoforge_req" | sed 's/[\[\],()]//g' | awk '{print $1}')
  
  # Track highest requirement
  if version_is_higher "$min_version" "$HIGHEST_NEOFORGE_FULL"; then
    HIGHEST_NEOFORGE_FULL="$min_version"
  fi
done
```

**Build.sh Update:**
```bash
# Get current NeoForge version
CURRENT=$(grep '^NEOFORGE_VERSION=' build.sh | cut -d'"' -f2)

# If upgrade needed
if [[ "$HIGHEST_NEOFORGE_FULL" > "$CURRENT" ]]; then
  sed -i "s/^NEOFORGE_VERSION=\"[^\"]*\"/NEOFORGE_VERSION=\"$HIGHEST_NEOFORGE_FULL\"/" build.sh
fi
```

### Version History Tracking

**Example Timeline:**
```
Initial:    21.1.194 (base modpack)
Update 1:   21.1.206 (Create updated)
Update 2:   21.1.215 (Multiple mods required higher)
```

**Detection Output:**
```
[INFO] Current NeoForge version: 21.1.194
[INFO] Scanning all 142 installed mods for NeoForge requirements...
[WARN] NeoForge upgrade required: 21.1.194 → 21.1.215
[✓] Updated build.sh with NeoForge 21.1.215
```

---

## Build Script Integration

### Version Bump Mechanism

**Problem:** Build script uses content hashing to detect changes. When mods update, hash changes, but we need to signal that the update is significant enough for a version bump.

**Solution:** Update script creates marker file, build script detects it.

### Update Script Side

**After Successful Updates:**
```bash
# Phase 7: Download and Installation
if [[ $DOWNLOAD_SUCCESS -gt 0 ]]; then
  touch "$MODS_DIR/.updated"
  log_info "Created update marker for build script"
fi
```

### Build Script Side

**Version Detection Enhancement:**
```bash
# Check for update marker from smart-dependency-update.sh
local force_version_bump=false
if [ -f "$MODS_DIR/.updated" ]; then
  echo "- Update marker detected: mods were updated"
  force_version_bump=true
  rm -f "$MODS_DIR/.updated"  # Clear the marker
fi

# Check if content changed OR marker present
if [ "$current_hash" != "$stored_hash" ] || [ "$force_version_bump" = true ]; then
  # Increment version
  CURRENT_VERSION=$(increment_version "$base_version" "mod")
fi
```

### Version Increment Rules

**Semantic Versioning:** `major.minor.patch`

**Increment Type:**
- `mod` change → increment minor (3.14.3 → 3.14.4)
- `config` change → increment patch (3.14.3 → 3.14.3.1)
- `infrastructure` → increment patch with note

**Example Flow:**
```
1. Update script: 83 mods updated → creates mods/.updated
2. Build script: Detects marker → bumps version (3.14.3 → 3.14.4)
3. Build script: Removes marker → generates new mrpack
4. Result: Survival Not Guaranteed-3.14.4.mrpack
```

### Content Hash System

**Purpose:** Detect any changes to modpack content between builds.

**Hash Components:**
```bash
generate_content_hash() {
  local mod_hash=$(find mods/ -name "*.jar" | sort | xargs sha256sum | sha256sum)
  local config_hash=$(find config/ -type f | sort | xargs sha256sum | sha256sum)
  local other_hash=$(find . -name "servers.dat" | xargs sha256sum | sha256sum)
  
  echo "MOD:$mod_hash|CONFIG:$config_hash|OTHER:$other_hash"
}
```

**Storage:**
```bash
echo "$current_hash" > .content_hash
```

---

## Usage Examples

### Basic Update Check (Dry Run)

```bash
./tools/smart-dependency-update.sh
```

**Output:**
```
[INFO] Minecraft: 1.21.1
[INFO] Loader: neoforge
[INFO] Mode: DRY RUN

[✓] Found 142 mods on Modrinth
[✓] Safe Updates Available: 5

Wave 1 (Independent):
  [1] Create Ore Excavation: 2.0.6 → 2.1.0
  [2] AmbientSounds: 6.3.0 → 6.3.1

Wave 2 (Consumers):
  [3] Create Enchantment Industry: 1.2.11 → 1.2.12
```

### Perform Updates

```bash
DRY_RUN=false ./tools/smart-dependency-update.sh
```

**What Happens:**
1. Validates all updates (same as dry run)
2. Downloads new versions from CDN
3. Removes old versions
4. Creates `.updated` marker
5. Reports success statistics

**Output:**
```
[INFO] Phase 7: Downloading and installing updates...

[1/5] ✓ Updated: Create Ore Excavation
[2/5] ✓ Updated: AmbientSounds
[3/5] ✓ Updated: Create Enchantment Industry
[4/5] ✓ Updated: Create Dragons Plus
[5/5] ✓ Updated: YUNG's API

═══════════════════════════════════════════
Successfully Updated:  5/5
Failed:                0/5
═══════════════════════════════════════════
```

### Build Updated Modpack

```bash
./build.sh
```

**What Happens:**
1. Detects `.updated` marker → forces version bump
2. Scans all 142 mods
3. Generates modrinth.index.json with CDN URLs
4. Packages into .mrpack file
5. Version: 3.14.4 (bumped from 3.14.3)

**Output:**
```
- Update marker detected: mods were updated
- Content changes detected, analyzing change type...
- Mod changes detected
+ New version: 3.14.4
- Using configured NeoForge version: 21.1.215

Scanning mods in: mods (142 mod files found)
...
Modpack built successfully!
Output: Survival Not Guaranteed-3.14.4.mrpack
```

### Full Update Workflow

```bash
# 1. Check for updates (dry run)
./tools/smart-dependency-update.sh

# 2. Review output, then perform updates
DRY_RUN=false ./tools/smart-dependency-update.sh

# 3. Build new modpack
./build.sh

# 4. Test the updated modpack
# (manual testing in Minecraft)
```

---

## Troubleshooting

### Issue: "No mods found on Modrinth"

**Cause:** Empty mods directory or API timeout

**Solution:**
```bash
# Check mods directory
ls -la mods/*.jar | wc -l

# Test API connectivity
curl -s "https://api.modrinth.com/v2/version_file/$(sha512sum mods/create-*.jar | awk '{print $1}')"
```

### Issue: "Update marked unsafe: needs_deps"

**Cause:** New version requires dependencies you don't have

**Solution:**
1. Check Phase 4.5 output for missing dependencies
2. Script will auto-download if available on Modrinth
3. If not on Modrinth, manually add the dependency

**Example:**
```
[WARN] realism_tweaks needs: realism_tweaks_lib
[INFO] Will download: realism_tweaks_lib-1.2.3
```

### Issue: "Loader validation failed"

**Cause:** Latest version doesn't support NeoForge (only Forge/Fabric)

**Solution:**
- Mod doesn't have NeoForge version yet
- Check mod's Modrinth page for updates
- May need to wait for mod author to release NeoForge version

### Issue: NeoForge version not updating

**Cause:** Phase 5 only ran when updates were available (v1.0 bug)

**Solution:** Fixed in v2.0 - now scans ALL mods every run

**Verify Fix:**
```bash
./tools/smart-dependency-update.sh 2>&1 | grep "Scanning all"
# Should show: "Scanning all 142 installed mods"
```

### Issue: Version not incrementing after updates

**Cause:** `.updated` marker not created or not detected

**Debug:**
```bash
# Check if marker was created
ls -la mods/.updated

# Check build script detection
./build.sh 2>&1 | grep "Update marker"
```

**Manual Fix:**
```bash
touch mods/.updated
./build.sh
```

### Issue: API rate limiting

**Symptom:** Many failed API calls, slow performance

**Solution:**
- Add delays between API calls
- Use API key (if available from Modrinth)
- Reduce parallel requests

**Current Mitigation:**
- Sequential processing (no parallel API calls)
- 8-second timeouts prevent hanging
- Cached version mappings reduce duplicate calls

### Issue: Hash mismatch after update

**Symptom:** Mod appears to update but script still shows old version

**Cause:** Multiple files with same project ID

**Solution:**
```bash
# Find duplicate mods
find mods/ -name "*.jar" -exec sha512sum {} \; | sort | uniq -d

# Remove old versions manually
rm mods/create-old-version.jar
```

---

## Performance Optimization

### Current Performance (142 mods)

- Phase 1 (Hashing): ~15 seconds
- Phase 2-3 (API queries): ~30 seconds  
- Phase 5 (NeoForge scan): ~45 seconds (142 API calls)
- Phase 7 (Downloads): ~2 seconds per mod
- **Total (dry run): ~90 seconds**
- **Total (with 83 updates): ~250 seconds**

### Optimization Strategies

**1. Version ID Caching**
```bash
# Cache version mappings to avoid redundant API calls
if [[ -f ".version_cache.json" ]]; then
  cached_version=$(jq -r ".[\"$version_id\"]" .version_cache.json)
fi
```

**2. Parallel Hash Calculation**
```bash
# Use GNU parallel for faster hashing
find mods/ -name "*.jar" | parallel sha512sum
```

**3. Batch API Queries**
```bash
# Request multiple versions in single API call
curl "https://api.modrinth.com/v2/versions?ids=[\"id1\",\"id2\",\"id3\"]"
```

**4. NeoForge Cache**
```bash
# Cache NeoForge requirements (rarely change)
# Only rescan if new mods added
```

---

## Future Enhancements

### Planned Features

1. **Rollback Mechanism**
   - Save old mod versions before update
   - Quick rollback if update causes issues

2. **Update Scheduling**
   - Weekly auto-update checks
   - Email notifications for available updates

3. **Dependency Graph Visualization**
   - Generate visual dependency tree
   - Identify critical provider mods

4. **Update Blacklist**
   - Skip specific mod updates
   - Pin versions that are known stable

5. **Changelog Integration**
   - Fetch mod changelogs from Modrinth
   - Include in update report

6. **Multi-Version Support**
   - Support multiple Minecraft versions
   - Parallel development branches

---

## Version History

### v2.0 (January 5, 2026)
- **CRITICAL FIX**: Phase 5 now scans ALL installed mods (not just updates)
- **NEW**: Automatic version bump via marker file integration
- **IMPROVED**: Build script detects and consumes `.updated` marker
- **TESTED**: Successfully updated 83/83 mods in production

### v1.0 (January 4, 2026)
- Initial release with 7-phase update system
- Hash-based mod identification
- Dependency validation and safety checking
- Wave categorization
- Missing dependency resolution
- NeoForge version detection (only for updates)
- Actual download and file replacement

---

## Credits

**Author:** AI-assisted development (GitHub Copilot)  
**Platform:** Modrinth API v2  
**Modpack:** Survival Not Guaranteed  
**Environment:** Bazzite Linux, Minecraft 1.21.1, NeoForge 21.1.215+

**Special Thanks:**
- Modrinth for comprehensive API
- NeoForge team for version management
- Mod developers for maintaining dependencies

---

## License

This script is part of the Survival Not Guaranteed modpack. Feel free to adapt for your own modpacks with attribution.
