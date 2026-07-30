# Scene List

Every scene has a fixed **state number** (its index in the `scenes[]` array, set once in `setup()` and never changed). Which scenes are actually reachable day-to-day is a separate list: `SCENE_ORDER[]` in `Music_Visualizer_CK.pde` picks 29 of the 58 total scenes as "the rotation."

- **LB / RB** (controller) and **`<` / `>`** (keyboard) step through `SCENE_ORDER` - previous/next in that list, not by state number.
- **Number keys `1`-`9`, `0`** jump straight to `SCENE_ORDER[0..9]` - i.e. only the *first 10 entries* of the rotation get a direct number-key slot. The remaining rotation scenes (and anything outside the rotation entirely) are reached via **`Tab`** (visual scene picker), LB/RB cycling, or `.devscene` (accepts a state number or a scene class name - see the [README](../README.md#dev-overrides)).
- Some scenes are **hotkey-only** - reachable by a dedicated key, not part of the rotation at all (see below).
- The rest exist in code but aren't wired into `SCENE_ORDER` right now - reachable via `.devscene` or by editing `SCENE_ORDER` yourself.

**This file is generated.** Run `scripts/gen_scene_list.py` after adding, renaming, or reordering a scene rather than hand-editing the tables below - CI checks this file matches freshly-generated output (`scripts/gen_scene_list.py --check`).

## Active rotation (`SCENE_ORDER`, in cycling order)

| Key | Pos. | State | Scene | File |
|-----|------|-------|-------|------|
| 1 | 0 | 1 | Original | `OriginalScene.pde` |
| 2 | 1 | 28 | Maze Puzzle | `src/scenes/games/MazePuzzleScene.pde` |
| 3 | 2 | 29 | Lissajous Knot | `LissajousKnotScene.pde` |
| 4 | 3 | 25 | Table Tennis 3D | `src/scenes/games/TableTennis3DScene.pde` |
| 5 | 4 | 53 | TT Sim Lab | `src/scenes/games/TableTennisSimScene.pde` |
| 6 | 5 | 54 | Sim Cube | `src/scenes/games/SimCubeScene.pde` |
| 7 | 6 | 7 | Prism Codex | `PrismCodexScene.pde` |
| 8 | 7 | 13 | Gravity Strings | `GravityStringsScene.pde` |
| 9 | 8 | 14 | Neural Weave - see [neural_weave.md](neural_weave.md) | `NeuralWeaveScene.pde` |
| 0 | 9 | 17 | Fractal | `FractalScene.pde` |
| - | 10 | 18 | Shader | `ShaderScene.pde` |
| - | 11 | 19 | Worm | `WormScene.pde` |
| - | 12 | 23 | Recursive Mandala | `RecursiveMandalaScene.pde` |
| - | 13 | 24 | Kaleidoscope | `KaleidoscopeScene.pde` |
| - | 14 | 26 | Void Bloom | `VoidBloomScene.pde` |
| - | 15 | 31 | Hourglass | `HourglassScene.pde` |
| - | 16 | 32 | Sacred Geometry | `SacredGeometryScene.pde` |
| - | 17 | 34 | Torus Knot | `TorusKnotScene.pde` |
| - | 18 | 35 | Rose Curve | `RoseCurveScene.pde` |
| - | 19 | 38 | Psychedelic Eye | `PsychedelicEyeScene.pde` |
| - | 20 | 39 | Cosmic Lattice | `CosmicLatticeScene.pde` |
| - | 21 | 42 | Merkaba Star | `MerkabaStarScene.pde` |
| - | 22 | 43 | Pentagonal Vortex | `PentagonalVortexScene.pde` |
| - | 23 | 47 | Strange Attractor | `StrangeAttractorScene.pde` |
| - | 24 | 52 | Hyperspace Bloom | `HyperspaceBloomScene.pde` |
| - | 25 | 55 | Fable Murmuration | `FableMurmurationScene.pde` |
| - | 26 | 56 | Spatial Orbit - see [8d_audio.md](8d_audio.md) | `SpatialOrbitScene.pde` |
| - | 27 | 57 | Paralyzed | `ParalyzedScene.pde` |
| - | 28 | 48 | Sacred Fractals | `SacredFractalsScene.pde` |

(Position 9 in the table above is where the row for keyboard `0` sits - `SCENE_ORDER[9]`, not `SCENE_ORDER[0]`. Keys `1`-`9` map to positions `0`-`8`, and `0` maps to position `9`.)

## Hotkey-only scenes (not in the rotation)

| Key | State | Scene | File |
|-----|-------|-------|------|
| `w` | 33 | Math Wave | `MathWaveScene.pde` |
| `v` | 45 | Explainer | `VisualizerExplainerScene.pde` |

## Not currently in the rotation

Exists in code, has a state number, loads fine - just not wired into `SCENE_ORDER`. Reach any of these with `.devscene` (name or number) or by adding the constant to `SCENE_ORDER` yourself. Where the code comment next to a scene's (commented-out) `SCENE_ORDER` entry gives a reason, it's shown; most others simply predate the current rotation and haven't been revisited.

| State | Scene | File | Note |
|-------|-------|------|------|
| 0 | RIP | `RIPScene.pde` |  |
| 2 | Heart Grid | `HeartGridScene.pde` |  |
| 3 | Shapes 3D | `Shapes3DScene.pde` |  |
| 4 | Cats Cradle | `CatsCradleScene.pde` |  |
| 5 | Oscilloscope | `OscilloscopeScene.pde` |  |
| 6 | Table Tennis | `src/scenes/games/TableTennisScene.pde` |  |
| 8 | Particle Fountain | `ParticleFountainScene.pde` |  |
| 9 | Halo2 Logo | `Halo2LogoScene.pde` |  |
| 10 | Aurora Ribbons | `AuroraRibbonsScene.pde` |  |
| 11 | Radial FFT | `RadialFFTScene.pde` |  |
| 12 | Spirograph | `SpirographScene.pde` |  |
| 15 | Shoal Lumina | `ShoalLuminaScene.pde` |  |
| 16 | Antigravity | `AntigravityScene.pde` |  |
| 20 | FFT Worm | `FFTWormScene.pde` |  |
| 21 | Deep Space | `DeepSpaceScene.pde` |  |
| 22 | Cyber Grid | `CyberGridScene.pde` |  |
| 27 | Circuit Maze | `CircuitMazeScene.pde` | disabled - dynamic circuit maze, revisit later |
| 30 | Fluid Sim | `FluidSimScene.pde` |  |
| 36 | Sri Yantra | `SriYantraScene.pde` | disabled, revisit later |
| 37 | Net Of Being | `NetOfBeingScene.pde` | disabled, revisit later |
| 40 | Original 3D | `Original3DScene.pde` |  |
| 41 | Dot Mandala | `DotMandalaScene.pde` | disabled, revisit later |
| 44 | Tunnel Yantra | `TunnelYantraScene.pde` | disabled - combo layer scene, revisit later |
| 46 | Chladni Plate | `ChladniPlateScene.pde` | disabled - chladni skybox, revisit later |
| 49 | They Dont Know | `TheyDontKnowScene.pde` | disabled, revisit later |
| 50 | Live Code | `LiveCodeScene.pde` | disabled - live code console, revisit later |
| 51 | Silhouette Painting | `SilhouettePaintingScene.pde` | disabled, revisit later |

## Scene count

58 total (`SCENE_COUNT` in `Music_Visualizer_CK.pde`), 29 in the active rotation, 2 hotkey-only, 27 not currently wired in. Regenerate this file (`scripts/gen_scene_list.py`) rather than editing these numbers by hand.
