/**
 * HelpOverlay — onscreen cheat sheet of stage hotkeys.
 *
 * Shown / hidden with `?`. Designed for venue use — operator hits `?` once
 * to see what every key does, hits `?` again to dismiss. Lines are grouped
 * by subsystem so each section reads as a self-contained panel.
 */
class HelpOverlay {
  boolean visible = false;
  void toggle() { visible = !visible; }

  // Each line is "KEY...DESCRIPTION" — a tab marker `\t` separates the two.
  // Two-column layout: section title rows have empty key half.
  String[] lines = {
    "STAGE\t",
    "Ctrl+Enter\tshowtime — fullscreen + strobe safety on",
    "F11\ttoggle fullscreen on current display",
    "Ctrl+1..9\tmove window to display N",
    "Esc\temergency fade-to-black (kill switch)",
    "F12\ttoggle strobe safety cap",
    "F3\ttext overlay  (Shift+F3 cycles layout)",
    "F4\tMIDI bridge — scan + open inputs",
    "F5\tstart / stop mp4 recording",
    "F9\tauto-switcher  (Shift+F9 cycles mode)",
    "",
    "TEMPO + SETLIST\t",
    "\\\ttap tempo  (4 taps to lock)",
    "|\tclear tempo lock",
    "]\tsetlist: next entry",
    "[\tsetlist: previous entry",
    "}\tsetlist: toggle auto-advance",
    "{\tsetlist: reload setlist.txt",
    "",
    "SCENES\t",
    "1..0\tjump to SCENE_ORDER[0..9]",
    "<  >\tprev / next scene",
    "Tab\tscene switcher overlay",
    "'\taudio source switcher",
    "g  G\tcycle / clear post-FX",
    "h  H\thand-drawn renderer cycle",
    "",
    "INFO\t",
    "?\ttoggle this help",
    "i\tcontroller guide",
    "m\tmetadata HUD",
    "`\tcode overlay (when scene exposes it)",
  };

  void draw(int winW, int winH, PFont font) {
    if (!visible) return;
    pushStyle();
    if (font != null) textFont(font);

    float ts        = 13 * uiScale();
    float pad       = 14 * uiScale();
    float lineH     = ts + 4;
    float maxKeyW   = 0;
    float maxDescW  = 0;

    textSize(ts);
    for (String l : lines) {
      int tab = l.indexOf('\t');
      String k = (tab >= 0) ? l.substring(0, tab) : l;
      String d = (tab >= 0) ? l.substring(tab + 1) : "";
      maxKeyW  = max(maxKeyW,  textWidth(k));
      maxDescW = max(maxDescW, textWidth(d));
    }
    float gap = 18 * uiScale();
    float boxW = maxKeyW + gap + maxDescW + pad * 2;
    float boxH = lineH * lines.length + pad * 2;

    float boxX = (winW - boxW) / 2;
    float boxY = (winH - boxH) / 2;

    noStroke();
    fill(0, 220);
    rect(boxX, boxY, boxW, boxH, 6);

    float y = boxY + pad;
    textAlign(LEFT, TOP);
    for (String l : lines) {
      int tab = l.indexOf('\t');
      String k = (tab >= 0) ? l.substring(0, tab) : l;
      String d = (tab >= 0) ? l.substring(tab + 1) : "";
      if (k.length() > 0 && d.length() == 0) {
        // Section header
        fill(180, 240, 200);
        text(k, boxX + pad, y);
      } else {
        fill(220, 200, 120);
        text(k, boxX + pad, y);
        fill(230);
        text(d, boxX + pad + maxKeyW + gap, y);
      }
      y += lineH;
    }
    popStyle();
  }
}
