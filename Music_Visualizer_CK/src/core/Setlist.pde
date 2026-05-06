/**
 * Setlist — pre-planned scene queue for live shows.
 *
 * Reads `setlist.txt` from the user data directory. Format: one entry per
 * line. Each line is either a scene index (0..SCENE_COUNT-1) or a scene
 * class name (e.g. RoseCurveScene). Trailing `@duration <seconds>` enables
 * auto-advance.
 *
 *   # opener
 *   45             @duration 60
 *   RoseCurveScene @duration 90
 *   46
 *   # peak
 *   30             @duration 120
 *
 * Hotkeys (wired in main keyPressed):
 *   ]   advance to next entry (crossfade via switchScene)
 *   [   step back one entry
 *   }   toggle auto-advance (Shift+])
 *   {   reload setlist.txt from disk (Shift+[)
 *
 * Lines that don't resolve to a scene are skipped with a console warning,
 * so a typo doesn't kill the queue mid-set.
 */
class Setlist {
  static final String FILE_NAME = "setlist.txt";

  class Entry {
    int    sceneId;
    String label;
    int    durationSeconds; // 0 = manual-only
    Entry(int id, String l, int d) { sceneId = id; label = l; durationSeconds = d; }
  }

  ArrayList<Entry> entries = new ArrayList<Entry>();
  int     cursor          = -1;     // -1 = not started; 0..n-1 active entry
  long    enteredAtMs     = 0;
  boolean autoAdvance     = false;

  void load() {
    entries.clear();
    cursor = -1;

    String path = userDataPath(FILE_NAME);
    java.io.File f = new java.io.File(path);
    if (!f.exists()) writeSampleFile(path);

    String[] lines = null;
    try { lines = loadStrings(path); } catch (Exception ignored) {}
    if (lines == null) {
      println("[SETLIST] no " + FILE_NAME + " at " + path);
      return;
    }

    for (String raw : lines) {
      String line = raw.trim();
      if (line.length() == 0 || line.startsWith("#")) continue;

      int duration = 0;
      int atIdx = line.indexOf('@');
      String body = (atIdx >= 0) ? line.substring(0, atIdx).trim() : line;
      if (atIdx >= 0) {
        String tail = line.substring(atIdx).trim();
        // Recognise @duration <N>  (with optional 's')
        if (tail.startsWith("@duration")) {
          String num = tail.substring("@duration".length()).trim();
          if (num.endsWith("s")) num = num.substring(0, num.length() - 1).trim();
          try { duration = Integer.parseInt(num); } catch (Exception ignored) {}
        }
      }

      int sceneId = resolveScene(body);
      if (sceneId < 0) {
        println("[SETLIST] skipping unknown entry: " + body);
        continue;
      }
      entries.add(new Entry(sceneId, body, duration));
    }
    println("[SETLIST] loaded " + entries.size() + " entries from " + path);
  }

  // Drop a commented template so a fresh install has something to edit.
  void writeSampleFile(String path) {
    try {
      saveStrings(path, new String[]{
        "# Setlist template",
        "# One scene per line: numeric id (0..49) or scene class name.",
        "# Optional `@duration <seconds>` enables auto-advance when toggled (}).",
        "# Lines starting with # are ignored. Edit and reload with {.",
        "#",
        "# 45             @duration 60",
        "# RoseCurveScene @duration 90",
        "# 46"
      });
      println("[SETLIST] wrote template to " + path);
    } catch (Exception ignored) {}
  }

  int resolveScene(String token) {
    // Numeric?
    try {
      int n = Integer.parseInt(token);
      if (n >= 0 && n < SCENE_COUNT && scenes[n] != null) return n;
    } catch (Exception ignored) {}
    // Class-name match
    for (int i = 0; i < SCENE_COUNT; i++) {
      if (scenes[i] != null
          && scenes[i].getClass().getSimpleName().equalsIgnoreCase(token)) {
        return i;
      }
    }
    return -1;
  }

  void advance() {
    if (entries.isEmpty()) { println("[SETLIST] empty — load setlist.txt first"); return; }
    cursor = (cursor + 1) % entries.size();
    activate();
  }

  void back() {
    if (entries.isEmpty()) return;
    cursor = (cursor - 1 + entries.size()) % entries.size();
    activate();
  }

  void toggleAuto() {
    autoAdvance = !autoAdvance;
    println("[SETLIST] auto-advance " + (autoAdvance ? "ON" : "OFF"));
  }

  // Called once per frame from main draw().
  void tick() {
    if (!autoAdvance || cursor < 0 || cursor >= entries.size()) return;
    Entry e = entries.get(cursor);
    if (e.durationSeconds <= 0) return;
    long elapsedMs = System.currentTimeMillis() - enteredAtMs;
    if (elapsedMs >= e.durationSeconds * 1000L) advance();
  }

  void activate() {
    Entry e = entries.get(cursor);
    enteredAtMs = System.currentTimeMillis();
    println("[SETLIST] " + (cursor + 1) + "/" + entries.size()
            + " -> " + e.label + " (scene " + e.sceneId
            + (e.durationSeconds > 0 ? ", " + e.durationSeconds + "s" : "") + ")");
    switchScene(e.sceneId);
  }

  String nowLabel() {
    if (cursor < 0 || cursor >= entries.size()) return "—";
    Entry e = entries.get(cursor);
    int total = e.durationSeconds;
    if (total <= 0) return e.label;
    int elapsed = (int)((System.currentTimeMillis() - enteredAtMs) / 1000);
    return e.label + " " + elapsed + "/" + total + "s";
  }

  String nextLabel() {
    if (entries.isEmpty()) return "—";
    int next = (cursor + 1) % entries.size();
    return entries.get(next).label;
  }

  boolean isActive() { return cursor >= 0 && !entries.isEmpty(); }
  int     size()     { return entries.size(); }
}
