# Guide: Performing Live (VJ)

You're driving this in front of people. This guide is workflow-first: what to
set up before doors, what to touch during the set, and what to hit if
something goes wrong. Full hotkey reference lives in the
[README](../README.md#controls) — this is the "what order do I actually do
things in" version.

## Before doors

**1. Get your song library / live input sorted.**

- Playing from files: `./run.sh` (or launch the installed app) opens a file
  picker. `n` / `N` skip to the next / a random track once running.
- Playing from a DJ mixer / live source instead: press **`'`** (apostrophe)
  to open the audio source picker. It lists every PulseAudio source it can
  see, with a **★ RECOMMENDED** entry at the top — the monitor of whatever's
  currently your default output, i.e. "hear whatever the speakers are
  playing." Arrow keys / `j`/`k` to move, Enter to select. If your mixer
  shows up as a real input (not a monitor) instead, it'll be listed under
  `[INPUT]`.
- This picker is the easy path — you generally don't need `loopback.sh`
  manually anymore, that's the advanced/scripted fallback if the picker
  doesn't see your source for some reason (see `documentation/audio_capture_strategy.md`).

**2. Build a setlist (optional but recommended for a planned set).**

Press **`{`** once to write a template `setlist.txt`, then edit it. Each line
is a scene name or number, with an optional timing:

```
RoseCurveScene @duration 90
45              @duration 60
GravityStringsScene
```

- **`]`** / **`[`** — next / previous setlist entry
- **`}`** — toggle auto-advance (uses each entry's `@duration`; entries
  without one just sit until you advance manually)
- **`{`** — reload from disk if you edit it mid-set

**3. Decide your safety defaults before you're in front of people.**

- **`F12`** — strobe safety cap. Auto-enables when you go fullscreen, but
  check it's on if you're not going fullscreen for some reason. It dampens
  flash rate / brightness jumps that could bother a photosensitive audience
  member — leave it on unless you have a specific reason not to.
- Know where the kill switch is: **`Esc`** (or **Back+Start** on the
  controller) instantly fades to black. Re-press to bring the visuals back.
  This is your "something's wrong, cut it now" button — muscle-memory it.

**4. Get on the right screen.**

- **`F11`** toggles fullscreen on whatever display the window is currently on.
- **`Ctrl+1`..`Ctrl+9`** moves the window to display N first, if you're
  running multi-monitor and need it on the projector/LED wall specifically.
- **`Ctrl+Enter`** — "showtime" macro, does fullscreen + strobe safety in one
  press. Good one-key "we're live" button. Safe to hit again if you're
  already in that state.

## During the set

**Switching scenes** — controller **LB / RB** (previous/next) is the
lowest-friction way to do this live without looking down. Keyboard
equivalents: **`<`** / **`>`**, or **`1`-`9`/`0`** to jump straight to a
favorite slot, or **`Tab`** for a visual picker if you want to browse.

**Reading the room / hands-off moments** — **`F9`** turns on the
auto-switcher if you need to step away or want scenes to cycle themselves for
a stretch; **`Shift+F9`** cycles its mode (sequential / random / weighted
toward favorites). Controller **L3** does the same toggle, **R3** cycles
mode, so you don't have to reach for the keyboard.

**Tempo** — tap **`\`** four times on the beat to lock BPM (some
scenes/effects use this for timing); **`|`** clears the lock.

**Visual intensity** — **`G`** cycles through post-processing one effect at
a time (bloom → chromatic aberration → scanlines → vignette → pixel-sort),
**`Shift+G`** kills all of them at once if things get too busy.

**Per-scene control** — every scene has its own stick/trigger/button
mappings. Press **`i`** to bring up the live control guide for whatever
scene's currently up, so you're not guessing.

**Telling people what's playing** — **`F3`** toggles a text overlay (track
title / your name), **`Shift+F3`** cycles where it sits on screen.

**Recording the set** — **`F5`** starts/stops an mp4 recording (downscaled,
piped through ffmpeg) if you want a copy for socials afterward.

**Streaming to a screen elsewhere in the venue** (a lobby TV, a second room,
someone's phone) — **`F6`** (or **`F7`** if your window manager eats F6)
toggles a LAN stream; **`Shift+F6`/`F7`** switches to a low-bandwidth profile
if the venue WiFi is weak. This is LAN-only — see the venue tech guide if
you're setting this up for the first time at a new space.

## If something goes wrong

- **Frozen / a scene misbehaving** — the visualizer catches scene crashes on
  its own (`SceneGuard`): it'll show a brief "scene recovering" card and
  auto-skip to the next scene if a scene fails 3 times in a session. You
  usually don't need to do anything but keep going.
- **Need it black right now** — `Esc` or Back+Start. Always works.
- **Audio cut out / wrong source** — apostrophe (`'`) to reopen the source
  picker, pick again.
- **Lost your place** — `Tab` for the visual scene picker, or `?` for the
  full onscreen hotkey cheat sheet if your memory blanks under pressure.

## After

- `q` quits cleanly (stops audio properly first, so you don't leave a
  process holding the audio device for the next thing you do).
