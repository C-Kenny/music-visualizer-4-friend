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
Tunnel tunnel;
Plasma plasma;
PolarPlasma polarPlasma;
Shapes3DScene shapes3D;
CatsCradleScene catsCradle;
OscilloscopeScene oscilloscope;
ParticleFountainScene particleFountain;
Halo2LogoScene halo2Logo;
PrismCodexScene prismCodex;
TableTennisScene tableTennis;
WormScene wormScene;
FFTWormScene fftWorm;
AuroraRibbonsScene auroraRibbons;
RadialFFTScene radialFFT;
SpirographScene spirograph;
GravityStringsScene gravityStrings;
NeuralWeaveScene neuralWeave;
ShoalLuminaScene shoalLumina;
AntigravityScene antigravity;
FractalScene fractalScene;
ShaderScene shaderScene;
PFont monoFont;


OriginalScene originalScene;
HeartGridScene heartGridScene;


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
  log_to_stdo("canvas spawned");
  initializeGlobals();
  setSongToVisualize();
  surface.setResizable(true);
  frameRate(160);
  surface.setTitle(config.TITLE_BAR);
  setupController();
  loadSongToVisualize();
  tunnel = new Tunnel();
  plasma = new Plasma();
  polarPlasma = new PolarPlasma();
  shapes3D = new Shapes3DScene();
  catsCradle = new CatsCradleScene();
  oscilloscope = new OscilloscopeScene();
  particleFountain = new ParticleFountainScene();
  halo2Logo = new Halo2LogoScene();
  prismCodex = new PrismCodexScene();
  tableTennis = new TableTennisScene();
  wormScene     = new WormScene();
  fftWorm       = new FFTWormScene();
  auroraRibbons = new AuroraRibbonsScene();
  radialFFT     = new RadialFFTScene();
  spirograph    = new SpirographScene();
  gravityStrings = new GravityStringsScene();
  neuralWeave = new NeuralWeaveScene();
  shoalLumina = new ShoalLuminaScene();
  antigravity = new AntigravityScene();
  fractalScene = new FractalScene();
  shaderScene = new ShaderScene();
  originalScene = new OriginalScene(this);
  heartGridScene = new HeartGridScene();
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
  if (tableTennis != null) tableTennis.closeScoreLog();
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
  if (config.STATE == 8 && particleFountain != null) {
    particleFountain.triggerBurstAt(mouseX, mouseY);
  }
}

void keyPressed() {
  // State 14: B/G used by Neural Weave — skip global blend (same pattern as other scene-specific keys)
  if ((key == 'b' || key == 'B') && config.STATE != 9 && config.STATE != 14) {
    changeBlendMode();
  }
  if (key == 'h') {
    cycleHandDrawn();
  }
  if (key == 'H') {
    config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
    CURRENT_HANDY_RENDERER.setIsHandy(config.APPEAR_HAND_DRAWN);
  }
  if (key == 'f' || key == 'F') {
    changeFinRotation();
  }
  if (key == 'd' && config.STATE == 1) {
    originalScene.modifyDiamondCenterPoint(false);
  }
  if (key == 'D' && config.STATE == 1) {
    originalScene.modifyDiamondCenterPoint(true);
  }
  if (key == 'r' || key == 'R') {
    config.SCREEN_RECORDING = !config.SCREEN_RECORDING;
  }
  if (key == 's' || key == 'S') {
    toggleSongPlaying();
  }
  if (key == 'l' || key == 'L') {
    config.LOGGING_ENABLED = !config.LOGGING_ENABLED;
  }
  if (key == 'y') {
    config.BEZIER_Y_OFFSET -= 10;
  }
  if (key == 'Y') {
    config.BEZIER_Y_OFFSET += 10;
  }
  if (config.STATE == 1 && key == 'r') {
    config.DIAMOND_RIGHT_EDGE_X += 20;
    config.DIAMOND_LEFT_EDGE_X -= 20;
  }
  if (config.STATE == 1 && key == 'R') {
    config.DIAMOND_RIGHT_EDGE_X -= 20;
    config.DIAMOND_LEFT_EDGE_X += 20;
  }
  if (key == 'c') {
    config.DIAMOND_RIGHT_EDGE_Y += 20;
    config.DIAMOND_LEFT_EDGE_Y -= 20;
  }
  if (key == 'C') {
    config.DIAMOND_RIGHT_EDGE_Y -= 20;
    config.DIAMOND_LEFT_EDGE_Y += 20;
  }
  // State 14: G cycles Neural Weave growth — skip global background toggle
  if ((key == 'g' || key == 'G') && config.STATE != 14) {
    config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
  }
  if (key == '<' || key == '>') {
    config.DRAW_DIAMONDS = !config.DRAW_DIAMONDS;
  }
  if (key == 'w' || key == 'W') {
    config.DRAW_WAVEFORM = !config.DRAW_WAVEFORM;
  }
  if (key == '/') {
    config.DRAW_FINS = !config.DRAW_FINS;
  }
  if (key == 'o' || key == 'O') {
    reset();
  }
  if (key == 'n') {
    nextSong();
  }
  if (key == 'N') {
    shuffleSong();
  }
  if (key == 'i' || key == 'I') {
    config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }
  if ((key >= '1' && key <= '9') || key == '0') {
    int newState = (key == '0') ? 10 : ((int) key - 48);
    // Only allow switching to active scenes (3 and 9 are disabled)
    if (_sceneOrderIndex(newState) >= 0 || newState == SCENE_ORDER[0]) {
      boolean inRotation = false;
      for (int s : SCENE_ORDER) { if (s == newState) { inRotation = true; break; } }
      if (inRotation) {
        log_to_stdo("Switching to state: " + newState);
        switchScene(newState);
      }
    }
  }
  // Table Tennis tuning keys (state 6 only)
  if (config.STATE == 6 && tableTennis != null) {
    if (key == '+' || key == '=') tableTennis.adjustGravity(0.02);
    if (key == '-')               tableTennis.adjustGravity(-0.02);
    if (key == '[')               tableTennis.adjustMagnus(-0.005);
    if (key == ']')               tableTennis.adjustMagnus(0.005);
  }

  // Shapes3DScene live tuning keys (state 3 only)
  if (config.STATE == 3 && shapes3D != null) {
    if (key == 'k') shapes3D.incrementBlades(-1);
    if (key == 'K') shapes3D.incrementBlades(1);
    if (key == '[') shapes3D.adjustFinWidth(-2);
    if (key == ']') shapes3D.adjustFinWidth(2);
    if (key == ',') shapes3D.adjustPlateScale(-0.05);
    if (key == '.') shapes3D.adjustPlateScale(0.05);
    if (key == 'u') shapes3D.adjustPulseSensitivity(-0.05);
    if (key == 'U') shapes3D.adjustPulseSensitivity(0.05);
  }
  // Oscilloscope live tuning keys (state 5 only)
  if (config.STATE == 5 && oscilloscope != null) {
    if (key == '[') oscilloscope.adjustGainX(-0.1);
    if (key == ']') oscilloscope.adjustGainX(0.1);
    if (key == '-') oscilloscope.adjustGainY(-0.1);
    if (key == '=') oscilloscope.adjustGainY(0.1);
    if (key == ';') oscilloscope.adjustTrail(-2);
    if (key == '\'') oscilloscope.adjustTrail(2);
  }

  // Heart grid keys (state 2 only)
  if (config.STATE == 2) {
    if (key == '[') config.HEART_COLS = max(1, config.HEART_COLS - 1);
    if (key == ']') config.HEART_COLS = min(10, config.HEART_COLS + 1);
  }

  // Halo 2 Logo keys (state 9 only)
  if (config.STATE == 9 && halo2Logo != null) {
    if (key == 'b' || key == 'B') halo2Logo.cycleBgMode();
    if (key == CODED) {
      if (keyCode == UP)   halo2Logo.adjustPulseSens(0.05);
      if (keyCode == DOWN) halo2Logo.adjustPulseSens(-0.05);
    }
  }

  // Particle Fountain keys (state 8 only)
  if (config.STATE == 8 && particleFountain != null) {
    if (key == ' ')  particleFountain.triggerBurst();
    if (key == '[')  particleFountain.adjustSpread(-radians(5));
    if (key == ']')  particleFountain.adjustSpread(radians(5));
    if (key == 'w' || key == 'W') particleFountain.nudgeOrigin(0, -10);
    if (key == 'a' || key == 'A') particleFountain.nudgeOrigin(-10, 0);
    if (key == 's' || key == 'S') particleFountain.nudgeOrigin(0, 10);
    if (key == 'd' || key == 'D') particleFountain.nudgeOrigin(10, 0);
  }
  // Radial FFT keys (state 11 only)
  if (config.STATE == 11 && radialFFT != null) {
    if (key == 'r' || key == 'R') radialFFT.reverseDirection();
    if (key == '[') radialFFT.adjustSpeed(-0.001);
    if (key == ']') radialFFT.adjustSpeed(0.001);
  }
  // Neural Weave (state 14) — see documentation/neural_weave.md
  if (config.STATE == 14 && neuralWeave != null) {
    if (key == '[') neuralWeave.adjustCols(-1);
    if (key == ']') neuralWeave.adjustCols(1);
    if (key == '-' || key == '_') neuralWeave.adjustEdgeGain(-0.08);
    if (key == '=' || key == '+') neuralWeave.adjustEdgeGain(0.08);
    if (key == 'k' || key == 'K') neuralWeave.cyclePalette();
    if (key == ' ') neuralWeave.triggerRipple();
    if (key == 'e' || key == 'E') neuralWeave.toggleLabMode();
    if (key == 'g' || key == 'G' || key == 'b' || key == 'B') neuralWeave.cycleGrowthMode();
    if (key == 'v' || key == 'V') neuralWeave.toggleVesicles();
  }

  // Shoal Lumina (state 15)
  if (config.STATE == 15 && shoalLumina != null) {
    if (key == '[') shoalLumina.adjustLayers(-1);
    if (key == ']') shoalLumina.adjustLayers(1);
    if (key == '-' || key == '_') shoalLumina.adjustSpeed(-0.0025);
    if (key == '=' || key == '+') shoalLumina.adjustSpeed(0.0025);
    if (key == ' ') shoalLumina.triggerSurge();
  }

  // Antigravity (state 16 only)
  if (config.STATE == 16 && antigravity != null) {
    if (key == '[') antigravity.adjustGravity(-0.1);
    if (key == ']') antigravity.adjustGravity(0.1);
    if (key == '-' || key == '_') antigravity.adjustWind(-0.1);
    if (key == '=' || key == '+') antigravity.adjustWind(0.1);
    if (key == 'y' || key == 'Y') antigravity.cyclePalette();
    if (key == ' ') antigravity.triggerPulse();
  }

  // Fractal Scene (state 17 only)
  if (config.STATE == 17 && fractalScene != null) {
    if (key == '[') fractalScene.adjustZoom(-0.1);
    if (key == ']') fractalScene.adjustZoom(0.1);
    if (key == '-' || key == '_') fractalScene.adjustRotationSpeed(-0.01);
    if (key == '=' || key == '+') fractalScene.adjustRotationSpeed(0.01);
    if (key == 'y' || key == 'Y') fractalScene.cyclePalette();
    if (key == 'x' || key == 'X') {
      fractalScene.globalZoom = 0;
      fractalScene.rotationSpeed = 0.005;
    }
    if (key == 'A' || key == 'a') {
      fractalScene.symmetries = (fractalScene.symmetries % 8) + 3;
    }
  }

  // Shader Scene (state 18 only)
  if (config.STATE == 18 && shaderScene != null) {
    if (key == 'y' || key == 'Y') shaderScene.loadMyShader();
    if (key == 'A' || key == 'a') {
      shaderScene.panX = 0;
      shaderScene.panY = 0;
      shaderScene.twist = 0;
    }
  }

  // Aurora ribbons keys (state 10 only)
  if (config.STATE == 10 && auroraRibbons != null) {
    if (key == '[') auroraRibbons.adjustTurbulence(-0.05);
    if (key == ']') auroraRibbons.adjustTurbulence(0.05);
    if (key == '-' || key == '_') auroraRibbons.adjustLength(-0.05);
    if (key == '=' || key == '+') auroraRibbons.adjustLength(0.05);
    if (key == 'h' || key == 'H') auroraRibbons.adjustHue(-7);
    if (key == 'j' || key == 'J') auroraRibbons.adjustHue(7);
    if (key == 'k' || key == 'K') auroraRibbons.cyclePalette();
    if (key == ' ') auroraRibbons.triggerFlash();
  }
  if (key == '`') {
    config.SHOW_CODE = !config.SHOW_CODE;
  }
  if (key == 'x' || key == 'X') {
    audio.stop();
    exit();
  }
  if (key == 'q' || key == 'Q') {
    exit();
  }
  if (key == 't' || key == 'T') {
    config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
    if (config.DRAW_TUNNEL) {enableOneBackgroundAndDisableOthers("tunnel");}
  }
  if (key == 'p') {
    config.DRAW_PLASMA = !config.DRAW_PLASMA;
    if (config.DRAW_PLASMA) {
      plasma = new Plasma();
      enableOneBackgroundAndDisableOthers("plasma");
      }
  }
  if (key == 'P') {
    config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
    if (config.DRAW_POLAR_PLASMA) {enableOneBackgroundAndDisableOthers("polar_plasma");}
  }
  if (key == CODED) {
    if (keyCode == LEFT) {
      audio.skip(-10000);
    }
    if (keyCode == RIGHT) {
      audio.skip(10000);
    }
    if (config.STATE == 8 && particleFountain != null) {
      if (keyCode == UP)   particleFountain.adjustGravity(-0.01);
      if (keyCode == DOWN) particleFountain.adjustGravity(0.01);
    } else {
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

  if (!usingController) {
    return ;
  }

  controller.read();

  if (config.STATE == 1) {
    originalScene.applyController(controller);
  }

  if (controller.dpad_hat_switch_up) {
   config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
   if (config.DRAW_TUNNEL) {
    enableOneBackgroundAndDisableOthers("tunnel");
   }
  }

  if (controller.dpad_hat_switch_left) {
   config.DRAW_PLASMA = !config.DRAW_PLASMA;
   if (config.DRAW_PLASMA) {
    plasma = new Plasma();
    enableOneBackgroundAndDisableOthers("plasma");
   }
  }

  if (controller.dpad_hat_switch_right) {
   config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
   if (config.DRAW_POLAR_PLASMA) {
    enableOneBackgroundAndDisableOthers("polar_plasma");
   }
  }
  if (controller.dpad_hat_switch_down) {
   config.DRAW_TUNNEL = false;
   config.DRAW_POLAR_PLASMA = false;
   config.DRAW_PLASMA = false;
  }

  if (config.STATE == 2) {
    heartGridScene.applyController(controller);
  }

  // oscilloscope live tuning via controller (only when on that scene)
  if (config.STATE == 5 && oscilloscope != null) {
    oscilloscope.applyController(controller);
  }

  // particle fountain controller input
  if (config.STATE == 8 && particleFountain != null) {
    particleFountain.applyController(controller);
    if (controller.b_just_pressed) particleFountain.long_trail = !particleFountain.long_trail;
  }

  // cats cradle live tuning
  if (config.STATE == 4 && catsCradle != null) {
    catsCradle.applyController(controller);
  }

  // table tennis live tuning
  if (config.STATE == 6 && tableTennis != null) {
    tableTennis.applyController(controller);
  }

  // prism codex live tuning
  if (config.STATE == 7 && prismCodex != null) {
    prismCodex.applyController(controller);
  }

  // halo 2 logo live tuning
  if (config.STATE == 9 && halo2Logo != null) {
    halo2Logo.applyController(controller);
  }

  // worm colony
  if (config.STATE == 3 && wormScene != null) {
    wormScene.applyController(controller);
  }

  // fft worm
  if (config.STATE == 9 && fftWorm != null) {
    fftWorm.applyController(controller);
  }

  // aurora ribbons
  if (config.STATE == 10 && auroraRibbons != null) {
    auroraRibbons.applyController(controller);
  }

  // radial fft
  if (config.STATE == 11 && radialFFT != null) {
    radialFFT.applyController(controller);
  }

  // spirograph
  if (config.STATE == 12 && spirograph != null) {
    spirograph.applyController(controller);
  }

  // gravity strings
  if (config.STATE == 13 && gravityStrings != null) {
    gravityStrings.applyController(controller);
  }

  // Neural Weave — documentation/neural_weave.md
  if (config.STATE == 14 && neuralWeave != null) {
    neuralWeave.applyController(controller);
  }

  // Shoal Lumina
  if (config.STATE == 15 && shoalLumina != null) {
    shoalLumina.applyController(controller);
  }

  // Antigravity
  if (config.STATE == 16 && antigravity != null) {
    antigravity.applyController(controller);
  }

  // Fractal
  if (config.STATE == 17 && fractalScene != null) {
    fractalScene.applyController(controller);
  }

  // Shader
  if (config.STATE == 18 && shaderScene != null) {
    shaderScene.applyController(controller);
  }

  // map controller sticks to Shapes3DScene parameters for live tuning
  if (config.STATE == 3 && shapes3D != null) {
    // controller.* values are mapped to screen coords (0..width or 0..height) by Controller
    // normalize them back to -1..1 before mapping to scene params
    float nx = map(controller.rx, 0, width, -1, 1);
    float ny = map(controller.ry, 0, height, -1, 1);
    float lx = map(controller.lx, 0, width, -1, 1);
    float ly = map(controller.ly, 0, height, -1, 1);

    int bladesFromStick = int(map(nx, -1, 1, 4, 12));
    shapes3D.setBlades(bladesFromStick);

    float finW = map(ly, -1, 1, 8, min(width, height) * 0.08);
    shapes3D.setFinWidth(finW);

    float plateS = map(lx, -1, 1, 0.8, 1.6);
    shapes3D.setPlateScale(plateS);

    float pulseS = map(ny, -1, 1, 0.2, 1.2);
    shapes3D.setPulseSensitivity(pulseS);
  }

  boolean wormScene_active = (config.STATE == 3 || config.STATE == 9);

  // State 14: B cycles growth — skip global blend
  if (controller.b_just_pressed && !wormScene_active && config.STATE != 14) {
    changeBlendMode();
  }

  if (controller.a_just_pressed && !wormScene_active) {
    switch (config.STATE) {
      case 8:  if (particleFountain != null) particleFountain.triggerBurst(); break;
      case 14: if (neuralWeave != null) neuralWeave.triggerRipple(); break; // not rainbow_fins
      case 15: break; // surge handled in ShoalLuminaScene.applyController
      default: config.RAINBOW_FINS = !config.RAINBOW_FINS; break;
    }
  }

  // State 14 (Neural Weave) opts out so Y only runs scene palette there — see documentation/neural_weave.md
  if (controller.y_just_pressed && !wormScene_active && config.STATE != 14 && config.STATE != 15) {
    if (config.STATE != 9) changeFinRotation();
  }

  // State 14: X toggles lab mode in NeuralWeaveScene.applyController
  if (controller.x_just_pressed && !wormScene_active && config.STATE != 14) {
    config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
  }

  if (controller.back_just_pressed) {
    stopSong();
  }

  if (controller.start_just_pressed) {
    startSong();
  }

  if (controller.lb_just_pressed) switchScene(prevActiveScene());
  if (controller.rb_just_pressed) switchScene(nextActiveScene());

  // State 14: stick clicks handled by NeuralWeaveScene (reset view / reshuffle bridges)
  if (controller.lstickclick_just_pressed && config.STATE != 14) {
    config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
  }

  if (controller.rstickclick_just_pressed && config.STATE != 14) {
    config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }
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
  // occasional log to show current state
  if (frameCount % 240 == 0) println("Main draw state=" + config.STATE);

  if (config.STATE != previous_state) {
    previous_state = config.STATE;
  }

  // Audio analysis — run once per frame so every scene reads the same snapshot.
  // Calling forward() or beat.detect() inside individual scenes is redundant and wastes CPU.
  audio.forward();
  audio.beat.detect(audio.player.mix);

  switch(config.STATE){
    case 0:
      background(200);
      textSize(48 * uiScale());
      fill(0,255,0);
      text("RIP Sam", width/2, height/2);
      break;
   
  case 1:
    getUserInput(config.USING_CONTROLLER);
    originalScene.drawScene();
    addFPSToTitleBar();
    break;
  case 2:
    getUserInput(config.USING_CONTROLLER);
    heartGridScene.drawScene();
    addFPSToTitleBar();
    break;
  case 3:
    getUserInput(config.USING_CONTROLLER);
    wormScene.drawScene();
    addFPSToTitleBar();
    break;
  case 4:
    getUserInput(config.USING_CONTROLLER);
    background(0);
    catsCradle.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(catsCradle.getCodeLines());
    addFPSToTitleBar();
    break;
  case 5:
    getUserInput(config.USING_CONTROLLER);
    oscilloscope.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(oscilloscope.getCodeLines());
    addFPSToTitleBar();
    break;
  case 6:
    getUserInput(config.USING_CONTROLLER);
    tableTennis.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(tableTennis.getCodeLines());
    addFPSToTitleBar();
    break;
  case 7:
    getUserInput(config.USING_CONTROLLER);
    prismCodex.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(prismCodex.getCodeLines());
    addFPSToTitleBar();
    break;
  case 8:
    getUserInput(config.USING_CONTROLLER);
    particleFountain.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(particleFountain.getCodeLines());
    addFPSToTitleBar();
    break;
  case 9:
    getUserInput(config.USING_CONTROLLER);
    fftWorm.drawScene();
    addFPSToTitleBar();
    break;
  case 10:
    getUserInput(config.USING_CONTROLLER);
    auroraRibbons.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(auroraRibbons.getCodeLines());
    addFPSToTitleBar();
    break;
  case 11:
    getUserInput(config.USING_CONTROLLER);
    radialFFT.drawScene();
    addFPSToTitleBar();
    break;
  case 12:
    getUserInput(config.USING_CONTROLLER);
    spirograph.drawScene();
    addFPSToTitleBar();
    break;
  case 13:
    getUserInput(config.USING_CONTROLLER);
    gravityStrings.drawScene();
    addFPSToTitleBar();
    break;
  case 14:
    getUserInput(config.USING_CONTROLLER);
    neuralWeave.drawScene();
    addFPSToTitleBar();
    break;
  case 15:
    getUserInput(config.USING_CONTROLLER);
    shoalLumina.drawScene();
    addFPSToTitleBar();
    break;
  case 16:
    getUserInput(config.USING_CONTROLLER);
    antigravity.drawScene();
    addFPSToTitleBar();
    break;
  case 17:
    getUserInput(config.USING_CONTROLLER);
    fractalScene.drawScene();
    addFPSToTitleBar();
    break;
  case 18:
    getUserInput(config.USING_CONTROLLER);
    shaderScene.drawScene();
    addFPSToTitleBar();
    break;
  }

  // ── Per-scene controls HUD (` to toggle) ────────────────────────────────────
  if (config.STATE == 1  && config.SHOW_CODE) drawControlsHUD();
  if (config.STATE == 3  && config.SHOW_CODE) drawSceneControlsHUD(wormScene.getCodeLines());
  if (config.STATE == 9  && config.SHOW_CODE) drawSceneControlsHUD(fftWorm.getCodeLines());
  if (config.STATE == 10 && config.SHOW_CODE) drawSceneControlsHUD(auroraRibbons.getCodeLines());
  if (config.STATE == 11 && config.SHOW_CODE) drawSceneControlsHUD(radialFFT.getCodeLines());
  if (config.STATE == 12 && config.SHOW_CODE) drawSceneControlsHUD(spirograph.getCodeLines());
  if (config.STATE == 13 && config.SHOW_CODE) drawCodeOverlay(gravityStrings.getCodeLines());
  if (config.STATE == 14 && config.SHOW_CODE) drawSceneControlsHUD(neuralWeave.getCodeLines());
  if (config.STATE == 15 && config.SHOW_CODE) drawSceneControlsHUD(shoalLumina.getCodeLines());
  if (config.STATE == 18 && config.SHOW_CODE && shaderScene.shaderLoaded) drawCodeOverlay(shaderScene.getCodeLines());

  // ── Crossfade overlay ───────────────────────────────────────────────────────
  // Drawn after every scene so it always sits on top.
  // The snapshot fades out while the new scene plays live underneath.
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
      blendMode(BLEND);  // snapshot must use normal alpha blend, not the scene's blend mode
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


