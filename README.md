# Survival Not Guaranteed

**A NeoForge 1.21.1 Survival RPG Modpack**

This repository contains the source configuration and build tools for the "Survival Not Guaranteed" modpack. It uses a fully automated build and update system to ensure stability and ease of maintenance.

## Documentation

*   [**System Architecture**](docs/ARCHITECTURE.md): Overview of the modpack structure, visual stack (Patrix/Shaders), and file layout.
*   [**Build & Maintenance**](docs/BUILD_AND_MAINTENANCE.md): Instructions for using `tools/build.sh` and the `smart-dependency-update.sh` system.
*   [**Troubleshooting**](docs/TROUBLESHOOTING.md): Solutions for common rendering and build issues.

## Quick Start (Development)

1.  **Install Dependencies**: ensure you have `bash`, `curl`, `jq`, and `sha512sum`.
2.  **Build the Pack**:
    ```bash
    ./tools/build.sh
    ```
    This generates a `.mrpack` file ready for import into Modrinth App, Prism Launcher, etc.

3.  **Update Mods**:
    ```bash
    ./tools/smart-dependency-update.sh
    ```

## Visual Experience

This pack is designed with a specific visual target:
*   **Textures**: Patrix 32x (Basic + Custom CTM Override)
*   **Shaders**: Complementary Unbound
*   **Engine**: Iris & Oculus (No OptiFine)

*Consult [Architecture](docs/ARCHITECTURE.md) for details on the visual stack.*
