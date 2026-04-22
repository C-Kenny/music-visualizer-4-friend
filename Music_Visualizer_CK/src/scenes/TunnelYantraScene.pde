/**
 * TunnelYantraScene (scene 44) — Combo layering scene
 *
 * Swappable background + swappable foreground with selectable blend mode.
 *
 * Keys:
 *   [ / ]   — cycle background
 *   { / }   — cycle foreground
 *   =       — cycle blend mode (ADD → SCREEN → MULTIPLY → EXCLUSION)
 *
 * Controller delegated to active foreground scene (if it's SriYantraScene).
 */
class TunnelYantraScene implements IScene {

  IBackground[] backgrounds;
  IForeground[] foregrounds;
  int bgIndex  = 0;
  int fgIndex  = 0;

  // Blend modes for fg-on-bg compositing
  int[]    blendModes     = {ADD, SCREEN, MULTIPLY, EXCLUSION};
  String[] blendModeNames = {"ADD", "SCREEN", "MULTIPLY", "EXCLUSION"};
  int      blendIdx       = 0;

  TunnelYantraScene() {
    String[] skyboxDirs = discoverSkyboxNames();
    backgrounds = new IBackground[2 + skyboxDirs.length];
    backgrounds[0] = new TunnelBackground();
    backgrounds[1] = new StarfieldBackground();
    for (int i = 0; i < skyboxDirs.length; i++) {
      backgrounds[2 + i] = new SkyboxBackground(skyboxDirs[i]);
    }

    foregrounds = new IForeground[]{
      new SriYantraScene(),
      new DotMandalaScene(),
      new NetOfBeingScene(),
    };
  }

  void onEnter() {
    bgIndex  = 0;
    fgIndex  = 0;
    blendIdx = 0;
    for (IForeground fg : foregrounds) {
      if (fg instanceof IScene) ((IScene)fg).onEnter();
    }
  }

  void onExit() {
    for (IForeground fg : foregrounds) {
      if (fg instanceof IScene) ((IScene)fg).onExit();
    }
  }

  void applyController(Controller c) {
    // D-pad: left/right = cycle background, up/down = cycle foreground
    if (c.dpadRightJustPressed) bgIndex = (bgIndex + 1) % backgrounds.length;
    if (c.dpadLeftJustPressed)  bgIndex = (bgIndex - 1 + backgrounds.length) % backgrounds.length;
    if (c.dpadDownJustPressed)  fgIndex = (fgIndex + 1) % foregrounds.length;
    if (c.dpadUpJustPressed)    fgIndex = (fgIndex - 1 + foregrounds.length) % foregrounds.length;

    // Delegate remaining input to active foreground
    IForeground fg = foregrounds[fgIndex];
    if (fg instanceof IScene) ((IScene)fg).applyController(c);
  }

  void handleKey(char k) {
    switch (k) {
      case '[': bgIndex = (bgIndex - 1 + backgrounds.length) % backgrounds.length; break;
      case ']': bgIndex = (bgIndex + 1) % backgrounds.length;                      break;
      case '{': fgIndex = (fgIndex - 1 + foregrounds.length) % foregrounds.length; break;
      case '}': fgIndex = (fgIndex + 1) % foregrounds.length;                      break;
      case '=': blendIdx = (blendIdx + 1) % blendModes.length;                     break;
      default:
        IForeground fg = foregrounds[fgIndex];
        if (fg instanceof IScene) ((IScene)fg).handleKey(k);
    }
  }

  void drawScene(PGraphics pg) {
    pg.background(0);

    // Layer 1: background
    backgrounds[bgIndex].drawBackground(pg);

    // Layer 2: foreground composited with selected blend mode
    pg.blendMode(blendModes[blendIdx]);
    foregrounds[fgIndex].drawForeground(pg);
    pg.blendMode(BLEND);

    // Status label (bottom-left)
    float ts = uiScale();
    pg.textFont(monoFont);
    pg.fill(255, 255, 255, 80);
    pg.textSize(10 * ts);
    pg.textAlign(LEFT, BOTTOM);
    pg.text(
      "BG: " + backgrounds[bgIndex].label() +
      "  FG: " + foregrounds[fgIndex].fgLabel() +
      "  blend: " + blendModeNames[blendIdx] +
      "   [ ]bg  { }fg  =blend",
      12 * ts, pg.height - 12 * ts
    );
  }

  String[] getCodeLines() {
    return new String[]{
      "=== Combo Layer Scene ===",
      "",
      "[ / ]   cycle background (" + backgrounds.length + " total)",
      "{ / }   cycle foreground (" + foregrounds.length + " total)",
      "=       cycle blend mode",
      "",
      "BG: " + backgrounds[bgIndex].label(),
      "FG: " + foregrounds[fgIndex].fgLabel(),
      "Blend: " + blendModeNames[blendIdx],
    };
  }

  ControllerLayout[] getControllerLayout() {
    IForeground fg = foregrounds[fgIndex];
    if (fg instanceof IScene) return ((IScene)fg).getControllerLayout();
    return new ControllerLayout[]{};
  }
}
