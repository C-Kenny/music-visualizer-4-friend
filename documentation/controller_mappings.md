# Controller Mappings

All scenes support a controller (Xbox-style via GameControlPlus).

## Global controls (all scenes)

| Button | Action |
|--------|--------|
| LB     | Previous scene |
| RB     | Next scene |
| `` ` `` (backtick) | Toggle controls overlay (right side) |

## Per-scene controls

### Scene 1 — Tunnel Zoom
| Control | Action |
|---------|--------|
| L Stick | Steer tunnel focus |
| R Stick ↕ | Zoom speed |
| LT / RT | Speed via Z axis |
| A | Trigger burst |
| Y | Cycle colour palette |

### Scene 3 — Worm Colony
| Control | Action |
|---------|--------|
| L Stick | Lure all worms toward stick |
| R Stick | Repel worms from stick |
| Z axis (LT full = turbo, RT full = slow) | Speed scale |
| A | Spawn a worm |
| B | Remove last worm |
| X | Scatter burst |
| Y | Cycle colour mode (Mono / Rainbow / Gradient) |

### Scene 9 — FFT Worm
| Control | Action |
|---------|--------|
| L Stick | Steer the worm's head |
| R Stick ↕ | Body reactivity (amplitude multiplier) |
| Z axis | Speed (LT = slow crawl, RT = turbo) |
| A | Coil into circle formation |
| B | Resume wandering |
| X | Reverse direction (highs at head) |
| Y | Cycle colour palette (Spectrum / Heat / Ice / Mono) |

### Scene 8 — Particle Fountain
| Control | Action |
|---------|--------|
| A | Trigger manual burst |

### Scene 2 — Heart Grid
| Control | Action |
|---------|--------|
| L Stick | Pan colour columns |
| R Stick | Zoom toward stick direction |

### Scene 4 — Cats Cradle
| Control | Action |
|---------|--------|
| L Stick ↕ | Rotation speed |
| R Stick ↔ | Number of anchors (4–14) |
| A | Trigger pulse |

### Scene 5 — Oscilloscope
| Control | Action |
|---------|--------|
| L Stick ↕ | Amplitude scale |
| R Stick ↕ | Zoom |

### Scene 6 — Table Tennis
| Control | Action |
|---------|--------|
| R Stick ↕ | Gravity (incremental) |
| L Stick ↕ | Magnus force (incremental) |
| A | Randomise ball spin |

### Scene 7 — Prism Codex
| Control | Action |
|---------|--------|
| L Stick ↕ | Spin speed |
| R Stick ↕ | Drift speed |
| A | Trigger beat glow |

## Technical notes

- The Xbox controller on Linux exposes LT and RT as a **single combined "z" axis** via GameControlPlus (`getSlider("z")`). Values: `-1.0` = LT fully pressed, `+1.0` = RT fully pressed.
- Named sliders `"lt"` and `"rt"` do NOT exist on this setup — accessing them throws `NullPointerException`. Always use `"z"` inside a `try/catch`.
- Sticks: `c.lx`, `c.ly`, `c.rx`, `c.ry` are raw pixel coordinates (0..width / 0..height). Map them to [-1, 1] with `map(c.lx, 0, width, -1, 1)`.
- Dead zone: check magnitude > 0.18 before treating as active input.
