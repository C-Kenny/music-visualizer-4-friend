// SceneSwitcher — matrix terminal overlay for browsing, favouriting, and reordering scenes.
//
// Toggle with Tab. While open, ALL key input is routed here — scene hotkeys are suppressed.
//
// Keys while open:
//   j / ↓        move cursor down
//   k / ↑        move cursor up
//   Enter/Space  switch to selected scene
//   f            toggle favourite on selected scene
//   J (shift-j)  move selected scene DOWN in rotation
//   K (shift-k)  move selected scene UP in rotation
//   Esc / Tab    close
//
// Favourites are sorted to the top of the list automatically.
// Order and favourites persist in Music_Visualizer_CK/.scene_prefs between runs.

class SceneSwitcher {

  // ── Runtime state ─────────────────────────────────────────────────────────
  ArrayList<Integer> activeOrder;  // live rotation order, fully dynamic
  HashSet<Integer>   favourites;   // set of favoured scene indices
  boolean            isOpen = false;
  int                cursor = 0;   // highlighted row in the overlay list
  
  // ── Input Repeat Logic ───────────────────────────────────────────────────
  long lastRepeatTime = 0;
  int  repeatDelay    = 300; // ms before first repeat
  int  repeatInterval = 60;  // ms between subsequent repeats
  boolean isRepeating = false;
  char lastRepeatKey  = 0;
  int  lastRepeatCode = 0;

  // ── Display tuning ────────────────────────────────────────────────────────
  int BG_COLOR, BORDER_COLOR, ROW_LIVE, ROW_CURSOR;
  int TEXT_HEADER, TEXT_FAV, TEXT_DIM, TEXT_HINT;

  // ── Prefs file ────────────────────────────────────────────────────────────
  final String PREFS_FILE = ".scene_prefs";

  // ── Scene name map (index → friendly label) ───────────────────────────────
  String[] SCENE_NAMES = new String[SCENE_COUNT];

  SceneSwitcher(int[] defaultOrder) {
    // Initialise palette colours inside constructor (Processing can't call color() at field-init time)
    BG_COLOR     = color(0, 210);
    BORDER_COLOR = color(0, 255, 0);
    ROW_LIVE     = color(0, 255, 0, 60);
    ROW_CURSOR   = color(0, 255, 0, 100);
    TEXT_HEADER  = color(0, 255, 0);
    TEXT_FAV     = color(255, 220, 0);
    TEXT_DIM     = color(150, 255, 150);
    TEXT_HINT    = color(100, 200, 100);

    activeOrder = new ArrayList<Integer>();
    favourites  = new HashSet<Integer>();

    for (int s : defaultOrder) activeOrder.add(s);
    buildNameMap();
    loadPrefs(); // override from persisted prefs if present

    // Ensure any scenes in defaultOrder that were missing from prefs (e.g. newly added) are included
    for (int s : defaultOrder) {
      if (!activeOrder.contains(s)) {
        activeOrder.add(s);
      }
    }

    sortFavouritesToTop();
  }

  // Build a simple name map by reflecting on each scene's class name,
  // stripping the trailing "Scene" suffix to make it friendlier.
  void buildNameMap() {
    for (int i = 0; i < SCENE_COUNT; i++) {
      if (scenes[i] != null) {
        String raw = scenes[i].getClass().getSimpleName();
        // Strip trailing "Scene" if present
        if (raw.endsWith("Scene")) raw = raw.substring(0, raw.length() - 5);
        // Insert spaces before capital letters for CamelCase → words
        SCENE_NAMES[i] = raw.replaceAll("([A-Z])", " $1").trim();
      } else {
        SCENE_NAMES[i] = "Scene " + i;
      }
    }
  }

  // ── Toggle ────────────────────────────────────────────────────────────────
  void toggle() {
    isOpen = !isOpen;
    if (isOpen) {
      // Snap cursor to the currently-playing scene
      for (int i = 0; i < activeOrder.size(); i++) {
        if (activeOrder.get(i) == config.STATE) { cursor = i; break; }
      }
      resetRepeat();
    }
  }

  void resetRepeat() {
    lastRepeatTime = 0;
    isRepeating = false;
    lastRepeatKey = 0;
    lastRepeatCode = 0;
  }

  // ── Runtime update (called from main draw loop) ──────────────────────────
  void update() {
    if (!isOpen) return;

    // 1. Controller handling
    if (controller.isConnected()) {
      if (controller.bJustPressed || controller.backJustPressed) { isOpen = false; return; }
      if (controller.aJustPressed) {
        switchSceneDirect(activeOrder.get(cursor));
        isOpen = false;
        return;
      }
      if (controller.xJustPressed) toggleFavourite();
      
      // Reordering with bumpers/triggers or buttons
      if (controller.lbJustPressed || controller.yJustPressed) moveSelected(-1);
      if (controller.rbJustPressed) moveSelected(1);

      // Movement with repeat
      if (controller.dpadUpHeld)    handleRepeatMove(-1);
      else if (controller.dpadDownHeld)  handleRepeatMove(1);
      else if (!keyPressed) resetRepeat(); // reset if no controller movement and no keys
    }

    // 2. Keyboard repeat handling
    if (keyPressed) {
      if (key == 'j' || keyCode == DOWN) handleRepeatMove(1);
      else if (key == 'k' || keyCode == UP) handleRepeatMove(-1);
      else resetRepeat();
    } else if (!controller.dpadUpHeld && !controller.dpadDownHeld) {
      resetRepeat();
    }
  }

  void handleRepeatMove(int dir) {
    long now = millis();
    if (lastRepeatTime == 0) {
      // First hit
      moveCursor(dir);
      lastRepeatTime = now;
      isRepeating = false;
    } else {
      long wait = isRepeating ? repeatInterval : repeatDelay;
      if (now - lastRepeatTime > wait) {
        moveCursor(dir);
        lastRepeatTime = now;
        isRepeating = true;
      }
    }
  }

  void moveCursor(int dir) {
    int n = activeOrder.size();
    cursor = (cursor + dir + n) % n;
  }

  void toggleFavourite() {
    int sceneIdx = activeOrder.get(cursor);
    if (favourites.contains(sceneIdx)) {
      favourites.remove(sceneIdx);
    } else {
      favourites.add(sceneIdx);
    }
    sortFavouritesToTop();
    // Re-snap cursor to the scene it was on
    for (int i = 0; i < activeOrder.size(); i++) {
        if (activeOrder.get(i) == sceneIdx) { cursor = i; break; }
    }
    savePrefs();
  }

  void moveSelected(int dir) {
    int n = activeOrder.size();
    if (dir == -1 && cursor > 0) {
      Integer tmp = activeOrder.get(cursor);
      activeOrder.set(cursor, activeOrder.get(cursor - 1));
      activeOrder.set(cursor - 1, tmp);
      cursor--;
      savePrefs();
    } else if (dir == 1 && cursor < n - 1) {
      Integer tmp = activeOrder.get(cursor);
      activeOrder.set(cursor, activeOrder.get(cursor + 1));
      activeOrder.set(cursor + 1, tmp);
      cursor++;
      savePrefs();
    }
  }

  // ── Key handling — returns true if the key was consumed ──────────────────
  boolean handleKey(char k, int kc) {
    if (!isOpen) {
      if (k == TAB) { toggle(); return true; }
      return false;
    }

    // Overlay is open — handle one-off keys (Tab, Esc, Enter, f, Shift-J/K)
    // Movement (j/k) is handled in update() for repeats.
    if (k == TAB || kc == ESC || k == ESC) {
      isOpen = false;
      return true;
    }

    // Switch to scene
    if ( k == '\n' || k == '\r' || k == ' ' ) {
      int sceneIdx = activeOrder.get(cursor);
      isOpen = false;
      switchSceneDirect(sceneIdx);
      return true;
    }

    // Action keys
    if ( k == 'f' || k == 'F' ) { toggleFavourite(); return true; }
    if ( k == 'K' ) { moveSelected(-1); return true; }
    if ( k == 'J' ) { moveSelected(1); return true; }

    return true; // consume all keys while open
  }

  // ── Sorted navigation helpers (used by LB/RB in main file) ───────────────
  int nextScene(int currentState) {
    int n = activeOrder.size();
    for (int i = 0; i < n; i++) {
      if (activeOrder.get(i) == currentState) return activeOrder.get((i + 1) % n);
    }
    return activeOrder.get(0);
  }

  int prevScene(int currentState) {
    int n = activeOrder.size();
    for (int i = 0; i < n; i++) {
      if (activeOrder.get(i) == currentState) return activeOrder.get((i - 1 + n) % n);
    }
    return activeOrder.get(0);
  }

  boolean isInRotation(int sceneIdx) {
    return activeOrder.contains(sceneIdx);
  }

  // ── Sort favourites to the top, stable (preserves internal orders) ────────
  void sortFavouritesToTop() {
    ArrayList<Integer> favs   = new ArrayList<Integer>();
    ArrayList<Integer> others = new ArrayList<Integer>();
    for (int s : activeOrder) {
      if (favourites.contains(s)) favs.add(s);
      else others.add(s);
    }
    activeOrder.clear();
    activeOrder.addAll(favs);
    activeOrder.addAll(others);
    // Clamp cursor
    if (cursor >= activeOrder.size()) cursor = activeOrder.size() - 1;
  }

  // ── Render overlay ────────────────────────────────────────────────────────
  void drawOverlay() {
    blendMode(BLEND);
    pushStyle();
    textFont(monoFont);

    float lineH = 19 * uiScale();
    float pad   = 14 * uiScale();
    int   visibleRows = activeOrder.size();

    // Header + footer rows + rows
    float headerLines = 2;
    float footerLines = 2;
    float boxH = pad * 2 + (visibleRows + headerLines + footerLines) * lineH;
    float boxW = 420 * uiScale();
    float boxX = 20 * uiScale();         // Shifted to the left edge
    float boxY = (height - boxH) / 2.0;  // centred vertically

    // ── Background / border ───────────────────────────────────────────────
    fill(BG_COLOR);
    stroke(BORDER_COLOR);
    strokeWeight(2);
    rect(boxX, boxY, boxW, boxH, 10);

    noStroke();
    float ty = boxY + pad;

    // ── Header ────────────────────────────────────────────────────────────
    fill(TEXT_HEADER);
    textAlign(CENTER, TOP);
    textSize(13 * uiScale());
    text("★  SCENE SWITCHER  ★", boxX + boxW / 2.0, ty);
    ty += lineH;

    fill(TEXT_HINT);
    textSize(10 * uiScale());
    text("Tab / Esc  close      f  favourite      J/K  reorder", boxX + boxW / 2.0, ty);
    ty += lineH * 1.1;

    // ── Scene rows ────────────────────────────────────────────────────────
    textAlign(LEFT, TOP);
    textSize(12 * uiScale());
    for (int i = 0; i < activeOrder.size(); i++) {
      int   sceneIdx  = activeOrder.get(i);
      boolean isLive  = (sceneIdx == config.STATE);
      boolean isCursor= (i == cursor);
      boolean isFav   = favourites.contains(sceneIdx);

      // Row background
      if (isCursor) {
        fill(ROW_CURSOR);
        noStroke();
        rect(boxX + 4, ty - 2, boxW - 8, lineH + 1, 4);
      } else if (isLive) {
        fill(ROW_LIVE);
        noStroke();
        rect(boxX + 4, ty - 2, boxW - 8, lineH + 1, 4);
      }

      // Favourite star
      fill(isFav ? TEXT_FAV : TEXT_HINT);
      text(isFav ? "\u2605 " : "  ", boxX + pad, ty);

      // Scene index
      fill(isCursor ? TEXT_HEADER : TEXT_DIM);
      text(nf(sceneIdx, 2), boxX + pad + 22 * uiScale(), ty);

      // Scene name
      String label = SCENE_NAMES[sceneIdx];
      if (isLive) label += "  \u25c4 LIVE";
      fill(isLive ? TEXT_HEADER : (isCursor ? color(200, 255, 200) : TEXT_DIM));
      text(label, boxX + pad + 60 * uiScale(), ty);

      ty += lineH;
    }

    // ── Footer hint ───────────────────────────────────────────────────────
    ty += lineH * 0.3;
    stroke(BORDER_COLOR);
    strokeWeight(1);
    line(boxX + pad, ty, boxX + boxW - pad, ty);
    ty += 4;
    noStroke();
    fill(TEXT_HINT);
    textSize(10 * uiScale());
    textAlign(CENTER, TOP);
    text("j/k \u2193\u2191 navigate    \u23ce Enter  go to scene    f  \u2605 favourite", boxX + boxW / 2.0, ty);

    popStyle();
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  void savePrefs() {
    StringBuilder sb = new StringBuilder();
    // ORDER line
    sb.append("ORDER=");
    for (int i = 0; i < activeOrder.size(); i++) {
      if (i > 0) sb.append(",");
      sb.append(activeOrder.get(i));
    }
    sb.append("\n");
    // FAVORITES line
    sb.append("FAVORITES=");
    boolean first = true;
    for (int f : favourites) {
      if (!first) sb.append(",");
      sb.append(f);
      first = false;
    }
    sb.append("\n");
    saveStrings(PREFS_FILE, new String[]{ sb.toString() });
  }

  void loadPrefs() {
    try {
      String[] lines = loadStrings(PREFS_FILE);
      if (lines == null) return;
      // Combine — saveStrings might split our newlines
      String raw = join(lines, "\n");
      for (String line : raw.split("\n")) {
        line = line.trim();
        if (line.startsWith("ORDER=")) {
          String body = line.substring(6);
          if (body.isEmpty()) continue;
          ArrayList<Integer> newOrder = new ArrayList<Integer>();
          for (String tok : body.split(",")) {
            try {
              int idx = Integer.parseInt(tok.trim());
              if (idx >= 0 && idx < SCENE_COUNT) newOrder.add(idx);
            } catch (Exception ignored) {}
          }
          if (!newOrder.isEmpty()) {
            activeOrder = newOrder;
          }
        } else if (line.startsWith("FAVORITES=")) {
          String body = line.substring(10);
          if (body.isEmpty()) continue;
          favourites.clear();
          for (String tok : body.split(",")) {
            try {
              int idx = Integer.parseInt(tok.trim());
              if (idx >= 0 && idx < SCENE_COUNT) favourites.add(idx);
            } catch (Exception ignored) {}
          }
        }
      }
    } catch (Exception e) {
      // No prefs yet — silently use defaults
    }
  }
}
