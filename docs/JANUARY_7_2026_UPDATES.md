# January 7, 2026 - System Updates

## Overview
Comprehensive modpack updates including version increment, mod changes, configuration updates, and build system improvements.

## Version Changes
- **New Version**: 3.14.6
- **Previous Version**: 3.14.3
- **Release Date**: January 7, 2026

## Mod Changes

### Added Mods (2)
- **Botany Pots** (v21.1.41)
  - SHA1: 4f216887a3b95d6abde0f2458a94487523531a1c
  - Universal mod (client + server)
  - Resource: Modrinth
  
- **LambDynamicLights** (v4.8.7+1.21.1)
  - SHA1: b7dc4acb053b98810faffab19fde0f18b453a824
  - Client-only mod
  - Resource: Modrinth

### Removed Mods (3)
- **Create Wizardry** (v0.3.5)
  - Reason: Mod incompatibility or deprecation
  
- **EC Iron's Spells 'n Spellbooks Plugin** (v1.0.1)
  - Reason: Dependency removed (Iron's Spellbooks)
  
- **Iron's Spellbooks** (v3.14.8)
  - Reason: Causing server errors and mod conflicts

### Updated Mods (1)
- **SuperMartijn642 Core Lib**
  - Old: v1.1.18b
  - New: v1.1.19
  - SHA1: 7288a5f11ffedc72495d0afaca64f2e83f9c9c0f

## Configuration Changes

### Cold Sweat (`config/coldsweat/item.toml`)
- **Removed Custom Armor Insulation**: Cleaned up modded armor entries
- **Before**: 12 custom armor pieces with insulation values
- **After**: Only vanilla leather armor insulation retained
- **Impact**: Simplifies temperature mechanics, removes dependency on removed mods

### Open Parties and Claims (`config/openpartiesandclaims-server.toml`)
- **Permission System**: Changed from `prometheus` → `permission_api`
- **Party System**: Changed from `argonauts_guilds` → `default`
- **Reason**: Fallback to vanilla systems for better compatibility

### Launcher Profiles (`launcher_profiles.json`)
- **Added**: Official server configuration
  - Server Name: "Survival Not Guaranteed Official Server"
  - Address: `survivalnotguaranteed.hardmode.pro:26635`
  - Description: The official multiplayer server

## Build System Improvements

### build.sh Updates
1. **API Rate Limiting**: Added 0.25s delay between API calls to prevent Cloudflare errors
   ```bash
   api_rate_limit() {
     sleep 0.25  # ~4 requests/second
   }
   ```

2. **Enhanced Version Extraction**: Improved mod name/version parsing from filenames

3. **Mod Comparison Logic**: Better detection of same mods with different versions

4. **Changelog Generation**: 
   - Smarter mod change detection
   - Proper display names with title casing
   - Version tracking improvements

5. **Manual Environment Overrides**:
   - Added Carry On as universal (requires server-side)
   - Added Glitchcore as universal
   - Better handling of library mods

6. **Removed CurseForge Support**: Simplified to Modrinth-only workflow

### Smart Dependency Update Script (`tools/smart-dependency-update.sh`)
- Replaced checkmark/cross symbols with `[+]`/`[-]` for better terminal compatibility
- Improved readability across different console environments

### Tools Documentation (`tools/README.md`)
- Removed "forbidden" emoji from legacy scripts section
- Improved markdown compatibility

## Server Setup

### New Server List Files
- **Created**: `client-overrides/servers.dat`
- **Created**: `overrides/servers.dat`
- **Created**: `servers.dat.original`
- **Content**: Pre-configured official server entry for easy multiplayer access

## Documentation Cleanup

### README.md
- Removed excessive emoji usage
- Improved markdown compatibility
- Cleaner formatting throughout

### RELEASE_NOTES.md
- Removed emoji from "Technical Details" heading
- Professional formatting

### CHANGELOG.md
- Updated version numbers (3.14.3 → 3.14.6)
- Updated release date
- Updated mod counts (146 → 145 mods)
- Universal mods: 133 → 135
- Client-only mods: 13 → 10

## Build System Statistics

### Final Mod Counts
- **Total Mods**: 145 (down from 146)
- **Universal Mods**: 135 (up from 133)
- **Client-Only Mods**: 10 (down from 13)
- **Server-Only Mods**: 0
- **External Download Coverage**: 100%

### File Cleanup
- Removed: Outdated manual overrides in `mod_overrides.conf`
- Added: Test scripts for API debugging (`test_lookup.sh`, `test_rate_limit.sh`)

## Technical Improvements

### Modrinth API Integration
1. **Better Error Handling**: Detects Cloudflare rate limiting (error 1015)
2. **Automatic Retry**: Waits 3 seconds and retries once on rate limit
3. **Proper Algorithm Specification**: Uses `?algorithm=sha1` parameter
4. **User-Agent Headers**: Proper HTTP headers for API compliance

### JSON Parsing Fixes
- Safer jq queries with null checks
- Proper array validation before parsing
- Inline processing to avoid function complexity

### Version Constraint Resolution
- Exact Minecraft version matching (1.21.1)
- NeoForge loader detection
- Fallback to compatible versions when exact match unavailable

## Testing & Validation

### Scripts Added
1. **test_lookup.sh**: Tests hash-based mod lookup with specific examples
2. **test_rate_limit.sh**: Simulates rapid API calls to verify rate limiting

### Validation Performed
- All 145 mods verified with Modrinth API
- Hash integrity confirmed
- Download URLs validated
- Client/server environment detection verified

## Migration Notes

### For Server Operators
1. **Cold Sweat**: Custom armor insulation removed - only vanilla leather provides insulation
2. **Party System**: Now using default party system instead of Argonauts Guilds
3. **Permissions**: Now using Permission API instead of Prometheus
4. **Iron's Spellbooks**: Removed - any existing magic items/structures will be cleaned up

### For Players
1. **New Mods Available**:
   - Botany Pots: Automated crop growing
   - LambDynamicLights: Dynamic lighting from held items (client-only)

2. **Removed Features**:
   - Iron's Spellbooks magic system
   - Create Wizardry integration
   - Custom temperature armor

3. **Server List**: Official server now pre-configured in launcher

## Commit Information

### Files Modified (11)
- CHANGELOG.md
- README.md
- RELEASE_NOTES.md
- build.sh
- config/coldsweat/item.toml
- config/openpartiesandclaims-server.toml
- launcher_profiles.json
- mod_overrides.conf
- modrinth.index.json
- tools/README.md
- tools/smart-dependency-update.sh

### Files Added (5)
- client-overrides/servers.dat
- overrides/servers.dat
- servers.dat.original
- test_lookup.sh
- test_rate_limit.sh

### Total Changes
- 16 files changed
- ~500+ lines modified
- 3 mods removed, 2 added, 1 updated
- Multiple configuration and documentation improvements

## Next Steps

1. ✅ All changes documented
2. ⏳ Stage changes for commit
3. ⏳ Commit with descriptive message
4. ⏳ Push to main branch
5. ⏳ Build and test new .mrpack
6. ⏳ Create GitHub release for v3.14.6

## Notes

- This update focuses on stability and compatibility
- Removal of Iron's Spellbooks resolves server startup errors
- Build system now more robust with rate limiting
- Better terminal compatibility across different environments
