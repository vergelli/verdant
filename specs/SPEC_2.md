
# Spec: Verdant Temporal Analytics Engine (v1.1.0)

## 1. System Overview
Implement a real-time temporal recording and visualization engine for Verdant's core metrics (eHPS, MPS). 
The goal is to provide a post-combat/live progression area chart (Stacked Fills) to help users analyze their performance ceiling over time.

**Reference Material:** 
Inspect the window generation and UI container logic in `C:\code\teso\Addons\other_addons\CombatMetrics` (specifically their graph rendering files) to understand how they construct the main `TopLevelWindow` and handle UI scaling. **Do not** copy their single-line plotting logic; Verdant requires a stacked area fill.

## 2. Strict Community Standards (ESOUI / Baertram's Rules)
Claude MUST adhere strictly to these rules to ensure community compliance:
1.  **No Global Leaks:** All functions and variables must be localized or scoped within the `Verdant` namespace.
2.  **Memory Management:** The UI rendering MUST use `ZO_ObjectPool` for all graph data points (Textures). Pre-allocate pools to avoid Garbage Collection frame-drops during combat.
3.  **Localization:** All new text strings for settings and UI must use `ZO_CreateStringId` natively. No custom translation tables.
4.  **Settings Persistence:** Only save user configurations (Slider values) via `ZO_SavedVars`. **DO NOT** save the combat data buffer to SavedVariables to avoid bloat and I/O lag.

## 3. Architecture Component: The Data Buffer
Implement a high-performance Circular Buffer in Lua to hold the time-series data.

*   **Configurable Parameters (Add to Verdant Settings menu):**
    *   `Sampling Rate`: Slider from 1 Hz to 10 Hz (Determines how often a snapshot is taken).
    *   `Time Window`: Slider from 30s to 300s (Determines the total duration the buffer holds).
*   **Buffer Size Calculation:** `Max_Capacity = Time Window * Sampling Rate`.
*   **Data Structure:** A pre-allocated 1D numerical array or simple table `[index] = {timestamp, eHPS, MPS}`. Overwrite old data using a modulo operation (`current_index % Max_Capacity`) to avoid table re-allocation.

## 4. Architecture Component: The Render Engine (Stacked Fills)
Unlike CMX's line plots, Verdant uses a Stacked Area approach. EMS is not plotted directly; it is the visual sum of eHPS (Green) and MPS (Pink).

*   **Canvas:** A `Texture` or `Backdrop` control serving as the graph background.
*   **Data Points (Bars):** Use two synchronized `ZO_ObjectPool`s of `Texture` controls.
    1.  `Pool_eHPS`: Green textures ( ALWAYS TRY TO MATCH THE AME COLOR AS ALREADY IMPLEMENTED BARS).
    2.  `Pool_MPS`: Pink/Lavender textures (ALWAYS TRY TO MATCH THE AME COLOR AS ALREADY IMPLEMENTED BARS).
*   **Rendering Math (Per Data Point):**
    *   Calculate the `Max_EMS` in the current buffer to establish the Y-axis scale.
    *   Width of each point: `Canvas_Width / Active_Samples`.
    *   **Green Bar (eHPS):** Height scaled to eHPS value. `BOTTOM` anchored to the `BOTTOM` of the Canvas.
    *   **Pink Bar (MPS):** Height scaled to MPS value. `BOTTOM` anchored to the `TOP` of the corresponding Green Bar.
    *   This physical anchoring creates the "Stacked Fill" visual progression automatically.

## 5. UI Controls & Flow
1.  **Record Button:** Toggles the state machine. When active, registers `EVENT_MANAGER:RegisterForUpdate` using the user's configured `Sampling Rate`.
2.  **Stop Button:** Unregisters the update loop.
3.  **Watch Record Button:** Spawns the Graph Window. Iterates through the Circular Buffer, acquires the necessary objects from the `ZO_ObjectPool`, applies the scaling math, and renders the stacked progression.
4.  **Auto-Clear:** The UI pools must be released (`:ReleaseAllObjects()`) when the graph window is closed to free memory.

***