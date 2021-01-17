import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import ddf.minim.*; 
import ddf.minim.analysis.*; 
import org.gicentre.handy.*; 
import org.gamecontrolplus.gui.*; 
import org.gamecontrolplus.*; 
import net.java.games.input.*; 
import java.util.Map; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class Music_Visualizer_CK extends PApplet {

/*

Music Visualizer ♫ ♪♪

*/


// minim is used for music analysis, fast Fourier transform and beat detection



// handy is used for the alternative style where it looks "sketched".


// game control plus from Quark's place






Minim minim;
AudioPlayer player;
BeatDetect beat;
FFT fft;

// HANDY DRAWN STYLE ----------------------------------------
// Draw shapes like they are hand drawn (thanks to Handy)
HandyRenderer h, h1, h2;
HandyRenderer[] HANDY_RENDERERS;

int HANDY_RENDERERS_COUNT;

int MIN_HANDY_RENDERER_POSITION;
int MAX_HANDY_RENDERER_POSITION;
int CURRENT_HANDY_RENDERER_POSITION;
HandyRenderer CURRENT_HANDY_RENDERER;

boolean APPEAR_HAND_DRAWN;

// Toggle whether elements are drawn or not
boolean DRAW_DIAMONDS;
boolean DRAW_FINS;
boolean DRAW_WAVEFORM;

// FINS ------------------------------------------------------
boolean FIN_REDNESS_ANGRY;
boolean ANIMATED;

int LAST_FIN_CHECK; // last time fin was checked, to be changed
float FINS;
int FIN_REDNESS;

boolean canChangeFinDirection;
boolean finRotationClockWise;

float BEZIER_Y_OFFSET;
float MAX_BEZIER_Y_OFFSET;
float MIN_BEZIER_Y_OFFSET;

// WAVE FORM -------------------------------------------------
float WAVE_MULTIPLIER;


// DIAMONDS --------------------------------------------------
float DIAMOND_DISTANCE_FROM_CENTER;

boolean DIAMOND_CAN_CHANGE_CENTER_DISANCE;
boolean DIAMON_CAN_CHANGE_X_WIDTH;

// how far diamond width retracts/expands
float DIAMOND_WIDTH_OFFSET;
float DIAMOND_HEIGHT_OFFSET;

float DIAMOND_RIGHT_EDGE_X;
float DIAMOND_LEFT_EDGE_X;

float DIAMOND_RIGHT_EDGE_Y;
float DIAMOND_LEFT_EDGE_Y;

float MAX_DIAMOND_DISTANCE;
float MIN_DIAMOND_DISTANCE;

boolean INCREMENT_DIAMOND_DISTANCE;

// BLEND MODES -----------------------------------------------
int[] modes;

int CURRENT_BLEND_MODE_INDEX;

String[]modeNames;

// Background fill modes
boolean BACKGROUND_ENABLED;

// the number of bands per octave
int bandsPerOctave;

// Visualize song passed to, prog waits for this to be legit
String SONG_TO_VISUALIZE;

int STATE; // used to show loading screen

float GLOBAL_REDNESS;

boolean EPILEPSY_MODE_ON;

// SONG META DATA --------------------------------------------
boolean SONG_PLAYING;
String SONG_NAME;


/* Gamepadsetup thanks to http://www.lagers.org.uk/gamecontrol/index.html */
ControlIO control;
ControlDevice stick;

float lx, ly; // left joystick position
float rx, ry; // right joystick position

boolean a_button, b_button, x_button, y_button;

boolean USING_CONTROLLER;

// Logging ---------------------------------------------------
boolean LOGGING_ENABLED;

// Screen capture --------------------------------------------
boolean SCREEN_RECORDING;

// Operating System Platform Specific Setup
String OS_TYPE;

public void initializeGlobals() {
  log_to_stdo("initializeGlobals");

  // HANDY DRAWN STYLE ----------------------------------------
  HandyRenderer h, h1, h2;
  HANDY_RENDERERS = new HandyRenderer[3];
  
  HANDY_RENDERERS_COUNT = HANDY_RENDERERS.length;
  
  MIN_HANDY_RENDERER_POSITION = 0;
  MAX_HANDY_RENDERER_POSITION = HANDY_RENDERERS_COUNT -1;
  CURRENT_HANDY_RENDERER_POSITION = 0;
  HandyRenderer CURRENT_HANDY_RENDERER;
  
  APPEAR_HAND_DRAWN = true;
  
  // Toggle whether elements are drawn or not
  DRAW_DIAMONDS = true;
  DRAW_FINS = true;
  DRAW_WAVEFORM = true;
  
  // FINS ------------------------------------------------------
  FIN_REDNESS_ANGRY = true;
  ANIMATED = true;
  
  FINS = 8.0f;
  FIN_REDNESS = 1;
  
  canChangeFinDirection = true;
  finRotationClockWise = false;
  
  BEZIER_Y_OFFSET = -50;
  MAX_BEZIER_Y_OFFSET = 40;
  MIN_BEZIER_Y_OFFSET = -140;
  
  // WAVE FORM -------------------------------------------------
  WAVE_MULTIPLIER = 50.0f;
  
  
  // DIAMONDS --------------------------------------------------
  DIAMOND_DISTANCE_FROM_CENTER = width*0.07f;
  
  DIAMOND_CAN_CHANGE_CENTER_DISANCE = true;
  DIAMON_CAN_CHANGE_X_WIDTH = true;
  
  // how far diamond width retracts/expands
  DIAMOND_WIDTH_OFFSET = 0.0f;
  DIAMOND_HEIGHT_OFFSET = 0.0f;
  
  MAX_DIAMOND_DISTANCE = width * 0.3f; //0.57;
  MIN_DIAMOND_DISTANCE = height * 0.1f; //0.2;
  
  INCREMENT_DIAMOND_DISTANCE = true;
  
  modes = new int[]{
    BLEND, ADD, SUBTRACT, EXCLUSION,
    DIFFERENCE, MULTIPLY, SCREEN,
    REPLACE
  };
  
  CURRENT_BLEND_MODE_INDEX = 0;
  
  modeNames = new String[]{
    "BLEND", "ADD", "SUBTRACT", "EXCLUSION",
    "DIFFERENCE", "MULTIPLY", "SCREEN",
    "REPLACE"
  };
  
  // Background fill modes
  BACKGROUND_ENABLED = true;
  
  // the number of bands per octave
  bandsPerOctave = 4;
  
  // Visualize song passed to, prog waits for this to be legit
  SONG_TO_VISUALIZE = "";
  
  STATE = 0; // used to show loading screen
  
  GLOBAL_REDNESS = 0.0f;
  
  EPILEPSY_MODE_ON = false;
  
  // SONG META DATA --------------------------------------------
  SONG_PLAYING = false;
  SONG_NAME = "";
  
  
  /* Gamepad setup */
  USING_CONTROLLER = false;
  
  // Logging ---------------------------------------------------
  LOGGING_ENABLED = true;
  
  // Screen capture --------------------------------------------
  SCREEN_RECORDING = false;
}


public String fileSelected(File selection) {
  if (selection == null) {
    log_to_stdo("No file selected. Window might have been closed/cancelled");
    return "";
    
  } else {
    log_to_stdo("File selected: " + selection.getAbsolutePath());
    SONG_TO_VISUALIZE = selection.getAbsolutePath();
  }
  return selection.getAbsolutePath();
}

public String discoverOperatingSystem() {
  String os = System.getProperty("os.name");
  if (os.contains("Windows")) {
    return "win"; //<>//
  } else if (os.contains("Mac")) {
    return "mac";
  } else if (os.contains("Linux")) {
    return "linux";
  } else {
    return "other";
  }
}

public String getSongNameFromFilePath(String song_path, String os_type) {
  log_to_stdo("Getting song name from file path, where os_type is: " + os_type);
  
  String[] file_name_parts;
  
  if (os_type == "linux") {
    file_name_parts = split(song_path, "/");
  } else if (os_type == "win") {
    file_name_parts = split(song_path, "\\");
  } else { //<>//
    // default to Windows :fingers_crossed:
    file_name_parts = split(song_path, "\\");
  }
  SONG_NAME = file_name_parts[file_name_parts.length-1];
  log_to_stdo("SONG_NAME: " + SONG_NAME);
  
  return SONG_NAME;
}
  

public void setup() {
  // Entry point, run once
  
  // P3D runs faster than JAVA2D
  // https://forum.processing.org/beta/num_1115431708.html
  
  
  initializeGlobals();
  
  OS_TYPE = discoverOperatingSystem();

  // Visualizer only begins once a song has been selected
  selectInput("Select song to visualize", "fileSelected");

  while (SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  STATE = 1;
  
  log_to_stdo("SONG TO VISUALIZE: " + SONG_TO_VISUALIZE);
  SONG_NAME = getSongNameFromFilePath(SONG_TO_VISUALIZE, OS_TYPE);
  // Processing Tweak mode doesn't provide nice file paths. 
  // TODO: Investigate why it chokes on this.

  log_to_stdo("Initializing Handy Renderers");
  
  // render shapes like they are hand drawn
  h = HandyPresets.createWaterAndInk(this);
  h1 = HandyPresets.createMarker(this);
  h2 = new HandyRenderer(this);

  // TODO: There's gotta be a better way to init array of objects..
  HANDY_RENDERERS[0] = h;
  HANDY_RENDERERS[1] = h1;
  HANDY_RENDERERS[2] = h2;

  log_to_stdo("Count of Handy Renderers: " + HANDY_RENDERERS_COUNT);
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[CURRENT_HANDY_RENDERER_POSITION];



  control = ControlIO.getInstance(this);

  // Attempt to find a device that matches the configuration file
  stick = control.getMatchedDevice("joystick");
  if (stick != null) {
    USING_CONTROLLER = true;
  }
  log_to_stdo("USING CONTROLLER? " + USING_CONTROLLER);


  // Resizable allows Windows snap features (i.e. snap to right side of screen)
  surface.setResizable(true);

  
  frameRate(160);
  surface.setTitle("press[b,d,f,h,s,y,p,w,>,/] | [x,y,a,b] on controller");


  minim = new Minim(this); //<>// //<>//
  player = minim.loadFile(SONG_TO_VISUALIZE); //<>//

  player.loop(); //<>//
  SONG_PLAYING = true;
  beat = new BeatDetect();
  ellipseMode(CENTER);

  blendMode(BLEND);
 //<>//
  // an FFT needs to know how
  // long the audio buffers it will be analyzing are
  // and also needs to know
  // the sample rate of the audio it is analyzing
  fft = new FFT(player.bufferSize(), player.sampleRate());

  // calculate averages based on a miminum octave width of 22 Hz
  // split each octave into a number of bands
  fft.logAverages(22, bandsPerOctave);
   //<>//
  DIAMOND_RIGHT_EDGE_X = width*0.92f; //<>//
  DIAMOND_LEFT_EDGE_X = width*0.74f;
  
  DIAMOND_RIGHT_EDGE_Y = height*0.71f;
  DIAMOND_LEFT_EDGE_Y = height*0.92f;
  
  background(200);

}


public void drawDiamond(float distanceFromCenter) {
  /*
  Coordinate System

  x -------->
      0 1 2 3 4 5
  y  0
  |  1
  |  2
  v  3
     4
     5
  */

  float innerDiamondCoordinate = ((width/2) + DIAMOND_DISTANCE_FROM_CENTER % (height * 0.57f) );


  //log_to_stdo("CURRENT_HANDY_RENDERER_POSITION: " + CURRENT_HANDY_RENDERER_POSITION);
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[CURRENT_HANDY_RENDERER_POSITION];

  // bottom right diamond 
  CURRENT_HANDY_RENDERER.quad(
    innerDiamondCoordinate, innerDiamondCoordinate,
    DIAMOND_RIGHT_EDGE_X + DIAMOND_WIDTH_OFFSET, DIAMOND_RIGHT_EDGE_Y + DIAMOND_HEIGHT_OFFSET,
    width, height,
    DIAMOND_LEFT_EDGE_X - DIAMOND_WIDTH_OFFSET, DIAMOND_LEFT_EDGE_Y - DIAMOND_HEIGHT_OFFSET
  );
}

public void drawDiamonds() {
  // Diamonds are drawn by transforming the canvas

  // bottom left diamond
  pushMatrix();
    scale(-1,1);
    translate(-width, 0);
    drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  // top left diamond
  pushMatrix();
    scale(-1,-1);
    translate(-width, -height);
    drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();

  // top right diamond
  pushMatrix();
    scale(1,-1);
    translate(0, -height);
    drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}

public void drawInnerCircle() {
  // red inner circle, is used to make the fins look smooth internally
  ellipseMode(RADIUS);
  //stroke(FIN_REDNESS, 0, 0);
  stroke(204, 39, 242);

  strokeWeight(8);
  noFill();
  h.ellipse(width/2.0f, height/2.0f, 110, 110);
}

public void stop() {
  minim.stop();
  super.stop();
}

public void drawBezierFins(float redness, float fins, boolean finRotationClockWise) {
  //stroke(redness, 0, 0);
  stroke(7);

  strokeWeight(5);

  float xOffset = -20;
  float yOffset = -50;

  yOffset = BEZIER_Y_OFFSET;

  for (int i=0; i<fins; i++) {

    pushMatrix();

      float rotationAmount = (2 * (i / fins) * PI);
  
      if (finRotationClockWise == true) {
        rotationAmount = 0 - rotationAmount;
      }
  
      translate(width/2, height/2);       // shift focal drawing point to center for fins
      scale(1.75f);                        // scale up fins to handle larger screen sizes
      float random_noise_spin = random(0.01f, 0.99f);
      
      rotate( (radians(frameCount + random_noise_spin) / 2.0f) );  // pulse rotating of inner fins

      rotate(rotationAmount);
      
      if (APPEAR_HAND_DRAWN) {
        fill(247,9,143, 100);
      } else {
        noFill();
      }
      /*
      .
        .
          .
           .
            .
      */
      bezier(
        -36 + xOffset,-126 + yOffset,
        -36 + xOffset,-126 + yOffset,
        32 + xOffset,-118 + yOffset,
        68 + xOffset,-52 + yOffset
      );
  
      /*
        .
         .
         .
        .
      */
      bezier(
        -36 + xOffset,-126 + yOffset,
        -36 + xOffset,-126 + yOffset,
        -10 + xOffset,-88 + yOffset,
        -22 + xOffset,-52 + yOffset
      );
  
      /*
  
       ,......,
      .        .
      */
    bezier(
        -22 + xOffset,-52 + yOffset,
        -22 + xOffset,-52 + yOffset,
        20 + xOffset,-74 + yOffset,
        68 + xOffset,-52 + yOffset
      );
    popMatrix();
  }
}

public void applyBlendModeOnDrop(int intensityOutOfTen) {
  FIN_REDNESS_ANGRY = true;

  // To reduce eye sore, only change blend mode on RNG
  float randomNumber = random(1, 10);

  if (intensityOutOfTen > randomNumber) {
    log_to_stdo("Change blend mode if random number: " + randomNumber + " is less than intensity: " + intensityOutOfTen);
    changeBlendMode();
  }
}

public void changeBlendMode() {
  log_to_stdo("BlendMode before: " + modeNames[CURRENT_BLEND_MODE_INDEX]);

  if (CURRENT_BLEND_MODE_INDEX == modes.length - 1) {
    CURRENT_BLEND_MODE_INDEX = 0;
  } else {
    CURRENT_BLEND_MODE_INDEX += 1;
  }

  blendMode(CURRENT_BLEND_MODE_INDEX);
  log_to_stdo("Changed blendMode to: " + modeNames[CURRENT_BLEND_MODE_INDEX]);
}

public void changeFinRotation() {
  finRotationClockWise = !finRotationClockWise;

  // once it has been changed, wait cooldown before changing again
  canChangeFinDirection = false;
}

public void modifyDiamondCenterPoint(boolean closerToCenter) {
  if (closerToCenter) {
    DIAMOND_DISTANCE_FROM_CENTER = DIAMOND_DISTANCE_FROM_CENTER + (width * 0.02f);

  } else {
    DIAMOND_DISTANCE_FROM_CENTER = DIAMOND_DISTANCE_FROM_CENTER - (width * 0.02f);
  }
}

public void toggleHandDrawn(){
  APPEAR_HAND_DRAWN = !APPEAR_HAND_DRAWN;
  h.setIsHandy(APPEAR_HAND_DRAWN);
  //h3.setIsHandy(false);
}

public void toggleHandDrawn3(){
  APPEAR_HAND_DRAWN = !APPEAR_HAND_DRAWN;
  h.setIsHandy(APPEAR_HAND_DRAWN);
  //h.setIsHandy(false);
}


public void keyPressed() {
  // blend
  if (key == 'b' || key == 'B') {
    changeBlendMode();
  }
  
  // cycle between drawing styles
  if (key == 'h') {
    //toggleHandDrawn();
    log_to_stdo("MAX_HANDY_RENDERER_POSITION: " + MAX_HANDY_RENDERER_POSITION);
    CURRENT_HANDY_RENDERER_POSITION += 1;
    CURRENT_HANDY_RENDERER_POSITION = CURRENT_HANDY_RENDERER_POSITION % HANDY_RENDERERS_COUNT;
    //(CURRENT_HANDY_RENDERER_POSITION + 1) % HANDY_RENDERERS_COUNT;//MAX_HANDY_RENDERER_POSITION;
    log_to_stdo("CURRENT_HANDY_RENDERER_POSITION: " + CURRENT_HANDY_RENDERER_POSITION);
  }

  // toggle being hand-drawn or not
  if (key == 'H') {
    APPEAR_HAND_DRAWN = !APPEAR_HAND_DRAWN;
    CURRENT_HANDY_RENDERER.setIsHandy(APPEAR_HAND_DRAWN);
    //toggleHandDrawn3();
  }

  // fins
  if (key == 'f' || key == 'F') {
    changeFinRotation();
  }

  // diamonds
  if (key == 'd') {
    modifyDiamondCenterPoint(false);
  }
  if (key == 'D') {
    modifyDiamondCenterPoint(true);
  }


  // record screen as pictures
  if (key == 'r' || key == 'R') {
    SCREEN_RECORDING = !SCREEN_RECORDING;
  }

  // pause/play
  if (key == 'p' || key == 'P') {
    if (SONG_PLAYING) {
      player.pause();
    } else {
      player.play();
    }
    SONG_PLAYING = !SONG_PLAYING;
  }

  // logging / debug
  if (key == 'l' || key == 'L') {
    LOGGING_ENABLED = !LOGGING_ENABLED;
  }

  // change bezier y offset
  if (key == 'y') {
    BEZIER_Y_OFFSET -= 10;
  }
  if (key == 'Y') {
    BEZIER_Y_OFFSET += 10;
  }
  
  if (key == 'r') {
    DIAMOND_RIGHT_EDGE_X += 20;
    DIAMOND_LEFT_EDGE_X -= 20;
  }
  
  if (key == 'R') {
    DIAMOND_RIGHT_EDGE_X -= 20;
    DIAMOND_LEFT_EDGE_X += 20;
  }
  
  if (key == 'c') {
    DIAMOND_RIGHT_EDGE_Y += 20;
    DIAMOND_LEFT_EDGE_Y -= 20;
  }
  
  if (key == 'C') {
    DIAMOND_RIGHT_EDGE_Y -= 20;
    DIAMOND_LEFT_EDGE_Y += 20;
  }
  
  // toggle background redrawing fresh every frame, 
  // looks great when off and EPILEPSY_MODE_ON is on
  if (key == 'g' || key == 'G') {
    BACKGROUND_ENABLED = !BACKGROUND_ENABLED;
  }

  if (key == 's' || key == 'S') {
    EPILEPSY_MODE_ON = !EPILEPSY_MODE_ON;
  }
  
  // toggle drawing diamonds
  if (key == '<' || key == '>') {
    DRAW_DIAMONDS = !DRAW_DIAMONDS;
  }
  
  // toggle drawing waveform 
  if (key == 'w' || key == 'W') {
    DRAW_WAVEFORM = !DRAW_WAVEFORM;
  }
  
  // toggle drawing fins
  if (key == '/') {
    DRAW_FINS = !DRAW_FINS;
  }
  
  // TODO: Open new song on pressing open keyboard shortcut
  if (key == 'o' || key == 'O') {
    reset();
  } 

  // exit nicely
  if (key == 'x' || key == 'X') {
    minim.stop();
    exit();
  }

  // quit
  if (key == 'q' || key == 'Q') {
    exit();
  }
}

public void reset(){
  minim.stop();
  initializeGlobals();
  frameCount = -1;
}

public void log_to_stdo(String message_to_log) {
  // we use this logging wrapper to be able to toggle logging off/now in real time with 'l' keyboard shortcut
  if (LOGGING_ENABLED) {
    println(message_to_log);
  }
}

public void splitFrequencyIntoLogBands() {
  fft.avgSize();

  for(int i = 0; i < fft.avgSize(); i++ ){
    // get amplitude of frequency band
    float amplitude = fft.getAvg(i);

    // convert the amplitude to a DB value.
    // this means values will range roughly from 0 for the loudest
    // bands to some negative value.
    float bandDB = 20 * log(2 * amplitude / fft.timeSize());


    //log_to_stdo("i: " + i);
    //log_to_stdo("bandDB: " + bandDB);

    //log_to_stdo("BlendMode: " + modeNames[CURRENT_BLEND_MODE_INDEX]);


    if ((i >= 0 && i <= 5) && bandDB > -10) {
      // bass
      //changeBlendMode();
      applyBlendModeOnDrop(3);
    }

    if ((i >=6 && i<= 15) && bandDB >-27) {
      // mids
      modifyDiamondCenterPoint(INCREMENT_DIAMOND_DISTANCE);
    }

    if (canChangeFinDirection == true) {
      if ((i >=16 && i <= 35) && bandDB > -150) {
        // highs
        changeFinRotation();
      }
    }
  }
}

// Poll for user input called from the draw() method.
public void getUserInput(boolean usingController) {

  if (!usingController) {
    return ;
  }

  /* joy sticks */
  lx = map(stick.getSlider("lx").getValue(), -1, 1, 0, width);
  ly = map(stick.getSlider("ly").getValue(), -1, 1, 0, height);

  rx = map(stick.getSlider("rx").getValue(), -1, 1, 0, width);
  ry = map(stick.getSlider("ry").getValue(), -1, 1, 0, height);


  BEZIER_Y_OFFSET = (ly - (height/2)) - 12; // % (height / 2);
  //log_to_stdo("BEZIER Y OFFSET: " + BEZIER_Y_OFFSET);

  WAVE_MULTIPLIER = (ry % (height/5)) + 25;
  //log_to_stdo("WAVE MULTIPLIER: " + WAVE_MULTIPLIER);
  
  // where rx the right joystick x axis position between (0, 1200)
  DIAMOND_WIDTH_OFFSET = ((rx - (height/10)) / 5.0f) - 80;
  //log_to_stdo("DIAMOND_WIDTH_OFFSET: " + DIAMOND_WIDTH_OFFSET);
  
  DIAMOND_HEIGHT_OFFSET = ((ry - (height/10)) / 5.0f) - 80;
  //log_to_stdo("DIAMOND_HEIGHT_OFFSET: " + DIAMOND_HEIGHT_OFFSET);
  

  //log_to_stdo("controller left stick:\t lx: " + lx + ", ly " + ly);
  //log_to_stdo("controller right stick:\t rx: " + rx + ", ry " + ry);


  /* buttons */
  a_button = stick.getButton("a").pressed();
  b_button = stick.getButton("b").pressed();
  x_button = stick.getButton("x").pressed();
  y_button = stick.getButton("y").pressed();

  /*
  log_to_stdo("a button pressed: " + a_button);
  log_to_stdo("b button pressed: " + b_button);
  log_to_stdo("x button pressed: " + x_button);
  log_to_stdo("y button pressed: " + y_button);
  */

  if (b_button) {
    changeBlendMode();
  }

  if (a_button) {
    CURRENT_HANDY_RENDERER_POSITION = (CURRENT_HANDY_RENDERER_POSITION + 1) % MAX_HANDY_RENDERER_POSITION;
  }

  if (y_button) {
    changeFinRotation();
  }

  if (x_button) {
    //EPILEPSY_MODE_ON = !EPILEPSY_MODE_ON;
    BACKGROUND_ENABLED = !BACKGROUND_ENABLED;
  }

   /*
  if (y_button) {
    // change bezier y offset
    if (key == 'y') {
      BEZIER_Y_OFFSET -= 10;
    }
    if (key == 'Y') {
      BEZIER_Y_OFFSET += 10;
    }
  */

}

public void setBackGroundFillMode(){
    fill(0xfffbfafa); 
}


public void draw() {
  if (STATE == 0) {
    // show loading screen
    background(200);

    textSize(48);
    fill(0,255,0);
    text("RIP Sam", width/2, height/2);
  }

  getUserInput(USING_CONTROLLER); // Polling

  // reset drawing params when redrawing frame
  stroke(0);
  noStroke();

  if(BACKGROUND_ENABLED) {
    background(200);
  }

  if (!EPILEPSY_MODE_ON) {
    h.setSeed(117);
    h1.setSeed(322);
    h2.setSeed(420);
  }

  // first perform a forward fft on one of song's mix buffers
  fft.forward(player.mix);

  stroke(216, 16, 246, 128);
  strokeWeight(8);

  // only change fin direction, if it has been more than 10s since last it was changed.
  // otherwise eyes might hurt o_O

  int msSinceProgStart = millis();
  if (msSinceProgStart > LAST_FIN_CHECK + 10000) {
    canChangeFinDirection = true;
    LAST_FIN_CHECK = millis();
  }
  //log_to_stdo("Can change fin direction: " + canChangeFinDirection);

  splitFrequencyIntoLogBands();

  //log_to_stdo("MAX specSize: " + fft.specSize());
  int blendModeIntensity = 5;

  /*
  for(int i = 0; i < fft.specSize(); i++)
  {
    line(i, height, i, height - fft.getBand(i)*4);
    if (fft.getBand(i)*4 > 1000.0) {
      //applyBlendModeOnDrop(blendModeIntensity);
    }

  }
  */
  strokeWeight(2);

  stroke(255);
  float r_line = (frameCount % 255) / 10;
  float g_line = (frameCount % 255) - 75;
  float b_line = (frameCount % 255);
  

  if (DRAW_WAVEFORM) {
    // draw the waveforms
    // the values returned by left.get() and right.get() will be between -1 and 1,
    // so we need to scale them up to see the waveform
    // note that if the file is MONO, left.get() and right.get() will return the same value
    for(int i = 0; i < player.bufferSize() - 1; i++)
    {
      float x1 = map( i, 0, player.bufferSize(), 0, width );
      float x2 = map( i+1, 0, player.bufferSize(), 0, width );
  
      stroke(r_line, g_line, b_line);
      line( x1, height/2.0f + player.right.get(i)*WAVE_MULTIPLIER, x2, height/2.0f + player.right.get(i+1)*WAVE_MULTIPLIER );
      //CURRENT_HANDY_RENDERER.line( x1, height/2.0 + player.right.get(i)*WAVE_MULTIPLIER, x2, height/2.0 + player.right.get(i+1)*WAVE_MULTIPLIER );
  
    }
  }
  stroke(255);

  // draw a line to show where in the player playback is currently located
  // located at the bottom of the output screen
  // uses custom style, so doesn't alter other strokes
  float posx = map(player.position(), 0, player.length(), 0, width);
  pushStyle();
    stroke(252,4,243);
    line(posx, height, posx, (height * .975f));
  popStyle();

  // DIAMONDS

  // check if should be incrementing  distance from center
  if (DIAMOND_DISTANCE_FROM_CENTER >= MAX_DIAMOND_DISTANCE) {
    log_to_stdo("Too far from center.\nDistance from center: " + DIAMOND_DISTANCE_FROM_CENTER);
    log_to_stdo("Max Diamond Distance: " + MAX_DIAMOND_DISTANCE);
    INCREMENT_DIAMOND_DISTANCE = false;

  } else if (DIAMOND_DISTANCE_FROM_CENTER <= MIN_DIAMOND_DISTANCE) {
    INCREMENT_DIAMOND_DISTANCE = true;
  }


  //log_to_stdo("APPEAR_HAND_DRAWN: " + APPEAR_HAND_DRAWN);
  if (APPEAR_HAND_DRAWN) {
    fill(255, 76, 52);
    //background(50, 25, 200);
  } else {
    fill(255);
    background(200);
  }

  if (DRAW_DIAMONDS) {
    // bottom right diamond
    drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  
    // draw rest of diamonds, by rotating canvas
    drawDiamonds();
  }
  
  noFill();

  // redness of fins, goes upto RED then back to BLACK
  if (FIN_REDNESS >= 255) {
    FIN_REDNESS_ANGRY = false;

  } else if (FIN_REDNESS <= 0) {
    FIN_REDNESS_ANGRY = true;
  }

  // calm fins down for now
  
  if (ANIMATED) {
    if (FIN_REDNESS_ANGRY) {
      FIN_REDNESS += 1;
      FINS += 0.02f;
    } else {
      FIN_REDNESS -= 1;
      FINS -= 0.02f;
    }
  }
  
  // red circle, of which the bezier shapes touch
  //drawInnerCircle();
  
  
  if (DRAW_FINS) {
      drawBezierFins(FIN_REDNESS, FINS, finRotationClockWise);
  }
  
  //rotate(radians(rot));
  drawSongNameOnScreen(SONG_NAME, width/2, height-5);

  if (SCREEN_RECORDING) {
    saveFrame("/tmp/output/frames####.png");
  }
  
  // only update fps counter in title a sane amount of times to maintain performance
  if (frameCount % 100 == 0) {
    //log_to_stdo("frameRate: " + frameRate);
    surface.setTitle("press[b,d,f,h,s,y,p,w,>,/] | [x,y,a,b] on controller | fps: " + PApplet.parseInt(frameRate));
 }

 
 //log_to_stdo("Current blendMode: " + modeNames[CURRENT_BLEND_MODE_INDEX]);

}

public void drawSongNameOnScreen(String song_name, float nameLocationX, float nameLocationY) {
  textSize(24);
  textAlign(CENTER);
  text(song_name, nameLocationX, nameLocationY);
}

public void mouseClicked() {
  // toggles fin animated state on mouse click
  ANIMATED = !ANIMATED;
}
  public void settings() {  size(1200, 1200, P3D);  smooth(4); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "Music_Visualizer_CK" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
