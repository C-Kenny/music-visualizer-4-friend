# Neural Weave (state 14)

Audio-reactive scene that blends a **woven FFT mesh** with **biological** cues (diffuse glow, node jitter, vesicle halos, curved synapse bridges) and **instrumentation** cues (scanlines, crosshair, “tech” accent on edges). Implementation: `Music_Visualizer_CK/NeuralWeaveScene.pde`.

## How to open

- **LB / RB** cycle `SCENE_ORDER` in `Music_Visualizer_CK.pde`; Neural Weave is **state 14** (after Gravity Strings).
- **Number keys 1–9 / 0** jump by position in `SCENE_ORDER`, not by state id — there is **no** dedicated key for state 14. Use LB/RB or dev override `.devscene` with value `14`.

## Audio

- Per-band energy via `audio.normalisedAvg(i)` with smoothing (stable across loudness).
- **Bass / mid / high** buckets drive diffusion, rotation drift, and edge character.
- **Beat onsets** increase ripple and shift the global hue (in palette-dependent ways).

## Controller

| Input | Role |
|-------|------|
| **L stick** | Pan the field |
| **R stick ↔** | Zoom |
| **R stick ↕** | Spin speed (center ≈ coast) |
| **LT** | Metabolism: diffusion strength, organic node jitter, filament harmonics |
| **RT** | Tech: scanline/crosshair strength, sharper bridges and nodes |
| **A** | Ripple |
| **B** | Cycle **growth**: Mesh → Synapse web → Tissue bloom |
| **X** | Toggle **lab** overlay (crosshair + scanlines + cooler tint) |
| **Y** | Cycle palette |
| **L3** | Reset pan, zoom, default spin |
| **R3** | Regenerate synapse bridges + pulse ripple |

**LB / RB** remain **scene prev/next** (handled in `getUserInput()` before scene logic).

Triggers are read on `Controller` as **`lt` / `rt`** in `0…1` (see `Controller.pde`). Devices without those axes leave them at `0`.

## Keyboard (only while state 14 is active)

| Key | Role |
|-----|------|
| `[` / `]` | Coarser / finer grid |
| `-` / `=` | Edge intensity |
| `Space` | Ripple |
| `K` | Cycle palette (avoid global `Y` fin-offset on keyboard) |
| `E` | Toggle lab mode |
| `G` or `B` | Cycle growth stage |
| `V` | Toggle vesicle halos |
| `` ` `` | Toggle code/controls overlay (`getCodeLines()`) |

## Growth stages

1. **Mesh** — lattice only (H/V/diagonal weave).  
2. **Synapse web** — adds quadratic **bridges** between distant nodes (periodic reshuffle).  
3. **Tissue bloom** — more bridges + larger vesicle halos under nodes.

## Integration with the main sketch

Neural Weave is **self-contained** in `NeuralWeaveScene`. The main file only:

- Instantiates `neuralWeave`, adds **`case 14:`** in `draw()`, calls `neuralWeave.applyController(controller)` when `config.STATE == 14`, and extends **`SCENE_ORDER`** with `14`.
- **`keyPressed`**: block `// Neural weave keys (state 14 only)` for scene-local keys.
- **Global shortcuts that are skipped on state 14** so they do not fight scene bindings:
  - **`b`** (blend cycle), **`g`** (background toggle)
  - **`controller`**: **B** (blend), **X** (background), **L3/R3** (background / inner diamonds), **Y** (fin rotation — unchanged for all other scenes; only state 14 is excluded so **Y** = palette here)
- **`controller.a`**: `switch` includes **`case 14`** for ripple instead of toggling rainbow fins.

Removing Neural Weave later: delete `NeuralWeaveScene.pde`, strip `14` from `SCENE_ORDER`, remove the `case`, variable, `applyController` block, `keyPressed` block, and the `STATE != 14` / `case 14` branches listed above.

## Related files

| File | Role |
|------|------|
| `Music_Visualizer_CK/NeuralWeaveScene.pde` | Scene class |
| `Music_Visualizer_CK/Controller.pde` | `lt`, `rt` trigger fields |
| `Music_Visualizer_CK/Music_Visualizer_CK.pde` | State machine, input routing |
| `documentation/scene_list.md` | Master scene index |
