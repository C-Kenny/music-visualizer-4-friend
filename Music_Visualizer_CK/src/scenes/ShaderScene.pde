/**
 * ShaderScene — live GLSL playground.
 *
 * Edits to `live_shader.glsl` in the user data dir hot-reload on save (mtime
 * poll). Compile failures display a red banner with the GLSL error; the last
 * good shader keeps rendering so the screen never goes black mid-set.
 *
 * Seed: copied from bundled milkdrop_lesson.glsl on first run.
 *
 * Controls:
 *   Left stick  pan
 *   Right stick X  twist
 *   A  recenter
 *   Y  force reload (ignores mtime)
 */
class ShaderScene implements IScene {
  ShaderConsole console;

  float panX = 0.0, panY = 0.0, twist = 0.0;

  ShaderScene() {
    console = new ShaderConsole("live_shader.glsl", "milkdrop_lesson.glsl");
    console.forceReload();
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width,  -1, 1);
    float ly = map(c.ly, 0, height, -1, 1);
    float rx = map(c.rx, 0, width,  -1, 1);
    if (abs(lx) > 0.1) panX -= lx * 0.02;
    if (abs(ly) > 0.1) panY += ly * 0.02;
    if (abs(rx) > 0.1) twist += rx * 0.05;
    if (c.aJustPressed) { panX = 0; panY = 0; twist = 0; }
    if (c.yJustPressed) console.forceReload();
  }

  void drawScene(PGraphics pg) {
    pg.background(0);
    console.reloadIfChanged();

    PShader sh = console.activeShader();
    if (sh == null) {
      drawNoShader(pg);
      drawHud(pg, 0, 0, 0);
      return;
    }

    float bass = analyzer.bass, mid = analyzer.mid, high = analyzer.high;
    float d = displayDensity();

    boolean ok = true;
    try {
      sh.set("u_resolution", float(pg.width) * d, float(pg.height) * d);
      sh.set("u_time", pg.parent.millis() / 1000.0);
      sh.set("audio_bass", bass);
      sh.set("audio_mid",  mid);
      sh.set("audio_high", high);
      sh.set("controller_pan", panX, panY);
      sh.set("controller_twist", twist);
      pg.shader(sh);
      pg.noStroke();
      pg.fill(255);
      pg.rect(0, 0, pg.width, pg.height);
    } catch (Throwable t) {
      ok = false;
      console.markRuntimeError(t);
    } finally {
      pg.resetShader();
    }

    if (!ok) drawNoShader(pg);

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
    drawHud(pg, bass, mid, high);
    drawErrorBanner(pg);
  }

  void drawNoShader(PGraphics pg) {
    pg.fill(40, 0, 0);
    pg.noStroke();
    pg.rect(0, 0, pg.width, pg.height);
    pg.fill(255, 90, 90);
    pg.textAlign(CENTER, CENTER);
    pg.textSize(28 * uiScale());
    pg.text("shader compile failed — see banner", pg.width / 2.0, pg.height / 2.0);
  }

  void drawErrorBanner(PGraphics pg) {
    float scale = uiScale();
    long  since = millis() - console.lastReloadMs;
    boolean justReloaded = console.reloadCount > 0 && since < 1500 && !console.hasError();

    // Top-right persistent status pill — always visible, never covered by song
    // name / ticker / setlist badge at bottom edge.
    pg.pushStyle();
    float ts = 14 * scale;
    pg.textSize(ts);
    String pillText = console.hasError()
        ? ("GLSL ERR  #" + console.reloadCount)
        : ("GLSL OK  #" + console.reloadCount);
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
      float t = 1.0 - (since / 1500.0);
      bg = color(0, lerp(60, 200, t), 0, 230); border = color(120, 255, 120); fg = color(255);
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

    // Full error banner across the TOP — top edge is mostly clear (only scene
    // HUD top-left, which we offset around).
    if (!console.hasError()) return;

    pg.pushStyle();
    String msg = console.errorMessage();
    String[] lines = split(msg, '\n');
    float ets = 13 * scale;
    float lh  = ets * 1.3;
    float h   = lh * (lines.length + 1) + 16;
    float y   = pillY + pillH + 8 * scale;
    pg.noStroke();
    pg.fill(80, 0, 0, 235);
    pg.rect(0, y, pg.width, h);
    pg.fill(255, 200, 200);
    pg.textAlign(LEFT, TOP);
    pg.textSize(ets);
    pg.text("GLSL ERROR — " + console.filePath(), 12, y + 6);
    for (int i = 0; i < lines.length; i++) {
      pg.text(lines[i], 12, y + 6 + lh * (i + 1));
    }
    pg.popStyle();
  }

  String[] getCodeLines() {
    return new String[] {
      "// LIVE SHADER CONSOLE",
      "// Edit: " + (console != null ? console.filePath() : "(not initialized)"),
      "// Save → next frame recompiles. Fail → red banner, last-good keeps drawing.",
      "//",
      "// Uniforms available:",
      "//   uniform vec2  u_resolution;",
      "//   uniform float u_time;",
      "//   uniform float audio_bass, audio_mid, audio_high;",
      "//   uniform vec2  controller_pan;",
      "//   uniform float controller_twist;",
      "//",
      "// Y = force reload   A = recenter pan/twist"
    };
  }

  void drawHud(PGraphics pg, float low, float mid, float high) {
    pg.pushStyle();
    float ts = 11 * uiScale();
    float lh = ts * 1.3;
    pg.fill(0, 125);
    pg.noStroke();
    pg.rectMode(CORNER);
    pg.rect(8, 8, 420 * uiScale(), 8 + lh * 6);
    pg.fill(255);
    pg.textSize(ts);
    pg.textAlign(LEFT, TOP);
    pg.text("Scene: Live Shader Console", 12, 12);
    pg.text("file: " + (console != null ? console.userFileName : "?") +
            "  reloads: " + (console != null ? console.reloadCount : 0), 12, 12 + lh);
    pg.text("low / mid / high: " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh * 2);
    pg.text("twist: " + nf(twist, 1, 2) + "  pan: " + nf(panX, 1, 2) + " / " + nf(panY, 1, 2), 12, 12 + lh * 3);
    pg.text("A center  Y force-reload  edit .glsl in any editor → autoreloads", 12, 12 + lh * 4);
    pg.text("` for code overlay", 12, 12 + lh * 5);
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
