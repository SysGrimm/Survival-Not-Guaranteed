# Quick Reference Guide

**Last Updated:** January 5, 2026

## Common Commands

### Check for Updates (Dry Run)
```bash
./tools/smart-dependency-update.sh
```
Shows what updates are available without making changes.

### Apply Updates
```bash
DRY_RUN=false ./tools/smart-dependency-update.sh
```
Downloads and installs all safe updates, auto-updates NeoForge version if needed.

### Build Modpack
```bash
./build.sh
```
Generates `.mrpack` file with auto-incremented version.

### Full Update Workflow
```bash
# 1. Check what's available
./tools/smart-dependency-update.sh

# 2. Apply updates
DRY_RUN=false ./tools/smart-dependency-update.sh

# 3. Build new version
./build.sh
```

---

## What Each System Does

### Smart Update System (`tools/smart-dependency-update.sh`)
- **Phase 1:** Identifies all 142 mods using SHA-512 hashes
- **Phase 2:** Resolves version constraints from Modrinth API
- **Phase 3:** Validates update safety (checks dependencies)
- **Phase 4:** Categorizes by dependency relationship
- **Phase 4.5:** Finds and prepares missing dependencies
- **Phase 5:** Scans ALL mods for NeoForge requirements, auto-updates build.sh
- **Phase 6:** Displays comprehensive update report
- **Phase 7:** Downloads updates, replaces files, creates version bump marker

### Build System (`build.sh`)
- **Version Detection:** Queries GitHub/Modrinth for latest version
- **Change Detection:** Checks for `mods/.updated` marker or content hash changes
- **Version Increment:** Bumps version when changes detected
- **Mod Scanning:** Identifies all mods via SHA-512 hash lookup
- **Manifest Generation:** Creates modrinth.index.json with CDN URLs
- **Packaging:** Generates `.mrpack` file ready for distribution

---

## Understanding Output

### Update Script Phases
```
[✓] Found 142 mods on Modrinth          # Phase 1 complete
[✓] Version constraints resolved        # Phase 2 complete
[✓] Safety validation complete          # Phase 3 complete
[✓] No missing dependencies found       # Phase 4.5 complete
[✓] No NeoForge upgrade required        # Phase 5 complete (or will show upgrade)
[✓] Successfully Updated: 83/83         # Phase 7 complete
```

### Build Script Output
```
- Update marker detected: mods were updated    # Version will increment
+ New version: 3.14.4                          # Version incremented
- Using configured NeoForge version: 21.1.215  # NeoForge version in use
Scanning mods in: mods (142 mod files found)   # Processing all mods
+ Modrinth index generated with 142 mods       # Manifest created
Output: Survival Not Guaranteed-3.14.4.mrpack  # Final output file
```

---

## Wave Categories Explained

**Wave 1 - Independent (Safest)**
- No dependencies on other installed mods
- Can update first without risk
- Example: Standalone content mods

**Wave 2 - Consumers**
- Depend on other mods (providers)
- Update after their dependencies
- Example: Create addons (depend on Create)

**Wave 3 - Providers (Riskiest)**
- Other mods depend on them
- Breaking changes affect multiple mods
- Example: Library mods like Geckolib

**Wave 4 - Complex**
- Both provider and consumer
- Require careful coordination
- Example: Create (provides API, depends on Flywheel)

---

## Version Numbering

### Format: `major.minor.patch`
Example: `3.14.4`

### Increment Rules
- **Mod Changes:** Increment minor (3.14.3 → 3.14.4)
- **Config Changes:** Increment patch (3.14.3 → 3.14.4)
- **Infrastructure:** Increment patch (3.14.3 → 3.14.4)

### When Version Increments
1. Update script downloads mods → creates `mods/.updated` marker
2. Build script detects marker → increments version
3. New `.mrpack` file created with new version

---

## File Locations

### Scripts
- `tools/smart-dependency-update.sh` - Update system (687 lines)
- `build.sh` - Build system (1692 lines)

### Documentation
- `docs/SMART_UPDATE_SYSTEM.md` - Complete update system docs
- `docs/BUILD_SYSTEM.md` - Complete build system docs
- `docs/CHANGELOG_SESSION.md` - All changes made
- `docs/QUICK_REFERENCE.md` - This file

### Configuration
- Line 28 in `build.sh`: `MODS_DIR="mods"`
- Line 33 in `build.sh`: `NEOFORGE_VERSION="21.1.215"`
- Line 25 in `smart-dependency-update.sh`: `MINECRAFT_VERSION="1.21.1"`
- Line 26 in `smart-dependency-update.sh`: `LOADER_TYPE="neoforge"`

### Generated Files
- `.content_hash` - Content change tracking (ignored by git)
- `mods/.updated` - Update marker (temporary, auto-deleted)
- `modrinth.index.json` - Manifest file (included in .mrpack)
- `*.mrpack` - Final modpack files (ignored by git)

---

## Troubleshooting

### "No updates available" but I know there are
```bash
# Check if you're in dry run mode (default)
DRY_RUN=false ./tools/smart-dependency-update.sh
```

### Version didn't increment after updates
```bash
# Manually create marker and rebuild
touch mods/.updated
./build.sh
```

### NeoForge version not detected
```bash
# Update script now scans ALL mods every run (v2.0)
# If still not working, manually check build.sh line 33
grep NEOFORGE_VERSION build.sh
```

### Build fails with API errors
```bash
# Check internet connection
curl -s https://api.modrinth.com/v2/projects | jq .

# If timeout issues, increase timeout in scripts
# smart-dependency-update.sh line 103: --max-time 8 → --max-time 15
```

### Missing dependencies detected
```bash
# Script will try to download automatically
# If not on Modrinth, manually download and place in mods/
# Check crash logs for required dependencies
```

---

## Performance

### Update Script (142 mods)
- **Dry Run:** ~115 seconds
- **With Downloads (83 mods):** ~256 seconds
- **API Calls:** ~610 total

### Build Script (142 mods)
- **Full Build:** ~74 seconds
- **API Calls:** ~284 total

---

## Safety Features

✅ **Hash-Based Identification** - 100% accurate mod identification  
✅ **Dependency Validation** - Never breaks dependency chains  
✅ **Loader Validation** - Only downloads NeoForge-compatible versions  
✅ **Version Constraints** - Respects version requirements  
✅ **Automatic Rollback** - Old files kept until download succeeds  
✅ **API Timeouts** - Scripts never hang indefinitely  
✅ **Error Handling** - Graceful failures with clear messages  

---

## Integration Flow

```
┌────────────────────────────────────────────────────────┐
│  Update Script                                          │
│  - Scans mods                                          │
│  - Validates dependencies                               │
│  - Downloads updates                                    │
│  - Creates mods/.updated marker ──────────────┐        │
│  - Updates build.sh if NeoForge needed        │        │
└────────────────────────────────────────────────────────┘
                                                 │
                                                 │ Marker
                                                 │ Signal
                                                 ▼
┌────────────────────────────────────────────────────────┐
│  Build Script                                           │
│  - Detects marker                                      │
│  - Increments version (3.14.3 → 3.14.4)                │
│  - Scans all mods                                       │
│  - Generates manifest                                   │
│  - Creates .mrpack file                                │
│  - Removes marker                                      │
└────────────────────────────────────────────────────────┘
```

---

## Status Indicators

### Update Script
- `[INFO]` - Informational messages
- `[✓]` - Success, task completed
- `[WARN]` - Warning, may need attention
- `[ERROR]` - Error occurred
- `[WAVE]` - Wave categorization info

### Build Script
- `+` - Positive action (version set, file created)
- `-` - Informational status
- `→` - Processing item

---

## Best Practices

1. **Always dry run first:** See what will change before applying
2. **Review wave reports:** Understand dependency relationships
3. **Test after updates:** Verify modpack loads in Minecraft
4. **Keep backups:** Save old .mrpack files before major updates
5. **Check NeoForge:** Verify correct version after updates
6. **Monitor logs:** Watch for missing dependency warnings

---

## Resources

- **Modrinth API Docs:** https://docs.modrinth.com/api-spec/
- **NeoForge Docs:** https://docs.neoforged.net/
- **Modpack Format:** https://docs.modrinth.com/docs/modpacks/format/

---

## Quick Checklist

Before updating:
- [ ] Check current modpack works
- [ ] Backup current .mrpack file
- [ ] Run dry run to see changes
- [ ] Review update report

After updating:
- [ ] Verify version incremented
- [ ] Check NeoForge version correct
- [ ] Test modpack in Minecraft
- [ ] Check for missing dependencies

---

## Support

For issues or questions:
1. Check `docs/TROUBLESHOOTING.md`
2. Review `docs/SMART_UPDATE_SYSTEM.md` for details
3. Check `latest.log` in Minecraft for errors
4. Verify all dependencies installed

---

**Remember:** The system is designed to be safe and automatic. Trust the dependency validation, but always test the final modpack!
