/*
Music Visualizer ♫ ♪♪
*/
import org.gicentre.handy.*;
import java.util.Map;
import garciadelcastillo.dashedlines.*;
import peasy.*;

Config config;
Audio audio;
Controller controller;
IScene[] scenes;
final int SCENE_COUNT = 19;
int previousState = -1;

AudioAnalyser analyzer;
PFont monoFont;


// UI scale: 1.0 at 1080p, grows proportionally for higher resolutions.
// Use uiScale() for textSize, strokeWeight, and HUD rect sizes.
float uiScale() { return max(1.0, min(width, height) / 1080.0); }

PImage h3_emblem;
PImage new_h3_emblem;

HandyRenderer h, h1, h2;
HandyRenderer[] HANDY_RENDERERS;
HandyRenderer CURRENT_HANDY_RENDERER;

int[] modes;
String[]modeNames;

PeasyCam cam;

void loadSongToVisualize() {
  log_to_stdo("Loading song to visualize");
  audio = new Audio(this, config.SONG_TO_VISUALIZE, config.bandsPerOctave);
  config.SONG_PLAYING = true;
}

void setupController() {
  controller = new Controller(this);
  if (controller.isConnected()) {
    config.USING_CONTROLLER = true;
    config.TITLE_BAR = "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (h)and-drawn, (p)lasma, (s)top, (w)ave, (>)toggle diamonds, (/)toggle fins";
    controller.debugPrintControls();
  }
  log_to_stdo("USING CONTROLLER? " + config.USING_CONTROLLER);
}

void initializeGlobals() {
  log_to_stdo("initializeGlobals");

  config = new Config();

  ellipseMode(CENTER);
  blendMode(BLEND);


  HANDY_RENDERERS = new HandyRenderer[3];
  config.HANDY_RENDERERS_COUNT = HANDY_RENDERERS.length;
  config.MAX_HANDY_RENDERER_POSITION = config.HANDY_RENDERERS_COUNT -1;

  h = HandyPresets.createWaterAndInk(this);
  h1 = HandyPresets.createMarker(this);
  h2 = new HandyRenderer(this);

  HANDY_RENDERERS[0] = h;
  HANDY_RENDERERS[1] = h1;
  HANDY_RENDERERS[2] = h2;

  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];

  modes = new int[]{
    BLEND, ADD, SUBTRACT, EXCLUSION,
    DIFFERENCE, MULTIPLY, SCREEN,
    REPLACE
  };
  
  modeNames = new String[]{
    "BLEND", "ADD", "SUBTRACT", "EXCLUSION",
    "DIFFERENCE", "MULTIPLY", "SCREEN",
    "REPLACE"
  };
}

boolean isDevMode() {
  // Check several locations — sketchPath() can vary depending on how Processing CLI is invoked
  String[] candidates = {
    sketchPath() + "/.devmode",
    sketchPath() + "/../.devmode",
    System.getProperty("user.dir") + "/.devmode",
    System.getProperty("user.home") + "/.devmode"
  };
  for (String path : candidates) {
    java.io.File f = new java.io.File(path);
    log_to_stdo("devmode check: " + f.getAbsolutePath() + " → " + f.exists());
    if (f.exists()) return true;
  }
  return false;
}

void setSongToVisualize() {
  log_to_stdo("Current song: " + config.SONG_TO_VISUALIZE);
  log_to_stdo("sketchPath() = " + sketchPath());
  log_to_stdo("user.dir     = " + System.getProperty("user.dir"));
  boolean useRandomSong = isDevMode();
  if (useRandomSong) {
    // Dev shortcut: if .devsong exists, always use that song while developing.
    // e.g.  echo "/home/user/Music/song.mp3" > Music_Visualizer_CK/.devsong
    try {
      java.io.File devSongFile = new java.io.File(sketchPath(".devsong"));
      if (devSongFile.exists()) {
        String devSongPath = join(loadStrings(devSongFile.getAbsolutePath()), "").trim();
        if (new java.io.File(devSongPath).exists()) {
          config.SONG_TO_VISUALIZE = devSongPath;
          config.SONG_NAME = getSongNameFromFilePath(devSongPath, config.OS_TYPE);
          config.STATE = 1;
          log_to_stdo("Dev song: " + config.SONG_TO_VISUALIZE);
          return;
        }
      }
    } catch (Exception e) { /* ignore */ }

    java.io.File musicDir = new java.io.File(System.getProperty("user.home"), "Music");
    if (config.songList.size() == 0) {
      collectSongs(musicDir, config.songList);
    }
    if (config.songList.size() > 0) {
      config.currentSongIndex = (int) random(config.songList.size());
      config.SONG_TO_VISUALIZE = config.songList.get(config.currentSongIndex);
      log_to_stdo("Random song selected: " + config.SONG_TO_VISUALIZE);
      config.STATE = 1;
      config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      return;
    }
    log_to_stdo("No songs found in " + musicDir.getAbsolutePath() + ", falling back to file picker");
  }
  selectInput("Select song to visualize", "fileSelected");
  while (config.SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  config.STATE = 1;
  log_to_stdo("SONG TO VISUALIZE: " + config.SONG_TO_VISUALIZE);
  config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
}

void loadSongByPath(String path) {
  audio.stop();
  config.SONG_TO_VISUALIZE = path;
  config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
  loadSongToVisualize();
  log_to_stdo("Now playing: " + config.SONG_NAME);
}

void nextSong() {
  if (config.songList.size() == 0) return;
  config.currentSongIndex = (config.currentSongIndex + 1) % config.songList.size();
  loadSongByPath(config.songList.get(config.currentSongIndex));
}

void shuffleSong() {
  if (config.songList.size() == 0) return;
  int newIndex;
  do {
    newIndex = (int) random(config.songList.size());
  } while (config.songList.size() > 1 && newIndex == config.currentSongIndex);
  config.currentSongIndex = newIndex;
  loadSongByPath(config.songList.get(config.currentSongIndex));
}

void collectSongs(java.io.File dir, ArrayList<String> songs) {
  if (dir == null || !dir.exists()) return;
  java.io.File[] files = dir.listFiles();
  if (files == null) return;
  for (java.io.File f : files) {
    if (f.isDirectory()) {
      collectSongs(f, songs);
    } else {
      String name = f.getName().toLowerCase();
      if (name.endsWith(".mp3") || name.endsWith(".wav") || name.endsWith(".flac") || name.endsWith(".aiff")) {
        songs.add(f.getAbsolutePath());
      }
    }
  }
}

String fileSelected(File selection) {
  if (selection == null) {
    log_to_stdo("No file selected. Window might have been closed/cancelled");
    return "";
  } else {
    log_to_stdo("File selected: " + selection.getAbsolutePath());
    config.SONG_TO_VISUALIZE = selection.getAbsolutePath();
    // Scan the parent directory so n/N can navigate nearby songs
    if (config.songList.size() == 0) {
      collectSongs(selection.getParentFile(), config.songList);
    }
    config.currentSongIndex = config.songList.indexOf(selection.getAbsolutePath());
    if (config.currentSongIndex < 0) config.currentSongIndex = 0;
  }
  return selection.getAbsolutePath();
}

String discoverOperatingSystem() {
  String os = System.getProperty("os.name");
  if (os.contains("Windows")) {
    return "win";
  } else if (os.contains("Mac")) {
    return "mac";
  } else if (os.contains("Linux")) {
    return "linux";
  } else {
    return "other";
  }
}

String getSongNameFromFilePath(String song_path, String os_type) {
  log_to_stdo("Getting song name from file path, where os_type is: " + os_type);
  String[] file_name_parts;
  if (os_type == "linux") {
    file_name_parts = split(song_path, "/");
  } else if (os_type == "win") {
    file_name_parts = split(song_path, "\\");
  } else {
    file_name_parts = split(song_path, "\\");
  }
  config.SONG_NAME = file_name_parts[file_name_parts.length-1];
  log_to_stdo("SONG_NAME: " + config.SONG_NAME);
  return config.SONG_NAME;
}

void settings() {
  size(displayWidth, displayHeight - 80, P3D);
  smooth(2);
}

void setup() {
  background(200);
  config = new Config();
  analyzer = new AudioAnalyser();
  log_to_stdo("canvas spawned");
  initializeGlobals();
  setSongToVisualize();
  surface.setResizable(true);
  frameRate(160);
  surface.setTitle(config.TITLE_BAR);
  setupController();
  loadSongToVisualize();

  // Initialize scene registry (0-18)
  scenes = new IScene[SCENE_COUNT];
  scenes[0]  = new RIPScene();
  scenes[1]  = new OriginalScene(this);
  scenes[2]  = new HeartGridScene();
  scenes[3]  = new Shapes3DScene();
  scenes[4]  = new CatsCradleScene();
  scenes[5]  = new OscilloscopeScene();
  scenes[6]  = new TableTennisScene();
  scenes[7]  = new PrismCodexScene();
  scenes[8]  = new ParticleFountainScene();
  scenes[9]  = new Halo2LogoScene();
  scenes[10] = new AuroraRibbonsScene();
  scenes[11] = new RadialFFTScene();
  scenes[12] = new SpirographScene();
  scenes[13] = new GravityStringsScene();
  scenes[14] = new NeuralWeaveScene();
  scenes[15] = new ShoalLuminaScene();
  scenes[16] = new AntigravityScene();
  scenes[17] = new FractalScene();
  scenes[18] = new ShaderScene();

  // Initial lifecycle trigger
  previousState = config.STATE;
  scenes[config.STATE].onEnter();
  monoFont = createFont("Monospaced", 15, true);
  // Dev shortcut: if .devscene exists in the sketch dir, start on that scene.
  // e.g.  echo 6 > Music_Visualizer_CK/.devscene
  try {
    java.io.File devScene = new java.io.File(sketchPath(".devscene"));
    if (devScene.exists()) {
      String raw = join(loadStrings(devScene.getAbsolutePath()), "").trim();
      config.STATE = Integer.parseInt(raw);
    }
  } catch (Exception e) { /* ignore — missing or malformed file */ }
  // load Halo 3 emblem used as reference for colors and texture
  h3_emblem = loadImage("../media/h3_emblem.jpg");
}

void stop() {
  audio.stop();
  super.stop();
}

void toggleHandDrawn(){
  config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
  h.setIsHandy(config.APPEAR_HAND_DRAWN);
}

void toggleHandDrawn3(){
  config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
  h.setIsHandy(config.APPEAR_HAND_DRAWN);
}

void toggleSongPlaying(){
   if (config.SONG_PLAYING) {
    stopSong();
  } else {
    startSong();
  }
}

void stopSong(){
  audio.pause();
  config.SONG_PLAYING = false;
}

void startSong(){
  audio.play();
  config.SONG_PLAYING = true;
}

void mousePressed() {
  scenes[config.STATE].handleKey(' '); // reuse handleKey for simple click-bursts if scene desires
}

void keyPressed() {
  // 1. Delegate to current scene first
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].handleKey(key);
  }

  // 2. Global Shortcuts
  if (key == 'h') cycleHandDrawn();
  if (key == 'H') {
    config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
    CURRENT_HANDY_RENDERER.setIsHandy(config.APPEAR_HAND_DRAWN);
  }
  if (key == 's' || key == 'S') toggleSongPlaying();
  if (key == 'n') nextSong();
  if (key == 'N') shuffleSong();
  if (key == 'l' || key == 'L') config.LOGGING_ENABLED = !config.LOGGING_ENABLED;
  if (key == '`') config.SHOW_CODE = !config.SHOW_CODE;
  if (key == 'q' || key == 'Q' || key == 'x' || key == 'X') {
    audio.stop();
    exit();
  }

  // Scene Switching (0-9)
  if ((key >= '1' && key <= '9') || key == '0') {
    int newState = (key == '0') ? 10 : ((int) key - 48);
    if (newState >= 0 && newState < SCENE_COUNT) {
      switchScene(newState);
    }
  }

  // Global background toggles
  if (key == 't' || key == 'T') {
    config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
    if (config.DRAW_TUNNEL) enableOneBackgroundAndDisableOthers("tunnel");
  }
  if (key == 'p') {
    config.DRAW_PLASMA = !config.DRAW_PLASMA;
    if (config.DRAW_PLASMA) enableOneBackgroundAndDisableOthers("plasma");
  }
  if (key == 'P') {
    config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
    if (config.DRAW_POLAR_PLASMA) enableOneBackgroundAndDisableOthers("polar_plasma");
  }

  if (key == CODED) {
    if (keyCode == LEFT)  audio.skip(-10000);
    if (keyCode == RIGHT) audio.skip(10000);
    if (keyCode == UP) {
      float current_gain = audio.getGain();
      audio.setGain(current_gain + 5);
    }
    if (keyCode == DOWN) {
      float current_gain = audio.getGain();
      audio.setGain(current_gain - 5);
    }
  }
}

void enableOneBackgroundAndDisableOthers(String backgroundToEnable) {
  config.DRAW_TUNNEL = false;
  config.DRAW_PLASMA = false;
  config.DRAW_POLAR_PLASMA = false;
  
  switch(backgroundToEnable) {
    case "tunnel":
      config.DRAW_TUNNEL = true;
      break;
    case "plasma":
      config.DRAW_PLASMA = true;
      break;
    case "polar_plasma":
      config.DRAW_POLAR_PLASMA = true;
      break;
  }
}

void cycleHandDrawn() {
  config.CURRENT_HANDY_RENDERER_POSITION += 1;
  config.CURRENT_HANDY_RENDERER_POSITION = config.CURRENT_HANDY_RENDERER_POSITION % config.HANDY_RENDERERS_COUNT;
}

void reset(){
  log_to_stdo("reset");
  audio.stop();
  config.SONG_TO_VISUALIZE = "";
  setSongToVisualize();
  loadSongToVisualize();
}

void log_to_stdo(String message_to_log) {
  if (config.LOGGING_ENABLED) {
    println(message_to_log);
  }
}



public void getUserInput(boolean usingController) {
  if (!usingController) return;
  controller.read();

  // 1. Delegate to active scene
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].applyController(controller);
  }

  // 2. Global Controller Shortcuts
  if (controller.dpad_hat_switch_up) {
    config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
    if (config.DRAW_TUNNEL) enableOneBackgroundAndDisableOthers("tunnel");
  }
  if (controller.dpad_hat_switch_left) {
    config.DRAW_PLASMA = !config.DRAW_PLASMA;
    if (config.DRAW_PLASMA) enableOneBackgroundAndDisableOthers("plasma");
  }
  if (controller.dpad_hat_switch_right) {
    config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
    if (config.DRAW_POLAR_PLASMA) enableOneBackgroundAndDisableOthers("polar_plasma");
  }
  if (controller.dpad_hat_switch_down) {
    config.DRAW_TUNNEL = false;
    config.DRAW_POLAR_PLASMA = false;
    config.DRAW_PLASMA = false;
  }

  if (controller.lb_just_pressed) switchScene(prevActiveScene());
  if (controller.rb_just_pressed) switchScene(nextActiveScene());
  
  if (controller.back_just_pressed) stopSong();
  if (controller.start_just_pressed) startSong();
}
void setBackGroundFillMode(){
    fill(#fbfafa); 
}

int previous_state = -1;

// ── Active scene list ─────────────────────────────────────────────────────────
// Only these scenes are reachable via LB/RB cycling. Scenes 3 and 9 are kept
// in the codebase but excluded from rotation for now.
final int[] SCENE_ORDER = {1, 3, 2, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18};

int _sceneOrderIndex(int state) {
  for (int i = 0; i < SCENE_ORDER.length; i++) {
    if (SCENE_ORDER[i] == state) return i;
  }
  return 0; // default to first if current scene not in list
}

int nextActiveScene() {
  int idx = (_sceneOrderIndex(config.STATE) + 1) % SCENE_ORDER.length;
  return SCENE_ORDER[idx];
}

int prevActiveScene() {
  int idx = (_sceneOrderIndex(config.STATE) - 1 + SCENE_ORDER.length) % SCENE_ORDER.length;
  return SCENE_ORDER[idx];
}

// ── Scene crossfade ───────────────────────────────────────────────────────────
// When switchScene() is called, we capture the current frame as a frozen
// snapshot and draw it on top of the incoming scene with decreasing alpha.
// This gives a smooth dissolve without needing two live render buffers.

PImage crossfadeSnapshot  = null;
int    crossfadeFrame     = 0;
final int CROSSFADE_DURATION = 45; // frames  (~0.75 s at 60 fps)

void switchScene(int newState) {
  if (config.STATE == newState) return;
  crossfadeSnapshot = get();        // freeze the last frame of the current scene
  crossfadeFrame    = 0;
  config.STATE      = newState;
  previous_state    = newState;     // suppress the background(0) clear so no black flash
}

void draw() {
  // 1. Scene Lifecycle Management
  if (config.STATE != previousState) {
    if (previousState >= 0 && previousState < SCENE_COUNT) {
      scenes[previousState].onExit();
    }
    previousState = config.STATE;
    if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
      scenes[config.STATE].onEnter();
    }
  }

  // 2. Continuous Logic Updates
  if (frameCount % 480 == 0) log_to_stdo("Draw state=" + config.STATE);

  // Audio update
  audio.forward();
  audio.beat.detect(audio.player.mix);
  analyzer.update(audio);

  // Input update
  getUserInput(config.USING_CONTROLLER);

  // 3. Render Active Scene
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    pushMatrix();
    scenes[config.STATE].drawScene();
    popMatrix();
    
    // Global overlays
    if (config.SHOW_CODE) {
      drawCodeOverlay(scenes[config.STATE].getCodeLines());
    }
  }

  addFPSToTitleBar();

  // ── Crossfade overlay ───────────────────────────────────────────────────────
  if (crossfadeSnapshot != null) {
    crossfadeFrame++;
    // Beat-snap: if a beat lands when we're past the halfway point, finish early
    if (audio.beat.isOnset() && crossfadeFrame > CROSSFADE_DURATION / 2) {
      crossfadeFrame = CROSSFADE_DURATION;
    }

    if (crossfadeFrame >= CROSSFADE_DURATION) {
      crossfadeSnapshot = null;
    } else {
      float alpha = map(crossfadeFrame, 0, CROSSFADE_DURATION, 255, 0);
      blendMode(BLEND); 
      tint(255, alpha);
      image(crossfadeSnapshot, 0, 0);
      noTint();
    }
  }
}

// Generic right-side terminal HUD — used by worm scenes (and any future scene).
void drawSceneControlsHUD(String[] lines) {
  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float boxW  = 360 * uiScale();
  float boxH  = pad * 2 + lines.length * lineH;
  float boxX  = width - boxW - 12 * uiScale();
  float boxY  = (height - boxH) / 2.0;

  fill(0, 0, 0, 210); noStroke(); rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 6);
  stroke(0, 220, 80, 180); strokeWeight(1.5); noFill();
  rect(boxX, boxY, boxW, boxH, 6);

  textAlign(LEFT, TOP); textSize(13 * uiScale());
  float tx = boxX + pad, ty = boxY + pad;
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if      (line.startsWith("===")) fill(0, 255, 120);
    else if (line.equals(""))        fill(0, 0, 0, 0); // invisible spacer
    else                             fill(180, 255, 180);
    text(line, tx, ty + i * lineH);
  }
  popStyle();
}

// Draws a terminal-style code overlay showing the formulas a scene uses.
// Each scene passes in plain-English lines explaining its maths.
// Controls HUD for scene 1 — shown on the right side when ` is pressed.
void drawControlsHUD() {
  // pushStyle() does not save blend mode — reset explicitly so scene's active
  // blend mode (EXCLUSION, ADD, etc.) doesn't invert/corrupt the HUD colours.
  blendMode(BLEND);
  String[] sections = {
    "=== CONTROLLER (scene 1) ===",
    "LB / RB          prev / next scene",
    "L Stick ↕        fin Y offset",
    "R Stick ↕        wave amplitude",
    "R Stick ↔        diamond width",
    "L Trigger        tunnel zoom",
    "A                rainbow fins",
    "B                cycle blend mode",
    "X / L-Click      stacking / trails mode",
    "Y                flip fin direction",
    "R-Click          inner diamonds",
    "D-pad ↑          toggle tunnel",
    "D-pad ←          toggle plasma",
    "D-pad →          toggle polar plasma",
    "D-pad ↓          clear backgrounds",
    "Start / Back     play / stop song",
    "",
    "=== CONTROLLER (other scenes) ===",
    "2: R ↔           heart grid columns",
    "4: L ↕           rotation speed",
    "4: R ↔           anchor count",
    "4: A             beat pulse",
    "6: R ↕           gravity",
    "6: L ↕           magnus spin",
    "6: A             randomise spin",
    "7: L ↕           spin speed",
    "7: R ↕           lattice drift",
    "7: A             glow flash",
    "9: L ↕           pulse sensitivity",
    "9: Y             cycle bg mode",
    "9: A             manual pulse",
    "10: L ↔          wind drift",
    "10: R ↕          ribbon length",
    "10: R ↔          turbulence",
    "10: A / Y        flash / hue shift",
    "10: K / Space    palette / flash",
    "14: L pan  R zoom/spin  LT/RT bio/tech  A ripple  B growth  X lab",
    "",
    "=== KEYBOARD ===",
    "0–9              switch scene",
    "`                toggle this HUD",
    "t                tunnel",
    "b                blend mode",
    "d / >            diamonds",
    "/                fins",
    "w                waveform",
    "n / N            next / shuffle song",
  };

  pushStyle();
  textFont(monoFont);
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float boxW  = 380 * uiScale();
  float boxH  = pad * 2 + sections.length * lineH;
  float boxX  = width - boxW - 12 * uiScale();
  float boxY  = (height - boxH) / 2.0;

  fill(0, 0, 0, 210);
  noStroke();
  rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 6);

  stroke(0, 220, 80, 180);
  strokeWeight(1.5);
  noFill();
  rect(boxX, boxY, boxW, boxH, 6);

  textAlign(LEFT, TOP);
  textSize(13 * uiScale());
  float tx = boxX + pad;
  float ty = boxY + pad;
  for (int i = 0; i < sections.length; i++) {
    String line = sections[i];
    if (line.startsWith("===")) {
      fill(0, 255, 120);
    } else if (line.equals("")) {
      // blank spacer — skip
    } else {
      fill(180, 255, 180);
    }
    text(line, tx, ty + i * lineH);
  }
  popStyle();
  blendMode(config.CURRENT_BLEND_MODE_INDEX);  // restore scene blend mode
}

// Toggle with the backtick key (`).
void drawCodeOverlay(String[] lines) {
  // Same style as drawSceneControlsHUD but anchored to the left edge.
  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  textSize(13 * uiScale());
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float maxLineW = 0;
  for (String l : lines) maxLineW = max(maxLineW, textWidth(l));
  float boxW  = maxLineW + pad * 2;
  float boxH  = pad * 2 + lines.length * lineH;
  float boxX  = 12 * uiScale();
  float boxY  = (height - boxH) / 2.0;

  fill(0, 0, 0, 210); noStroke(); rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 6);
  stroke(0, 220, 80, 180); strokeWeight(1.5); noFill();
  rect(boxX, boxY, boxW, boxH, 6);

  textAlign(LEFT, TOP);
  float tx = boxX + pad, ty = boxY + pad;
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if      (line.startsWith("//"))  fill(120, 200, 120);  // comments → dim green
    else if (line.startsWith("===")) fill(0, 255, 120);    // title → bright green
    else if (line.equals(""))        fill(0, 0, 0, 0);     // invisible spacer
    else                             fill(180, 255, 180);   // body → light green
    text(line, tx, ty + i * lineH);
  }
  popStyle();
}

void addFPSToTitleBar() {
  if (frameCount % 100 == 0) {
    surface.setTitle("fps: " + int(frameRate) + " | " + config.TITLE_BAR);
  }
}

float pulseValBetweenRange(float currentVal, float minVal, float maxVal) {
  currentVal += config.PULSE_VALUE;
  if (currentVal > maxVal) {
    config.PULSE_VALUE = -40;
  } else if (currentVal <= minVal) {
    config.PULSE_VALUE = 40;
  }
  return currentVal;
}

void drawSongNameOnScreen(String song_name, float nameLocationX, float nameLocationY) {
  textSize(24 * uiScale());
  textAlign(CENTER);
  fill(0);
  
  text(song_name, nameLocationX + 2, nameLocationY + 2);
  
  fill(255);
  text(song_name, nameLocationX, nameLocationY);
}

void mouseClicked() {
  config.ANIMATED = !config.ANIMATED;
}

void changeBlendMode() {
  if (config.CURRENT_BLEND_MODE_INDEX == modes.length - 1) {
    config.CURRENT_BLEND_MODE_INDEX = 0;
  } else {
    config.CURRENT_BLEND_MODE_INDEX += 1;
  }
  blendMode(config.CURRENT_BLEND_MODE_INDEX);
}

void changeFinRotation() {
  config.finRotationClockWise = !config.finRotationClockWise;
  config.canChangeFinDirection = false;
}


