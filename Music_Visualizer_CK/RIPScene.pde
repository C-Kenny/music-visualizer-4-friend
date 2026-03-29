// RIP Sam Tribute — state 0
// A dedicated scene for the visualizer's "resting" state.
// This is a tribute to the creator's friend, Sam.

class RIPScene implements IScene {
  
  RIPScene() {}

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void drawScene() {
    background(0);
    fill(255, 100);
    textAlign(CENTER, CENTER);
    textSize(24 * uiScale());
    text("RIP Sam", width/2, height/2 - 20);
    
    textSize(14 * uiScale());
    fill(255, 60);
    text("Music Visualizer Tribute", width/2, height/2 + 20);
    
    drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
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
}
