# Roadmap

Long-horizon goals for the visualizer beyond the active feature backlog.

## Distribution: `apt install music-visualizer-ck`

**Goal:** end-users on Debian/Ubuntu can install with one command and run from
the application launcher, without Processing knowledge.

**Why:** today the project requires Processing 4 + Contribution Manager
libraries + a sketch folder. Heavy lift for non-technical clients/venue
operators. A `.deb` package collapses this to a single command.

### Why not just ship a tarball?
- `apt` handles deps (Java runtime, OpenGL, audio libs, etc.) automatically
- System-managed install/update/uninstall lifecycle
- Desktop entry + icon for free via packaging conventions
- Optional later: third-party PPA → `apt update` ships new releases

### Architectural shifts required (none today, plan for the future)

1. **Stop depending on the Processing IDE.** Today `run.sh` invokes
   `processing cli` which is the IDE's launcher. For packaging we need to
   either:
   - **(a) Use processing-java standalone** — Processing ships a CLI-only
     `processing-java` build that compiles + runs sketches without the IDE.
     Bundle that with the package. Smaller, but still wraps the IDE codebase.
   - **(b) Convert sketch to plain Java + Gradle** — strip Processing's
     preprocessor, make `Music_Visualizer_CK` a real Java project that
     `javac`/`gradle build` can produce a runnable JAR from. More work upfront,
     but eliminates Processing-IDE coupling entirely. Recommended long-term.

2. **Vendor the Processing core JAR.** Currently scenes import `processing.core.*`
   etc. The IDE provides those JARs. For packaging, we need them on a stable
   classpath via dependencies (Maven Central has `org.processing:core`).

3. **Asset paths.** `sketchPath()`, `data/`, `code/` are sketch-folder
   conventions. After Java conversion these become resource lookups from the
   classpath, or `/usr/share/music-visualizer-ck/` paths.

4. **Audio source abstraction.** Today the file picker is a Swing dialog tied
   to the sketch's home directory. For a packaged app, switch to:
   - System audio capture (live FFT off the loopback device) as primary input,
   - File picker as fallback,
   - CLI flag `--song <path>` for scripted use.

5. **Settings location.** Move `featureflags.json`, `.devmode`, `.display`,
   etc. to XDG-compliant locations (`$XDG_CONFIG_HOME/music-visualizer-ck/`).

### Packaging plan (in order)

1. **Phase 0 — keep current dev loop working.** All future steps must not
   break `./run.sh` for the dev workflow.
2. **Phase 1 — Gradle build.** Add `build.gradle` that compiles the .pde files
   (after preprocessing) into a runnable fat-JAR. Pull Processing core, Minim,
   Java-WebSocket, etc. from Maven Central.
3. **Phase 2 — Strip preprocessor.** Replace Processing-only syntax (top-level
   functions, `color` type alias) with plain Java. Sketch becomes a single
   `MusicVisualizerCK extends PApplet` class.
4. **Phase 3 — `.deb` packaging.** Use `jpackage` (JDK 14+, ships native
   bundles) or `dpkg-deb` directly. Produces `music-visualizer-ck_X.Y.Z_amd64.deb`
   with:
   - `/usr/bin/music-visualizer-ck` launcher
   - `/usr/share/music-visualizer-ck/` (assets, libraries)
   - `/usr/share/applications/music-visualizer-ck.desktop`
   - Depends: `default-jre-headless`, `libgl1`, `libpulse0`
5. **Phase 4 — distribution.** GitHub Releases attaches the `.deb`; later, a
   PPA on Launchpad for `apt update` semantics.

### Decision points to revisit when ready

- **Native vs JVM bundle** — `jpackage` can produce a self-contained app with
  a bundled JRE (~50MB extra) or rely on system Java. Self-contained is more
  reliable but bigger.
- **Snap vs deb** — snap solves the dependency story differently (sandbox,
  auto-updates), but harder to side-load. `.deb` is more universal for our
  audience.
- **Code signing / repository hosting** — needed if we want `apt update`
  rather than manual `.deb` install.

### Anti-goals

- Don't pivot to Electron or web-only. The Processing/JVM stack is what makes
  the rendering fast on modest GPUs.
- Don't depend on Snap-only paths in the codebase (today `run.sh` already
  falls back gracefully — keep that pattern).
- Don't break the no-build-step `./run.sh` dev loop until Phase 1 is solid.

---

## Phone Controller + Admin Backlog (post-2.4.0)

Small follow-ups identified at the close of the 2.4.0 release. Grouped by
effort/payoff so the next session can grab the top of the list and ship.

### Low-effort, high-impact
- **Admin role-select flicker** — same DOM-rebuild bug the flags dropdown had.
  `renderClients()` does `tb.innerHTML = ""` every 1.5s, so the per-client role
  `<select>` closes mid-click. Apply the build-once / sync-values pattern from
  `index.html` to `admin.html`.
- **Cancel input poll on auth loss** — `controller.html`'s send loop keeps
  firing 60Hz fetches between when the cookie/PIN goes invalid and when the
  page reloads. `clearPinAndReprompt()` should `clearInterval(pollTimer)` (and
  the stick send interval) before the alert.
- **Lockdown HUD badge on the visualizer** — when `clientRegistry.lockdownMode`
  is true, draw a red `LOCKDOWN` pill next to the existing WEB CONTROL badge so
  the operator sees it at a glance from the stage.

### Small features
- **Lockdown timed-release** — `/admin/lockdown` accepts an optional `ttlMs`;
  background timer flips it back off. Useful for "block during set, auto-open
  for the encore."
- **Kick cooldown countdown in admin** — clients table shows "kicked, 4m left"
  per `tempBanIds`/`tempBanIps` so the operator doesn't re-kick by mistake.
- **PIN rotation button** — admin-side `/admin/pins/rotate-master` to mint a
  fresh master PIN without restarting the sketch.
- **Score reset hotkey in TableTennis** — currently the rally counter never
  resets; expose `R` (or an admin scene action) to zero scores + serve order.

### Hygiene
- **gitignore `Music_Visualizer_CK/data/crash_log.txt`** — runtime byproduct
  that shows up dirty after every session.
- **WS reconnect backoff in `controller.html`** — currently retries every 1s
  forever after a drop. Cap at ~5s after N attempts to stop hammering a downed
  visualizer.
- **Admin auth attempt rate-limit** — `/admin/auth` accepts unlimited token
  guesses. Add a 5-fail/min lockout per remote IP (mirror what `PinManager`
  already does for PINs).
