/*

Music Visualizer ♫ ♪♪

Trivia:

Diamonds and circles intersect to form a Celtic Cross
*/


// minim is used for music analysis, fast Fourier transform and beat detection
import ddf.minim.*;
import ddf.minim.analysis.*;


// handy is used for the alternative style where it looks "sketched".
import org.gicentre.handy.*;

// game control plus from Quark's place
import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

import java.util.Map;


Minim minim;
AudioPlayer player;
BeatDetect beat;
FFT fft;

// GLOBALS

// HANDY DRAWN STYLE ----------------------------------------
// Draw shapes like they are hand drawn (thanks to Handy)
HandyRenderer h, h1, h2, h3, h4;
HandyRenderer[] HANDY_RENDERERS = new HandyRenderer[4];

int HANDY_RENDERERS_COUNT = HANDY_RENDERERS.length;

int MIN_HANDY_RENDERER_POSITION = 0;
int MAX_HANDY_RENDERER_POSITION = HANDY_RENDERERS_COUNT;
int CURRENT_HANDY_RENDERER_POSITION = 0;
HandyRenderer CURRENT_HANDY_RENDERER;

boolean APPEAR_HAND_DRAWN = true;

// Toggle whether elements are drawn or not
boolean DRAW_DIAMONDS = true;
boolean DRAW_FINS = true;
boolean DRAW_WAVEFORM = true;

// FINS ------------------------------------------------------
boolean FIN_REDNESS_ANGRY = true;
boolean ANIMATED = true;

int LAST_FIN_CHECK; // last time fin was checked, to be changed
float FINS = 8.0;
int FIN_REDNESS = 1;

boolean canChangeFinDirection = true;
boolean finRotationClockWise = false;

float BEZIER_Y_OFFSET = -50;
float MAX_BEZIER_Y_OFFSET = 40;
float MIN_BEZIER_Y_OFFSET = -140;

// WAVE FORM -------------------------------------------------
float WAVE_MULTIPLIER = 50.0;


// DIAMONDS --------------------------------------------------
float DIAMOND_DISTANCE_FROM_CENTER = width*0.07;

// how far diamond width retracts/expands
float DIAMOND_WIDTH_OFFSET = 0.0;
float DIAMOND_HEIGHT_OFFSET = 0.0;

float DIAMOND_RIGHT_EDGE_X;
float DIAMOND_LEFT_EDGE_X;

float DIAMOND_RIGHT_EDGE_Y;
float DIAMOND_LEFT_EDGE_Y;

float MAX_DIAMOND_DISTANCE = width * 0.57;
float MIN_DIAMOND_DISTANCE = height * 0.2;

boolean INCREMENT_DIAMOND_DISTANCE = true;

// BLEND MODES -----------------------------------------------
// TODO: Possible refactor into enums for Blend Modes?
int[] modes = new int[]{
  BLEND, ADD, SUBTRACT, EXCLUSION,
  DIFFERENCE, MULTIPLY, SCREEN,
  REPLACE
};

int CURRENT_BLEND_MODE_INDEX = 0;

String[] modeNames = new String[]{
  "BLEND", "ADD", "SUBTRACT", "EXCLUSION",
  "DIFFERENCE", "MULTIPLY", "SCREEN",
  "REPLACE"
};

// Background fill modes

boolean BACKGROUND_ENABLED = true;

// the number of bands per octave
int bandsPerOctave = 4;

// Visualize song passed to, prog waits for this to be legit
String SONG_TO_VISUALIZE = "";

int STATE = 0; // used to show loading screen

float GLOBAL_REDNESS = 0.0;

boolean EPILEPSY_MODE_ON = false;

// SONG META DATA --------------------------------------------
boolean SONG_PLAYING = false;
String SONG_NAME = "";


/* Gamepad setup thanks to http://www.lagers.org.uk/gamecontrol/index.html */
ControlIO control;
ControlDevice stick;

float lx, ly; // left joystick position
float rx, ry; // right joystick position

boolean a_button, b_button, x_button, y_button;

boolean USING_CONTROLLER = false;

// Logging ---------------------------------------------------
boolean LOGGING_ENABLED = true;

// Screen capture --------------------------------------------
boolean SCREEN_RECORDING = false;

// Operating System Platform Specific Setup
String OS_TYPE;


String fileSelected(File selection) {
  if (selection == null) {
    log_to_stdo("No file selected. Window might have been closed/cancelled");
    return "";
  } else {
    log_to_stdo("File selected: " + selection.getAbsolutePath());
    SONG_TO_VISUALIZE = selection.getAbsolutePath();
  }
  return selection.getAbsolutePath();
}

String discoverOperatingSystem() {
  String os = System.getProperty("os.name");
  if (os.contains("Windows")) {
    return "win";
  } else if (os.contains("Mac")) { //<>//
    return "mac";
  } else if (os.contains("Linux")) {
    return "linux";
  } else {
    return "other";
  }
}

String getSongNameFromFilePath(String song_path, String os_type) {
  String[] file_name_parts;
  
  if (os_type == "linux") {
    file_name_parts = split(song_path, "/");
  } else if (os_type == "win") {
    file_name_parts = split(song_path, "\\");
  } else {
    // assume unix like path
    file_name_parts = split(song_path, "/");
  }
  
  SONG_NAME = file_name_parts[file_name_parts.length-1];
  return SONG_NAME;
}
  

void setup() {
  // Entry point, run once
  
  OS_TYPE = discoverOperatingSystem();

  // Visualizer only begins once a song has been selected
  selectInput("Select song to visualize", "fileSelected");

  while (SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  STATE = 1;
  
  SONG_NAME = getSongNameFromFilePath(SONG_TO_VISUALIZE, OS_TYPE);

  // render shapes like they are hand drawn
  h = new HandyRenderer(this);
  h1 = HandyPresets.createPencil(this);
  h2 = HandyPresets.createColouredPencil(this);
  h3 = HandyPresets.createWaterAndInk(this);
  h4 = HandyPresets.createMarker(this);

  // TODO: There's gotta be a better way to init array of objects..
  HANDY_RENDERERS[0] = h;
  //HANDY_RENDERERS[1] = h1;
  HANDY_RENDERERS[1] = h2;
  HANDY_RENDERERS[2] = h3;
  HANDY_RENDERERS[3] = h4;

  //log_to_stdo("Count of Handy Renderers: " + HANDY_RENDERERS_COUNT);
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[CURRENT_HANDY_RENDERER_POSITION];

  // P3D runs faster than JAVA2D
  // https://forum.processing.org/beta/num_1115431708.html
  size(1200, 1200, P3D);

  // Initialise the ControlIO
  control = ControlIO.getInstance(this);

  // Attempt to find a device that matches the configuration file
  stick = control.getMatchedDevice("joystick");
  if (stick != null) {
    USING_CONTROLLER = true;
  }
  log_to_stdo("USING CONTROLLER?" + USING_CONTROLLER);


  // Resizable allows Windows snap features (i.e. snap to right side of screen)
  surface.setResizable(true);

  smooth(4);
  frameRate(160);
  surface.setTitle("press[b,d,f,h,s,y,p] | [x,y,a,b] on controller");


  minim = new Minim(this);
  player = minim.loadFile(SONG_TO_VISUALIZE);

  player.loop();
  SONG_PLAYING = true;
  beat = new BeatDetect();
  ellipseMode(CENTER);

  blendMode(BLEND);

  // an FFT needs to know how //<>//
  // long the audio buffers it will be analyzing are
  // and also needs to know
  // the sample rate of the audio it is analyzing
  fft = new FFT(player.bufferSize(), player.sampleRate());

  // calculate averages based on a miminum octave width of 22 Hz
  // split each octave into a number of bands
  fft.logAverages(22, bandsPerOctave);
  
  DIAMOND_RIGHT_EDGE_X = width*0.92;
  DIAMOND_LEFT_EDGE_X = width*0.74;
  
  DIAMOND_RIGHT_EDGE_Y = height*0.71;
  DIAMOND_LEFT_EDGE_Y = height*0.92;
  
  background(200);

}


void drawDiamond(float distanceFromCenter) {
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

  float innerDiamondCoordinate = ((width/2) + DIAMOND_DISTANCE_FROM_CENTER % (height * 0.57) );


  //log_to_stdo("CURRENT_HANDY_RENDERER_POSITION: " + CURRENT_HANDY_RENDERER_POSITION);
  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[CURRENT_HANDY_RENDERER_POSITION]; //<>//

  // bottom right diamond 
  CURRENT_HANDY_RENDERER.quad(
    innerDiamondCoordinate, innerDiamondCoordinate,
    DIAMOND_RIGHT_EDGE_X + DIAMOND_WIDTH_OFFSET, DIAMOND_RIGHT_EDGE_Y + DIAMOND_HEIGHT_OFFSET,
    width, height,
    DIAMOND_LEFT_EDGE_X - DIAMOND_WIDTH_OFFSET, DIAMOND_LEFT_EDGE_Y - DIAMOND_HEIGHT_OFFSET
  );
}

void drawDiamonds() {
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

void drawInnerCircle() {
  // red inner circle, is used to make the fins look smooth internally
  ellipseMode(RADIUS);
  //stroke(FIN_REDNESS, 0, 0);
  stroke(204, 39, 242);

  strokeWeight(8);
  noFill();
  h.ellipse(width/2.0, height/2.0, 110, 110);
}

void stop() {
  minim.stop();
  super.stop();
}

void drawBezierFins(float redness, float fins, boolean finRotationClockWise) {
  //stroke(redness, 0, 0);
  stroke(0);

  strokeWeight(3);

  float xOffset = -20;
  float yOffset = -50;

  yOffset = BEZIER_Y_OFFSET;

  for (int i=0; i<fins; i++) {

    pushMatrix();

      float rotationAmount = (2 * (i / fins) * PI);
  
      if (finRotationClockWise == true) {
        rotationAmount = 0 - rotationAmount;
      }
  
      translate(width/2, height/2);
      rotate(rotationAmount);
      if (APPEAR_HAND_DRAWN) {
        fill(255,0,0, 100);
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

void applyBlendModeOnDrop(int intensityOutOfTen) {
  FIN_REDNESS_ANGRY = true;

  // To reduce eye sore, only change blend mode on RNG
  float randomNumber = random(1, 10);

  if (intensityOutOfTen > randomNumber) {
    changeBlendMode();
  }
}

void changeBlendMode() {
  log_to_stdo("BlendMode before: " + modeNames[CURRENT_BLEND_MODE_INDEX]);

  if (CURRENT_BLEND_MODE_INDEX == modes.length - 1) {
    CURRENT_BLEND_MODE_INDEX = 0;
  } else {
    CURRENT_BLEND_MODE_INDEX += 1;
  }

  blendMode(CURRENT_BLEND_MODE_INDEX);
  log_to_stdo("Changed blendMode to: " + modeNames[CURRENT_BLEND_MODE_INDEX]);
}

void changeFinRotation() {
  finRotationClockWise = !finRotationClockWise;

  // once it has been changed, wait cooldown before changing again
  canChangeFinDirection = false;
}

void modifyDiamondCenterPoint(boolean closerToCenter) {
  if (closerToCenter) {
    DIAMOND_DISTANCE_FROM_CENTER = DIAMOND_DISTANCE_FROM_CENTER + (width * 0.02);

  } else {
    DIAMOND_DISTANCE_FROM_CENTER = DIAMOND_DISTANCE_FROM_CENTER - (width * 0.02);
  }
}

void toggleHandDrawn(){
  APPEAR_HAND_DRAWN = !APPEAR_HAND_DRAWN;
  h.setIsHandy(APPEAR_HAND_DRAWN);
  //h3.setIsHandy(false);
}

void toggleHandDrawn3(){
  APPEAR_HAND_DRAWN = !APPEAR_HAND_DRAWN;
  h3.setIsHandy(APPEAR_HAND_DRAWN);
  //h.setIsHandy(false);
}


void keyPressed() {
  // blend
  if (key == 'b' || key == 'B') {
    changeBlendMode();
  }
  
  // cycle between drawing styles
  if (key == 'h') {
    //toggleHandDrawn();
    CURRENT_HANDY_RENDERER_POSITION = (CURRENT_HANDY_RENDERER_POSITION + 1) % MAX_HANDY_RENDERER_POSITION;
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
  
  if (key == '<' || key == '>') {
    DRAW_DIAMONDS = !DRAW_DIAMONDS;
  }
    
  if (key == 'w' || key == 'W') {
    DRAW_WAVEFORM = !DRAW_WAVEFORM;
  }
  
 
  if (key == '/') {
    DRAW_FINS = !DRAW_FINS;
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

void log_to_stdo(String message_to_log) {
  // we use this logging wrapper to be able to toggle logging off/now in real time with 'l' keyboard shortcut
  if (LOGGING_ENABLED) {
    println(message_to_log);
  }
}



void splitFrequencyIntoLogBands() {
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
      changeBlendMode();
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
  DIAMOND_WIDTH_OFFSET = ((rx - (height/10)) / 5.0) - 80;
  //log_to_stdo("DIAMOND_WIDTH_OFFSET: " + DIAMOND_WIDTH_OFFSET);
  
  DIAMOND_HEIGHT_OFFSET = ((ry - (height/10)) / 5.0) - 80;
  //log_to_stdo("DIAMOND_HEIGHT_OFFSET: " + DIAMOND_HEIGHT_OFFSET);
  

  log_to_stdo("controller left stick:\t lx: " + lx + ", ly " + ly);
  log_to_stdo("controller right stick:\t rx: " + rx + ", ry " + ry);


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
    EPILEPSY_MODE_ON = !EPILEPSY_MODE_ON;
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

void setBackGroundFillMode(){
    fill(#FFFFFF); 
}


void draw() {
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
  

  //fill(#FFFFFF); 

  // stop redrawing the hand drawn everyframe aka jitters
  // TODO: Investigate seeds for more gpu intensive styles

  if (!EPILEPSY_MODE_ON) {
    h.setSeed(117);
    //h1.setSeed(322); // super intensive/slow
    h2.setSeed(322);
    h3.setSeed(420);
    h4.setSeed(666);
  }

  // first perform a forward fft on one of song's mix buffers
  fft.forward(player.mix);

  stroke(255, 0, 0, 128);
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
  // Blend Mode changes on any loud volume

  for(int i = 0; i < fft.specSize(); i++)
  {
    //line(i, height, i, height - fft.getBand(i)*4);
    if (fft.getBand(i)*4 > 1000.0) {
      //applyBlendModeOnDrop(blendModeIntensity);
    }

  }
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
      line( x1, height/2.0 + player.right.get(i)*WAVE_MULTIPLIER, x2, height/2.0 + player.right.get(i+1)*WAVE_MULTIPLIER );
      //CURRENT_HANDY_RENDERER.line( x1, height/2.0 + player.right.get(i)*WAVE_MULTIPLIER, x2, height/2.0 + player.right.get(i+1)*WAVE_MULTIPLIER );
  
    }
  }
  stroke(255);


  // draw a line to show where in the player playback is currently located
  // located at the bottom of the output screen
  // uses custom style, so doesn't alter other strokes
  float posx = map(player.position(), 0, player.length(), 0, width);
  pushStyle();
    stroke(0,200,0);
    line(posx, height, posx, (height * .975));
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
      FINS += 0.04;
    } else {
      FIN_REDNESS -= 1;
      FINS -= 0.04;
    }
  }
  
  // red circle, of which the bezier shapes touch
  //drawInnerCircle();
  
  
  if (DRAW_FINS) {
      drawBezierFins(FIN_REDNESS, FINS, finRotationClockWise);
  }
  
  //rotate(radians(rot));
  textSize(24);
  textAlign(CENTER);
  text(SONG_NAME, width/2, height-5);

  if (SCREEN_RECORDING) {
    saveFrame("/tmp/output/frames####.png");
  }
  
  // only update fps counter in title a sane amount of times to maintain performance
  if (frameCount % 100 == 0) {
    log_to_stdo("frameRate: " + frameRate);
    surface.setTitle("press[b,d,f,g,h,s,y,p] | [x,y,a,b] on controller | fps: " + int(frameRate));
 }
 
 log_to_stdo("Current blendMode: " + modeNames[CURRENT_BLEND_MODE_INDEX]);

}

void mouseClicked() {
  // toggles fin animated state on mouse click
  ANIMATED = !ANIMATED;
}

/*
Ascii version

o++ossyhyhhyhhyyyhyyyyhhyyhhyyyyhhyyyyyyyyyyyhyyyyyyyyyyyhyyyhyyyhyyyyyysso+/::y
+.```..-:/+ossyyhyyhyyhhyyyyhhhhyyyhhyyyyyyyyyhhyyyyyyhhyhyyyyyyso++/:-.``````:y
y-```````````.--:/+ossyyhyhhhhyyyhhyyyyyyyyyyyhhyyyyyyhyyso/::-.`````````````-oy
y+.``````````````````./yhyhhhhhhhhyyyyyyyyyyyyyyyyyyyhhho.```````````````````:yy
yy-````````````````````/yhyyyhhhhhhhhhyyyyyyyyyyhyyyhhhho.``````````````````-oyy
hh+.````````````````````oyyyyyhhhhhhhhhhhyyyyyyhyyhhyyyhh+.`````````````````/yyh
hys:````````````````````.syyyyyhhhhhhhhhhhhyyhyyyyyyyyyhhh/````````````````-+yhy
yhy/.````````````````````-syyyyhhhhhhhhhhhhhhyyyhyyyyyhhhhs-```````````````/yyhh
yhhs:`````````````````````:oyyyhhhhhhhhhhhhhhhhyyyhhhhhhhhh/``````````````.oyyyy
yyyy+`````````````...---:::oyhhhhhhhhhhhhhhhhhhhhhhhhhhhhhho-`````````````/syyhy
yyyyo:`````..:/+ossyyyyhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhs:````````````.oyyyyy
yyyyys/-:+oyhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhy/`````````.:+syhhhhy
yhyyyhhhhhhhyhhhhhhhhhhhhhhhhhhhhhhhhyyyyyyhhhhhhhhhhhhhhhhh+````.:/oyyhyhhyyhyh
yyyyyhyhhyyyyyyyhhhhhhhhhhhhhs+ohyyyyyyyhhyyyyhy:+shhhhhhhhho::+syyyyyyyhhhyyyyy
yyyyyyyyyyyyyyyyhhhhhhhhhhhs/.`.syyyyyhyhhyyyyy/``./shhhhhhhhyyyyyyyyyhhhhhyyyyy
hyyyyyyyyyyyhhhhyyhhhhhhhho-````.syyyyyyyhhhyy+`````:shhhhhhhhyhhhhhhhhhhhyyyhyy
yyyyyyyhhyyyyyyyhhhhhhhhhhhys+:-`:syyyyyhyyyyo..:+syyyhhhhhhhhhhhhhhhhhhhhyyyyyy
yyyyyyyyyyyyyyyhhhhhhhhhhhhyyyyysoyyyyhhhyyhyysyyyhhhyyhhhhhhhhhhhhhhhhhyyyhhyyh
yhyyyyhhyyyyyhhhhhhhhhhhhyyyyyyyyyyyyyyhhyhyyyyhyyyyhyyhhhhhhhhhhhhhhhhhyyyhyyyy
yyyhyyyyyhyhhhhhhhhhhhhhyyhhyyyyyyyyyyyyyyyyyhhyhyyyhhyyhhhhhhhhhhhhhhhyyyyyyyyy
hyhhhyhhyyhhhhhhhhhhhhhhyyhhyyyyyhhyyyyyyyyyyhhyyhhyyhyyhhhhhhhhhhhhhyyhyyyyyyyy
yyyhhhyyyhhhhhhhhhhhhhhhhyyhhhyhhyhhhyyyyyhhyyyyyyyhhyyhhhhhhhhhhhhyyhhyyyyyyyyy
yyyyhhyyhhhhhhhhhhhhhhhhhhyyhyyyysyyyyyhyhhyyyssyyyhhyyhhhhhhhhhhyyhhyyhyyyyyyyy
hyhyyhyhhhhhhhhhhhhhhhhhhhyyys+:..oyyyhhyyhyyo-.-/osyhhhhhhhhhhyhhyyyyhyyyyyyyyy
hhyhhhhhhhhhhhhhhyhhhhhhhhs:`````oyyyyyyhhyyyys.````-ohhhhhhhhyyyyhyyyyyyyyyyyyy
yyhhyhhhhhyyyyyyyyyhhhhhhhhs/.``+yhhyyhyyyhhhyyo``./shhhhhhhhhhyhyhhyyyyyyyyyyyy
hyhhhhhhyyhhyyys+::ohhhhhhhhhs+/yhyhhyhhhyyhyyyy++shhhhhhhhhhhhhyhyyyyyhhhhhyyyy
yhhhhhhyhyyo/:.````+hhhhhhhhhhhhhhhhhyyyyyhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhyyhyy
hhyhyys+:.`````````/yhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhyo+::/syyyhh
hhhyyo`````````````:shhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhyyyysss+/:..`````/shhhy
hyyys:`````````````-ohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhyo:::---...````````````.+yyyy
yyyy+.``````````````/hhhhhhhhhyyyhhhhhhhhhhhhhhhhyyyo-`````````````````````/syhh
yyys:```````````````-shhhhhyyyyhyyhhhhhhhhhhhhhhhyyyyo.````````````````````.+yyy
hhy+.````````````````/hhhyyyyyyyyyyyyhhhhhhhhhhhhyyyyyo`````````````````````:shh
yhs:`````````````````.+hhyyyyyyyyhyhhyyhhhhhhhhhhyyyyhy+````````````````````-+yy
yy+-``````````````````.ohhhhyyyyyyhhhyhhyyhhhhhhhhhhyhhh:````````````````````:yh
yy:```````````````````.ohhyyyyyyyyyhyyyyyyyyyyhhhhhhhhhyy:.``````````````````.+y
y+.`````````````--::/osyhyyyyyyyyyyyyyyyyyyyhyyyyyhhhhyhyysso//:-..```````````:y
y-``````.-:/++ssyyyyhhhyhhhyyyyyyyyyyyyyyyyyyyyhyhhhyyyyhhyyyyhyyysso+/:-..```.o
y::/+ossyyhhyyhyyhyyhyyhyyhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyhyhyyyyyyyyhyyhyyysso++o

I know we shared a love for visualizers. I remember Foobar's
spectrum laying low on your secondary display, while
Battlefield was being played.

When you held that party, I was drawn to your audio/visualizer
setup. You gestured towards the PC. I navigated Foobar, kicked
Milkdrop 2 off using Shpeck. Thanks, man.

RIP Sam,
CK

PS: If anyone ever wants to talk, I'm open ears and don't be
hesitant even if I have headphones on d(-_-)b
*/
