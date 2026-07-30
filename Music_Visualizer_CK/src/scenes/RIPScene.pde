// RIP Sam Tribute — state 0
// A dedicated scene for the visualizer's "resting" state.
// This is a tribute to the creator's friend, Sam.
//
// Kept deliberately quiet: soft breathing glow behind the text and a few
// ember motes drifting upward, swaying gently with the music. The knobs
// only adjust how much warmth surrounds the words — never the words.

class RIPScene implements IScene {

  // Live knobs (ParamRouter spine — sticks, keyboard, web, idle autopilot).
  SceneParam pGlow    = new SceneParam("glow",    "Glow Warmth",   0,   2,   0.8);
  SceneParam pEmbers  = new SceneParam("embers",  "Ember Count",   0,   60,  24);
  SceneParam pBreathe = new SceneParam("breathe", "Breathe Speed", 0.2, 2,   0.7);
  SceneParam[] params = { pGlow, pEmbers, pBreathe };

  // Ember motes — small warm points born at the bottom, fading as they rise.
  int MAX_EMBERS = 60;
  float[] emberX     = new float[MAX_EMBERS];
  float[] emberY     = new float[MAX_EMBERS];
  float[] emberLife  = new float[MAX_EMBERS];  // 1 = newborn, 0 = gone
  float[] emberDrift = new float[MAX_EMBERS];  // horizontal sway seed

  float breathePhase = 0;

  RIPScene() {
    for (int i = 0; i < MAX_EMBERS; i++) respawnEmber(i, true);
  }

  void respawnEmber(int i, boolean anywhere) {
    emberX[i]     = random(0.15, 0.85);                  // fraction of width
    emberY[i]     = anywhere ? random(0.3, 1.1) : 1.05;  // fraction of height
    emberLife[i]  = random(0.4, 1);
    emberDrift[i] = random(1000);
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.background(0);

    // Soft breathing halo behind the text. Audio leans on it very lightly —
    // this scene should feel calm even on a loud track.
    breathePhase += 0.008 * pBreathe.value;
    float breathe = 0.5 + 0.5 * sin(breathePhase * TWO_PI);
    float halo = (0.25 + 0.5 * breathe + 0.25 * analyzer.bass) * pGlow.value;
    pg.noStroke();
    for (int ring = 4; ring >= 1; ring--) {
      float d = ring * 90 * uiScale() * (0.7 + 0.3 * breathe);
      pg.fill(255, 180, 110, 9 * halo);
      pg.ellipse(pg.width / 2, pg.height / 2, d, d);
    }

    // Ember motes rising past the text.
    int visible = (int) pEmbers.value;
    for (int i = 0; i < MAX_EMBERS; i++) {
      emberY[i]    -= 0.0008 + 0.0012 * analyzer.master;
      emberLife[i] -= 0.0015;
      if (emberY[i] < -0.05 || emberLife[i] <= 0) respawnEmber(i, false);
      if (i >= visible) continue;

      float sway = (noise(emberDrift[i], emberY[i] * 3) - 0.5) * 0.04;
      float x = (emberX[i] + sway) * pg.width;
      float y = emberY[i] * pg.height;
      float a = 120 * emberLife[i];
      pg.fill(255, 190, 120, a);
      pg.ellipse(x, y, 3 * uiScale(), 3 * uiScale());
    }

    pg.fill(255, 100);
    pg.textAlign(CENTER, CENTER);
    pg.textSize(24 * uiScale());
    pg.text("RIP Sam", pg.width/2, pg.height/2 - 20);

    pg.textSize(14 * uiScale());
    pg.fill(255, 60);
    pg.text("Music Visualizer Tribute", pg.width/2, pg.height/2 + 20);

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2, pg.height - 5);
  }

  void applyController(Controller c) {
    routeParamsToSticks(c, params);
  }

  void handleKey(char k) {
    handleParamKey(k);
  }

  SceneParam[] getParams() { return params; }

  String[] getCodeLines() {
    return new String[] {
      "// RIP Sam",
      "// This visualizer is a tribute to a friend.",
      "// Keeping the memory alive through code and color."
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
