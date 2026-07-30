/**
 * TunnelYantraScene (scene 44) - Combo layering scene
 *
 * Swappable background + swappable foreground with selectable blend mode.
 *
 * Keys:
 *   [ / ] - cycle background
 *   { / } - cycle foreground
 *   = - cycle blend mode (ADD → SCREEN → MULTIPLY → EXCLUSION)
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

  // Stepped knobs (ParamRouter spine): value rounds to a layer index, so web
  // sliders and the idle autopilot can slowly morph the bg/fg/blend combo.
  // Created in the constructor - bg count isn't known until skyboxes are found.
  SceneParam pBg, pFg, pBlend;
  SceneParam[] params;

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

    pBg    = new SceneParam("bg",    "Background", 0, backgrounds.length - 1, 0);
    pFg    = new SceneParam("fg",    "Foreground", 0, foregrounds.length - 1, 0);
    pBlend = new SceneParam("blend", "Blend Mode", 0, blendModes.length - 1,  0);
    params = new SceneParam[]{ pBg, pFg, pBlend };
  }

  // Keys/dpad step the index directly; knobs may also be dragged by web or
  // autopilot. Indexes are re-derived from the knobs each frame, so the knob
  // is the single source of truth and every input route stays in sync.
  void syncIndexesFromParams() {
    bgIndex  = constrain(round(pBg.value),    0, backgrounds.length - 1);
    fgIndex  = constrain(round(pFg.value),    0, foregrounds.length - 1);
    blendIdx = constrain(round(pBlend.value), 0, blendModes.length - 1);
  }

  void onEnter() {
    pBg.reset();
    pFg.reset();
    pBlend.reset();
    syncIndexesFromParams();
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
    if (c.dpadRightJustPressed) pBg.set((bgIndex + 1) % backgrounds.length);
    if (c.dpadLeftJustPressed)  pBg.set((bgIndex - 1 + backgrounds.length) % backgrounds.length);
    if (c.dpadDownJustPressed)  pFg.set((fgIndex + 1) % foregrounds.length);
    if (c.dpadUpJustPressed)    pFg.set((fgIndex - 1 + foregrounds.length) % foregrounds.length);

    // Delegate remaining input to active foreground
    IForeground fg = foregrounds[fgIndex];
    if (fg instanceof IScene) ((IScene)fg).applyController(c);
  }

  void handleKey(char k) {
    switch (k) {
      case '[': pBg.set((bgIndex - 1 + backgrounds.length) % backgrounds.length); break;
      case ']': pBg.set((bgIndex + 1) % backgrounds.length);                      break;
      case '{': pFg.set((fgIndex - 1 + foregrounds.length) % foregrounds.length); break;
      case '}': pFg.set((fgIndex + 1) % foregrounds.length);                      break;
      case '=': pBlend.set((blendIdx + 1) % blendModes.length);                   break;
      default:
        IForeground fg = foregrounds[fgIndex];
        if (fg instanceof IScene) ((IScene)fg).handleKey(k);
    }
  }

  SceneParam[] getParams() { return params; }

  void drawScene(PGraphics pg) {
    syncIndexesFromParams();
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
