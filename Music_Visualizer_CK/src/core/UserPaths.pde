// UserPaths.pde — resolve a writable per-user data dir for runtime files.
//
// Why: when the app is installed under /opt/music-visualizer (deb) or
// C:\Program Files (Windows), the install dir is not user-writable. Anything
// the sketch needs to *save* (featureflags.json, pins.json, bans.json, crash
// log, prefs, scores) must live under a per-user location.
//
// Layout (XDG / platform-native):
//   Linux   — $XDG_CONFIG_HOME/music-visualizer/   (or ~/.config/music-visualizer/)
//   macOS   — ~/Library/Application Support/MusicVisualizer/
//   Windows — %APPDATA%\MusicVisualizer\           (fallback ~/AppData/Roaming)
//
// Dev-mode bypass: when isDevMode() is true (./run.sh creates .devmode), we
// keep using sketchPath() so files stay next to the sketch in the repo and
// `git status` still surfaces changes during development.
//
// Migration: if a runtime file already exists at the legacy sketchPath(name)
// location and not yet at userDataPath(name), we copy it on first access so
// existing installs keep their state across the move.

String _cachedUserDataDir = null;

String userDataDir() {
  if (_cachedUserDataDir != null) return _cachedUserDataDir;

  // Dev override: run.sh exports MV_USER_DATA_DIR=$ORIGIN_DIR so editing the
  // sketch from the repo keeps state next to the source. We deliberately do
  // NOT use isDevMode() here — it checks ~/.devmode, which leaks into any
  // installed copy on the same user account.
  String env = System.getenv("MV_USER_DATA_DIR");
  String dir;
  if (env != null && env.length() > 0) {
    dir = env;
  } else {
    String os = System.getProperty("os.name").toLowerCase();
    String home = System.getProperty("user.home");
    if (os.contains("win")) {
      String appdata = System.getenv("APPDATA");
      dir = (appdata != null && appdata.length() > 0 ? appdata : home + "\\AppData\\Roaming") + "\\MusicVisualizer";
    } else if (os.contains("mac")) {
      dir = home + "/Library/Application Support/MusicVisualizer";
    } else {
      String xdg = System.getenv("XDG_CONFIG_HOME");
      dir = (xdg != null && xdg.length() > 0 ? xdg : home + "/.config") + "/music-visualizer";
    }
  }

  java.io.File d = new java.io.File(dir);
  if (!d.exists()) d.mkdirs();
  _cachedUserDataDir = d.getAbsolutePath();
  return _cachedUserDataDir;
}

// Resolve a read-only resource (skyboxes, web UI, images) across all layouts.
//
// Layouts we need to support:
//   dev (./run.sh):  sketchPath() = .../music-visualizer-4-friend/.build/Music_Visualizer_CK/
//                    media/ + featureflags-ui/ live two levels up at repo root
//   exported app:    sketchPath() = /opt/music-visualizer/  (or %APP%/Music_Visualizer_CK/)
//                    media/ + featureflags-ui/ are copied into data/<name>/ by release.yml
//
// Try a list of candidate locations and return the first that exists. Falls
// back to the last candidate so callers see a consistent (broken) path in
// error messages rather than a confusing empty string.
String resourcePath(String rel) {
  String[] candidates = {
    sketchPath("data/" + rel),       // exported / .deb layout (bundled under data/)
    sketchPath(rel),                 // sketch root
    sketchPath("../" + rel),         // dev .build sibling
    sketchPath("../../" + rel)       // dev repo root (legacy)
  };
  for (String c : candidates) {
    if (new java.io.File(c).exists()) return c;
  }
  return candidates[candidates.length - 1];
}

// Returns absolute path to <userDataDir>/<name>, creating the dir on first
// call. If the file is missing here but exists at the legacy sketchPath(name)
// location, copy it across so upgrades preserve user state.
String userDataPath(String name) {
  String target = userDataDir() + java.io.File.separator + name;
  java.io.File t = new java.io.File(target);
  if (!t.exists()) {
    try {
      java.io.File legacy = new java.io.File(sketchPath(name));
      if (legacy.exists() && !legacy.getCanonicalPath().equals(t.getCanonicalPath())) {
        java.io.File parent = t.getParentFile();
        if (parent != null && !parent.exists()) parent.mkdirs();
        java.nio.file.Files.copy(legacy.toPath(), t.toPath());
        println("[UserPaths] migrated " + name + " → " + target);
      }
    } catch (Exception e) {
      // best-effort migration; fall through and let the caller create fresh
    }
  }
  return target;
}
