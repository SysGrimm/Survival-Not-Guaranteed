# Survival Not Guaranteed - Compatibility Fixes Summary

## Overview
This document tracks compatibility issues discovered during the mod update process and the solutions implemented.

## Active Compatibility Pins

### 1. Fragmentum ↔ Elixirum
- **Issue**: Breaking API change in Fragmentum 2.x removed `Deferred` class
- **Affected Mods**:
  - Fragmentum (library)
  - Ars Elixirum (dependent mod)
- **Current Versions**:
  - Fragmentum: **0.0.13** (pinned from 2.1.0)
  - Elixirum: **0.2.2**
- **Status**: Pinned until Elixirum updates past 0.2.2
- **Auto-release**: Yes - when elixirum > 0.2.2

### 2. Relics ↔ Reliquified Ars Nouveau
- **Issue**: Breaking API change in Relics 0.11+ removed/relocated `IRenderableCurio` interface
- **Affected Mods**:
  - Relics (library)
  - Reliquified Ars Nouveau (dependent mod)
- **Current Versions**:
  - Relics: **0.10.7.6** (pinned from 0.11.5.1)
  - Reliquified Ars Nouveau: **0.6.1**
- **Status**: Pinned until Reliquified Ars Nouveau updates past 0.6.1
- **Auto-release**: Yes - when reliquified_ars_nouveau > 0.6.1

### 3. JEI ↔ ctgui
- **Issue**: Breaking API change in JEI 19.27+ changed `RecipesGui` constructor signature
- **Affected Mods**:
  - Just Enough Items (library/API)
  - CraftTweaker GUI (dependent mod with mixins)
- **Current Versions**:
  - JEI: **19.25.1.334** (pinned from 19.27.0.340)
  - ctgui: **0.3.1**
- **Status**: Pinned until ctgui updates past 0.3.1
- **Auto-release**: Yes - when ctgui > 0.3.1

## Technical Details

### Fragmentum Downgrade
```bash
# Issue discovered: Jan 5, 2026
# Error: ClassNotFoundException: dev.obscuria.fragmentum.api.Deferred
# Location: elixirum.mixins.json:MixinEntity

# Downgrade applied:
rm mods/fragmentum-neoforge-1.21.1-2.1.0.jar
curl -L -o mods/fragmentum-neoforge-1.21.1-0.0.13.jar \
  https://cdn.modrinth.com/data/49C5QgTK/versions/fSK1b6R6/fragmentum-neoforge-1.21.1-0.0.13.jar
```

### Relics Downgrade
``# JEI Downgrade
```bash
# Issue discovered: Jan 5, 2026
# Error: MixinTransformerError - InvalidInjectionException
# Details: @Inject annotation on addButton could not find any targets matching '<init>'
# Location: ctgui.mixins.json:RecipesGuiMixin
# Cause: JEI 19.27.0.340 (released Jan 5, 2026) changed RecipesGui constructor signature

# Version history:
# - Dec 21, 2025: JEI 19.25.1.334 released (compatible)
# - Dec 29, 2025: JEI 19.27.x series begins with constructor changes
# - Jan 5, 2026: JEI 19.27.0.340 released, breaking ctgui mixins

# Downgrade applied:
rm mods/jei-1.21.1-neoforge-19.27.0.340.jar
curl -L -o mods/jei-1.21.1-neoforge-19.25.1.334.jar \
  https://cdn.modrinth.com/data/u6dRKJwZ/versions/UJRXzDfp/jei-1.21.1-neoforge-19.25.1.334.jar
```

##`bash
# Issue discovered: Jan 5, 2026

# JEI pin
u6dRKJwZ:19.25.1.334:if:W38R1bwF:<=:0.3.1:Required by ctgui 0.3.1 - breaking changes in JEI 19.27+
# Error: ClassNotFoundException: it.hurts.sskirillss.relics.items.relics.base.IRenderableCurio
# Location: reliquified_ars_nouveau.init.ItemRegistry:33

# Downgrade applied:
rm mods/relics-1.21.1-0.11.5.1.jar
curl -L -o mods/relics-1.21.1-0.10.7.6.jar \
  https://cdn.modrinth.com/data/OCJRPujW/versions/pHqkVRdi/relics-1.21.1-0.10.7.6.jar
```

## Pin File Configuration

Location: `mods/.pinned`

```
# Fragmentum pin
49C5QgTK:0.0.13:if:oYe4cXFm:<=:0.2.2:Required by elixirum 0.2.2 - elixirum needs old Deferred API

# Relics pin
OCJRPujW:0.10.7.6:if:qNOCEdeg:<=:0.6.1:Required by reliquified_ars_nouveau 0.6.1 - needs IRenderableCurio interface
```

### Pin Format Explanation
```
project_id:version:if:dependent_project_id:operator:version:reason
```

- **project_id**: Modrinth project ID of the pinned mod
- **version**: Version to pin at
- **if**: Keyword indicating conditional pin
- **dependent_project_id**: Modrinth project ID of the mod that requires this version
- **operator**: Comparison operator (<=, <, >=, >, ==)
- **version**: Version constraint for dependent mod
- **reason**: Human-readable explanation

## Automatic Pin Release

The pinning system automatically releases pins when the dependent mod updates beyond the constraint:

1. **During each update check**, the script:
   - Loads all pins from `mods/.pinned`
   - For conditional pins, finds the current version of the dependent mod
   - Evaluates the version constraint (e.g., `elixirum_version <= 0.2.2`)
   - If constraint is **still true**: Pin remains active
   - If constraint is **now false**: Pin automatically releases, mod can update

2. **Example scenario**:
   ```
   Current state:
   - Elixirum: 0.2.2
   - Fragmentum: 0.0.13 (pinned)
   - Constraint: elixirum <= 0.2.2 → TRUE → Pin active
   
   After elixirum updates to 0.2.3:
   - Elixirum: 0.2.3
   - Fragmentum: 0.0.13 (checking pin...)
   - Constraint: elixirum <= 0.2.2 → FALSE → Pin released!
   - Fragmentum can now update to 2.1.0+
   ```

## Bug Reports Filed

### 1. Reliquified Ars Nouveau
- **File**: `docs/bug-report-reliquified-ars-nouveau.md`
- **Status**: Ready to submit to developer
- **Platform**: Discord (https://discord.gg/pHren9yxzW)
- **Summary**: Needs update to support Relics 0.11+ API changes

### 2. Elixirum

### 3. ctgui (CraftTweaker GUI)
- **Status**: Monitoring for updates
- **Issue**: Needs update to support JEI 19.27+ API changes
- **Breaking Change**: RecipesGui constructor signature changed in JEI 19.27+
- **Note**: Mixin injection targeting old constructor fails with current JEI
- **Status**: Monitoring for updates
- **Issue**: Needs update to support Fragmentum 2.x API
- **Note**: Modrinth dependency metadata shows no version constraint despite code requirement

## Update Script Changes

### New Features Added
1. **Conditional Pinning System**
   - Pins with version constraints on dependent mods
   - Automatic release when constraints no longer apply
   - Version comparison using semantic versioning

2. **Pin File Format**
   - Simple format: `project_id:version:reason`
   - Conditional format: `project_id:version:if:dependent_id:operator:version:reason`
   - Comments supported with `#`

3. **Version Comparison Function**
   - Supports operators: `<=`, `<`, `>=`, `>`, `==`
   - Handles semantic versioning with `sort -V`
   - Normalizes versions by removing prefixes/suffixes

## Monitoring Plan

### Weekly Checks
- Check Elixirum Modrinth page for updates past 0.2.2
- Check Reliquified Ars Nouveau Modrinth page for updates past 0.6.1
- Check ctgui Modrinth page for updates past 0.3.1
- Review changelogs for compatibility mentions

### When Updates Detected
1. Developer releases compatible version
2. Run update script - pins auto-release
3. Verify game launches successfully
4. Update this document with resolution date
5. Remove entries from "Active Compatibility Pins" section

## Lessons Learned

1. **Dependency Metadata Gaps**: Modrinth dependency metadata doesn't always specify version constraints, even when code has hard requirements

2. **Breaking Changes**: Library mods can introduce breaking API changes without requiring dependent mods to update their metadata
Rapid Update Cycles**: JEI updated 7 times between Dec 21 and Jan 5, introducing breaking changes mid-cycle

4. **Mixin Fragility**: Mods using mixins to inject into library mod code are especially vulnerable to constructor/method signature changes

5. **Update Timing**: ~4 month gap between Relics 0.11.0 (breaking change) and discovery highlights need for proactive monitoring

6. **Automation Value**: Conditional pinning system prevents manual tracking while ensuring compatibility

7. **Same-Day Releases**: Breaking changes can be released on the same day as testing, requiring immediate rollback capa
4. **Automation Value**: Conditional pinning system prevents manual tracking while ensuring compatibility

## Related Documentation
- Main bug report: `docs/bug-report-reliquified-ars-nouveau.md`
- Update script: `tools/smart-dependency-update.sh`
- Pin file: `mods/.pinned`4  
**Active Pins**: 3  
**Resolved Pins**: 0

## Compatibility Matrix

| Library Mod | Version | Last Breaking Change | Dependent Mod | Version | Compatibility Status |
|-------------|---------|---------------------|---------------|---------|---------------------|
| Fragmentum | 0.0.13 | v2.x removed Deferred API | Elixirum | 0.2.2 | ⚠️ Pinned |
| Relics | 0.10.7.6 | v0.11+ removed IRenderableCurio | Reliquified Ars Nouveau | 0.6.1 | ⚠️ Pinned |
| JEI | 19.25.1.334 | v19.27+ changed constructor | ctgui | 0.3.1 | ⚠️ Pinned |

### Status Legend
- ✅ **Compatible**: Latest versions work together
- ⚠️ **Pinned**: Conditionally pinned, awaiting dependent mod update
- ❌ **Broken**: Known incompatibility, no workaround available
---

**Last Updated**: January 5, 2026  
**Modpack Version**: 3.14.x  
**Active Pins**: 2  
**Resolved Pins**: 0
