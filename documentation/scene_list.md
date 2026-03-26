# Scene List

Scenes are cycled with **LB / RB** on the controller, or **number keys 1–9** on the keyboard.

The active scene order is defined by `SCENE_ORDER` in `Music_Visualizer_CK.pde`:

```java
final int[] SCENE_ORDER = {1, 3, 9, 8, 2, 4, 5, 6, 7, 10};
```

| Key | State | Scene | File |
|-----|-------|-------|------|
| 1   | 1     | Tunnel / Infinite Zoom | Music_Visualizer_CK.pde (inline) |
| 3   | 3     | Worm Colony | WormScene.pde |
| 9   | 9     | FFT Worm | FFTWormScene.pde |
| 8   | 8     | Particle Fountain | ParticleFountainScene.pde |
| 2   | 2     | Heart Grid | Music_Visualizer_CK.pde (inline) |
| 4   | 4     | Cats Cradle | CatsCradleScene.pde |
| 5   | 5     | Oscilloscope | OscilloscopeScene.pde |
| 6   | 6     | Table Tennis | TableTennisScene.pde |
| 7   | 7     | Prism Codex | PrismCodexScene.pde |
| 0   | 10    | Aurora Ribbons | AuroraRibbonsScene.pde |

State 0 still exists as a legacy placeholder. State 10 (Aurora Ribbons) is in SCENE_ORDER and reachable via LB/RB cycle and keyboard `0`.

> **Note:** Keyboard keys map to the *position* in SCENE_ORDER, not the state number directly.
> Key `1` → SCENE_ORDER[0] = state 1, key `2` → SCENE_ORDER[1] = state 3, etc.


Keyboard note: key `0` maps to state `10` for Aurora Ribbons.
