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
PFont monoFont;

BezierHeart bezier_heart_0;
BezierHeart bezier_heart_1;
BezierHeart bezier_heart_2;
BezierHeart bezier_heart_3;
ArrayList<BezierHeart> bezier_hearts;

DashedLines dash;
float dash_dist;

// Scene 1 is designed as a square. On widescreen we render it into a
// centered square of side s1Size and leave the sides as plain background.
int   s1Size    = 1200;
float s1OffsetX = 0;

float heartBeatDecay   = 0;    // beat impulse, decays to 0 between beats
float heartHue         = 0;    // current hue (0–360), smoothly lerped
float heartTargetHue   = 0;    // hue we're drifting toward

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

class BezierHeart {
  float bezier_angle, bezier_speed, bezier_range;

  float bezier_heart_l_x1, bezier_heart_l_y1;
  float bezier_heart_l_x2, bezier_heart_l_y2;
  float bezier_heart_l_x3, bezier_heart_l_y3;
  float bezier_heart_l_x4, bezier_heart_l_y4;

  float bezier_heart_r_x1, bezier_heart_r_y1;
  float bezier_heart_r_x2, bezier_heart_r_y2;
  float bezier_heart_r_x3, bezier_heart_r_y3;
  float bezier_heart_r_x4, bezier_heart_r_y4;

  float bezier_heart_fill_color_r = random(255);
  float bezier_heart_fill_color_g = 100.0;
  float bezier_heart_fill_color_b = random(255);


  BezierHeart (float b_angle, float b_speed, float b_range) {
    bezier_angle = b_angle;
    bezier_speed = b_speed;
    bezier_range = b_range;

    bezier_heart_l_x1 = 0;  bezier_heart_l_y1 = 562;
    bezier_heart_l_x2 = -443;    bezier_heart_l_y2 = 88;
    bezier_heart_l_x3 = -70;  bezier_heart_l_y3 = 0;
    bezier_heart_l_x4 = 0;  bezier_heart_l_y4 = 178;

    bezier_heart_r_x1 = 0;  bezier_heart_r_y1 = 562;
    bezier_heart_r_x2 = 388;  bezier_heart_r_y2 = 58;
    bezier_heart_r_x3 = 17;  bezier_heart_r_y3 = 0;
    bezier_heart_r_x4 = 0;  bezier_heart_r_y4 = 178;
  }

  void BezierUpdateAngle () {
    bezier_angle += bezier_speed;
  }

  void BezierUpdateFillColor (float new_heart_color_g) {
    bezier_heart_fill_color_g = new_heart_color_g;
  }

  // Scale-aware overload — s replaces the hardcoded 0.75.
  // xOffset / yOffset are in natural (unscaled) heart coordinates.
  void drawBezierHeart(float xHeartOffset, float yHeartOffset, float s) {
      pushMatrix();
        scale(s);
        translate(xHeartOffset, yHeartOffset);

        fill(bezier_heart_fill_color_r, bezier_heart_fill_color_g, bezier_heart_fill_color_b);
        stroke(255, 1, 1);
        strokeWeight(1.0);

        bezier(
          bezier_heart_l_x1,                        bezier_heart_l_y1,
          bezier_heart_l_x2 - (config.HEART_PULSE),        bezier_heart_l_y2,
          bezier_heart_l_x3 - (config.HEART_PULSE / 2.0),  bezier_heart_l_y3,
          bezier_heart_l_x4,                        bezier_heart_l_y4
        );
        bezier(
          bezier_heart_r_x1,                        bezier_heart_r_y1,
          bezier_heart_r_x2 + (config.HEART_PULSE),        bezier_heart_r_y2,
          bezier_heart_r_x3 + (config.HEART_PULSE / 2.0),  bezier_heart_r_y3,
          bezier_heart_r_x4,                        bezier_heart_r_y4
        );
      popMatrix();
  }

}

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
  }
  log_to_stdo("USING CONTROLLER? " + config.USING_CONTROLLER);
}

void initializeGlobals() {
  log_to_stdo("initializeGlobals");

  config = new Config();

  ellipseMode(CENTER);
  blendMode(BLEND);

  bezier_heart_0 = new BezierHeart(0.0, 0.25, 300);
  bezier_heart_1 = new BezierHeart(0.0, 0.25, 300);
  bezier_heart_2 = new BezierHeart(0.0, 0.25, 300);
  bezier_heart_3 = new BezierHeart(0.0, 0.25, 300);

  bezier_hearts = new ArrayList<BezierHeart>();
  bezier_hearts.add(bezier_heart_0);

  dash = new DashedLines(this);
  dash.pattern(130, 110);
  dash_dist = 0;

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
  s1Size    = min(width, height);
  s1OffsetX = (width - s1Size) / 2.0;
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
  monoFont = createFont("Monospaced", 15, true);
  // load Halo 3 emblem used as reference for colors and texture
  h3_emblem = loadImage("../media/h3_emblem.jpg");
}

void drawDiamond(float dash_distanceFromCenter) {
  float innerXY = s1Size / 2.0 + config.DIAMOND_DISTANCE_FROM_CENTER;
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];
  strokeWeight(5);
  strokeCap(SQUARE);
  dash.quad(
    innerXY, innerXY,
    config.DIAMOND_RIGHT_EDGE_X + config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_RIGHT_EDGE_Y + config.DIAMOND_HEIGHT_OFFSET,
    s1Size, s1Size,
    config.DIAMOND_LEFT_EDGE_X - config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_LEFT_EDGE_Y - config.DIAMOND_HEIGHT_OFFSET
  );
}

void drawInnerDiamonds() {
  pushMatrix();
    fill(0,0,0);
    scale(0.5, 0.5);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(0,0,0);
    scale(-0.5, 0.5);
    translate(-s1Size, 0);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(0,0,0);
    scale(-0.5,-0.5);
    translate(-s1Size, -s1Size);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(0,0,0);
    scale(0.5,-0.5);
    translate(0, -s1Size);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}

void drawDiamonds() {
  pushMatrix();
    fill(255, 76, 52);
    scale(-1,1);
    translate(-s1Size, 0);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(255, 76, 52);
    scale(1, 1);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(255, 76, 52);
    scale(-1,-1);
    translate(-s1Size, -s1Size);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  pushMatrix();
    fill(255, 76, 52);
    scale(1,-1);
    translate(0, -s1Size);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}

void drawInnerCircle() {
  ellipseMode(RADIUS);
  stroke(204, 39, 242);
  strokeWeight(8);
  noFill();
  h.ellipse(s1Size/2.0, s1Size/2.0, 110, 110);
}

void stop() {
  audio.stop();
  super.stop();
}

void drawBezierFins(float redness, float fins, boolean finRotationClockWise) {
  stroke(7);
  strokeWeight(5);
  float xOffset = -20;
  float yOffset = -50;
  yOffset = config.BEZIER_Y_OFFSET;
  for (int i=0; i<fins; i++) {
    pushMatrix();
      float rotationAmount = (2 * (i / fins) * PI);
      if (finRotationClockWise == true) {
        rotationAmount = 0 - rotationAmount;
      }
      translate(s1Size/2.0, s1Size/2.0);
      scale(1.75 * uiScale());
      float random_noise_spin = random(0.01, 0.99);
      rotate( (radians(frameCount + random_noise_spin) / 2.0) );
      rotate(rotationAmount);
      if (config.APPEAR_HAND_DRAWN) {
        fill(247,9,143, 100);
      } else {
        noFill();
      }
      bezier(
        -36 + xOffset,-126 + yOffset,
        -36 + xOffset,-126 + yOffset,
        32 + xOffset,-118 + yOffset,
        68 + xOffset,-52 + yOffset
      );
      bezier(
        -36 + xOffset,-126 + yOffset,
        -36 + xOffset,-126 + yOffset,
        -10 + xOffset,-88 + yOffset,
        -22 + xOffset,-52 + yOffset
      );
    bezier(
        -22 + xOffset,-52 + yOffset,
        -22 + xOffset,-52 + yOffset,
        20 + xOffset,-74 + yOffset,
        68 + xOffset,-52 + yOffset
      );
    popMatrix();
  }
}

void applyBlendModeOnDrop(int intensityOutOfTen) {
  config.FIN_REDNESS_ANGRY = true;
  float randomNumber = random(1, 10);
  if (intensityOutOfTen > randomNumber) {
    changeBlendMode();
  }
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

void modifyDiamondCenterPoint(boolean closerToCenter) {
  if (closerToCenter) {
    config.DIAMOND_DISTANCE_FROM_CENTER = config.DIAMOND_DISTANCE_FROM_CENTER + (width * 0.02);
  } else {
    config.DIAMOND_DISTANCE_FROM_CENTER = config.DIAMOND_DISTANCE_FROM_CENTER - (width * 0.02);
  }
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
  if ((key == 'b' || key == 'B') && config.STATE != 9) {
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
  if (key == 'd') {
    modifyDiamondCenterPoint(false);
  }
  if (key == 'D') {
    modifyDiamondCenterPoint(true);
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
  if (key == 'g' || key == 'G') {
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
  if (key >= '0' && key <= '9') {
    int newState = (int) key - 48;
    log_to_stdo("Switching to state: " + newState);
    switchScene(newState);
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

void changeDashedLineSpeed(float amountToChange) {
  if (config.DASH_LINE_SPEED > config.DASH_LINE_SPEED_LIMIT) {
    config.DASH_LINE_SPEED_INCREASING = false;
  } else if (config.DASH_LINE_SPEED < -config.DASH_LINE_SPEED_LIMIT) {
    config.DASH_LINE_SPEED_INCREASING = true;
  }
  
  config.DASH_LINE_SPEED = config.DASH_LINE_SPEED_INCREASING ? config.DASH_LINE_SPEED + amountToChange: config.DASH_LINE_SPEED - amountToChange;
}

void splitFrequencyIntoLogBands() {
  audio.fft.avgSize();

  for(int i = 0; i < audio.fft.avgSize(); i++ ){
    float amplitude = audio.fft.getAvg(i);
    float bandDB = 20 * log(2 * amplitude / audio.fft.timeSize());

    if ((i >= 0 && i <= 5) && bandDB > -10) {
      applyBlendModeOnDrop(3);
      changeDashedLineSpeed(0.2);
    }

    if ((i >=6 && i<= 15) && bandDB >-27) {
      modifyDiamondCenterPoint(config.INCREMENT_DIAMOND_DISTANCE);
    }

    if (config.canChangeFinDirection == true) {
      if ((i >=16 && i <= 35) && bandDB > -150) {
        changeFinRotation();
      }
    }
    
    if ((i >=35 && i<=36) && bandDB > -130) {
      changePlasmaFlow(1);
      changeDashedLineSpeed(0.1);
    }
  
    if ((i >=40 && i<=41) && bandDB > -130) {
      config.PLASMA_INCREMENTING = !config.PLASMA_INCREMENTING;
    }
  }
}

void changePlasmaFlow(int amountToChange){
    if (random(0, 10) > 6) {
      if (config.canChangePlasmaFlow) {
        if(config.PLASMA_INCREMENTING) {
            config.PLASMA_SEED = (config.PLASMA_SEED + abs(amountToChange))  % (config.PLASMA_SIZE/2 -1);
        } else {
            config.PLASMA_SEED = (config.PLASMA_SEED - amountToChange)  % (config.PLASMA_SIZE/2 -1);
        }
      }
    }
}

public void getUserInput(boolean usingController) {

  if (!usingController) {
    return ;
  }

  controller.read();

  config.BEZIER_Y_OFFSET = (controller.ly - (height/2)) - 12;
  config.WAVE_MULTIPLIER = (controller.ry % (height/5)) + 25;
  config.DIAMOND_WIDTH_OFFSET = ((controller.rx - (height/10)) / 5.0) - 80;
  config.DIAMOND_HEIGHT_OFFSET = ((controller.ry - (height/10)) / 5.0) - 80;
  
  float l_trigger_depletion = map(controller.stick.getSlider("lt").getValue(), -1, 1, -2, 6);
  int tunnel_zoom_amount_by_controller = int(l_trigger_depletion);
  config.TUNNEL_ZOOM_INCREMENT = config.TUNNEL_ZOOM_INCREMENT + tunnel_zoom_amount_by_controller;

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

  // oscilloscope live tuning via controller (only when on that scene)
  if (config.STATE == 5 && oscilloscope != null) {
    oscilloscope.applyController(controller);
  }

  // particle fountain controller input
  if (config.STATE == 8 && particleFountain != null) {
    particleFountain.applyController(controller);
    if (controller.a_just_pressed) particleFountain.triggerBurst();
    if (controller.b_just_pressed) particleFountain.long_trail = !particleFountain.long_trail;
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

  if (controller.b_just_pressed) {
    changeBlendMode();
  }

  if (controller.a_just_pressed) {
    cycleHandDrawn();
  }

  if (controller.y_just_pressed) {
    changeFinRotation();
  }

  if (controller.x_just_pressed) {
    config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
  }

  if (controller.back_just_pressed) {
    stopSong();
  }

  if (controller.start_just_pressed) {
    startSong();
  }

  if (controller.lb_just_pressed) {
    config.EPILEPSY_MODE_ON = !config.EPILEPSY_MODE_ON;
  }

  if (controller.rb_just_pressed) {
    config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }

  if (controller.lstickclick_just_pressed) {
    config.DRAW_DIAMONDS = !config.DRAW_DIAMONDS;
  }

  if (controller.rstickclick_just_pressed) {
    config.DRAW_FINS = !config.DRAW_FINS;
  }
}

void setBackGroundFillMode(){
    fill(#fbfafa); 
}

int previous_state = -1;

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

  // clear canvas on first frame of a scene switch so previous scene doesn't bleed through
  if (config.STATE != previous_state) {
    background(0);
    previous_state = config.STATE;
  }

  switch(config.STATE){
    case 0:
      background(200);
      textSize(48 * uiScale());
      fill(0,255,0);
      text("RIP Sam", width/2, height/2);
      break;
   
   case 1:
    getUserInput(config.USING_CONTROLLER);
    stroke(0);
    noStroke();

    // Full-screen background first (sides stay gray)
    if(config.BACKGROUND_ENABLED) {
      background(200);
    }

    // Constrain all art to the centered square
    clip((int)s1OffsetX, 0, s1Size, s1Size);
    pushMatrix();
    translate(s1OffsetX, 0);
  
    if (!config.EPILEPSY_MODE_ON) {
      h.setSeed(117);
      h1.setSeed(322);
      h2.setSeed(420);
    }
  
    audio.forward();
  
    stroke(216, 16, 246, 128);
    strokeWeight(8);
  
    int msSinceProgStart = millis();
    if (msSinceProgStart > config.LAST_FIN_CHECK + 10000) {
      config.canChangeFinDirection = true;
      config.LAST_FIN_CHECK = millis();
    }
  
    if (msSinceProgStart > config.LAST_PLASMA_CHECK + 10000) {
      config.canChangePlasmaFlow = true;
      config.PLASMA_INCREMENTING = !config.PLASMA_INCREMENTING;
      config.LAST_PLASMA_CHECK = millis();
    }
  
    splitFrequencyIntoLogBands();
  
    strokeWeight(2);
  
    stroke(255);
    float r_line = (frameCount % 255) / 10;
    float g_line = (frameCount % 255) - 75;
    float b_line = (frameCount % 255);
    
    audio.beat.detect(audio.player.mix);
    if (audio.beat.isOnset() ){
      log_to_stdo("Beat onset detected");
      config.TUNNEL_ZOOM_INCREMENT = (config.TUNNEL_ZOOM_INCREMENT + 3) % 10000;
    }
    
    stroke(255);
  
    if (config.DIAMOND_DISTANCE_FROM_CENTER >= config.MAX_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = false;
    } else if (config.DIAMOND_DISTANCE_FROM_CENTER <= config.MIN_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = true;
    }
  
    if (config.APPEAR_HAND_DRAWN) {
      fill(255, 76, 52);
    } else {
      fill(255);
      background(200);
    }
    
    if (config.DRAW_TUNNEL) {
      tunnel.draw(config.TUNNEL_ZOOM_INCREMENT);
    }
    
    if (config.DRAW_PLASMA) {
      plasma.draw(config.PLASMA_SEED);
    }
    
    if (config.DRAW_POLAR_PLASMA) {
      polarPlasma.draw();
    }
    
     if (config.DRAW_WAVEFORM) {
      pushStyle();
        strokeWeight(4);
        strokeCap(ROUND);
        for(int i = 0; i < audio.player.bufferSize() - 1; i++) {
          float x1 = map( i, 0, audio.player.bufferSize(), 0, s1Size );
          float x2 = map( i+1, 0, audio.player.bufferSize(), 0, s1Size );

          stroke(r_line, g_line, b_line);
          line( x1, s1Size/2.0 + audio.player.right.get(i)*config.WAVE_MULTIPLIER, x2, s1Size/2.0 + audio.player.right.get(i+1)*config.WAVE_MULTIPLIER );
        }
      popStyle();
    }
    strokeWeight(2);
  
    if (config.DRAW_DIAMONDS) {
      pushMatrix();
        drawDiamonds();
        if (config.DRAW_INNER_DIAMONDS) {
          pushMatrix();
            drawInnerDiamonds();
          popMatrix();
          
          pushMatrix();
            translate(0, s1Size/2.0);
            drawInnerDiamonds();
          popMatrix();

          pushMatrix();
            translate(s1Size/2.0, 0);
            drawInnerDiamonds();
          popMatrix();

          pushMatrix();
            translate(s1Size/2.0, s1Size/2.0);
            drawInnerDiamonds();
          popMatrix();
        }
        popMatrix();
    }
    
    noFill();
  
    if (config.FIN_REDNESS >= 255) {
      config.FIN_REDNESS_ANGRY = false;
    } else if (config.FIN_REDNESS <= 0) {
      config.FIN_REDNESS_ANGRY = true;
    }
  
    if (config.ANIMATED) {
      if (config.FIN_REDNESS_ANGRY) {
        config.FIN_REDNESS += 1;
        config.FINS += 0.02;
      } else {
        config.FIN_REDNESS -= 1;
        config.FINS -= 0.02;
      }
    }
    
    if (config.DRAW_FINS) {
        drawBezierFins(config.FIN_REDNESS, config.FINS, config.finRotationClockWise);
    }
    
    dash.offset(dash_dist);
    
    dash_dist = dash_dist + (.2 * config.DASH_LINE_SPEED);
    if (dash_dist >= 10000 || dash_dist <= -10000) {
      dash_dist = 0;
    }
    
    drawSongNameOnScreen(config.SONG_NAME, s1Size/2.0, s1Size-5);

    if (config.SCREEN_RECORDING) {
      saveFrame("/tmp/output/frames####.png");
    }

    float posx = map(audio.player.position(), 0, audio.player.length(), 0, s1Size);
    pushStyle();
      stroke(252,4,243);
      line(posx, s1Size, posx, s1Size * .975);
    popStyle();

    popMatrix();  // end square canvas translate
    noClip();

    addFPSToTitleBar();
   break;
  case 2:
    background(0);
    audio.forward();

    // Natural bounding box of one heart at scale=1:
    //   x: -443 (leftmost ctrl pt) to 388 (rightmost ctrl pt)  → width  = 831
    //   y:    0 (top)              to 562 (bottom tip)          → height = 562
    // We compute scale s so that exactly HEART_COLS hearts span the screen width.
    {
      final float HEART_NAT_W = 831.0;
      final float HEART_NAT_H = 562.0;
      float baseScale = width / (config.HEART_COLS * HEART_NAT_W);
      float cellH     = HEART_NAT_H;
      int   rows      = ceil(height / (cellH * baseScale)) + 1;

      audio.beat.detect(audio.player.mix);

      // Baseline breath: gentle sine wave so hearts always move subtly
      float breath = sin(frameCount * 0.03) * 12;

      // Beat impulse: snaps up on onset, decays back to 0
      if (audio.beat.isOnset()) {
        heartBeatDecay = 35.0;
        // Shift target hue by 60–120 degrees so colour changes are meaningful
        // but never jarring. Wrap-aware so we always go the short way around.
        heartTargetHue = (heartTargetHue + random(60, 120)) % 360;
      }
      heartBeatDecay *= 0.95;

      // Lerp heartHue toward target via the shortest arc
      float hueDiff = heartTargetHue - heartHue;
      if (hueDiff >  180) hueDiff -= 360;
      if (hueDiff < -180) hueDiff += 360;
      heartHue = (heartHue + hueDiff * 0.012 + 360) % 360;

      // Apply complementary colours: heart_1 is always 180° opposite heart_0
      colorMode(HSB, 360, 255, 255);
      color c0 = color(heartHue,              210, 220);
      color c1 = color((heartHue + 180) % 360, 210, 220);
      colorMode(RGB, 255);
      bezier_heart_0.bezier_heart_fill_color_r = red(c0);
      bezier_heart_0.bezier_heart_fill_color_g = green(c0);
      bezier_heart_0.bezier_heart_fill_color_b = blue(c0);
      bezier_heart_1.bezier_heart_fill_color_r = red(c1);
      bezier_heart_1.bezier_heart_fill_color_g = green(c1);
      bezier_heart_1.bezier_heart_fill_color_b = blue(c1);

      config.HEART_PULSE = breath + heartBeatDecay;

      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < config.HEART_COLS; col++) {
          float xOff = col * HEART_NAT_W + 443.0;
          float yOff = row * HEART_NAT_H;
          BezierHeart heart = ((row + col) % 2 == 0) ? bezier_heart_0 : bezier_heart_1;
          heart.drawBezierHeart(xOff, yOff, baseScale);
        }
      }
    }

    // HUD
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      fill(0, 140);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 230 * uiScale(), 8 + lh);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Hearts: " + config.HEART_COLS + " cols  ([ ] to adjust)", 12, 12);
    popStyle();

    addFPSToTitleBar();
    break;
  case 3:
    background(210);
    pushMatrix();
      shapes3D.drawScene();
    popMatrix();
    addFPSToTitleBar();
    break;
  case 4:
    background(0);
    catsCradle.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(catsCradle.getCodeLines());
    addFPSToTitleBar();
    break;
  case 5:
    audio.forward();
    oscilloscope.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(oscilloscope.getCodeLines());
    addFPSToTitleBar();
    break;
  case 8:
    getUserInput(config.USING_CONTROLLER);
    audio.forward();
    particleFountain.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(particleFountain.getCodeLines());
    addFPSToTitleBar();
    break;
  case 9:
    audio.forward();
    halo2Logo.drawScene();
    if (config.SHOW_CODE) drawCodeOverlay(halo2Logo.getCodeLines());
    addFPSToTitleBar();
    break;
  }

  // ── Crossfade overlay ───────────────────────────────────────────────────────
  // Drawn after every scene so it always sits on top.
  // The snapshot fades out while the new scene plays live underneath.
  if (crossfadeSnapshot != null) {
    crossfadeFrame++;

    // Beat-snap: if a beat lands when we're past the halfway point, finish early
    audio.beat.detect(audio.player.mix);
    if (audio.beat.isOnset() && crossfadeFrame > CROSSFADE_DURATION / 2) {
      crossfadeFrame = CROSSFADE_DURATION;
    }

    if (crossfadeFrame >= CROSSFADE_DURATION) {
      crossfadeSnapshot = null;
    } else {
      float alpha = map(crossfadeFrame, 0, CROSSFADE_DURATION, 255, 0);
      tint(255, alpha);
      image(crossfadeSnapshot, 0, 0);
      noTint();
    }
  }
}

// Draws a terminal-style code overlay showing the formulas a scene uses.
// Each scene passes in plain-English lines explaining its maths.
// Toggle with the backtick key (`).
void drawCodeOverlay(String[] lines) {
  pushStyle();
  textFont(monoFont);
  float lineH  = 20 * uiScale();
  float pad    = 16 * uiScale();
  float boxW   = width  * 0.55;
  float boxH   = pad * 2 + lines.length * lineH;
  float boxX   = (width  - boxW) / 2.0;
  float boxY   = (height - boxH) / 2.0;

  // dark terminal background
  fill(0, 0, 0, 210);
  noStroke();
  rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 6);

  // green border
  stroke(0, 220, 80, 180);
  strokeWeight(1.5);
  noFill();
  rect(boxX, boxY, boxW, boxH, 6);

  // text
  textAlign(LEFT, TOP);
  textSize(15 * uiScale());
  float tx = boxX + pad;
  float ty = boxY + pad;
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.startsWith("//")) {
      fill(120, 200, 120);   // comments → dim green
    } else if (line.startsWith("===")) {
      fill(0, 255, 120);     // title → bright green
    } else {
      fill(180, 255, 180);   // formula → light green
    }
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