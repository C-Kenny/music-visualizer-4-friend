# Guide: Just Want to Enjoy Some Visuals?

This one's for you if you just want to put on music and watch something cool
happen on screen — no venue, no crowd, no controller required (though it's
more fun with one).

## Getting it running

**Already have the `.deb` installed?**

```bash
music-visualizer
```

A file picker opens — choose a song, and you're in.

**Running from source instead?** See the main [README](../README.md#run-from-source)
for setup, then:

```bash
./run.sh
```

## The basics

- The visualizer opens on scene 1 and starts playing your song immediately.
- Press **`<`** / **`>`** to step through scenes, or **`Tab`** for a visual
  scene picker.
- Press **number keys `1`–`9`, `0`** to jump straight to a favorite.
- Press **`s`** to pause/resume, **`n`** for the next song, **`N`** to shuffle.
- Press **`o`** to open the file picker again and pick a different song.

## Just want to sit back and watch?

Two features exist for exactly this:

- **Auto-switcher** (`F9`) — cycles scenes on its own. `Shift+F9` changes how
  it picks: sequential, random, or weighted toward favorites.
- **Knob autopilot** (`:`) — if you stop touching the keyboard/controller for
  30 seconds, it starts slowly drifting scene parameters (colors, speed,
  shapes) on its own, so a scene never looks static even with no one driving.
  Touch any key or the controller and it hands control back to you instantly.

Turn both on and it'll run itself indefinitely — good for background ambiance
at a party, a desk visualizer, whatever.

## Got an Xbox controller?

Plug it in (or connect via Bluetooth) before launching, or it'll be picked up
automatically if you plug it in mid-session. **LB / RB** cycle scenes, and
every scene has its own stick/trigger/button mappings — press **`i`** to see
the live control guide for whatever scene you're on.

See the [full controller layout](../README.md#xbox-controller) in the README
if you want the complete picture.

## Comfort

- **`↑` / `↓`** — volume, in clean 5% steps. Handy late at night.
- **Headache-free mode** — a calmer palette + dimmer composite for long
  viewing sessions or photosensitivity. Not on a hotkey by default; flip
  `HEADACHE_FREE_MODE` in `Music_Visualizer_CK/featureflags.json` (create the
  file if it doesn't exist: `{"HEADACHE_FREE_MODE": true}`) and relaunch.

## A few nice-to-know extras

- **`G`** cycles through post-processing effects (bloom, chromatic
  aberration, scanlines, vignette, pixel-sort) one at a time; **`Shift+G`**
  turns them all off again.
- **`h`** cycles a hand-drawn line-art aesthetic on some scenes.
- **`` ` `` (backtick)** — a handful of scenes have a "how this works" formula
  overlay if you're curious about the math.
- **`q`** quits.

That's really it — the rest of the README's [Controls](../README.md#controls)
section covers every hotkey if you want to go deeper, but the above covers
everything a casual session needs.
