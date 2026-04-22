// RIP Sam Tribute — state 0
// A dedicated scene for the visualizer's "resting" state.
// This is a tribute to the creator's friend, Sam.

class RIPScene implements IScene {
  
  RIPScene() {}

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void drawScene(PGraphics pg) {
    pg.background(0);
    pg.fill(255, 100);
    pg.textAlign(CENTER, CENTER);
    pg.textSize(24 * uiScale());
    pg.text("RIP Sam", pg.width/2, pg.height/2 - 20);

    pg.textSize(14 * uiScale());
    pg.fill(255, 60);
    pg.text("Music Visualizer Tribute", pg.width/2, pg.height/2 + 20);

    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2, pg.height - 5);
  }

  void applyController(Controller c) {}

  void handleKey(char k) {}

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
