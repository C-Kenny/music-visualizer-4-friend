/**
 * LiveCodeScene — live Java playground (Janino-backed).
 *
 * Edits to `live_code.java` in the user data dir hot-reload on save. Compile
 * failures display a red banner with the error; the previous good snippet
 * keeps drawing so the screen never blacks out mid-set.
 *
 * Snippet contract:
 *   public class LiveCode {
 *     public void draw(PGraphics pg, float t, float bass, float mid, float high) { ... }
 *   }
 *
 * Controls:
 *   Y  force reload
 *   `  toggle code overlay
 */
class LiveCodeScene implements IScene {
  CodeConsole console;

  LiveCodeScene() {
    console = new CodeConsole("live_code.java", "live_code.seed.java");
    console.forceReload();
  }

  void applyController(Controller c) {
    if (c.yJustPressed) console.forceReload();
  }

  void drawScene(PGraphics pg) {
    console.reloadIfChanged();

    if (!console.hasInstance()) {
      pg.background(20, 0, 0);
      drawHud(pg, 0, 0, 0);
      drawErrorBanner(pg);
      return;
    }

    float bass = analyzer.bass, mid = analyzer.mid, high = analyzer.high;
    float t = pg.parent.millis() / 1000.0;

    boolean ok = true;
    try {
      console.invokeDraw(pg, t, bass, mid, high);
    } catch (Throwable th) {
      ok = false;
      console.markRuntimeError(th);
    }

    if (!ok) {
      pg.fill(40, 0, 0, 200);
      pg.noStroke();
      pg.rect(0, 0, pg.width, pg.height);
    }

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
    drawHud(pg, bass, mid, high);
    drawErrorBanner(pg);
  }

  void drawErrorBanner(PGraphics pg) {
    float scale = uiScale();
    long since = millis() - console.lastReloadMs;
    boolean justReloaded = console.reloadCount > 0 && since < 1500 && !console.hasError();

    pg.pushStyle();
    float ts = 14 * scale;
    pg.textSize(ts);
    String pillText = console.hasError()
        ? ("CODE ERR  #" + console.reloadCount)
        : ("CODE OK  " + console.className() + "  #" + console.reloadCount);
    float tw = pg.textWidth(pillText);
    float padX = 10 * scale, padY = 6 * scale;
    float pillW = tw + padX * 2;
    float pillH = ts + padY * 2;
    float pillX = pg.width - pillW - 12 * scale;
    float pillY = 12 * scale;

    int bg, border, fg;
    if (console.hasError()) {
      bg = color(80, 0, 0, 230); border = color(255, 80, 80); fg = color(255, 220, 220);
    } else if (justReloaded) {
      float tt = 1.0 - (since / 1500.0);
      bg = color(0, lerp(60, 200, tt), 0, 230); border = color(120, 255, 120); fg = color(255);
    } else {
      bg = color(0, 60, 0, 200); border = color(80, 200, 80, 180); fg = color(220, 255, 220);
    }
    pg.noStroke();
    pg.fill(bg);
    pg.rect(pillX, pillY, pillW, pillH, 6);
    pg.stroke(border);
    pg.strokeWeight(2);
    pg.noFill();
    pg.rect(pillX, pillY, pillW, pillH, 6);
    pg.noStroke();
    pg.fill(fg);
    pg.textAlign(LEFT, TOP);
    pg.text(pillText, pillX + padX, pillY + padY - 1);
    pg.popStyle();

    if (!console.hasError()) return;

    pg.pushStyle();
    String msg = console.errorMessage();
    String[] lines = split(msg, '\n');
    int maxLines = min(lines.length, 12);
    float ets = 13 * scale;
    float lh  = ets * 1.3;
    float h   = lh * (maxLines + 1) + 16;
    float y   = pillY + pillH + 8 * scale;
    pg.noStroke();
    pg.fill(80, 0, 0, 235);
    pg.rect(0, y, pg.width, h);
    pg.fill(255, 200, 200);
    pg.textAlign(LEFT, TOP);
    pg.textSize(ets);
    pg.text("JANINO ERROR — " + console.filePath(), 12, y + 6);
    for (int i = 0; i < maxLines; i++) {
      pg.text(lines[i], 12, y + 6 + lh * (i + 1));
    }
    pg.popStyle();
  }

  String[] getCodeLines() {
    return new String[] {
      "// LIVE CODE CONSOLE  (Janino · Java 11 syntax)",
      "// Edit: " + (console != null ? console.filePath() : "?"),
      "// Save → next frame recompiles. Fail → red banner, last-good keeps drawing.",
      "//",
      "// Required:",
      "//   public class LiveCode {",
      "//     public void draw(PGraphics pg, float t, float bass, float mid, float high) { ... }",
      "//   }",
      "//",
      "// Watchdog stalls (>2s) blacklist the scene. Y = force reload."
    };
  }

  void drawHud(PGraphics pg, float low, float mid, float high) {
    pg.pushStyle();
    float ts = 11 * uiScale();
    float lh = ts * 1.3;
    pg.fill(0, 125);
    pg.noStroke();
    pg.rectMode(CORNER);
    pg.rect(8, 8, 480 * uiScale(), 8 + lh * 6);
    pg.fill(255);
    pg.textSize(ts);
    pg.textAlign(LEFT, TOP);
    pg.text("Scene: Live Code Console (Janino)", 12, 12);
    pg.text("class: " + (console != null ? console.className() : "?")
            + "  reloads: " + (console != null ? console.reloadCount : 0), 12, 12 + lh);
    pg.text("low / mid / high: " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh * 2);
    pg.text("Y force-reload  edit .java in any editor → autoreloads", 12, 12 + lh * 3);
    pg.text("` for code overlay", 12, 12 + lh * 4);
    pg.popStyle();
  }

  void onEnter() { background(0); }
  void onExit()  { }

  void handleKey(char k) {
    if (k == 'y' || k == 'Y') console.forceReload();
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
