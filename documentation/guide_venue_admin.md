# Guide: Venue Admin / Tech

This covers everything from "first time setting this up at a new space" to
"running the phone-control/streaming side of a live show." If you're the one
performing rather than running the tech, see the [VJ guide](guide_vj.md)
instead — the two overlap but this one goes deeper on network/admin.

## Before you arrive: install + basics

**Linux:** `sudo dpkg -i music-visualizer_*.deb` then run `music-visualizer`.
Other platforms / from source: see the [README](../README.md#run-from-source).

Pair your Xbox controller before launch if you're using one. Load your
song library or set up live audio input via **`'`** (apostrophe) — see the
[VJ guide](guide_vj.md#before-doors) for the audio-source picker.

## Network setup — read this before the first show

**The stream is LAN-only, on purpose.** No internet, no STUN/TURN servers —
phones connect directly to your laptop over the local network. This is
covered in full in [`documentation/venue_network_setup.md`](venue_network_setup.md);
the two things that will actually bite you:

1. **Venue guest WiFi usually won't work.** Most guest/public WiFi has
   client isolation enabled — every device can reach the internet but not
   each other, even though they're all "connected." Your laptop and a
   phone on the same guest WiFi often can't see each other at all. **Bring
   your own travel router** (plug the laptop into it via ethernet if
   possible) rather than relying on the venue's network. Laptop-as-hotspot
   is the fallback if you can't bring a router.
2. **Firewall ports**, if your laptop's firewall is on:

   | Port | Protocol | Purpose |
   |---|---|---|
   | 8080 | TCP | Control panel, stream pages, admin — walks to 8081+ if 8080's taken |
   | 8889 | TCP+UDP | WebRTC low-latency stream (UDP matters — falls back to HLS silently without it) |
   | 8888 | TCP | HLS fallback stream |
   | 8554 | TCP | Internal RTSP hand-off to MediaMTX, laptop-local only |

   On Ubuntu/Debian: `sudo ufw allow 8080/tcp && sudo ufw allow 8889 && sudo ufw allow 8888/tcp`

3. **Scaling**: every phone watching the stream is a separate connection —
   roughly 1.5 Mbit/s each on the low-bandwidth venue profile. A cheap
   travel router will start struggling somewhere around 10-20 simultaneous
   viewers. Know your router's limits before promising "everyone can watch
   on their phone."

The sketch prints the URL to give out on launch — look for the `★` marked
line in the console, or the **WEB CONTROL** HUD badge (bottom-left onscreen),
something like `http://192.168.1.50:8080/`. If you see `⚠ NO LAN ADDRESS
FOUND`, you're not actually on a network phones can reach — fix that before
telling anyone to scan a QR code.

## Streaming to screens (lobby TV, second room, phones)

- **`F6`** toggles the stream (use **`F7`** instead if your window manager
  eats F6 — GNOME is known to). Watch URL: `http://<lan-ip>:8080/stream.html`
  — WebRTC first (100-300ms latency), auto-falls-back to HLS (1-3s) if
  WebRTC can't connect.
- **`Shift+F6`/`F7`** cycles bandwidth profile: NORMAL (30fps, 4 Mbit) vs
  VENUE (24fps, ~1.5 Mbit) for weak WiFi. Switch to VENUE proactively if
  you know the network is going to be crowded.
- Needs a MediaMTX binary. If you get `"MediaMTX not found"`, run
  `./install-stream.sh` once (fetches it automatically).
- If F6/F7 don't seem to do anything (WM stealing the keypress), use the
  **START STREAM** button on the operator dashboard instead (see below) —
  no auth needed if you're on the laptop itself.
- Logs if something's wrong: `stream_ffmpeg.log` and `mediamtx.log` in the
  app's user data directory.

## Phone control — PIN, queue, and admin

Anyone who opens the LAN URL and enters the **master PIN** (6 characters,
shown in the console at launch, changes every session) connects as a guest
and can drive the visualizer. A few things you control:

- **Turn-based queue** — each driver gets 5 minutes by default, then it
  rotates automatically. Spectators can 👍/👎 the current driver; enough
  dislikes (5+, and more than double the likes) force-ends their turn early
  — this is the built-in troll mitigation, you shouldn't need to intervene
  manually most nights.
- **Named PINs** — mint one for a specific person (co-VJ, a friend) with a
  role attached, from the admin panel. These persist across restarts,
  unlike the master PIN.
- **Lockdown mode** — refuses all new connections while active (existing
  drivers keep going). Use this if the queue's getting out of hand and you
  want to stop new people from jumping in. Can auto-release after a timer.
- **Kick** — disconnects someone and blocks them from reconnecting with the
  same PIN for 5 minutes. **Ban** is the permanent version.
- **Wrong-PIN lockout** happens automatically — 5 wrong attempts from an IP
  locks it out for 60 seconds, extending on repeated failures. You don't
  need to do anything for this to work, just know it's there if someone
  says "it won't let me in."

**Getting into the admin panel**: the token is auto-generated on first run
and printed to console (`[ADMIN] token: ...`) — also saved to
`.devadmintoken` in the app's user data dir if you need to find it later
without scrolling back through the console. Go to `/admin-login.html` on
your own device, enter the token (never put it in the URL — it's a
password-style field on purpose), and you're in for the session (cookie
lasts 24h). **If you're sitting at the laptop itself**, you skip all of this
— localhost never needs the token.

**Operator dashboard** (`/operator.html`) is worth having open on a second
screen or tablet during a show: live stream status, elapsed time, dropped
frames, and a stream toggle button, no login needed just to view it (only
actually toggling the stream from a *different* device needs the admin
cookie).

## Show-night checklist

1. **`Ctrl+Enter`** — showtime macro: fullscreen + strobe safety on, one
   press. Safe to hit again if some of that's already on.
2. Confirm strobe safety is actually on (**`F12`** toggles it, or just check
   it stuck from step 1) — this dampens brightness jumps/flash rate against
   WCAG-style thresholds, worth having on for any public show.
3. Confirm the right display: **`Ctrl+1`..`Ctrl+9`** moves the window to
   display N if you're multi-monitor.
4. If you're running a setlist, **`{`** loads it (writes a template first
   time), **`}`** turns on auto-advance if your entries have `@duration`
   set.
5. Know your kill switch: **`Esc`** (or controller **Back+Start**) fades to
   black instantly. This is your emergency stop — test it once before doors
   so you know exactly what it feels like.
6. If streaming to phones/TV: **`F6`**/`F7`, confirm the URL is reachable
   from an actual phone on the venue network before doors, not after.

## Troubleshooting

- **A scene crashed / looks broken** — the visualizer catches this itself
  (`SceneGuard`): shows a brief recovery card and skips the scene after 3
  failures in a session, no crash to desktop. If you want the details, they
  land in `crash_log.txt`.
- **Frame stall / stuck** — a watchdog thread detects renders that hang for
  >2s and logs the stack trace to the same crash log — useful if you need
  to file an issue, not something you fix live.
- **Phone can't connect at all** — almost always the guest-WiFi
  client-isolation problem above. Confirm the phone and laptop are actually
  on a network that lets devices see each other.
- **Stream works on WebRTC but not for one person** — that's HLS falling
  back for them (some networks/browsers block WebRTC's UDP traffic); it'll
  just be a couple seconds more latency for that viewer, not a bug.
- **Someone's being a problem in the queue** — kick them (5-min cooldown),
  or drop into lockdown mode if it's a pattern, not one person.

## See also

- [`documentation/venue_network_setup.md`](venue_network_setup.md) — full
  network guide with a glossary if any of the above terms are unfamiliar.
- [`documentation/production_readiness_for_live_shows.md`](production_readiness_for_live_shows.md)
  — the underlying feature list + what's still on the roadmap (operator HUD
  on a second display, preset snapshots, live mixer input verification).
- [VJ guide](guide_vj.md) — if you're also the one performing, not just
  running tech.
