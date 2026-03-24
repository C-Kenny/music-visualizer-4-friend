# Scene List

Scenes are cycled with **LB / RB** on the controller, or **number keys 1–9** on the keyboard.

The active scene order is defined by `SCENE_ORDER` in `Music_Visualizer_CK.pde`:

```java
final int[] SCENE_ORDER = {1, 3, 9, 8, 2, 4, 5, 6, 7};
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

States 0 and 10 exist in code (Halo2Logo at 0 or similar) but are not in SCENE_ORDER and are unreachable via normal navigation.

> **Note:** Keyboard keys map to the *position* in SCENE_ORDER, not the state number directly.
> Key `1` → SCENE_ORDER[0] = state 1, key `2` → SCENE_ORDER[1] = state 3, etc.
