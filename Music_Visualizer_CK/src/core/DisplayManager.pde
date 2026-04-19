/**
 * DisplayManager — runtime display selection and fullscreen for live shows.
 *
 * Hotkeys (wired in main keyPressed()):
 *   F11           toggle "fill current display" mode (borderless-style fullscreen)
 *   Ctrl+1..9     move window to display N (1-indexed in UI, 0-indexed internally)
 *
 * Persists last display index + fullscreen flag in Music_Visualizer_CK/.display
 * so the window comes up on the projector automatically next launch.
 *
 * Note: P3D's true OS-fullscreen toggle requires a sketch restart (fullScreen()
 * is settings()-only). This class instead resizes the window to fill the chosen
 * display's bounds — same visual result for venue use, fully runtime-toggleable.
 */
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.Rectangle;

class DisplayManager {
  final String PREFS_FILE = ".display";

  int     lastDisplay = 0;       // 0-indexed
  boolean fullscreen  = false;

  Rectangle[] displays() {
    GraphicsDevice[] gds = GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices();
    Rectangle[] out = new Rectangle[gds.length];
    for (int i = 0; i < gds.length; i++) {
      out[i] = gds[i].getDefaultConfiguration().getBounds();
    }
    return out;
  }

  int displayCount() { return displays().length; }

  void moveTo(int idx) {
    Rectangle[] r = displays();
    if (r.length == 0) return;
    if (idx < 0) idx = 0;
    if (idx >= r.length) idx = r.length - 1;

    if (fullscreen) {
      surface.setLocation(r[idx].x, r[idx].y);
      surface.setSize(r[idx].width, r[idx].height);
      noCursor();
    } else {
      int w = (int)(r[idx].width  * 0.75);
      int h = (int)(r[idx].height * 0.75);
      surface.setLocation(r[idx].x + (r[idx].width  - w) / 2,
                          r[idx].y + (r[idx].height - h) / 2);
      surface.setSize(w, h);
      cursor();
    }

    lastDisplay = idx;
    savePref();
    println("[DISPLAY] moved to display " + (idx + 1) + "/" + r.length
            + (fullscreen ? " (fullscreen " + r[idx].width + "x" + r[idx].height + ")" : " (windowed)"));
  }

  void toggleFullscreen() {
    fullscreen = !fullscreen;
    moveTo(lastDisplay);
  }

  void initFromPrefs() {
    loadPref();
    Rectangle[] r = displays();
    if (r.length == 0) return;
    if (lastDisplay >= r.length) lastDisplay = 0;
    if (lastDisplay != 0 || fullscreen) moveTo(lastDisplay);
  }

  void savePref() {
    saveStrings(PREFS_FILE, new String[]{
      "display="    + lastDisplay,
      "fullscreen=" + (fullscreen ? "1" : "0")
    });
  }

  void loadPref() {
    try {
      String[] lines = loadStrings(PREFS_FILE);
      if (lines == null) return;
      for (String raw : lines) {
        String line = raw.trim();
        if (line.startsWith("display=")) {
          try { lastDisplay = Integer.parseInt(line.substring(8).trim()); }
          catch (Exception ignored) {}
        } else if (line.startsWith("fullscreen=")) {
          fullscreen = line.substring(11).trim().equals("1");
        }
      }
    } catch (Exception ignored) {}
  }
}
