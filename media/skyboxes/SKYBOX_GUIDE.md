# Skybox Guide

How to get skyboxes working with the `Skybox` class in Processing.

---

## What the Skybox Class Expects

Each skybox = **one folder** containing **6 PNG files**, named exactly:

```
px.png   ← FRONT  (what camera faces by default)
nx.png   ← BACK
pz.png   ← RIGHT
nz.png   ← LEFT
py.png   ← UP     (sky overhead)
ny.png   ← DOWN   (ground below)
```

Load in code:
```java
skybox.load(sketchPath("../../media/skyboxes/my_skybox"));
```

---

## Naming Conventions Found in the Wild

Sites use wildly different names. Rename files to match the table above before use.

### Site: Poly Haven (`sky_XX_2k` packs)
Pre-sliced cubemaps already come with correct names. Just use the `sky_XX_cubemap_2k/` subfolder directly — no renaming needed.
```
sky_23_cubemap_2k/px.png  ← already correct
```

### Site: Jettelly / Blue Sky Skybox Pack
Uses `FRONT/BACK/LEFT/RIGHT/UP/DOWN` naming:
```
_FRONT.png  → px.png
_BACK.png   → nx.png
_RIGHT.png  → pz.png
_LEFT.png   → nz.png
_UP.png     → py.png
_DOWN.png   → ny.png
```

### Site: Generic "skybox" pack (front/back/left/right/top/bottom)
Uses plain words:
```
front.png   → px.png
back.png    → nx.png
right.png   → pz.png
left.png    → nz.png
top.png     → py.png
bottom.png  → ny.png
```

### Site: Skybox AI / Blockade Labs
Exports as `.exr`, `.hdr`, or equirectangular `.jpg/.glb` — **needs conversion** (see below).

### Site: spacescape / other tools
Check the exported filenames — usually `front/back/left/right/up/down` or `posx/negx/posy/negy/posz/negz`:
```
posx.png → px.png    negx.png → nx.png
posy.png → py.png    negy.png → ny.png
posz.png → pz.png    negz.png → nz.png
```

---

## Converting from .exr / .hdr (Equirectangular)

Most sites distribute a single panoramic image in `.exr` or `.hdr` format. Processing can't load these natively — convert to 6 PNG faces first.

**Option A — Command line (fastest):**

```bash
cd media/skyboxes
python3 convert_skybox.py my_file.exr my_skybox_name 1024
```

Requires: `pip3 install --break-system-packages numpy pillow py360convert` (one-time setup, already done).
Outputs 6 correctly named PNGs directly into `media/skyboxes/my_skybox_name/`.

**Option B — Web tool (no setup):**

Go to https://matheowis.github.io/HDRI-to-CubeMap, upload `.exr`/`.hdr`, set face size 1024px, download.
Drop the 6 PNGs into `media/skyboxes/my_skybox_name/` — no renaming needed, tool already uses correct convention.

---

## Face Layout Reference

```
          [py = UP]

[nx=BACK] [pz=RIGHT] [px=FRONT] [nz=LEFT]

          [ny = DOWN]
```

The arrow on each face in `cubemap_layout.png` (included in Poly Haven packs) shows which direction is "up" in that texture. This matches how our `Skybox` class renders them.

---

## Adding a New Skybox to a Scene

```java
// Field:
Skybox skybox = new Skybox();

// In drawScene() — lazy load on first frame:
if (!skybox.loaded) {
  skybox.load(sketchPath("../../media/skyboxes/my_skybox_name"));
}

// Draw AFTER camera rotations, BEFORE geometry:
skybox.draw(canvas);
```

> Use `sketchPath("../../media/...")` — Processing builds to `.build/Music_Visualizer_CK/`
> so two levels up gets back to the project root.

---

## Checklist When Skybox Appears Black

1. Check console for `Skybox: MISSING ...` — wrong path or wrong filename
2. Confirm 6 files exist and are named exactly `px/nx/py/ny/pz/nz.png`
3. Confirm `skybox.draw(canvas)` is called inside a `canvas.beginDraw()` / `canvas.endDraw()` block
4. Confirm you're NOT calling `noLights()` before or after `skybox.draw()` — that zeroes ambient light and turns textures black
