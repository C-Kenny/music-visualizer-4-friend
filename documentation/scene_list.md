# Scene List

Scenes are cycled with **LB / RB** on the controller, or **number keys 1–9** on the keyboard (by **index** in `SCENE_ORDER`, not by raw state number).

The active scene order is defined by `SCENE_ORDER` in `Music_Visualizer_CK.pde`:

```java
final int[] SCENE_ORDER = {1, 3, 2, 4, 5, 6, 7, 11, 12, 13, 14};
```

| Key | State | Scene | File |
|-----|-------|-------|------|
| 1   | 1     | Tunnel / Infinite Zoom | Music_Visualizer_CK.pde (inline) |
| 2   | 3     | Worm Colony | WormScene.pde |
| 3   | 2     | Heart Grid | Music_Visualizer_CK.pde (inline) |
| 4   | 4     | Cats Cradle | CatsCradleScene.pde |
| 5   | 5     | Oscilloscope | OscilloscopeScene.pde |
| 6   | 6     | Table Tennis | TableTennisScene.pde |
| 7   | 7     | Prism Codex | PrismCodexScene.pde |
| 8   | 11    | Radial FFT | RadialFFTScene.pde |
| 9   | 12    | Spirograph | SpirographScene.pde |
| - (LB/RB) | 13 | Gravity Strings | GravityStringsScene.pde |
| - (LB/RB) | 14 | Neural Weave | NeuralWeaveScene.pde - [detail doc](neural_weave.md) |

> **Disabled (code kept, not in rotation):** state 8 Particle Fountain, state 9 FFT Worm, state 10 Aurora Ribbons

> **Note:** Keyboard keys map to the *position* in `SCENE_ORDER`, not the state number directly.
> Key `1` → `SCENE_ORDER[0]` = state 1, key `2` → state 3, etc.
> States **11–14** have no direct number-key slot in the 1–9 row; reach them with **LB/RB** (or `.devscene`).

Keyboard: key **`0`** maps to state **10** (Aurora Ribbons), if you jump to that scene by number.

> **New (2026-06):** state **55** Fable Murmuration - `FableMurmurationScene.pde` - in rotation after Hyperspace Bloom. 2400-boid flock morphing between four formations; fully on the SceneParam spine.

> **New (2026-06):** state **56** Spatial Orbit - `SpatialOrbitScene.pde` - in rotation after Fable Murmuration. Showcase for the 8D-audio tracker (`documentation/8d_audio.md`): top-down listener head, comet marks where the sound sits, ignites and laps the head when an 8D orbit is detected. FFT bar ring + beat shockwaves keep it alive on normal stereo. On the SceneParam spine (ring/trail/glow/tilt/bars).

> **New (2026-07):** state **57** Paralyzed - `ParalyzedScene.pde` - in rotation after Spatial Orbit. Emotional scene inspired by NF's "Paralyzed" (numbness/depression). No figure drawn - the whole screen is glass under pressure: hairline fractures spawn, live ~10-20s, and fade/retire as a slow-following, self-normalizing "pressure" envelope climbs (no hard-coded timestamps, adapts to any song), always avoiding a hidden body-shaped no-go zone in the middle that reads like a chalk outline as the rest fills in. A soft glow drifts on an arc across the sky (song position) behind the glass. Beats flicker several cracks + send a traveling glint (a gasp); `DropPredictor` drives pre-drop tension that tightens but never releases; a genuine sustained collapse drains the light without healing the cracks. **Foreground**: a free-flying spark, directly piloted - left stick flies it anywhere on the pane (inertial drag), right stick aims a Tesla-coil discharge out from it when nothing's nearby, but fly close enough to an existing crack and the discharge grounds onto it instead - sending a glint down it and lighting it up as a "live wire" for as long as you stay close, snapping to a different crack as you move around. Hard bass hits jolt the spark off course mid-flight, L3 freezes it, R3 snaps back to center + burst. 10s with no controller input and it flies itself (Perlin-drift wander, aimed the way it's headed), handing back instantly the moment you touch a stick. Full controller layout wired (see in-app guide); on the SceneParam spine (pressure/hue/glow/grain/crack).
