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

BezierHeart bezier_heart_0;
BezierHeart bezier_heart_1;
BezierHeart bezier_heart_2;
BezierHeart bezier_heart_3;

ArrayList<BezierHeart> bezier_hearts;

DashedLines dash;
float dash_dist;

PImage h3_emblem;
PImage new_h3_emblem;
int x;
int y;
int i;

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

  void drawBezierHeart(float xHeartOffset, float yHeartOffset) {
      pushMatrix();
        scale(0.75);
        translate(0 + xHeartOffset, 0 + yHeartOffset);

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

void setSongToVisualize() {
  log_to_stdo("Current song: " + config.SONG_TO_VISUALIZE);
  selectInput("Select song to visualize", "fileSelected");
  while (config.SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  config.STATE = 1;
  log_to_stdo("SONG TO VISUALIZE: " + config.SONG_TO_VISUALIZE);
  config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
}

String fileSelected(File selection) {
  if (selection == null) {
    log_to_stdo("No file selected. Window might have been closed/cancelled");
    return "";
  } else {
    log_to_stdo("File selected: " + selection.getAbsolutePath());
    config.SONG_TO_VISUALIZE = selection.getAbsolutePath();
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

void setup() {
  size(1200, 1200, P3D);
  background(200);
  config = new Config();
  config.LOGGING_ENABLED = true;
  log_to_stdo("canvas spawned");
  initializeGlobals();
  setSongToVisualize();
  surface.setResizable(true);
  smooth(2);
  frameRate(160);
  surface.setTitle(config.TITLE_BAR);
  setupController();
  loadSongToVisualize();
  tunnel = new Tunnel();
  plasma = new Plasma();
  polarPlasma = new PolarPlasma();
}

void drawDiamond(float dash_distanceFromCenter) {
  float innerDiamondCoordinate = ((width/2) + config.DIAMOND_DISTANCE_FROM_CENTER % (height * 0.57) );
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];
  strokeWeight(5);
  strokeCap(SQUARE);
  dash.quad(
    innerDiamondCoordinate, innerDiamondCoordinate,
    config.DIAMOND_RIGHT_EDGE_X + config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_RIGHT_EDGE_Y + config.DIAMOND_HEIGHT_OFFSET,
    width, height,
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
    translate(-width, 0);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
  
   pushMatrix();
    fill(0,0,0);
    scale(-0.5,-0.5);
    translate(-width, -height);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
  
  pushMatrix();
    fill(0,0,0);
    scale(0.5,-0.5);
    translate(0, -height);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}

void drawDiamonds() {
  pushMatrix();
    fill(255, 76, 52);
    scale(-1,1);
    translate(-width, 0);
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
    translate(-width, -height);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
    
  pushMatrix();
    fill(255, 76, 52);
    scale(1,-1);
    translate(0, -height);
    drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}

void drawInnerCircle() {
  ellipseMode(RADIUS);
  stroke(204, 39, 242);
  strokeWeight(8);
  noFill();
  h.ellipse(width/2.0, height/2.0, 110, 110);
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
      translate(width/2, height/2);
      scale(1.75);
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

void keyPressed() {
  if (key == 'b' || key == 'B') {
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
  if (key == 's' || key == 's') {
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
  if (key == 'r') {
    config.DIAMOND_RIGHT_EDGE_X += 20;
    config.DIAMOND_LEFT_EDGE_X -= 20;
  }
  if (key == 'R') {
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
  if (key == 'i' || key == 'I') {
    config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }
  if (key >= '0' && key <= '9') {
    log_to_stdo("key:" + (int) key);
    config.STATE = (int) key - 48;
    log_to_stdo("STATE: " + config.STATE);
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

  if (controller.b_button) {
    changeBlendMode();
  }

  if (controller.a_button) {
    cycleHandDrawn();
  }

  if (controller.y_button) {
    changeFinRotation();
  }

  if (controller.x_button) {
    config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
  }
  
  if (controller.back_button) {
    stopSong();
  }
   
  if (controller.start_button) {
    startSong();
  }
  
  if (controller.lb_button) {
    config.EPILEPSY_MODE_ON = !config.EPILEPSY_MODE_ON;
  }
  
  if (controller.rb_button) {
    config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }
  
  if (controller.lstickclick_button) {
    config.DRAW_DIAMONDS = !config.DRAW_DIAMONDS;
  }
    
  if (controller.rstickclick_button) {
    config.DRAW_FINS = !config.DRAW_FINS;
  }
}

void setBackGroundFillMode(){
    fill(#fbfafa); 
}

void draw() {
  switch(config.STATE){
    case 0:
      background(200);
      textSize(48);
      fill(0,255,0);
      text("RIP Sam", width/2, height/2);
      break;
   
   case 1:
    getUserInput(config.USING_CONTROLLER);
    stroke(0);
    noStroke();
  
    if(config.BACKGROUND_ENABLED) {
      background(200);
    }
  
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
          float x1 = map( i, 0, audio.player.bufferSize(), 0, width );
          float x2 = map( i+1, 0, audio.player.bufferSize(), 0, width );
      
          stroke(r_line, g_line, b_line);
          line( x1, height/2.0 + audio.player.right.get(i)*config.WAVE_MULTIPLIER, x2, height/2.0 + audio.player.right.get(i+1)*config.WAVE_MULTIPLIER );
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
            translate(0, height/2.0);
            drawInnerDiamonds();
          popMatrix();
       
          pushMatrix();
            translate(width/2.0, 0);
            drawInnerDiamonds();
          popMatrix();
          
          pushMatrix();
            translate(width/2.0, height/2.0);
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
    
    drawSongNameOnScreen(config.SONG_NAME, width/2, height-5);
  
    if (config.SCREEN_RECORDING) {
      saveFrame("/tmp/output/frames####.png");
    }
    
    float posx = map(audio.player.position(), 0, audio.player.length(), 0, width);
    pushStyle();
      stroke(252,4,243);
      line(posx, height, posx, (height * .975));
    popStyle();
    
    addFPSToTitleBar();
   break;
  case 2:
    background(0);
    
    for(int i = 0; i <= (height + 500); i+= 500) {
      for(int j = 0; j <= (height + 500); j+=500) {
        if ( (i % 1000 == 0) && (j % 500 == 0) ) {
          bezier_heart_0.drawBezierHeart(i, j);
        } else {
          bezier_heart_1.drawBezierHeart(i, j);
        }
      }
    }
    
    audio.beat.detect(audio.player.mix);
    if (audio.beat.isOnset() ){
      log_to_stdo("Beat onset detected");      
      config.HEART_PULSE = pulseValBetweenRange(config.HEART_PULSE, -100, 200);
      bezier_heart_0.BezierUpdateFillColor(config.HEART_PULSE);
      bezier_heart_1.BezierUpdateFillColor(config.HEART_PULSE * .60);
    }
    addFPSToTitleBar();
    break;
  }
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
  textSize(24);
  textAlign(CENTER);
  fill(0);
  
  text(song_name, nameLocationX + 2, nameLocationY + 2);
  
  fill(255);
  text(song_name, nameLocationX, nameLocationY);
}

void mouseClicked() {
  config.ANIMATED = !config.ANIMATED;
}