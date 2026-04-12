/*
Music Visualizer ♫ ♪♪
*/
import org.gicentre.handy.*;
import java.util.Map;
import garciadelcastillo.dashedlines.*;
import peasy.*;
import java.util.ArrayList;
import java.util.HashSet;

Config config;
Audio audio;
Controller controller;
IScene[] scenes;
SceneSwitcher sceneSwitcher;
final int SCENE_COUNT = 34;
int previousState = -1;

AudioAnalyser analyzer;
DropPredictor dropPredictor;
PFont monoFont;
PGraphics sceneBuffer;
PShader bloomShader;


// UI scale: 1.0 at 1080p, grows proportionally for higher resolutions.
// Use uiScale() for textSize, strokeWeight, and HUD rect sizes.
float uiScale() { return max(1.0, min(width, height) / 1080.0); }

PImage h3_emblem;
PImage newHaloEmblem;

PShape xboxFrontSVG;

HandyRenderer h, h1, h2;
HandyRenderer[] HANDY_RENDERERS;
HandyRenderer CURRENT_HANDY_RENDERER;

int[] modes;
String[]modeNames;

PeasyCam cam;

void loadSongToVisualize() {
  logToStdout("Loading song to visualize");
  audio = new Audio(this, config.SONG_TO_VISUALIZE, config.bandsPerOctave);
  config.SONG_PLAYING = true;
  if (dropPredictor != null) dropPredictor.scan(config.SONG_TO_VISUALIZE);
}

void setupController() {
  controller = new Controller(this);
  if (controller.isConnected()) {
    config.USING_CONTROLLER = true;
    config.TITLE_BAR = "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (h)and-drawn, (p)lasma, (s)top, (w)ave, (>)toggle diamonds, (/)toggle fins";
    controller.debugPrintControls();
  }
  logToStdout("USING CONTROLLER? " + config.USING_CONTROLLER);
}

void initializeGlobals() {
  logToStdout("initializeGlobals");

  config = new Config();
  dropPredictor = new DropPredictor();

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
    logToStdout("devmode check: " + f.getAbsolutePath() + " → " + f.exists());
    if (f.exists()) return true;
  }
  return false;
}

// Explicit opt-in for frame preview saves — separate from devmode so it never
// runs unless you specifically need Claude to see the visuals.
// Enable:  touch Music_Visualizer_CK/.devpreview
// Disable: rm Music_Visualizer_CK/.devpreview
boolean isDevPreview() {
  String[] candidates = {
    sketchPath() + "/.devpreview",
    sketchPath() + "/../.devpreview",
    System.getProperty("user.dir") + "/.devpreview"
  };
  for (String path : candidates) {
    if (new java.io.File(path).exists()) return true;
  }
  return false;
}

void saveDevPreview() {
  if (isDevPreview() && frameCount % 300 == 1) saveFrame("/tmp/vis_preview.png");
}

void setSongToVisualize() {
  logToStdout("Current song: " + config.SONG_TO_VISUALIZE);
  logToStdout("sketchPath() = " + sketchPath());
  logToStdout("user.dir     = " + System.getProperty("user.dir"));

  // Dev / smoke-test shortcuts — skip the dialog
  if (isDevMode() || SMOKE_TEST_MODE) {
    try {
      java.io.File devSongFile = new java.io.File(sketchPath(".devsong"));
      if (devSongFile.exists()) {
        String devSongPath = join(loadStrings(devSongFile.getAbsolutePath()), "").trim();
        if (new java.io.File(devSongPath).exists()) {
          config.SONG_TO_VISUALIZE = devSongPath;
          config.SONG_NAME = getSongNameFromFilePath(devSongPath, config.OS_TYPE);
          config.STATE = SCENE_ORIGINAL;
          logToStdout("Dev song: " + config.SONG_TO_VISUALIZE);
          return;
        }
      }
    } catch (Exception e) { /* ignore */ }

    java.io.File musicDir = new java.io.File(System.getProperty("user.home"), "Music");
    if (config.songList.size() == 0) collectSongs(musicDir, config.songList);
    if (config.songList.size() > 0) {
      config.currentSongIndex = (int) random(config.songList.size());
      config.SONG_TO_VISUALIZE = config.songList.get(config.currentSongIndex);
      logToStdout("Random song selected: " + config.SONG_TO_VISUALIZE);
      config.STATE = SCENE_ORIGINAL;
      config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      return;
    }
    logToStdout("No songs found in ~/Music, falling back to file picker");
    // fall through to dialog
  }

  // Show a startup dialog: Random Song vs Browse
  int choice = javax.swing.JOptionPane.showOptionDialog(
    null,
    "How would you like to load a song?",
    "Music Visualizer",
    javax.swing.JOptionPane.DEFAULT_OPTION,
    javax.swing.JOptionPane.QUESTION_MESSAGE,
    null,
    new String[]{ "Random Song", "Browse..." },
    "Random Song"
  );

  if (choice == 0) {
    // Random song from ~/Music
    java.io.File musicDir = new java.io.File(System.getProperty("user.home"), "Music");
    if (config.songList.size() == 0) collectSongs(musicDir, config.songList);
    if (config.songList.size() > 0) {
      config.currentSongIndex = (int) random(config.songList.size());
      config.SONG_TO_VISUALIZE = config.songList.get(config.currentSongIndex);
      logToStdout("Random song selected: " + config.SONG_TO_VISUALIZE);
      config.STATE = SCENE_ORIGINAL;
      config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      return;
    }
    logToStdout("No songs found in ~/Music, falling back to file picker");
  }

  // Browse (choice == 1, or random had no songs)
  selectInput("Select song to visualize", "fileSelected");
  while (config.SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  config.STATE = SCENE_ORIGINAL;
  logToStdout("SONG TO VISUALIZE: " + config.SONG_TO_VISUALIZE);
  config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
}

void loadSongByPath(String path) {
  audio.stop();
  config.SONG_TO_VISUALIZE = path;
  config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
  loadSongToVisualize();
  logToStdout("Now playing: " + config.SONG_NAME);
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
      if (name.endsWith(".mp3") || name.endsWith(".wav") || name.endsWith(".aiff")) {
        songs.add(f.getAbsolutePath());
      }
    }
  }
}

void fileSelected(File selection) {
  if (selection == null) {
    logToStdout("No file selected. Window might have been closed/cancelled");
    return;
  }
  String path = selection.getAbsolutePath();
  logToStdout("File selected: " + path);
  config.SONG_TO_VISUALIZE = path;
  config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
  // Always rescan parent folder so n/N works with the new location
  config.songList.clear();
  collectSongs(selection.getParentFile(), config.songList);
  config.currentSongIndex = config.songList.indexOf(path);
  if (config.currentSongIndex < 0) config.currentSongIndex = 0;

  // At runtime (audio already exists) load immediately.
  // At startup the setSongToVisualize() while-loop picks up SONG_TO_VISUALIZE instead.
  if (audio != null) {
    loadSongByPath(path);
  }
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

String getSongNameFromFilePath(String song_path, String osType) {
  logToStdout("Getting song name from file path, where osType is: " + osType);
  String[] file_name_parts;
  if (osType == "linux") {
    file_name_parts = split(song_path, "/");
  } else if (osType == "win") {
    file_name_parts = split(song_path, "\\");
  } else {
    file_name_parts = split(song_path, "\\");
  }
  config.SONG_NAME = file_name_parts[file_name_parts.length-1];
  logToStdout("SONG_NAME: " + config.SONG_NAME);
  return config.SONG_NAME;
}

void settings() {
  size(displayWidth, displayHeight - 80, P3D);
  boolean useFancy = false;
  if (args != null) {
    for (String arg : args) {
      if (arg.equals("--fancy")) useFancy = true;
    }
  }
  
  if (useFancy) {
    smooth(2);
  } else {
    noSmooth();
  }
}

void setup() {
  sceneBuffer = createGraphics(width, height, P3D);
  sceneBuffer.beginDraw(); sceneBuffer.background(0); sceneBuffer.endDraw();
  background(200);
  config = new Config();
  analyzer = new AudioAnalyser();
  logToStdout("canvas spawned");
  initializeGlobals();
  // Detect smoke test early so setSongToVisualize() skips the file picker
  if (isSmokeTestMode()) {
    SMOKE_TEST_MODE = true;
    println("[SMOKE TEST] Detected — will exercise all " + SCENE_COUNT + " scenes");
  }
  setSongToVisualize();
  surface.setResizable(true);
  frameRate(999);
  surface.setTitle(config.TITLE_BAR);
  setupController();
  loadSongToVisualize();
  bloomShader = loadShader("bloom.glsl");

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
  scenes[19] = new WormScene();
  scenes[20] = new FFTWormScene();
  scenes[21] = new DeepSpaceScene();
  scenes[22] = new CyberGridScene();
  scenes[23] = new RecursiveMandalaScene();
  scenes[24] = new KaleidoscopeScene();
  scenes[25] = new TableTennis3DScene();
  scenes[26] = new VoidBloomScene();
  scenes[27] = new CircuitMazeScene();
  scenes[28] = new MazePuzzleScene();
  scenes[29] = new LissajousKnotScene();
  scenes[30] = new FluidSimScene();
  scenes[31] = new HourglassScene();
  scenes[32] = new SacredGeometryScene();
  scenes[33] = new MathWaveScene();

  // SceneSwitcher — must be created AFTER scenes[] is populated
  sceneSwitcher = new SceneSwitcher(SCENE_ORDER);

  // Initialise smoke test runner after all scenes exist
  if (SMOKE_TEST_MODE) {
    smokeTestRunner = new SmokeTestRunner();
    println("[SMOKE TEST] Runner initialised — starting on next draw()");
  }

  monoFont = createFont("Monospaced", 15, true);
  // Dev shortcut: if .devscene exists in the sketch dir, start on that scene.
  // Must be resolved BEFORE onEnter() so the correct scene receives the call.
  // e.g.  echo 6 > Music_Visualizer_CK/.devscene
  try {
    java.io.File devScene = new java.io.File(sketchPath(".devscene"));
    if (devScene.exists()) {
      String raw = join(loadStrings(devScene.getAbsolutePath()), "").trim();
      config.STATE = Integer.parseInt(raw);
    }
  } catch (Exception e) { /* ignore — missing or malformed file */ }

  // Initial lifecycle trigger (skipped in smoke test — runner manages this)
  previousState = config.STATE;
  if (!SMOKE_TEST_MODE) scenes[config.STATE].onEnter();
  // load Halo 3 emblem used as reference for colors and texture
  h3_emblem = loadImage("../media/h3_emblem.jpg");

  xboxFrontSVG = loadShape("controller/front.svg");
  if (xboxFrontSVG != null) xboxFrontSVG.disableStyle();
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

void mouseWheel(MouseEvent event) {
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].handleMouseWheel(event.getCount());
  }
}

void keyPressed() {
  // Tab always toggles scene switcher (checked before anything else)
  if (key == TAB) { sceneSwitcher.toggle(); return; }

  // While switcher is open, route ALL keys to it and suppress everything else
  if (sceneSwitcher.isOpen) {
    sceneSwitcher.handleKey(key, keyCode);
    return;
  }

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
  if (key == 'o' || key == 'O') selectInput("Select song to visualize", "fileSelected");
  if (key == 'l' || key == 'L') config.LOGGING_ENABLED = !config.LOGGING_ENABLED;
  if (key == 'm' || key == 'M') config.SHOW_METADATA = !config.SHOW_METADATA;
  if (key == '`') config.SHOW_CODE = !config.SHOW_CODE;
  if (key == 'i' || key == 'I') config.SHOW_CONTROLLER_GUIDE = !config.SHOW_CONTROLLER_GUIDE;  // Toggle controller guide
  if (key == 'g' || key == 'G') config.BLOOM_ENABLED = !config.BLOOM_ENABLED;
  if (key == 'c' || key == 'C') controller.calibrate();
  if (key == 'q' || key == 'Q' || key == ESC) {
    key = 0; // suppress Processing's default ESC→exit behaviour
    audio.stop();
    exit();
  }

  // Scene Switching: 1-9 → SCENE_ORDER[0..8], 0 → SCENE_ORDER[9]
  if ((key >= '1' && key <= '9') || key == '0') {
    int pos = (key == '0') ? 9 : ((int) key - 49);
    if (pos >= 0 && pos < SCENE_ORDER.length) {
      switchScene(SCENE_ORDER[pos]);
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
  logToStdout("reset");
  audio.stop();
  config.SONG_TO_VISUALIZE = "";
  setSongToVisualize();
  loadSongToVisualize();
}

void logToStdout(String messageToLog) {
  if (config.LOGGING_ENABLED) {
    println(messageToLog);
  }
}



public void getUserInput() {
  // Always read (handles hot-plug retry inside Controller.read()).
  // Update the flag each frame so scenes react as soon as the device appears.
  controller.read();
  config.USING_CONTROLLER = controller.isConnected();
  if (!config.USING_CONTROLLER) return;

  // 1. Delegate to active scene
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].applyController(controller);
  }

  // 2. Global Controller Shortcuts
  if (controller.dpadUpJustPressed) {
    config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
    if (config.DRAW_TUNNEL) enableOneBackgroundAndDisableOthers("tunnel");
  }
  if (controller.dpadLeftJustPressed) {
    config.DRAW_PLASMA = !config.DRAW_PLASMA;
    if (config.DRAW_PLASMA) enableOneBackgroundAndDisableOthers("plasma");
  }
  if (controller.dpadRightJustPressed) {
    config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
    if (config.DRAW_POLAR_PLASMA) enableOneBackgroundAndDisableOthers("polar_plasma");
  }
  if (controller.dpadDownJustPressed) {
    config.DRAW_TUNNEL = false;
    config.DRAW_POLAR_PLASMA = false;
    config.DRAW_PLASMA = false;
  }

  if (!controller.chord(controller.lbButton, controller.rbButton)) {
    if (controller.lbJustPressed) {
      println("CONTROLLER: LB pressed -> switching prev");
      switchScene(prevActiveScene());
    }
    if (controller.rbJustPressed) {
      println("CONTROLLER: RB pressed -> switching next");
      switchScene(nextActiveScene());
    }
  }
  
  if (controller.backJustPressed) {
    println("CONTROLLER: BACK pressed -> stopping");
    stopSong();
  }
  if (controller.startJustPressed) {
    println("CONTROLLER: START pressed -> starting");
    startSong();
  }
}
// ── Active scene list ─────────────────────────────────────────────────────────
// Fan-favourite scenes, in display order. Only these are reachable via
// LB/RB cycling or keyboard number keys. Add a SceneIds constant to re-enable.
// Scenes 3 (SHAPES_3D) and 9 (HALO2_LOGO) are kept in code but excluded for now.
final int[] SCENE_ORDER = {
  SCENE_ORIGINAL,
  SCENE_MAZE_PUZZLE,
  SCENE_LISSAJOUS_KNOT,
  SCENE_CATS_CRADLE,
  SCENE_TABLE_TENNIS,
  SCENE_TABLE_TENNIS_3D,
  SCENE_PRISM_CODEX,
  SCENE_GRAVITY_STRINGS,
  SCENE_NEURAL_WEAVE,
  SCENE_FRACTAL,
  SCENE_SHADER,
  SCENE_WORM,
  SCENE_RECURSIVE_MANDALA,
  SCENE_KALEIDOSCOPE,
  SCENE_VOID_BLOOM,
  SCENE_CIRCUIT_MAZE,
  SCENE_HOURGLASS,
  SCENE_SACRED_GEOMETRY,
  SCENE_MATH_WAVE
};

int _sceneOrderIndex(int state) {
  for (int i = 0; i < SCENE_ORDER.length; i++) {
    if (SCENE_ORDER[i] == state) return i;
  }
  return 0; // default to first if current scene not in list
}

int nextActiveScene() { return sceneSwitcher.nextScene(config.STATE); }
int prevActiveScene() { return sceneSwitcher.prevScene(config.STATE); }

// ── Scene crossfade ───────────────────────────────────────────────────────────
// When switchScene() is called, we capture the current frame as a frozen
// snapshot and draw it on top of the incoming scene with decreasing alpha.
// This gives a smooth dissolve without needing two live render buffers.

PImage crossfadeSnapshot  = null;
int    crossfadeFrame     = 0;
final int CROSSFADE_DURATION = 45; // frames  (~0.75 s at 60 fps)

void switchScene(int newState) {
  if (SMOKE_TEST_MODE) return; // runner manages scene state directly
  // Allow any scene in the switcher's active order (or direct calls from switcher itself)
  if (!sceneSwitcher.isInRotation(newState) && newState != config.STATE) {
    // Also allow direct jumps — just let it through if it's a valid scene index
    if (newState < 0 || newState >= SCENE_COUNT) return;
  }
  if (config.STATE == newState) return;
  crossfadeSnapshot = get();        // freeze the last frame of the current scene
  crossfadeFrame    = 0;
  config.STATE      = newState;
}

// Direct switch called from SceneSwitcher — bypasses rotation guard
void switchSceneDirect(int newState) {
  if (SMOKE_TEST_MODE) return;
  if (newState < 0 || newState >= SCENE_COUNT) return;
  if (config.STATE == newState) return;
  crossfadeSnapshot = get();
  crossfadeFrame    = 0;
  scenes[config.STATE].onExit();
  config.STATE      = newState;
  scenes[config.STATE].onEnter();
}

long lastLogicalFrame = 0;
float accumulator = 0;

void draw() {
  // ── Smoke test fast-path ─────────────────────────────────────────────────
  if (SMOKE_TEST_MODE) {
    // Keep audio ticking so FFT data is valid (scenes read it in drawScene)
    audio.forward();
    audio.beat.detect(audio.player.mix);
    analyzer.update(audio);
    smokeTestRunner.tick(sceneBuffer);
    blendMode(REPLACE);
    image(sceneBuffer, 0, 0);
    return;
  }
  // ────────────────────────────────────────────────────────────────────────
  if (frameCount % 60 == 0) println("SCENE: " + config.STATE + " | CONTROLLER: " + config.USING_CONTROLLER + " | FPS: " + int(frameRate));
  saveDevPreview();
  
  // 1. Scene Lifecycle Management
  if (config.STATE != previousState) {
    if (previousState >= 0 && previousState < SCENE_COUNT) {
      scenes[previousState].onExit();
    }
    previousState = config.STATE;
    if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
      scenes[config.STATE].onEnter();
    }
    // ── Clean render state on every scene switch ─────────────────────────
    sceneBuffer.beginDraw();
    sceneBuffer.blendMode(BLEND);
    sceneBuffer.background(0);
    sceneBuffer.endDraw();
    config.BACKGROUND_ENABLED = true;
    config.CURRENT_BLEND_MODE_INDEX = 0;
    blendMode(BLEND);
  }

  // Calculate Delta Time for Fixed Update Loop
  long now = millis();
  if (lastLogicalFrame == 0) lastLogicalFrame = now;
  float dtMs = now - lastLogicalFrame;
  lastLogicalFrame = now;
  if (dtMs > 100) dtMs = 16.666667; 
  accumulator += dtMs;
  
  boolean didRenderScene = false;

  // Fixed 60Hz Timestep for all Physics and Logic
  while (accumulator >= 16.666667) {
    accumulator -= 16.666667;
    config.logicalFrameCount++;

    // 2. Continuous Logic Updates
    if (frameCount % 480 == 0) logToStdout("Draw state=" + config.STATE);

    if (config.SONG_PLAYING && !audio.player.isPlaying()
        && config.songList.size() > 0) {
      shuffleSong();
    }

    audio.forward();
    audio.beat.detect(audio.player.mix);
    analyzer.update(audio);
    getUserInput();

    // 3. Render Active Scene to Buffer
    if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
      if (sceneBuffer.width != width || sceneBuffer.height != height) {
        sceneBuffer = createGraphics(width, height, P3D);
        sceneBuffer.beginDraw(); sceneBuffer.background(0); sceneBuffer.endDraw();
      }

      sceneBuffer.beginDraw();
      sceneBuffer.colorMode(PConstants.RGB, 255);
      sceneBuffer.rectMode(PConstants.CORNER);
      sceneBuffer.ellipseMode(PConstants.CENTER);
      sceneBuffer.imageMode(PConstants.CORNER);
      sceneBuffer.hint(PConstants.ENABLE_DEPTH_TEST);
      
      if (monoFont != null) sceneBuffer.textFont(monoFont);
      sceneBuffer.pushMatrix();
      scenes[config.STATE].drawScene(sceneBuffer);
      sceneBuffer.popMatrix();
      sceneBuffer.endDraw();
      didRenderScene = true;
    }
  } // End Fixed Timestep

  // 4. Post-Processing & Final Output (Runs Unlocked at >144FPS)
  blendMode(REPLACE); // Massive Performance improvement for laptops
  if (config.BLOOM_ENABLED) {
    shader(bloomShader);
  }
  image(sceneBuffer, 0, 0);
  if (config.BLOOM_ENABLED) {
    resetShader();
  }

  // 5. Global overlays (UI drawn at native res, over the buffer)
  blendMode(BLEND); 
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    if (config.SHOW_CODE) {
      drawCodeOverlay(scenes[config.STATE].getCodeLines());
    }
    if (config.SHOW_CONTROLLER_GUIDE) {
      ControllerLayout[] layout = scenes[config.STATE].getControllerLayout();
      if (layout != null) {
        drawControllerGuide(layout);
      }
    }
  }

  addFPSToTitleBar();

  // ── Crossfade overlay ───────────────────────────────────────────────────────
  if (crossfadeSnapshot != null) {
    if (didRenderScene) {
      crossfadeFrame++;
      if (audio.beat.isOnset() && crossfadeFrame > CROSSFADE_DURATION / 2) {
        crossfadeFrame = CROSSFADE_DURATION;
      }
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

  if (config.SHOW_METADATA) {
    drawMetadataOverlay();
  }

  // Scene switcher overlay — drawn last so it always floats on top
  if (sceneSwitcher.isOpen) {
    sceneSwitcher.update();
    sceneSwitcher.drawOverlay();
  }
}

void drawMetadataOverlay() {
  String[] lines = {
    "=== SYSTEM METADATA ===",
    "FPS (Render)    : " + int(frameRate),
    "Scene Index     : " + config.STATE,
    "Scene Name      : " + scenes[config.STATE].getClass().getSimpleName(),
    "Logical Frames  : " + config.logicalFrameCount,
    "",
    "=== AUDIO METADATA ===",
    "Song Name       : " + config.SONG_NAME,
    "Playing         : " + config.SONG_PLAYING,
    "Controller Match: " + config.USING_CONTROLLER
  };

  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  
  float maxTextWidth = 0;
  for (String line : lines) {
    float w = textWidth(line);
    if (w > maxTextWidth) maxTextWidth = w;
  }
  
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float boxW  = maxTextWidth + pad * 2;
  float boxH  = pad * 2 + lines.length * lineH;
  float boxX  = width - boxW - 12 * uiScale();
  float boxY  = 12 * uiScale();

  fill(0, 200);   
  stroke(0, 255, 0); 
  strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 8);

  fill(0, 255, 0);
  noStroke();
  float ty = boxY + pad + lineH * 0.8;
  for (int i = 0; i < lines.length; i++) {
    text(lines[i], boxX + pad, ty);
    ty += lineH;
  }
  popStyle();
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
    surface.setTitle("Music Visualizer CK | fps: " + int(frameRate) + " | scene: " + config.STATE
      + " | " + config.SONG_TO_VISUALIZE);
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

void drawSongNameOnScreen(PGraphics pg, String song_name, float nameLocationX, float nameLocationY) {
  pg.textSize(24 * uiScale());
  pg.textAlign(CENTER);
  pg.fill(0);
  
  pg.text(song_name, nameLocationX + 2, nameLocationY + 2);
  
  pg.fill(255);
  pg.text(song_name, nameLocationX, nameLocationY);

  // Small path line below song name for easy debugging
  pg.textSize(11 * uiScale());
  pg.fill(0);
  pg.text(config.SONG_TO_VISUALIZE, nameLocationX + 1, nameLocationY + 18 * uiScale() + 1);
  pg.fill(180, 180, 180, 180);
  pg.text(config.SONG_TO_VISUALIZE, nameLocationX, nameLocationY + 18 * uiScale());
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


