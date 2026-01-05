#!/bin/bash

# Smart Dependency-Aware Mod Update System with Full Version Constraint Resolution
# Ensures all dependency chains are satisfied before allowing updates

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
MAGENTA='\033[0;95m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_wave() { echo -e "${MAGENTA}[WAVE]${NC} $1"; }
log_check() { echo -e "${CYAN}[CHECK]${NC} $1"; }

# Configuration
MINECRAFT_VERSION="1.21.1"
LOADER_TYPE="neoforge"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODS_DIR="$BASE_DIR/mods"
DRY_RUN="${DRY_RUN:-true}"
PINNED_FILE="$MODS_DIR/.pinned"

# Data structures
declare -A MOD_INFO                    # filename -> project_id:current_version:latest_version:mod_name:current_version_id:latest_version_id
declare -A PROJECT_TO_FILE             # project_id -> filename
declare -A VERSION_ID_TO_NUMBER        # version_id -> version_number
declare -A MOD_CURRENT_DEPS            # project_id -> semicolon-separated "dep_id:version_id"
declare -A MOD_LATEST_DEPS             # project_id -> semicolon-separated "dep_id:version_id"
declare -A UPDATE_SAFETY               # project_id -> "safe" | "unsafe:reason"
declare -A MISSING_DEPS_TO_DOWNLOAD=() # project_id -> "latest_version"
declare -A PINNED_MODS=()              # project_id -> "version:reason"

# Wave arrays
declare -a WAVE_1_INDEPENDENT=()
declare -a WAVE_2_CONSUMERS=()
declare -a WAVE_3_PROVIDERS=()
declare -a WAVE_4_COMPLEX=()

# Counters
TOTAL_MODS=0
FOUND_MODS=0
SAFE_UPDATES=0
UNSAFE_UPDATES=0
CURRENT_MODS=0

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "  Smart Dependency-Aware Mod Update System"
log_info "  Full version constraint resolution"
log_info "═══════════════════════════════════════════════════════════════"
echo ""
log_info "Minecraft: $MINECRAFT_VERSION"
log_info "Loader: $LOADER_TYPE"
log_info "Mode: $([ "$DRY_RUN" = "true" ] && echo "DRY RUN" || echo "UPDATE MODE")"

# Function to compare semantic versions
compare_versions() {
    local ver1="$1"
    local op="$2"
    local ver2="$3"
    
    # Normalize versions by removing non-numeric prefixes and suffixes
    ver1=$(echo "$ver1" | sed 's/^[^0-9]*//' | sed 's/[^0-9.].*//')
    ver2=$(echo "$ver2" | sed 's/^[^0-9]*//' | sed 's/[^0-9.].*//')
    
    # Use sort -V for version comparison
    case "$op" in
        "<=")
            [[ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)" == "$ver1" ]]
            ;;
        "<")
            [[ "$ver1" != "$ver2" ]] && [[ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | head -n1)" == "$ver1" ]]
            ;;
        ">=")
            [[ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | tail -n1)" == "$ver1" ]]
            ;;
        ">")
            [[ "$ver1" != "$ver2" ]] && [[ "$(printf '%s\n' "$ver1" "$ver2" | sort -V | tail -n1)" == "$ver1" ]]
            ;;
        "==")
            [[ "$ver1" == "$ver2" ]]
            ;;
        *)
            return 1
            ;;
    esac
}
echo ""

# Load pinned mods
if [[ -f "$PINNED_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Split the line by colons
        IFS=':' read -ra PARTS <<< "$line"
        project_id="${PARTS[0]}"
        version="${PARTS[1]}"
        
        # Check if this is a conditional pin (has 'if' as third field)
        if [[ "${PARTS[2]}" == "if" ]]; then
            # Conditional format: project_id:version:if:dependent_id:operator:dep_version:reason
            dependent_id="${PARTS[3]}"
            operator="${PARTS[4]}"
            dep_version="${PARTS[5]}"
            reason="${PARTS[6]}"
            PINNED_MODS[$project_id]="$version:conditional:$dependent_id:$operator:$dep_version:$reason"
        else
            # Simple format: project_id:version:reason
            reason="${PARTS[2]}"
            PINNED_MODS[$project_id]="$version:$reason"
        fi
    done < "$PINNED_FILE"
    
    if [[ ${#PINNED_MODS[@]} -gt 0 ]]; then
        log_warning "${#PINNED_MODS[@]} pinned mod(s)"
    fi
fi

# Phase 1: Scan and identify all mods
log_info "Phase 1: Scanning and identifying mods..."
echo ""

TOTAL_MODS=$(find "$MODS_DIR" -name "*.jar" -type f 2>/dev/null | wc -l)

CURRENT=0
for mod_file in "$MODS_DIR"/*.jar; do
    [[ ! -f "$mod_file" ]] && continue
    
    CURRENT=$((CURRENT + 1))
    filename=$(basename "$mod_file")
    printf "\r\033[K[%d/%d] Scanning: %-50s" "$CURRENT" "$TOTAL_MODS" "$filename"
    
    # Calculate hash
    sha512hash=""
    if command -v sha512sum >/dev/null 2>&1; then
        sha512hash=$(sha512sum "$mod_file" 2>/dev/null | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        sha512hash=$(shasum -a 512 "$mod_file" 2>/dev/null | awk '{print $1}')
    fi
    
    [[ -z "$sha512hash" ]] && continue
    
    # Query Modrinth hash API
    response=$(curl -s --max-time 10 "https://api.modrinth.com/v2/version_file/$sha512hash" 2>/dev/null || echo "")
    [[ -z "$response" ]] || ! echo "$response" | jq -e '.project_id' >/dev/null 2>&1 && continue
    
    project_id=$(echo "$response" | jq -r '.project_id')
    current_version=$(echo "$response" | jq -r '.version_number')
    current_version_id=$(echo "$response" | jq -r '.id')
    mod_name=$(echo "$response" | jq -r '.name' | sed 's/\[.*\] //' | sed 's/:.*//' | cut -c1-40)
    
    FOUND_MODS=$((FOUND_MODS + 1))
    
    # Cache version ID to number mapping
    VERSION_ID_TO_NUMBER[$current_version_id]="$current_version"
    
    # Store current dependencies with version IDs
    current_deps=$(echo "$response" | jq -r '[.dependencies[]? | select(.dependency_type == "required") | "\(.project_id):\(.version_id // \"any\")"] | join(";")' 2>/dev/null || echo "")
    MOD_CURRENT_DEPS[$project_id]="$current_deps"
    
    # Check for latest version (filtered by MC version and loader)
    versions_response=$(curl -s --max-time 10 "https://api.modrinth.com/v2/project/$project_id/version?game_versions=%5B%22$MINECRAFT_VERSION%22%5D&loaders=%5B%22$LOADER_TYPE%22%5D" 2>/dev/null || echo "[]")
    
    if [[ "$versions_response" != "[]" ]] && echo "$versions_response" | jq -e '.[0]' >/dev/null 2>&1; then
        # Verify the version actually supports our loader
        latest_loaders=$(echo "$versions_response" | jq -r '.[0].loaders[]' 2>/dev/null | tr '\n' ',' || echo "")
        if [[ ! "$latest_loaders" =~ $LOADER_TYPE ]]; then
            # Skip if loader mismatch
            latest_version="$current_version"
            latest_version_id="$current_version_id"
            MOD_INFO[$filename]="$project_id:$current_version:$latest_version:$mod_name:$current_version_id:$latest_version_id"
            PROJECT_TO_FILE[$project_id]="$filename"
            CURRENT_MODS=$((CURRENT_MODS + 1))
            continue
        fi
        
        latest_version=$(echo "$versions_response" | jq -r '.[0].version_number')
        latest_version_id=$(echo "$versions_response" | jq -r '.[0].id')
        
        # Cache version ID to number mapping
        VERSION_ID_TO_NUMBER[$latest_version_id]="$latest_version"
        
        # Store latest dependencies with version IDs
        latest_deps=$(echo "$versions_response" | jq -r '[.[0].dependencies[]? | select(.dependency_type == "required") | "\(.project_id):\(.version_id // \"any\")"] | join(";")' 2>/dev/null || echo "")
        MOD_LATEST_DEPS[$project_id]="$latest_deps"
        
        MOD_INFO[$filename]="$project_id:$current_version:$latest_version:$mod_name:$current_version_id:$latest_version_id"
        PROJECT_TO_FILE[$project_id]="$filename"
        
        if [[ "$current_version" != "$latest_version" ]]; then
            UPDATE_SAFETY[$project_id]="pending"  # Will check later
        fi
    else
        latest_version="$current_version"
        latest_version_id="$current_version_id"
        MOD_INFO[$filename]="$project_id:$current_version:$latest_version:$mod_name:$current_version_id:$latest_version_id"
        PROJECT_TO_FILE[$project_id]="$filename"
        CURRENT_MODS=$((CURRENT_MODS + 1))
    fi
done

printf "\n\n"
log_success "Found $FOUND_MODS mods on Modrinth"
echo ""

# Phase 2: Resolve version constraints for all dependencies
log_info "Phase 2: Resolving version constraints..."
echo ""

# Cache version numbers for all referenced version IDs
TOTAL_VERSION_IDS=$(for key in "${!MOD_CURRENT_DEPS[@]}"; do echo "${MOD_CURRENT_DEPS[$key]}"; done | tr ';' '\n' | cut -d: -f2 | grep -v "^any$" | sort -u | wc -l)
CURRENT_VID=0

for key in "${!MOD_CURRENT_DEPS[@]}"; do
    deps="${MOD_CURRENT_DEPS[$key]}"
    [[ -z "$deps" ]] && continue
    
    IFS=';' read -ra dep_array <<< "$deps"
    for dep_entry in "${dep_array[@]}"; do
        IFS=':' read -r dep_id version_id <<< "$dep_entry"
        if [[ "$version_id" != "any" ]] && [[ -z "${VERSION_ID_TO_NUMBER[$version_id]:-}" ]]; then
            CURRENT_VID=$((CURRENT_VID + 1))
            printf "\r\033[K[%d/%d] Resolving version constraints..." "$CURRENT_VID" "$TOTAL_VERSION_IDS"
            
            ver_response=$(curl -s --max-time 8 "https://api.modrinth.com/v2/version/$version_id" 2>/dev/null || echo "")
            if [[ -n "$ver_response" ]] && echo "$ver_response" | jq -e '.version_number' >/dev/null 2>&1; then
                version_num=$(echo "$ver_response" | jq -r '.version_number')
                VERSION_ID_TO_NUMBER[$version_id]="$version_num"
            else
                VERSION_ID_TO_NUMBER[$version_id]="unknown"
            fi
        fi
    done
done

# Do the same for latest deps
for key in "${!MOD_LATEST_DEPS[@]}"; do
    deps="${MOD_LATEST_DEPS[$key]}"
    [[ -z "$deps" ]] && continue
    
    IFS=';' read -ra dep_array <<< "$deps"
    for dep_entry in "${dep_array[@]}"; do
        IFS=':' read -r dep_id version_id <<< "$dep_entry"
        if [[ "$version_id" != "any" ]] && [[ -z "${VERSION_ID_TO_NUMBER[$version_id]:-}" ]]; then
            CURRENT_VID=$((CURRENT_VID + 1))
            printf "\r\033[K[%d/%d] Resolving version constraints..." "$CURRENT_VID" "$TOTAL_VERSION_IDS"
            
            ver_response=$(curl -s --max-time 8 "https://api.modrinth.com/v2/version/$version_id" 2>/dev/null || echo "")
            if [[ -n "$ver_response" ]] && echo "$ver_response" | jq -e '.version_number' >/dev/null 2>&1; then
                version_num=$(echo "$ver_response" | jq -r '.version_number')
                VERSION_ID_TO_NUMBER[$version_id]="$version_num"
            else
                VERSION_ID_TO_NUMBER[$version_id]="unknown"
            fi
        fi
    done
done

printf "\n"
log_success "Version constraints resolved"
echo ""

# Phase 3: Check update safety for each mod
log_info "Phase 3: Validating update safety..."
echo ""

check_update_safety() {
    local project_id="$1"
    local check_type="${2:-latest}"  # "latest" or "current"
    
    local deps=""
    if [[ "$check_type" == "latest" ]]; then
        deps="${MOD_LATEST_DEPS[$project_id]:-}"
    else
        deps="${MOD_CURRENT_DEPS[$project_id]:-}"
    fi
    
    [[ -z "$deps" ]] && return 0  # No deps = safe
    
    IFS=';' read -ra dep_array <<< "$deps"
    for dep_entry in "${dep_array[@]}"; do
        IFS=':' read -r dep_id required_version_id <<< "$dep_entry"
        
        # Check if this dependency exists in our mod list
        if [[ -z "${PROJECT_TO_FILE[$dep_id]:-}" ]]; then
            # Dependency not in our modpack - assume external/satisfied
            continue
        fi
        
        local dep_file="${PROJECT_TO_FILE[$dep_id]}"
        IFS=':' read -r _ dep_current dep_latest _ dep_current_vid dep_latest_vid <<< "${MOD_INFO[$dep_file]}"
        
        # If dependency requires a specific version
        if [[ "$required_version_id" != "any" ]]; then
            local required_version="${VERSION_ID_TO_NUMBER[$required_version_id]:-unknown}"
            
            # Check if current version of dependency satisfies requirement
            if [[ "$dep_current_vid" == "$required_version_id" ]]; then
                # Current version satisfies - good
                continue
            elif [[ "$dep_latest_vid" == "$required_version_id" ]]; then
                # Latest version satisfies - need to update dependency first
                echo "needs_update:$dep_id:$required_version"
                return 1
            else
                # Neither current nor latest satisfies - incompatible
                echo "incompatible:$dep_id:$required_version:available=$dep_current/$dep_latest"
                return 2
            fi
        fi
    done
    
    return 0
}

CHECKED=0
TOTAL_TO_CHECK=$(for key in "${!UPDATE_SAFETY[@]}"; do echo "$key"; done | wc -l)

for project_id in "${!UPDATE_SAFETY[@]}"; do
    CHECKED=$((CHECKED + 1))
    filename="${PROJECT_TO_FILE[$project_id]}"
    IFS=':' read -r _ current_ver _ mod_name _ _ <<< "${MOD_INFO[$filename]}"
    
    printf "\r\033[K[%d/%d] Checking: %-40s" "$CHECKED" "$TOTAL_TO_CHECK" "$mod_name"
    
    # Check if this mod is pinned
    if [[ -n "${PINNED_MODS[$project_id]:-}" ]]; then
        IFS=':' read -ra PIN_PARTS <<< "${PINNED_MODS[$project_id]}"
        pinned_version="${PIN_PARTS[0]}"
        
        # Check if current version matches pinned version
        if [[ "$current_ver" == "$pinned_version" ]]; then
            # Check if this is a conditional pin
            if [[ "${PIN_PARTS[1]}" == "conditional" ]]; then
                dependent_id="${PIN_PARTS[2]}"
                operator="${PIN_PARTS[3]}"
                dep_version="${PIN_PARTS[4]}"
                reason="${PIN_PARTS[5]}"
                
                # Find the dependent mod's current version
                dependent_current_ver=""
                for dep_file in "${!MOD_INFO[@]}"; do
                    IFS=':' read -r dep_proj_id dep_ver _ _ _ _ <<< "${MOD_INFO[$dep_file]}"
                    if [[ "$dep_proj_id" == "$dependent_id" ]]; then
                        dependent_current_ver="$dep_ver"
                        break
                    fi
                done
                
                # If dependent mod found, check condition
                if [[ -n "$dependent_current_ver" ]]; then
                    if compare_versions "$dependent_current_ver" "$operator" "$dep_version"; then
                        # Condition is still true, keep pin active
                        UPDATE_SAFETY[$project_id]="pinned:$reason"
                        UNSAFE_UPDATES=$((UNSAFE_UPDATES + 1))
                        continue
                    else
                        # Condition no longer true, pin released automatically
                        log_warning "Pin released: $mod_name (dependent mod updated past constraint)"
                    fi
                else
                    # Dependent mod not found, keep pin active for safety
                    UPDATE_SAFETY[$project_id]="pinned:$reason (dependent mod not found)"
                    UNSAFE_UPDATES=$((UNSAFE_UPDATES + 1))
                    continue
                fi
            else
                # Simple pin (no condition)
                reason="${PIN_PARTS[1]}"
                UPDATE_SAFETY[$project_id]="pinned:$reason"
                UNSAFE_UPDATES=$((UNSAFE_UPDATES + 1))
                continue
            fi
        fi
    fi
    
    # Check if latest version dependencies are satisfied
    safety_result=$(check_update_safety "$project_id" "latest")
    safety_code=$?
    
    if [[ $safety_code -eq 0 ]]; then
        UPDATE_SAFETY[$project_id]="safe"
        SAFE_UPDATES=$((SAFE_UPDATES + 1))
    elif [[ $safety_code -eq 1 ]]; then
        UPDATE_SAFETY[$project_id]="needs_deps:$safety_result"
        UNSAFE_UPDATES=$((UNSAFE_UPDATES + 1))
    else
        UPDATE_SAFETY[$project_id]="incompatible:$safety_result"
        UNSAFE_UPDATES=$((UNSAFE_UPDATES + 1))
    fi
done

printf "\n"
log_success "Safety validation complete"
echo ""

# Phase 4: Categorize into waves (only safe updates)
log_info "Phase 4: Categorizing safe updates into waves..."
echo ""

# Build dependency/dependent maps for wave categorization
declare -A MOD_HAS_DEPS
declare -A MOD_HAS_DEPENDENTS

# First pass: mark mods that have dependencies
for project_id in "${!UPDATE_SAFETY[@]}"; do
    [[ "${UPDATE_SAFETY[$project_id]}" != "safe" ]] && continue
    
    latest_deps="${MOD_LATEST_DEPS[$project_id]:-}"
    if [[ -n "$latest_deps" ]]; then
        MOD_HAS_DEPS[$project_id]="yes"
    fi
done

# Second pass: mark mods that are depended upon (providers)
for project_id in "${!UPDATE_SAFETY[@]}"; do
    [[ "${UPDATE_SAFETY[$project_id]}" != "safe" ]] && continue
    
    latest_deps="${MOD_LATEST_DEPS[$project_id]:-}"
    [[ -z "$latest_deps" ]] && continue
    
    IFS=';' read -ra dep_array <<< "$latest_deps"
    for dep_entry in "${dep_array[@]}"; do
        IFS=':' read -r dep_id _ <<< "$dep_entry"
        # Mark this dependency as a provider if it's in our update list
        if [[ -n "${UPDATE_SAFETY[$dep_id]:-}" ]] && [[ "${UPDATE_SAFETY[$dep_id]}" == "safe" ]]; then
            MOD_HAS_DEPENDENTS[$dep_id]="yes"
        fi
    done
done

# Categorize
for project_id in "${!UPDATE_SAFETY[@]}"; do
    [[ "${UPDATE_SAFETY[$project_id]}" != "safe" ]] && continue
    
    filename="${PROJECT_TO_FILE[$project_id]}"
    has_deps="${MOD_HAS_DEPS[$project_id]:-no}"
    has_dependents="${MOD_HAS_DEPENDENTS[$project_id]:-no}"
    
    if [[ "$has_deps" == "no" ]] && [[ "$has_dependents" == "no" ]]; then
        WAVE_1_INDEPENDENT+=("$filename")
    elif [[ "$has_deps" == "yes" ]] && [[ "$has_dependents" == "no" ]]; then
        WAVE_2_CONSUMERS+=("$filename")
    elif [[ "$has_deps" == "no" ]] && [[ "$has_dependents" == "yes" ]]; then
        WAVE_3_PROVIDERS+=("$filename")
    else
        WAVE_4_COMPLEX+=("$filename")
    fi
done

# Phase 4.5: Resolve missing dependencies
log_info "Phase 4.5: Resolving missing dependencies..."
echo ""

# Build a list of installed mod project IDs from what we already scanned
declare -A INSTALLED_MODS
for proj_id in "${!PROJECT_TO_FILE[@]}"; do
    INSTALLED_MODS[$proj_id]="yes"
done

# Check ALL installed mods for missing dependencies (not just mods being updated)
declare -a MISSING_DEPS_ARRAY=()
log_info "Scanning all $TOTAL_MODS installed mods for missing dependencies..."

for filename in "${!MOD_INFO[@]}"; do
    IFS=':' read -r project_id current_ver _ _ current_version_id _ <<< "${MOD_INFO[$filename]}"
    
    # Get current version's dependencies
    version_data=$(curl -s --max-time 8 "https://api.modrinth.com/v2/version/$current_version_id" 2>/dev/null || echo "")
    
    if [[ -n "$version_data" ]] && echo "$version_data" | jq -e '.dependencies' >/dev/null 2>&1; then
        # Parse all dependencies
        while IFS= read -r dep_entry; do
            dep_id=$(echo "$dep_entry" | jq -r '.project_id')
            dep_type=$(echo "$dep_entry" | jq -r '.dependency_type')
            
            # Skip if not required or if it's neoforge/minecraft
            [[ "$dep_type" != "required" ]] && continue
            [[ "$dep_id" == "neoforge" || "$dep_id" == "minecraft" ]] && continue
            
            # If dependency is not installed, add to missing list
            if [[ -z "${INSTALLED_MODS[$dep_id]:-}" ]]; then
                # Only add each missing dep once
                if ! printf '%s\n' "${MISSING_DEPS_ARRAY[@]}" 2>/dev/null | grep -q "^$dep_id$"; then
                    MISSING_DEPS_ARRAY+=("$dep_id")
                fi
            fi
        done < <(echo "$version_data" | jq -c '.dependencies[]' 2>/dev/null)
    fi
done

# Resolve and download missing dependencies at latest version
MISSING_DEPS_COUNT=${#MISSING_DEPS_ARRAY[@]}
if [[ $MISSING_DEPS_COUNT -gt 0 ]]; then
    log_warning "Found $MISSING_DEPS_COUNT missing dependencies"
    echo ""
    
    DOWNLOADED_COUNT=0
    FAILED_COUNT=0
    
    for idx in "${!MISSING_DEPS_ARRAY[@]}"; do
        dep_id="${MISSING_DEPS_ARRAY[$idx]}"
        printf "\r\033[K[%d/%d] Searching Modrinth: %s" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_id"
        
        # Get latest version of the missing dependency
        dep_versions=$(curl -s --max-time 10 "https://api.modrinth.com/v2/project/$dep_id/version?game_versions=%5B%22$MINECRAFT_VERSION%22%5D&loaders=%5B%22$LOADER_TYPE%22%5D" 2>/dev/null || echo "[]")
        
        if [[ "$dep_versions" != "[]" ]] && echo "$dep_versions" | jq -e '.[0]' >/dev/null 2>&1; then
            dep_version=$(echo "$dep_versions" | jq -r '.[0].version_number')
            dep_name=$(echo "$dep_versions" | jq -r '.[0].name')
            dep_filename=$(echo "$dep_versions" | jq -r '.[0].files[0].filename')
            dep_download_url=$(echo "$dep_versions" | jq -r '.[0].files[0].url')
            
            MISSING_DEPS_TO_DOWNLOAD[$dep_id]="$dep_version"
            
            # Download if not in DRY_RUN mode
            if [[ "$DRY_RUN" != "true" ]] && [[ -n "$dep_download_url" ]] && [[ "$dep_download_url" != "null" ]]; then
                printf "\r\033[K[%d/%d] Downloading: %s v%s" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_name" "$dep_version"
                if curl -s --max-time 30 -L -o "$MODS_DIR/$dep_filename" "$dep_download_url" 2>/dev/null; then
                    DOWNLOADED_COUNT=$((DOWNLOADED_COUNT + 1))
                    printf "\r\033[K[%d/%d] ✓ Downloaded: %s v%s\n" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_name" "$dep_version"
                else
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    printf "\r\033[K[%d/%d] ✗ Download failed: %s\n" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_name"
                fi
            else
                printf "\r\033[K[%d/%d] Found: %s v%s (dry run)\n" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_name" "$dep_version"
            fi
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            printf "\r\033[K[%d/%d] ✗ Not found on Modrinth: %s\n" "$((idx + 1))" "$MISSING_DEPS_COUNT" "$dep_id"
        fi
    done
    printf "\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Found $MISSING_DEPS_COUNT missing dependencies (dry run - not downloading)"
    else
        if [[ $DOWNLOADED_COUNT -gt 0 ]]; then
            log_success "Downloaded $DOWNLOADED_COUNT/$MISSING_DEPS_COUNT missing dependencies"
        fi
        if [[ $FAILED_COUNT -gt 0 ]]; then
            log_error "Failed to download $FAILED_COUNT dependencies"
        fi
    fi
else
    log_success "No missing dependencies found"
fi

echo ""

# Phase 5: Detect required NeoForge version
log_info "Phase 5: Detecting NeoForge version requirements..."
echo ""

# Get current NeoForge version from build.sh
CURRENT_NEOFORGE_VERSION=$(grep '^NEOFORGE_VERSION=' "$BASE_DIR/build.sh" | cut -d'"' -f2)
log_info "Current NeoForge version: $CURRENT_NEOFORGE_VERSION"

# Track the highest required NeoForge version
HIGHEST_NEOFORGE_MAJOR=0
HIGHEST_NEOFORGE_MINOR=0
HIGHEST_NEOFORGE_PATCH=0
HIGHEST_NEOFORGE_FULL=""
NEOFORGE_UPGRADE_NEEDED=false

# Check NeoForge requirements from ALL installed mods (not just updates)
log_info "Scanning all $TOTAL_MODS installed mods for NeoForge requirements..."
for filename in "${!MOD_INFO[@]}"; do
    IFS=':' read -r project_id current_ver latest_ver mod_name current_version_id latest_version_id <<< "${MOD_INFO[$filename]}"
    
    # Check the CURRENT version's dependencies (what we have installed now)
    version_data=$(curl -s --max-time 8 "https://api.modrinth.com/v2/version/$current_version_id" 2>/dev/null || echo "")
    
    
    if [[ -n "$version_data" ]] && echo "$version_data" | jq -e '.dependencies' >/dev/null 2>&1; then
        # Look for neoforge dependency
        neoforge_req=$(echo "$version_data" | jq -r '.dependencies[] | select(.project_id == "neoforge") | .version_id // empty' 2>/dev/null)
        
        if [[ -n "$neoforge_req" ]]; then
            # Parse version requirement - could be a range like [21.1.206,)
            # Extract the minimum version number
            min_version=$(echo "$neoforge_req" | sed 's/[\[\],()]//g' | awk '{print $1}')
            
            if [[ "$min_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                IFS='.' read -r major minor patch <<< "$min_version"
                
                # Compare versions
                if [[ $major -gt $HIGHEST_NEOFORGE_MAJOR ]] || \
                   [[ $major -eq $HIGHEST_NEOFORGE_MAJOR && $minor -gt $HIGHEST_NEOFORGE_MINOR ]] || \
                   [[ $major -eq $HIGHEST_NEOFORGE_MAJOR && $minor -eq $HIGHEST_NEOFORGE_MINOR && $patch -gt $HIGHEST_NEOFORGE_PATCH ]]; then
                    HIGHEST_NEOFORGE_MAJOR=$major
                    HIGHEST_NEOFORGE_MINOR=$minor
                    HIGHEST_NEOFORGE_PATCH=$patch
                    HIGHEST_NEOFORGE_FULL="$major.$minor.$patch"
                fi
            fi
        fi
    fi
done

# Compare with current version
if [[ -n "$HIGHEST_NEOFORGE_FULL" ]] && [[ "$CURRENT_NEOFORGE_VERSION" != "$HIGHEST_NEOFORGE_FULL" ]]; then
    IFS='.' read -r curr_major curr_minor curr_patch <<< "$CURRENT_NEOFORGE_VERSION"
    
    if [[ $HIGHEST_NEOFORGE_MAJOR -gt $curr_major ]] || \
       [[ $HIGHEST_NEOFORGE_MAJOR -eq $curr_major && $HIGHEST_NEOFORGE_MINOR -gt $curr_minor ]] || \
       [[ $HIGHEST_NEOFORGE_MAJOR -eq $curr_major && $HIGHEST_NEOFORGE_MINOR -eq $curr_minor && $HIGHEST_NEOFORGE_PATCH -gt $curr_patch ]]; then
        NEOFORGE_UPGRADE_NEEDED=true
        log_warning "NeoForge upgrade required: $CURRENT_NEOFORGE_VERSION → $HIGHEST_NEOFORGE_FULL"
        
        # Update build.sh if not in dry run
        if [[ "$DRY_RUN" != "true" ]]; then
            sed -i "s/^NEOFORGE_VERSION=\"[^\"]*\"/NEOFORGE_VERSION=\"$HIGHEST_NEOFORGE_FULL\"/" "$BASE_DIR/build.sh"
            log_success "Updated build.sh with NeoForge $HIGHEST_NEOFORGE_FULL"
            
            # Also update modrinth.launcher.json if it exists
            if [[ -f "$BASE_DIR/modrinth.launcher.json" ]]; then
                sed -i 's/"version": "[0-9.]*"/"version": "'"$HIGHEST_NEOFORGE_FULL"'"/' "$BASE_DIR/modrinth.launcher.json"
                log_success "Updated modrinth.launcher.json with NeoForge $HIGHEST_NEOFORGE_FULL"
            fi
        else
            log_info "Dry run - would update build.sh to NeoForge $HIGHEST_NEOFORGE_FULL"
            if [[ -f "$BASE_DIR/modrinth.launcher.json" ]]; then
                log_info "Dry run - would update modrinth.launcher.json to NeoForge $HIGHEST_NEOFORGE_FULL"
            fi
        fi
    else
        log_success "Current NeoForge version is sufficient"
    fi
else
    log_success "No NeoForge upgrade required"
fi

echo ""
log_wave "Wave 1 (Independent): ${#WAVE_1_INDEPENDENT[@]} mods"
log_wave "Wave 2 (Consumers):   ${#WAVE_2_CONSUMERS[@]} mods"
log_wave "Wave 3 (Providers):   ${#WAVE_3_PROVIDERS[@]} mods"
log_wave "Wave 4 (Complex):     ${#WAVE_4_COMPLEX[@]} mods"
echo ""

# Phase 6: Display results
log_info "Phase 6: Update Report"
echo ""

display_update() {
    local filename="$1"
    local wave_label="$2"
    
    IFS=':' read -r project_id current_ver latest_ver mod_name _ _ <<< "${MOD_INFO[$filename]}"
    
    printf "${wave_label} %-40s %s → %s\n" "$mod_name" "$current_ver" "$latest_ver"
    
    # Show latest version dependencies with resolved versions
    local latest_deps="${MOD_LATEST_DEPS[$project_id]:-}"
    if [[ -n "$latest_deps" ]]; then
        IFS=';' read -ra dep_array <<< "$latest_deps"
        local dep_info=""
        for dep_entry in "${dep_array[@]}"; do
            IFS=':' read -r dep_id version_id <<< "$dep_entry"
            if [[ -n "${PROJECT_TO_FILE[$dep_id]:-}" ]]; then
                local dep_file="${PROJECT_TO_FILE[$dep_id]}"
                IFS=':' read -r _ _ _ dep_name _ _ <<< "${MOD_INFO[$dep_file]}"
                local version_req="any"
                if [[ "$version_id" != "any" ]]; then
                    version_req="${VERSION_ID_TO_NUMBER[$version_id]:-$version_id}"
                fi
                dep_info="${dep_info:+$dep_info, }$dep_name [$version_req]"
            fi
        done
        [[ -n "$dep_info" ]] && printf "    ${PURPLE}└─ Requires: $dep_info${NC}\n"
    fi
}

if [[ ${#WAVE_1_INDEPENDENT[@]} -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_wave "Wave 1: Independent Mods (Safest - No dependencies)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for filename in "${WAVE_1_INDEPENDENT[@]}"; do
        display_update "$filename" "${GREEN}[W1]${NC}"
    done
    echo ""
fi

if [[ ${#WAVE_2_CONSUMERS[@]} -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_wave "Wave 2: Consumer Mods (Safe - Dependencies validated)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for filename in "${WAVE_2_CONSUMERS[@]}"; do
        display_update "$filename" "${CYAN}[W2]${NC}"
    done
    echo ""
fi

if [[ ${#WAVE_3_PROVIDERS[@]} -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_wave "Wave 3: Provider Mods (Safe - Test after updating)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for filename in "${WAVE_3_PROVIDERS[@]}"; do
        display_update "$filename" "${YELLOW}[W3]${NC}"
    done
    echo ""
fi

if [[ ${#WAVE_4_COMPLEX[@]} -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_wave "Wave 4: Complex Mods (Safe - Both deps and dependents)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for filename in "${WAVE_4_COMPLEX[@]}"; do
        display_update "$filename" "${MAGENTA}[W4]${NC}"
    done
    echo ""
fi

# Show unsafe updates
if [[ $UNSAFE_UPDATES -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error "UNSAFE UPDATES (Blocked - Dependency issues)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for project_id in "${!UPDATE_SAFETY[@]}"; do
        safety="${UPDATE_SAFETY[$project_id]}"
        [[ "$safety" == "safe" ]] && continue
        
        filename="${PROJECT_TO_FILE[$project_id]}"
        IFS=':' read -r _ current_ver latest_ver mod_name _ _ <<< "${MOD_INFO[$filename]}"
        
        printf "${RED}[✗]${NC} %-40s %s → %s\n" "$mod_name" "$current_ver" "$latest_ver"
        
        if [[ "$safety" == needs_deps:* ]]; then
            reason="${safety#needs_deps:}"
            printf "    ${RED}└─ Needs dependency updates first${NC}\n"
        elif [[ "$safety" == incompatible:* ]]; then
            reason="${safety#incompatible:}"
            printf "    ${RED}└─ Incompatible dependency requirements${NC}\n"
        fi
    done
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════════════════════"
log_info "Summary"
echo "═══════════════════════════════════════════════════════════════"
log_success "Total Mods Scanned:        $FOUND_MODS"
log_success "Safe Updates Available:    $SAFE_UPDATES"
if [[ $UNSAFE_UPDATES -gt 0 ]]; then
    log_error "Blocked (Unsafe):          $UNSAFE_UPDATES"
fi
log_info    "Already Current:           $CURRENT_MODS"
if [[ ${#MISSING_DEPS_TO_DOWNLOAD[@]} -gt 0 ]]; then
    log_warning "Missing Dependencies:      ${#MISSING_DEPS_TO_DOWNLOAD[@]}"
fi
echo ""
log_wave "Wave 1 (Independent):      ${#WAVE_1_INDEPENDENT[@]} updates"
log_wave "Wave 2 (Consumers):        ${#WAVE_2_CONSUMERS[@]} updates"
log_wave "Wave 3 (Providers):        ${#WAVE_3_PROVIDERS[@]} updates"
log_wave "Wave 4 (Complex):          ${#WAVE_4_COMPLEX[@]} updates"
echo "═══════════════════════════════════════════════════════════════"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    log_info "This was a dry run with full dependency validation."
    log_success "All shown updates are SAFE and have verified dependencies."
    echo ""
    log_info "To perform updates: DRY_RUN=false ./tools/smart-dependency-update.sh"
else
    # Phase 7: Download and install updates
    echo ""
    log_info "Phase 7: Downloading and installing updates..."
    echo ""
    
    DOWNLOAD_SUCCESS=0
    DOWNLOAD_FAILED=0
    TOTAL_TO_UPDATE=$SAFE_UPDATES
    CURRENT_UPDATE=0
    
    # Process all safe updates
    for project_id in "${!UPDATE_SAFETY[@]}"; do
        [[ "${UPDATE_SAFETY[$project_id]}" != "safe" ]] && continue
        
        CURRENT_UPDATE=$((CURRENT_UPDATE + 1))
        filename="${PROJECT_TO_FILE[$project_id]}"
        IFS=':' read -r _ current_ver latest_ver mod_name _ latest_version_id <<< "${MOD_INFO[$filename]}"
        
        printf "\r\033[K[%d/%d] Downloading: %s" "$CURRENT_UPDATE" "$TOTAL_TO_UPDATE" "$mod_name"
        
        # Get download URL for the latest version
        version_data=$(curl -s --max-time 10 "https://api.modrinth.com/v2/version/$latest_version_id" 2>/dev/null || echo "")
        
        if [[ -n "$version_data" ]] && echo "$version_data" | jq -e '.files[0].url' >/dev/null 2>&1; then
            download_url=$(echo "$version_data" | jq -r '.files[0].url')
            new_filename=$(echo "$version_data" | jq -r '.files[0].filename')
            
            # Download the new version
            if curl -s --max-time 60 -L -o "$MODS_DIR/$new_filename" "$download_url" 2>/dev/null; then
                # Remove old version
                rm -f "$MODS_DIR/$filename"
                DOWNLOAD_SUCCESS=$((DOWNLOAD_SUCCESS + 1))
                printf "\r\033[K[%d/%d] ✓ Updated: %s\n" "$CURRENT_UPDATE" "$TOTAL_TO_UPDATE" "$mod_name"
            else
                DOWNLOAD_FAILED=$((DOWNLOAD_FAILED + 1))
                printf "\r\033[K[%d/%d] ✗ Failed: %s\n" "$CURRENT_UPDATE" "$TOTAL_TO_UPDATE" "$mod_name"
            fi
        else
            DOWNLOAD_FAILED=$((DOWNLOAD_FAILED + 1))
            printf "\r\033[K[%d/%d] ✗ No download URL: %s\n" "$CURRENT_UPDATE" "$TOTAL_TO_UPDATE" "$mod_name"
        fi
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log_info "Update Results"
    echo "═══════════════════════════════════════════════════════════════"
    log_success "Successfully Updated:  $DOWNLOAD_SUCCESS/$TOTAL_TO_UPDATE"
    if [[ $DOWNLOAD_FAILED -gt 0 ]]; then
        log_error "Failed:                $DOWNLOAD_FAILED/$TOTAL_TO_UPDATE"
    fi
    echo "═══════════════════════════════════════════════════════════════"
    
    # Signal to build.sh that content changed by touching mods directory
    if [[ $DOWNLOAD_SUCCESS -gt 0 ]]; then
        touch "$MODS_DIR/.updated"
        log_info "Created update marker for build script"
    fi
fi

echo ""
