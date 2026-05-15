# Audio Capture Strategy

How does the visualizer get system audio (Spotify, YouTube, DAW out) into the
FFT analyzer? Today's answer: `loopback.sh` flips the global default Pulse
source to the current sink's `.monitor`. It works but mutates user-global
state. This doc surveys cleaner approaches so we can pick a long-term path.

> **Status:** 2026-05-10. Current production path is `loopback.sh` (hardened
> for reboot survival in `59e70c9`) + `run-with-loopback.sh` wrapper for trap
> guarantees. Both are stopgaps — the global mutation is still the root issue.

---

## Constraint that shapes everything

JVM on Linux uses `javax.sound.sampled`, which enumerates ALSA mixers. On a
PipeWire system, `pipewire-alsa` provides ONE virtual ALSA device named
`default`. JVM does **not** see Pulse sources directly. So any solution has
to surface the desired capture as ALSA `default` (globally or per-process)
or replace the audio backend entirely.

This is why "just set `PULSE_SOURCE=...`" doesn't work — that only affects
native Pulse clients, and JVM is not one.

---

## Approaches

Ordered roughly cleanest → most invasive.

### A. `PIPEWIRE_NODE` env var (per-process binding)

PipeWire's ALSA bridge honors `PIPEWIRE_NODE=<node-name>` set on the client
process. The process's `default` ALSA device binds to that PipeWire node for
its lifetime. Zero global mutation, no cleanup needed.

```bash
PIPEWIRE_NODE="alsa_output.pci-0000_0e_00.4.analog-stereo.monitor" ./run.sh
```

**Pros:**
- Per-process — zero blast radius on crash, reboot, terminal close.
- No state file, no `off` step, no wireplumber cache pollution.
- Trivial to wrap (`run-with-pw-node.sh` resolves current sink monitor →
  exports env var → exec run.sh).

**Cons:**
- PipeWire-only. Pure PulseAudio (no PipeWire) doesn't honor it; would need
  fallback to `loopback.sh`-style flip.
- Untested whether `pipewire-alsa` faithfully forwards the env var when JVM
  opens the ALSA `default` line. Needs a spike.
- If the sink is hot-swapped while running (Bluetooth disconnect, headphone
  unplug), the bound node disappears and JVM's audio line errors out. Same
  hazard as today, but more visible (per-process error vs system wedge).

**Open questions:**
- Does `pipewire-alsa` propagate `PIPEWIRE_NODE` for capture lines, or only
  playback? Some forum threads suggest playback only.
- Is the env var lookup at line-open time or process-start time? Determines
  whether F10 device reselect inside the sketch can pick a different node.

**Verdict:** highest payoff if it works. Spike before betting on it.

---

### B. `module-remap-source` virtual mic

```bash
pactl load-module module-remap-source master=<monitor> source_name=vis_capture
# … sketch runs …
pactl unload-module <module-id>
```

Creates a named virtual source we own. Loading/unloading is fully scoped to
our session — no persistent state in wireplumber's `default-nodes` cache.

**Pros:**
- Survives sink changes (master can be re-set without changing source name).
- Cleanup is by module ID, not by reading saved-prior state — much harder to
  desync.
- Doesn't need the user to know about monitor sources.

**Cons:**
- Doesn't solve "JVM only sees ALSA default" — still need `PIPEWIRE_NODE` or
  a default-source flip to make JVM actually pick this source.
- So it's a complement to A or C, not a replacement.
- Slightly more state to track (module ID).

**Verdict:** worth combining with A for robustness, not standalone.

---

### C. Hardened `loopback.sh` (current path)

Flip `default-source` globally, save prior in `~/.cache/`, restore on `off`.
Wrapper traps EXIT/INT/TERM.

**Pros:**
- Works on Pulse and PipeWire.
- Already shipping.

**Cons:**
- Global mutation. WirePlumber persists it to `default-nodes` — survives
  reboot if cleanup is missed (kernel panic, OOM kill, machine yanked).
- Hardening reduces but doesn't eliminate the wedge risk. If the saved
  prior source is gone *and* every available source is a monitor, fallback
  fails and we leave the system on a monitor permanently.
- User-visible side effect: every other app on the machine starts capturing
  the monitor while the sketch runs. Voice-call apps especially.

**Verdict:** acceptable stopgap. Long-term goal is to retire it.

---

### D. xdg-desktop-portal (OBS's approach)

OBS, Firefox screen-share, GNOME Screenshot, etc. all use
`org.freedesktop.portal.ScreenCast` over DBus. With audio enabled, the
portal hands back a PipeWire node ID + file descriptor scoped to the
caller's PID. Per-app or system-wide capture is selectable in a permission
dialog the portal shows.

**Pros:**
- True per-app capture (capture *only* Spotify, not everything).
- No global state, no cleanup. Permission revoked when caller exits.
- Future-proof: this is where the Linux desktop is going.

**Cons:**
- DBus client + portal handshake. From Java, that means `dbus-java` (heavy)
  or shelling out to `gdbus`/Python helper.
- Permission dialog every launch unless persisted (and we can't persist
  programmatically without being a sandboxed app).
- Returns a PipeWire node, not an ALSA device. JVM still can't see it
  directly — would need to bridge via `pw-loopback` or rewrite the audio
  capture path to use `pw_stream` natively (JNI to libpipewire).
- Way more code. Probably 3-5 days of work + ongoing maintenance.

**Verdict:** correct long-term answer for power features (per-app capture),
overkill if all we want is "system audio in".

---

### E. Native PipeWire capture via JNI

Replace Minim's audio input path with a native pipewire capture node
written in C, called from Java via JNI. Same approach OBS takes internally
(though OBS is C++ throughout).

**Pros:**
- Total control — per-process, named node, zero ALSA involvement.
- Could expose device picker that lists PipeWire nodes by friendly name
  rather than the cryptic ALSA names today.

**Cons:**
- Major undertaking. JNI build, cross-compile pipewire bindings, lifecycle
  management.
- Loses Minim's FFT pipeline integration (would need to feed PCM into Minim
  manually, or replace Minim entirely).
- Linux-only. Mac/Windows still go through Java Sound. Splits the audio
  layer in two.

**Verdict:** only worth it if we're already replacing Minim for other
reasons (latency, multi-channel, stems). Not on the table today.

---

## Decision matrix

| Approach          | Global mutation | JVM works | Effort   | Per-app | Crash-safe |
|-------------------|-----------------|-----------|----------|---------|------------|
| A. PIPEWIRE_NODE  | None            | ?spike    | XS       | No      | Yes        |
| B. remap-source   | None            | No (alone)| S        | No      | Mostly     |
| C. loopback.sh    | Yes (hardened)  | Yes       | Done     | No      | Mostly     |
| D. portal         | None            | No (alone)| L        | Yes     | Yes        |
| E. JNI pipewire   | None            | Yes (own) | XL       | Yes     | Yes        |

---

## Recommended path

1. **Now:** ship hardened C (already done). Document A/D as alternatives.
2. **Next short:** spike A on this machine. Two outcomes:
   - Works → write `run-with-pw-node.sh`, deprecate `loopback.sh` to a
     legacy/Pulse-only fallback. Default to A in docs.
   - Fails → file the negative result here, fall through to B+A combined.
3. **Long term, if we ever want per-app capture:** pursue D. It's also the
   right shape if we ever ship a Mac/Windows port — every modern OS has an
   equivalent system-audio-capture portal (CoreAudio tap on macOS 14.4+,
   ActivateAudioInterfaceAsync on Windows). All are per-app and crash-safe.
4. **E only if** Minim itself becomes the bottleneck for an unrelated
   reason. Don't pull this in just for capture.

---

## Related files

- `loopback.sh` — current global-default-flip implementation.
- `run-with-loopback.sh` — wrapper with trap guarantees.
- `audio-probe.sh` — diagnostics; what sources/monitors exist + what JVM sees.
- `Music_Visualizer_CK/src/core/Audio.pde` — Minim init + device selection.
- `feature_audio_device_input.md` (memory) — the F10 device picker history.
