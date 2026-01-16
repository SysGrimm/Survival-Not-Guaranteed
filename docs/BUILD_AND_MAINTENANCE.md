# Build and Maintenance Guide

## Build System (`tools/build.sh`)

The `tools/build.sh` script is the central engine of the project. It converts the local development state into a distributable `.mrpack` file.

### Core Workflow
1.  **Scanning**: The script scans the `mods/` directory for `.jar` files.
2.  **Hashing**: Calculates SHA-512 hashes for every file.
3.  **Resolution**: 
    *   Queries Modrinth API to find download URLs.
    *   Uses cached responses (`.modrinth_cache`) to speed up subsequent builds.
    *   **Strict Mode**: If `STRICT_EXTERNAL_DOWNLOADS` is set, the build fails if a URL cannot be found.
4.  **Packaging**:
    *   Generates `modrinth.index.json`.
    *   Bundles `config/`, `client-overrides/` (as `overrides/`), and `resourcepacks/` (if configured as overrides).
    *   Produces `Survival Not Guaranteed-<VERSION>.mrpack`.

### Usage
```bash
./tools/build.sh
```
*   **Output**: `.mrpack` file in the root directory.
*   **Logs**: Terminal output indicates which mods were found on Modrinth vs. which are treated as manual overrides (if permitted).

### Handling Manual Overrides
If a mod is custom or removed from Modrinth:
1.  Ensure the `.jar` is in `mods/`.
2.  The build script will detect it has no remote URL.
3.  Based on configuration, it will either:
    *   Fail (Strict Mode).
    *   Bundle the file inside the zip (Permissive Mode - default).

---

## Smart Update System (`tools/smart-dependency-update.sh`)

We use a "Wave-Based" update strategy to safely upgrade 200+ mods without breaking dependencies.

### The Wave Strategy
updates are applied in 4 distinct waves to ensure stability:
1.  **Wave 1: Independent Mods** (Library mods, API cores) - *Safe to update first.*
2.  **Wave 2: Consumers** (Mods that depend on Wave 1) - *Updated once APIs are stable.*
3.  **Wave 3: Providers** (Content mods that provide systems) - *Heavy lifters.*
4.  **Wave 4: Complex/Unsafe** (Large overhauls, delicate mods) - *Requires manual review.*

### Usage
```bash
./tools/smart-dependency-update.sh
```
*   **Dry Run**: By default, it runs in "Dry Run" mode to show what would happen.
*   **Execute**: Set `DRY_RUN=false` to apply changes (Warning: This downloads new jars and deletes old ones).

### Pinning Mods & Resource Packs
To prevent a mod or resource pack from updating (e.g., if a new version breaks the pack):
1.  Edit `mods/.pinned`.
2.  Add an entry in the format: `project_id:version:reason`.
    *   Example: `olO1TaXd:72:Incompatible update breaks visual stack`
3.  **Note**: This system now supports Resource Packs as well (Phase 1c of the update script checks this file).

---

## Maintenance Workflow

### Adding a New Mod
1.  Download the `.jar` file manually.
2.  Place it in the `mods/` directory.
3.  (Optional) Run `./tools/smart-dependency-update.sh` to see if it integrates well with existing dependencies.
4.  Run `./tools/build.sh` to include it in the next pack release.

### Removing a Mod
1.  Delete the `.jar` from `mods/`.
2.  Run `./tools/build.sh`.

### Updating the Visual Stack
1.  **Resource Packs**: 
    *   Update standard packs via Modrinth.
    *   Update Override packs by replacing the zip in `resourcepacks/` and updating `options.txt` in `client-overrides`.
2.  **Shaders**:
    *   Update `shaderpacks/`.
    *   Ensure `options.txt` references the correct shader file name.
