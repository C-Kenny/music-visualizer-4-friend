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
| — (LB/RB) | 13 | Gravity Strings | GravityStringsScene.pde |
| — (LB/RB) | 14 | Neural Weave | NeuralWeaveScene.pde — [detail doc](neural_weave.md) |

> **Disabled (code kept, not in rotation):** state 8 Particle Fountain, state 9 FFT Worm, state 10 Aurora Ribbons

> **Note:** Keyboard keys map to the *position* in `SCENE_ORDER`, not the state number directly.
> Key `1` → `SCENE_ORDER[0]` = state 1, key `2` → state 3, etc.
> States **11–14** have no direct number-key slot in the 1–9 row; reach them with **LB/RB** (or `.devscene`).

Keyboard: key **`0`** maps to state **10** (Aurora Ribbons), if you jump to that scene by number.
