/**
 * TextOverlay — DJ name / track title overlay for live shows.
 *
 * Reads `text_overlay.txt` from the user data directory. Format: up to two
 * lines — first is the title, second is the subtitle. Blank lines and lines
 * starting with `#` are ignored.
 *
 *   # DJ name on top, track on bottom
 *   ARTIST GOES HERE
 *   "Track Title"
 *
 * The file's mtime is polled each frame; edits during a set take effect on
 * the next frame without a restart.
 *
 * Hotkeys (wired in main keyPressed):
 *   F3        toggle visibility
 *   Shift+F3  cycle layout (BOTTOM_CENTER, TOP_LEFT)
 */
class TextOverlay {
  static final String FILE_NAME = "text_overlay.txt";
  static final int LAYOUT_BOTTOM_CENTER = 0;
  static final int LAYOUT_TOP_LEFT      = 1;
  static final int LAYOUT_TICKER        = 2;
  static final int LAYOUT_COUNT         = 3;
  static final float TICKER_PX_PER_SEC  = 90;

  boolean visible      = false;
  int     layout       = LAYOUT_BOTTOM_CENTER;
  String  title        = "";
  String  subtitle     = "";
  long    lastMtimeMs  = -1;

  void toggle()       { visible = !visible; if (visible) reloadIfChanged(); }
  void cycleLayout()  { layout  = (layout + 1) % LAYOUT_COUNT; }

  void reloadIfChanged() {
    String path = userDataPath(FILE_NAME);
    java.io.File f = new java.io.File(path);
    if (!f.exists()) {
      title = "(no " + FILE_NAME + ")";
      subtitle = "";
      lastMtimeMs = -1;
      return;
    }
    long mtime = f.lastModified();
    if (mtime == lastMtimeMs) return;
    lastMtimeMs = mtime;

    title = "";
    subtitle = "";
    try {
      String[] lines = loadStrings(path);
      if (lines == null) return;
      int slot = 0;
      for (String raw : lines) {
        String line = raw.trim();
        if (line.length() == 0 || line.startsWith("#")) continue;
        if (slot == 0) title = line;
        else if (slot == 1) subtitle = line;
        else break;
        slot++;
      }
    } catch (Exception ignored) {}
  }

  void draw(int winW, int winH, PFont font) {
    if (!visible) return;
    reloadIfChanged();
    if (title.length() == 0 && subtitle.length() == 0) return;

    pushStyle();
    if (font != null) textFont(font);

    float scale  = uiScale();
    float titleSize = 42 * scale;
    float subSize   = 22 * scale;
    float pad       = 20 * scale;

    if (layout == LAYOUT_BOTTOM_CENTER) {
      textAlign(CENTER, BOTTOM);
      float baseY = winH - pad * 2.5;
      // Drop shadow for legibility over busy scenes
      noStroke();
      if (title.length() > 0) {
        textSize(titleSize);
        fill(0, 200);
        text(title, winW / 2 + 2, baseY + 2);
        fill(255);
        text(title, winW / 2, baseY);
      }
      if (subtitle.length() > 0) {
        textSize(subSize);
        fill(0, 200);
        text(subtitle, winW / 2 + 2, baseY + subSize + 8 + 2);
        fill(220);
        text(subtitle, winW / 2, baseY + subSize + 8);
      }
    } else if (layout == LAYOUT_TICKER) {
      // Endless scroll: title + " — " + subtitle, repeating with a wide gap.
      String msg = title;
      if (subtitle.length() > 0) msg += "   —   " + subtitle;
      if (msg.length() == 0) { popStyle(); return; }
      String repeated = msg + "          ";
      textSize(subSize * 1.2);
      float msgW = textWidth(repeated);
      if (msgW < 1) { popStyle(); return; }

      float bandH = subSize * 1.2 + pad;
      float bandY = winH - bandH;
      noStroke();
      fill(0, 200);
      rect(0, bandY, winW, bandH);

      float offset = (millis() / 1000.0 * TICKER_PX_PER_SEC) % msgW;
      textAlign(LEFT, CENTER);
      fill(255);
      // Draw enough copies to cover the whole window width as the ticker scrolls.
      for (float x = -offset; x < winW; x += msgW) {
        text(repeated, x, bandY + bandH / 2);
      }
    } else { // TOP_LEFT
      textAlign(LEFT, TOP);
      float x = pad;
      float y = pad;
      noStroke();
      if (title.length() > 0) {
        textSize(titleSize);
        fill(0, 200);
        text(title, x + 2, y + 2);
        fill(255);
        text(title, x, y);
      }
      if (subtitle.length() > 0) {
        textSize(subSize);
        fill(0, 200);
        text(subtitle, x + 2, y + titleSize + 4 + 2);
        fill(220);
        text(subtitle, x, y + titleSize + 4);
      }
    }
    popStyle();
  }
}
