# Skybox Assets — Bring Your Own (BYO)

The visualizer ships **zero skybox image assets**. The packs in
`media/skyboxes/` on dev machines have unclear licensing, so they are
gitignored and excluded from every release (.deb, zips, mirrors). Instead the
app supports two licensing-safe sources:

## 1. Generated skyboxes (always available)

Three procedural cubemaps are built at runtime — pure code, owned by this
project, present on every install with no files needed:

| Name | Look |
|------|------|
| `auto_stars`   | hashed starfield + faint galaxy haze |
| `auto_nebula`  | fbm nebula clouds with stars on top |
| `auto_horizon` | synthwave dusk: sun disk, scanlines, neon floor grid |

They appear first in every skybox picker. Palettes are seeded from the song
name at first generation, so each show gets its own tint. Generation takes a
moment per style (one-time per run, then cached).

## 2. User / venue packs (drop-in folder)

The venue supplies cubemaps **they** have the rights to. Drop them here:

```
Linux:   ~/.config/music-visualizer/skyboxes/<pack-name>/
macOS:   ~/Library/Application Support/MusicVisualizer/skyboxes/<pack-name>/
Windows: %APPDATA%\MusicVisualizer\skyboxes\<pack-name>\
```

(The `skyboxes/` folder is created automatically on first launch. Dev runs via
`./run.sh` use the repo dir instead — `MV_USER_DATA_DIR` override.)

Each pack is one folder with **six PNG faces, exact names**:

```
<pack-name>/
  px.png   ← front     nx.png   ← back
  py.png   ← up        ny.png   ← down
  pz.png   ← right     nz.png   ← left
```

- Square images, all six the same size. 1024×1024 or 2048×2048 recommended
  (2k × 6 faces ≈ fine on any GPU this app targets; 4k+ wastes VRAM).
- Any cubemap from a "skybox pack" download in this face convention works.
  Equirectangular panoramas must be converted to faces first (e.g.
  `py360convert`, see `media/skyboxes/convert_skybox.py` on dev machines).
- Packs are discovered at app launch — restart after adding one.
- A user pack with the same folder name as a bundled dev pack wins.

## Licensing note

Whoever drops files into the skyboxes folder is responsible for having the
rights to display them. The app never uploads, copies, or redistributes
them — they are read straight from the user folder at runtime.

## For maintainers

- Discovery: `discoverSkyboxNames()` in `SkyboxPicker.pde` (generated names
  first, then user dir, then dev-only `media/skyboxes/`).
- Routing: `loadSkyboxByName()` / `skyboxPath()` in
  `src/core/ProceduralSkybox.pde`. All scenes go through these — never call
  `skybox.load(resourcePath(...))` directly.
- Generation: `ProceduralSkybox.pde`. Faces are colored purely by view
  direction (corner tables copied from `Skybox.draw()`), which is what makes
  them seamless and correctly oriented. Add a new style = one pixel function
  + a name in `AUTO_SKYBOX_NAMES`.
- This resolves the "skyboxes missing from .deb" packaging gap: releases are
  *supposed* to have no skybox files now.
