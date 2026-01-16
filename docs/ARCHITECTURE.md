# System Architecture

## Project Overview
**Survival Not Guaranteed** is a high-fidelity NeoForge 1.21.1 modpack focused on challenging survival and RPG elements. The project is engineered for automated maintenance, strict dependency management, and a premium visual experience.

### Technical Specifications
- **Loader**: NeoForge 1.21.1
- **Distribution Format**: `.mrpack` (Modrinth Modpack Format)
- **Download Strategy**: 100% External Downloads (No binary distribution in git)
- **Mod Count**: ~200 Mods

---

## The `.mrpack` Architecture

The `.mrpack` file behaves similarly to a zip file but follows strict Modrinth specifications. It allows for efficient distribution by decoupling the configuration files from the mod binaries.

### Internal Structure
When you run `tools/build.sh`, the resulting archive contains:

1.  **`modrinth.index.json`**  
    The manifest. It instructs the launcher *where* to download the mods (URLs) and *what* their hashes are. It does **not** contain the `.jar` files themselves (unless a manual override forced a local bundle).

2.  **`overrides/` folder**  
    This directory's contents are copied over the Minecraft instance directory by the launcher.
    *   **Source**: Populated from the `config/` and `client-overrides/` directories in this repository.
    *   **Purpose**: Delivers configuration files (`config/*`), scripts (`kubejs/`), and resource packs (`resourcepacks/`).

3.  **Environment Handling**
    *   **Client Specifics**: `client-overrides/config/options.txt` dictates the specialized resource pack order.
    *   **Server Specifics**: Server-only mods or configs are handled via the `modrinth.index.json` environment flags (`client: unnecessary`, etc.).

---

## Visual Stack Architecture
The modpack employs a specific, multi-layered visual configuration to achieve high-quality graphics while maintaining compatibility.

### 1. Resource Packs
The resource pack order is critical and enforced via `options.txt` and the `client-overrides` system.

*   **Priority 1 (Highest): Patrix 32x CTM Override**
    *   **Type**: Local Integration (Manual Override)
    *   **Purpose**: Fixes Connected Texture Mapping (CTM) glitches and placeholder textures typically found in the standard Patrix pack on newer versions.
    *   **File**: `Patrix_32x_CTMOverride_1.20_1.21.zip`
*   **Priority 2: Patrix 1.21 32x Basic**
    *   **Type**: External Dependency (Modrinth)
    *   **Purpose**: Base textures for blocks and items.

### 2. Shader Configuration
*   **Engine**: Iris (via Oculus/Embeddium ecosystem)
*   **Shaderpack**: Complementary Unbound
*   **Key Customizations**:
    *   **Profile**: Forced to `CUSTOM` in config to ensure overrides apply.
    *   `SUN_MOON_STYLE_DEFINE` set to `Reimagined` (Values: `1`) to prevent square moon rendering issues.
    *   **Dual Config Strategy**: Configuration is maintained as `ComplementaryUnbound_r5.6.1.zip.txt` (and `.txt`) to ensure compatibility with different Iris versions.

### 3. Rendering Mods
This stack ensures full support for the resource packs and shaders:
*   **Entity Texture Features (ETF)** & **Entity Model Features (EMF)**: Provides OptiFine-parity for entity rendering (required for Patrix).
*   **Fusion**: Enables complex connected textures.
*   **Visuality**: Adds particle effects and immersive details.

---

## Directory Structure

### Root Directory
| Path | Description |
|------|-------------|
| `tools/build.sh` | The master build orchestrator. Generates the release `.mrpack`. |
| `mods/` | The "Source of Truth" for mod versions. Contains the physical `.jar` files used for scanning and hashing. |
| `config/` | NeoForge configuration files. Strictly versioned. |
| `client-overrides/` | Files that override default client settings. Contents are mapped to the `overrides/` folder in the `.mrpack`. |
| `tools/` | Maintenance scripts (Update system, etc). |
| `docs/` | System documentation. |

### `client-overrides/`
This directory is special. Files here are copied into the final modpack's `overrides` folder.
*   `config/`: Client-side only configs (e.g., `options.txt`).
*   **Important**: `options.txt` is maintained here to enforce the Resource Pack order and Keybinds.

---

## Configuration Management
*   **Global Configs**: Stored in `config/`. Common to Client and Server.
*   **Client Specifics**: Stored in `client-overrides/config/`.
*   **Mod Data**: The `mods/` directory acts as the manifest source. The build system scans this folder to generate the `modrinth.index.json`. We do *not* edit `modrinth.index.json` manually.

