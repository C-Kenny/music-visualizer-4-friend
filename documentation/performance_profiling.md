# Performance Profiling - methodology & worked examples

How the perf wins in 2.5.6/2.5.7/2.5.8 were found, so the next session can
do more of the same. Two layers: live in-sketch HUD, then sampling
profiler.

## Layer 1 - in-sketch `FrameBudget` HUD

`Music_Visualizer_CK/src/core/FrameBudget.pde`. Toggle with **F8**.

Shows per-phase frametime as a small bottom-left panel:

```
FRAME BUDGET (F8)
audio     0.31 ms   3%  ▓
input     0.12 ms   1%  ▓
scene     7.42 ms  74%  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓
postfx    0.05 ms   0%
compose   1.82 ms  18%  ▓▓▓
hud       0.40 ms   4%  ▓
sum       10.12 ms
frame     11.45 ms / 87 fps
```

Phases wrap the relevant calls in `draw()` with `System.nanoTime()` taps
(see `FrameBudget.begin(phase)` / `.end()`). Cost: ~6 nanoTime calls per
frame, <1 µs total. Colour code: green <2ms, yellow <6ms, red ≥6ms.

**Use for:** spotting which phase dominates *right now* on *this scene*.
If `scene` is red but `postfx` is green, the scene's code is the problem.
If `compose` is red and recorder is running, the encode pipeline is the
problem. Quick triage, no profiler needed.

**Limit:** phase totals only. Doesn't tell you which method inside the
scene is hot - that's Layer 2.

## Layer 2 - async-profiler

`profile.sh` is a wrapper. Wants `tools/async-profiler-3.0-linux-x64/`
installed (one-time `wget` + untar - see comments at the top of the
script).

### Run

```bash
./run.sh                          # leave it running, switch scenes
./profile.sh 60                   # 60s CPU sample, opens flame.html
./profile.sh 60 alloc             # alloc events (find GC pressure)
```

Wrapper auto-finds the sketch PID via `pgrep`, attaches via JVMTI,
samples at ~50Hz (using `itimer` event - works without kernel perms),
writes a flame graph HTML.

### Caveats on the dev box

- **CPU event needs `kernel.perf_event_paranoid=1`** (one-time sudo
  sysctl, lasts until reboot). Without it, async-profiler falls back to
  `itimer` (signal-based) - slightly lower fidelity but no sudo needed.
  `profile.sh` defaults to whatever it can get.
- **Sampling**, not tracing - methods that allocate get under-counted
  vs. methods that loop. For allocation pressure use `-e alloc`.
- **Dev box vs X1 ThinkPad** - CPU hotspots translate; GPU
  hotspots do not. Profile on the target hardware when possible.

### Reading the collapsed output

`profile.sh` writes both `flame.html` (visual) and the underlying
**collapsed** text file. Collapsed format is grep/awk-friendly - each
line is `frame1;frame2;...;leafFrame count`. Self-time of a method =
sum of counts where it's the leaf.

Pre-made one-liners:

```bash
# Top 30 self-time leaves (where CPU is *spent*, not just on stack)
awk '{n=split($0,a," "); count=a[n];
      $0=substr($0,1,length($0)-length(count)-1);
      m=split($0,f,";"); leaf=f[m]; sum[leaf]+=count}
     END{for(k in sum) print sum[k], k}' /tmp/flame.collapsed \
  | sort -rn | head -30

# Inclusive time per scene (cost of being inside that scene's drawScene)
awk '{n=split($0,a," "); count=a[n];
      $0=substr($0,1,length($0)-length(count)-1);
      m=split($0,f,";");
      for(i=1;i<=m;i++) if (f[i] ~ /Scene\.drawScene/) {sum[f[i]]+=count; break}}
     END{for(k in sum) print sum[k], k}' /tmp/flame.collapsed \
  | sort -rn | head -25

# Who calls a specific hotspot (e.g. trig)
awk '/libmCos|libmSin/' /tmp/flame.collapsed \
  | awk '{n=split($0,a," "); count=a[n];
          $0=substr($0,1,length($0)-length(count)-1);
          m=split($0,f,";");
          for(i=m;i>=1;i--) if (f[i] ~ /Scene\./) {sum[f[i]]+=count; break}}
         END{for(k in sum) print sum[k], k}' \
  | sort -rn | head -10
```

The "who calls X" form is the most useful: collapsed format preserves
the full stack, so you can ask "where does CPU spent in `cos()`
actually come *from*" and get scene-level attribution.

## Worked examples - 2.5.7 + 2.5.8

### Win #1 - StrobeSafety.snapshot ~3% CPU (2.5.7)

**Symptom (in flame data):**
```
99  Music_Visualizer_CK$StrobeSafety.snapshot   (3.3% of samples)
```

Surprising - strobe safety is **disabled by default**. Why is it eating
CPU at all?

**Read the code.** `maybeDampen()` early-exits when `!enabled`, but
`snapshot()` - called immediately after - didn't have the same guard. It
was doing a full-frame `image()` copy into a backing buffer every frame
regardless.

**Fix:** add `if (!enabled || src == null) return;` to the top of
`snapshot()`. Trivial. ~3% CPU back at default config.

**Lesson:** when the profile says "X is hot," ask whether X *should be
running at all* before optimizing it. Cheapest CPU is the one you don't
spend.

### Win #2 - Mandala bezier detail 20 → 10 (2.5.7)

**Symptom:**
```
600 jogamp/opengl/glu/tessellator/* (~20% of samples)
…
100 Music_Visualizer_CK$OriginalScene.drawScene
 16 Music_Visualizer_CK$OriginalScene.drawBezierFins
```

JOGL's CPU-side polygon tessellator was burning 20% of total CPU.
Mandala (the most-watched scene) was the heaviest caller.

**Read the code.** `drawBezierFins` draws 3 `pg.bezier()` curves per
fin × `fins` count per frame. Processing's default `bezierDetail` is
**20 segments** per curve. For tiny fin curves at ~140px on screen,
that's gross overkill - 10 segments looks identical.

**Fix:** one line. `pg.bezierDetail(10);` at the top of the function.
Halves vertex emission for that draw path.

**Lesson:** Processing's defaults are tuned for desktop-app demos at
arbitrary sizes. When you know the geometry is small or stylised,
override.

### Win #3 - Chladni cos() cache, ~100k calls/frame → 24 (2.5.8)

**Symptom:**
```
820  ChladniPlateScene.drawScene  (worst scene by inclusive time)
…
541  libmCos + libmSin           (~4.5% of total CPU in trig)
233  cos/sin from OriginalScene
152  cos/sin from ChladniPlateScene.uAtNorm
 79  cos/sin from ChladniPlateScene.uAtGrid
```

`uAtGrid` is called **64×64×6 = ~25k times per frame** (per-vertex mesh
eval over 6 faces). Inside, this line:

```java
s += modeAmp[k] * cos(u_time * 0.5 + phase * (k + 1)) * a;
```

The `cos(...)` only depends on `(faceIdx, k)` - **not** on the grid
position `(i, j)`. So it's computed redundantly ~100k times per frame
when it only needs 6 × ACTIVE_MODES = 24 evals.

**Fix:** add a `float[][] timeMod = new float[N_FACES][16];` field.
Populate once at the top of `drawScene()` via `refreshTimeMod()`.
`uAtGrid`/`uAtNorm` read `timeMod[faceIdx][k]` instead of calling
`cos()`.

**Result:** Chladni frametime 17.91 → 15.89 ms (-11%) on dev box. Should
be larger on the X1 (CPU-bound win scales harder when CPU is the
bottleneck).

**Lesson:** look for **loop-invariant computation in inner loops**.
Profiler shows you *that* `cos()` is hot - you have to read the code to
see *why* and confirm the value doesn't actually vary at the inner
loop's frequency.

## Suggested next targets (post-demo)

Based on the 240s flame data:

| Hotspot | Samples | Suggested fix |
|---|---|---|
| JOGL `glu_tessellator` (~20%) | 1200+ | Convert static fin/petal geometry to cached `PShape` (retained mode) so per-frame tessellation goes away. Big lift, big payoff. |
| `OriginalScene.drawScene` trig (233 cos/sin) | 233 | Find loop-invariant `cos`/`sin` in Mandala (likely particles or stacking transforms); same pattern as the Chladni fix. |
| Strange Attractor (488 inclusive) | second-worst scene | Read `drawParticles` for allocation in hot path (HashMap iterator showed up here). Likely a per-particle `HashSet.iterator()` or similar. |
| HashMap iterator allocation (404 self) | scattered | Replace `for (X x : map.values())` patterns with index-based iteration over an `ArrayList` cache, or use `EntrySet` with reusable iterator. |
| `libgallium` GPU driver (~15%) | unavoidable until pixel budget drops | Only addressable by reducing rendered pixel count. The proper LOW_POWER_MODE fix (scenes using `pg.width`/`pg.height` so buffer resize doesn't break geometry) is the real lever - see [[feedback_lowpower_geometry]]. |

## TL;DR workflow

1. Run sketch. Hit **F8** to see FrameBudget. Identify slow scene or
   phase.
2. `./profile.sh 60` (or `240` for stepping through every scene).
3. Run the awk one-liners against `/tmp/flame.collapsed`.
4. For each top hotspot, **read the code** before "optimizing". Ask:
   should this run at all? Is the inner loop doing work that doesn't
   depend on the inner variable?
5. Smoke test (`./smoketest.sh`) - confirms no regression and gives a
   leaderboard delta.
6. Release via git-flow.
