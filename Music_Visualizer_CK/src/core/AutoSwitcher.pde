// AutoSwitcher — beat-synced auto scene switching on major drops.
//
// Gated by dropPredictor: only fires when majorImminentDropFactor crosses
// a threshold. Has cooldown + recent-history so switches feel deliberate
// instead of random. Five modes, toggled via L3 / F9, cycled via R3 / Shift+F9.

class AutoSwitcher {

  // ── Modes ─────────────────────────────────────────────────────────────────
  // (no `static` — Processing classes are inner classes of PApplet)
  final int MODE_OFF            = 0;
  final int MODE_FAVS_ONLY      = 1;
  final int MODE_FAVS_WEIGHTED  = 2;
  final int MODE_SEQUENTIAL     = 3;
  final int MODE_RANDOM_ALL     = 4;
  final int MODE_COUNT          = 5;

  final String[] MODE_LABELS = {
    "OFF", "FAVS ONLY", "FAVS WEIGHTED", "SEQUENTIAL", "RANDOM"
  };

  // ── Tuning ────────────────────────────────────────────────────────────────
  final float DROP_THRESHOLD   = 0.55;    // majorImminentDropFactor gate
  final int   COOLDOWN_FRAMES  = 60 * 60; // 60s between switches
  final int   HISTORY_SIZE     = 3;       // avoid last N scenes on pick
  final int   FAV_WEIGHT       = 3;       // weighted mode multiplier

  // ── State ─────────────────────────────────────────────────────────────────
  int     mode            = MODE_FAVS_WEIGHTED; // default when enabled
  boolean enabled         = false;
  int     lastSwitchFrame = -9999;
  java.util.Deque<Integer> recent = new java.util.ArrayDeque<Integer>();

  // ── Public API ────────────────────────────────────────────────────────────
  void toggleEnabled() {
    enabled = !enabled;
    if (enabled) lastSwitchFrame = frameCount; // grace period after enabling
  }

  void cycleMode() {
    mode = (mode + 1) % MODE_COUNT;
    if (mode == MODE_OFF) mode = MODE_FAVS_ONLY; // OFF is handled by enabled flag
  }

  // Called every logical tick. Triggers switchScene() when drop detected.
  void tick() {
    if (!enabled) return;
    if (dropPredictor == null || !dropPredictor.isReady) return;
    if (frameCount - lastSwitchFrame < COOLDOWN_FRAMES) return;
    if (pendingScene >= 0) return; // switch already queued

    float imminence = dropPredictor.majorImminentDropFactor(audio.player.position(), 4.0);
    if (imminence < DROP_THRESHOLD) return;

    int next = pickNext();
    if (next < 0 || next == config.STATE) return;

    switchScene(next);
    lastSwitchFrame = frameCount;
    recent.addLast(next);
    while (recent.size() > HISTORY_SIZE) recent.removeFirst();
  }

  // ── Scene picking ─────────────────────────────────────────────────────────
  int pickNext() {
    ArrayList<Integer> order = sceneSwitcher.activeOrder;
    HashSet<Integer> favs    = sceneSwitcher.favourites;
    if (order.isEmpty()) return -1;

    switch (mode) {
      case MODE_SEQUENTIAL: {
        int next = sceneSwitcher.nextScene(config.STATE);
        // Skip blacklisted
        int guard = 0;
        while (sceneGuard != null && sceneGuard.isBlacklisted(next) && guard++ < order.size()) {
          next = sceneSwitcher.nextScene(next);
        }
        return next;
      }
      case MODE_FAVS_ONLY: {
        ArrayList<Integer> pool = new ArrayList<Integer>();
        for (int s : favs) if (s != config.STATE && !isBlocked(s)) pool.add(s);
        if (pool.isEmpty()) {
          // Fallback: any fav except current, ignoring history
          for (int s : favs) if (s != config.STATE) pool.add(s);
        }
        if (pool.isEmpty()) return -1;
        return pool.get((int) random(pool.size()));
      }
      case MODE_FAVS_WEIGHTED: {
        ArrayList<Integer> pool = new ArrayList<Integer>();
        for (int s : order) {
          if (s == config.STATE || isBlocked(s)) continue;
          int w = favs.contains(s) ? FAV_WEIGHT : 1;
          for (int i = 0; i < w; i++) pool.add(s);
        }
        if (pool.isEmpty()) return -1;
        return pool.get((int) random(pool.size()));
      }
      case MODE_RANDOM_ALL: {
        ArrayList<Integer> pool = new ArrayList<Integer>();
        for (int s : order) if (s != config.STATE && !isBlocked(s)) pool.add(s);
        if (pool.isEmpty()) return -1;
        return pool.get((int) random(pool.size()));
      }
    }
    return -1;
  }

  boolean isBlocked(int sceneIdx) {
    if (sceneGuard != null && sceneGuard.isBlacklisted(sceneIdx)) return true;
    return recent.contains(sceneIdx);
  }

  // ── HUD ───────────────────────────────────────────────────────────────────
  String hudLine() {
    if (!enabled) return null;
    int secsLeft = max(0, (COOLDOWN_FRAMES - (frameCount - lastSwitchFrame) + 59) / 60);
    String label = padRight(MODE_LABELS[mode], 13);
    String right = (secsLeft > 0) ? ("cd " + nf(secsLeft, 3) + "s  ") : "  READY  ";
    return "AUTO " + label + right;
  }

  String padRight(String s, int n) {
    StringBuilder sb = new StringBuilder(s);
    while (sb.length() < n) sb.append(' ');
    return sb.toString();
  }
}

// HUD badge — restored alongside AutoSwitcher class (was missing from develop).
void drawAutoSwitcherBadge() {
  String line = autoSwitcher.hudLine();
  if (line == null) return;
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);
  float tw    = textWidth("AUTO FAVS WEIGHTED cd 999s  ");
  float boxH  = ts + 10;
  float boxW  = tw + 16;
  float pad   = 10 * uiScale();
  float boxX  = width - pad - boxW;
  float boxY  = height - pad - boxH;
  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);
  fill(0, 255, 120);
  text(line, boxX + 8, boxY + 5);
  popStyle();
}
