# Troubleshooting Reference

## Common Issues & Solutions

### 1. Game Crash on Startup (Rendering)

**Symptom**: Game crashes immediately upon launching, often mentioning "textures" or "models".  
**Cause**: The **Patrix Resource Pack** requires specific rendering features that standard NeoForge does not provide.  
**Solution**:
*   Ensure **Entity Texture Features (ETF)** and **Entity Model Features (EMF)** are installed.
*   Verify **Fusion** and **Visuality** are present.
*   *Note: OptiFine is NOT supported.*

### 2. Missing Textures / "Purple and Black" Blocks

**Symptom**: Some blocks (fences, leaves) appear broken or have placeholder text.  
**Cause**: Patrix 1.21 Basic pack has some incomplete CTM (Connected Texture Mapping) definitions for 1.21.  
**Solution**:
*   We use a custom **Patrix CTM Override** pack.
*   Ensure `Patrix_32x_CTMOverride_1.20_1.21.zip` is loaded **ABOVE** the standard Patrix pack in the Resource Pack menu.
*   This is handled automatically by the `client-overrides/config/options.txt`.

### 3. Build Script Fails ("Missing Mirrors")

**Symptom**: `tools/build.sh` reports it cannot find download URLs for mods.  
**Cause**: Modrinth API might be down, or the file hash does not match any known version on Modrinth.  
**Solution**:
*   Check internet connection.
*   If the mod is custom (not on Modrinth), this is expected. The build script will bundle it locally if not in Strict Mode.
*   If the mod *should* be on Modrinth, try re-downloading the jar to ensure the hash is correct.

### 4. Square Moon / Shader Issues

**Symptom**: The moon looks like a square despite using shaders.  
**Cause**: Style conflict between Complementary Unbound and Patrix.  
**Solution**: 
*   In Shader Settings, ensure `SUN_MOON_STYLE_DEFINE` is set to `1` (Reimagined).

### 5. Update Script Skips Mods

**Symptom**: `smart-dependency-update.sh` refuses to update a mod.  
**Cause**: The mod is likely in the "Unsafe" wave or has a dependency conflict.  
**Solution**:
*   Check the console output for "UNSAFE" warnings.
*   Manually update the mod if you are sure it is safe, or check `mods/.pinned` to see if it was manually locked.
