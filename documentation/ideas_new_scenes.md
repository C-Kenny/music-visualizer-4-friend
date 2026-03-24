# Scene Ideas

These are ideas worth building. Each one has a clear visual concept, a reason it would work well
with music, and enough technical detail to start implementing.

---

## 1. Lissajous Knot

**What it looks like:** A single continuous 3D curve that ties itself into a knot, rotating slowly.
At rest it looks like a Celtic knot or a pretzel. On beat it snaps into a new configuration.

**Why it works with music:** Lissajous figures are literally the shape of a ratio between two
frequencies. Mapping bass to one axis frequency and treble to another creates a curve that
*is* the music's harmonic relationship — not just reacting to it.

**How to build it:**
```java
// Parametric — t goes 0..TWO_PI
x = sin(A * t + delta) * rx
y = sin(B * t) * ry
z = cos(C * t) * rz   // use PeasyCam for 3D, or project manually
```
Map `A`, `B`, `C` to FFT band averages. Small integer ratios (2:3:5, 3:4:7) look best.
Rotate the whole curve on the Y axis continuously. On beat, lerp A/B/C to new integer targets.

**Controller:** L stick = tilt the rotation axis, R stick = change A:B:C ratio, A = snap to
a "favourite" ratio (you hardcode a list of beautiful ones).

---

## 2. Fluid Simulation (Reaction-Diffusion)

**What it looks like:** Organic blobs that split, merge, and pulse — like a living petri dish.
Colours shift from deep ocean blue to hot magma depending on the music's energy.

**Why it works:** Reaction-diffusion (Gray-Scott model) naturally produces the kinds of
irregular-but-structured patterns that feel alive. It's visually unpredictable but not chaotic,
which pairs well with music that has groove.

**How to build it:**
Two float grids `A[][]` and `B[][]` at reduced resolution (e.g. 160×90). Each frame:
```
nextA[x][y] = A + dA*laplaceA - A*B*B + f*(1 - A)
nextB[x][y] = B + dB*laplaceB + A*B*B - (k + f)*B
```
Parameters `f` (feed rate) and `k` (kill rate) determine the pattern type. Map them to
bass and high FFT averages — small changes create large visual shifts.

On beat, inject a "seed" (set B=1) at a random worm position or the center of the screen.

**Performance note:** 160×90 = 14,400 cells. This is feasible in Processing at 60fps.
Full resolution is not — use the same RENDER_SCALE trick from Halo2LogoScene.

---

## 3. Aurora Ribbons

**What it looks like:** Translucent curtains of colour hanging from the top of the screen,
gently wavering. Like the northern lights, but they pulse and shimmer with the music.

**Why it works:** Ribbons drawn with `beginShape(TRIANGLE_STRIP)` and alpha blending create
a layered, atmospheric depth that feels totally different from the hard-edged geometric scenes.
It's the "calm scene" the set needs — good contrast after the worms.

**How to build it:**
```java
// Each ribbon is a list of control points along the top edge.
// For each point, compute a bottom point offset downward by a length driven by bass.
// Perlin noise gives the horizontal sway. Draw with TRIANGLE_STRIP.
for (int x = 0; x <= cols; x++) {
  float topY = 0;
  float sway = noise(x * 0.08 + noiseOff, frameCount * 0.004) * 80 - 40;
  float len  = 300 + bass * 20;
  vertex(x * spacing + sway, topY);
  vertex(x * spacing + sway * 0.4, topY + len);
}
```
Draw 4–6 ribbons with different hues and noise offsets. Use `blendMode(ADD)` for the
classic aurora glow. Hue sweeps slowly through the spectrum driven by mids.

**Controller:** R stick ↕ = ribbon length, L stick ↔ = horizontal wind drift, Y = hue offset.

---

## 4. Gravity String Web

**What it looks like:** A network of nodes connected by elastic strings. Nodes are pulled by
gravity toward each other AND toward the music's beat. The whole web breathes and quivers.

**Why it works:** String-spring physics is satisfying to watch because the motion has natural
momentum and overshoot. The strings visually encode energy — a taut string looks quiet, a
swinging one looks loud.

**How to build it:**
```java
// Each node has position, velocity.
// Each edge applies Hooke's law: F = k * (dist - restLength)
// Bass adds a downward gravity impulse. Beat fires a random node outward.
for (Edge e : edges) {
  float d   = dist(e.a.x, e.a.y, e.b.x, e.b.y);
  float f   = (d - e.rest) * 0.04;  // spring constant
  // push both nodes apart/together along the edge direction
}
```
Draw edges as lines with `strokeWeight` proportional to tension. Nodes as small glowing circles.
On beat, randomly select a node and give it a velocity kick.

**Interesting variation:** Make it 3D using PeasyCam. The depth adds a lot visually.

---

## 5. Pixel Sort / Glitch

**What it looks like:** The screen looks mostly normal, then on a loud beat, columns of pixels
get "sorted" by brightness — creating streaks of colour that shoot upward or sideways. Very
glitchy, very 2010s internet art.

**Why it works:** It's destructive by nature, which creates tension and release — perfect for
drop moments. Between beats the image heals itself.

**How to build it:**
Capture the current frame with `get()`. For each "glitch" column (select randomly on beat),
sort the pixels in that column by brightness using `Arrays.sort()` with a comparator. Paste
the sorted column back. Over N frames, lerp back to unsorted.

Can also be row-based or diagonal. Works best layered on top of another scene (treat it as
an effect, not a standalone scene).

**Implementation tip:** Don't sort every column every frame — that's O(width * height * log(height)).
Sort 10–20 random columns per frame for the glitchy effect without killing performance.

---

## 6. Radial FFT Bars (improved)

**What it looks like:** FFT bars arranged in a circle, but each bar is a tapered spike that
curves slightly outward as it grows. The whole circle rotates slowly. On beat, the circle
pulses outward and then snaps back.

**Why it works:** This is a classic for a reason. The improvement here is: (a) make the bars
taper to a point instead of being rectangles, (b) add a mirror ring on the inside so it
looks like a sun rather than a crown, (c) rotate the whole ring based on mids energy.

**How to build it:**
```java
for (int i = 0; i < fftSize; i++) {
  float ang    = TWO_PI * i / fftSize + rotation;
  float amp    = fft.getAvg(i) * scale;
  float inner  = radius;
  float outer  = radius + amp;
  // Draw a thin triangle: base at inner, point at outer, width proportional to 1/fftSize
  float w = TWO_PI / fftSize * inner * 0.7;
  // Use beginShape(TRIANGLES) to draw tapered spike
}
```

---

## 7. Spirograph / Hypotrochoid

**What it looks like:** A pen tracing the path of a circle rolling inside another circle.
The resulting curve is drawn incrementally — one point added per frame — so you watch the
pattern emerge. When it completes, it fades and starts a new one with different parameters.

**Why it works:** The emergence is the show. Watching the curve slowly reveal its shape is
meditative. Pair it with ambient or slow music. The completion → reset acts as a natural
visual phrase boundary.

**How to build it:**
```java
// Hypotrochoid: x = (R-r)*cos(t) + d*cos((R-r)/r * t)
//               y = (R-r)*sin(t) - d*sin((R-r)/r * t)
// R = outer radius, r = inner radius, d = pen distance from center of inner circle
// Small integer ratios of R/r give closed curves. E.g. R=5, r=3, d=5 → 5-pointed star shape.
```
Map `d` to bass (pen wobbles with bass). Map the trace speed to mids. On beat, pick new R/r values.
Keep a trail of the last N points and draw them with fading alpha.

---

## Things NOT worth building

- **3D spinning cube** — it's been done to death and doesn't add new insight
- **Bouncing ball frequency meter** — the bar chart is fine for analysis tools, not for a show
- **Text / lyric scenes** — too dependent on a specific song, not general enough
- **Camera feed / webcam effects** — interesting but requires additional hardware setup
