/*
 
Diamonds and circles intersect to form a Celtic Cross
 
Source image dimensions: 70x70 px
Output image dimensions: 420x420 px
 
Ratio 1:6

Keyboard Layout:

b = blend mode iterate
f = change direction of fins (requires ability to change fins i.e. timeotus)
d = diamond closer to center
D = diamond closer to outside

TODO:

- split up music into frequencies. change different shapes on ranges. 
- fix diamond center point. Currently it's modulo half way. But this means
it glitches back, once it reaches max. Have a look at the diamond incrementer,
logic doesn't appear to be reducing it.
 
*/

import ddf.minim.*;
import ddf.minim.analysis.*;
 
Minim minim;
AudioPlayer player;
BeatDetect beat;
FFT fft;

// GLOBALS

// FINS
boolean FIN_REDNESS_ANGRY = true;
boolean ANIMATED = true;

int LAST_FIN_CHECK; // last time fin was checked, to be changed
float FINS = 8.0;
int FIN_REDNESS = 1;

boolean canChangeFinDirection = true;
boolean finRotationClockWise = false;

// DIAMONDS
int DIAMOND_DISTANCE_FROM_CENTER = 30;

int MAX_DIAMOND_DISTANCE = 240;
int MIN_DIAMOND_DISTANCE = -240;

boolean INCREMENT_DIAMOND_DISTANCE = true;

// BLEND MODES
int[] modes = new int[]{
  BLEND, ADD, SUBTRACT, 
};

int CURRENT_BLEND_MODE_INDEX = 0;

String[] modeNames = new String[]{
  "BLEND", "ADD", "SUBTRACT",
  "EXLCUSION"  
};

// the number of bands per octave
int bandsPerOctave = 4;

// Visualize song passed to
String SONG_TO_VISUALIZE = "";
 


String fileSelected(File selection) {
  if (selection == null) {
    println("No file selected. Window might have been closed/cancelled");
    return "";
  } else {
    println("File selected: " + selection.getAbsolutePath());
    SONG_TO_VISUALIZE = selection.getAbsolutePath();
  }
  return selection.getAbsolutePath();
}


void setup() {
  // Visualizer only begins once a song has been selected
  selectInput("Select song to visualize", "fileSelected");
  
  while (SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  
  // Setup the display frame
  size(420, 420);
  smooth();
  frameRate(60);
  surface.setTitle("(Click) animates ::)");
  
  minim = new Minim(this);
  player = minim.loadFile(SONG_TO_VISUALIZE);
  
  player.loop();
  beat = new BeatDetect();
  ellipseMode(CENTER);
  
  blendMode(BLEND);
  
  // an FFT needs to know how 
  // long the audio buffers it will be analyzing are
  // and also needs to know 
  // the sample rate of the audio it is analyzing
  fft = new FFT(player.bufferSize(), player.sampleRate());
  
  // calculate averages based on a miminum octave width of 22 Hz
  // split each octave into a number of bands
  fft.logAverages(22, bandsPerOctave);
}
 
 
void drawDiamond(int distanceFromCenter) {
  /*
  Coordinate System
  
  x -->
      0 1 2 3 4 5
  y  0 
  |  1
  |  2
  v  3
     4
     5
  */
  
  //int innerDiamondCoordinate = (420/2) + (DIAMOND_DISTANCE_FROM_CENTER%240);
  // TODO: Fix, so it can come back to center also. Right now it resets
  // back to original position
  int innerDiamondCoordinate = ((420/2) + DIAMOND_DISTANCE_FROM_CENTER %240);

  //println("innerDiamond: " + innerDiamondCoordinate);
 
  // bottom right diamond
  quad(
    innerDiamondCoordinate, innerDiamondCoordinate,
    //240, 240,
    390,300,
    420,420,
    312,390
  );  
}
 
void drawDiamonds() {
  // Diamonds are drawn by transforming the canvas 
   
  // bottom left diamond
  pushMatrix();
  fill(255);
  scale(-1,1);
  translate(-width, 0);
  drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
  
  // top left diamond
  pushMatrix();
  fill(255);
  scale(-1,-1);
  translate(-width, -height);
  drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
  
  // top right diamond
  pushMatrix();
  fill(255);
  scale(1,-1);
  translate(0, -height);
  drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  popMatrix();
}
 
void drawInnerCircle() {
  // red inner circle, is used to make the fins look smooth internally
  ellipseMode(RADIUS);
  stroke(FIN_REDNESS, 0, 0);
  strokeWeight(8);
  noFill();
  ellipse(width/2.0, height/2.0, 110, 110);
}
 
void drawBezierFins(float redness, float fins, boolean finRotationClockWise) {
  //println("Fins are rotating clockwise? " + finRotationClockWise);
  stroke(redness, 0, 0);
  strokeWeight(4);
  
  float xOffset = -20;
  float yOffset = -50;
  for (int i=0; i<fins; i++) {

    pushMatrix();
    
    float rotationAmount = (2 * (i / fins) * PI);
    
    if (finRotationClockWise == true) {
      rotationAmount = 0 - rotationAmount;
    }
    
    translate(width/2, height/2);
    rotate(rotationAmount);
    noFill();
    
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
    changeBlendMode();     //<>//
  } 
}
 //<>//
void changeBlendMode() {
  if (CURRENT_BLEND_MODE_INDEX == modes.length - 1) { 
    CURRENT_BLEND_MODE_INDEX = 0;
  } else {
    CURRENT_BLEND_MODE_INDEX += 1;
  }
  blendMode(CURRENT_BLEND_MODE_INDEX);
  println("Changed blendMode to: " + modeNames[CURRENT_BLEND_MODE_INDEX]);
}

void changeFinRotation() {
  if (finRotationClockWise == true) {
    finRotationClockWise = false;
  } else {
    finRotationClockWise = true;
  }
  // once it has been changed, wait cooldown before changing again
  canChangeFinDirection = false;
}

void modifyDiamondCenterPoint(boolean closerToCenter) {
  if (closerToCenter) {
    DIAMOND_DISTANCE_FROM_CENTER++;
  } else {
    DIAMOND_DISTANCE_FROM_CENTER--; //<>//
  }
}
    
void keyPressed() {
  // blend
  if (key == 'b' || key == 'B') {
    changeBlendMode();
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
  
  // logging / debug
  // TODO: Implement valuable logging
  if (key == 'l' || key == 'L') {
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
   
    
    //println("i: " + i);
    //println("bandDB: " + bandDB);
    
    if ((i >= 0 && i <= 5) && bandDB > -10) {
      // bass
      changeBlendMode();
    } 
    
    // TODO diamond inner point, changes on beat
    if ((i >=6 && i<= 15) && bandDB >-27) {
        println("DIAMOND DISTANCE: " + DIAMOND_DISTANCE_FROM_CENTER);
        if (INCREMENT_DIAMOND_DISTANCE == true) {
          //modifyDiamondCenterPoint(closerToCenter=true);
          println("Moving center diamond point INWARDS");
          modifyDiamondCenterPoint(true); 
        } else {
          println("Moving center diamond point OUTWARDS");
          modifyDiamondCenterPoint(false);
        }
    }
    //println("canChangeFinDirection: " + canChangeFinDirection);
    if (canChangeFinDirection == true) {
      if ((i >=16 && i <= 35) && bandDB > -150) {
        println("About to change fin rotation");          
        changeFinRotation();
      }
    }
  }
}
  
  
void draw() {
  // reset drawing params when redrawing frame
  stroke(0);
  noStroke();
  background(200);
  
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
  
  splitFrequencyIntoLogBands();
  
 
  //println("MAX specSize: " + fft.specSize());
  int blendModeIntensity = 5;
  // Blend Mode changes on any loud volume
  for(int i = 0; i < fft.specSize(); i++)
  {
    //line(i, height, i, height - fft.getBand(i)*4);
    if (fft.getBand(i)*4 > 1000.0) {
      applyBlendModeOnDrop(blendModeIntensity);
    }
      
  }
  strokeWeight(2);

  stroke(255);
  
  // draw the waveforms
  // the values returned by left.get() and right.get() will be between -1 and 1,
  // so we need to scale them up to see the waveform
  // note that if the file is MONO, left.get() and right.get() will return the same value
  for(int i = 0; i < player.bufferSize() - 1; i++)
  {
    float x1 = map( i, 0, player.bufferSize(), 0, width );
    float x2 = map( i+1, 0, player.bufferSize(), 0, width );
    line( x1, height/2.0 + player.right.get(i)*50, x2, height/2.0 + player.right.get(i+1)*50 );
  }
  
  // draw a line to show where in the player playback is currently located
  // located at the bottom of the output screen
  // uses custom style, so doesn't alter other strokes
  float posx = map(player.position(), 0, player.length(), 0, width);
  pushStyle();
  stroke(0,200,0);
  line(posx, height, posx, height-15);
  popStyle();
  
  // DIAMONDS 
  
  
  // check if should be incrementing diamond distance from center
  if (DIAMOND_DISTANCE_FROM_CENTER >= MAX_DIAMOND_DISTANCE) {
    //println("Too far from center. ");
    INCREMENT_DIAMOND_DISTANCE = true;
  } else if (DIAMOND_DISTANCE_FROM_CENTER <= MIN_DIAMOND_DISTANCE) {
    INCREMENT_DIAMOND_DISTANCE = false;
  }
  
   
  // bottom right diamond
  fill(255);
  drawDiamond(DIAMOND_DISTANCE_FROM_CENTER);
  
  // draw rest of diamonds, by rotating canvas
  drawDiamonds();
  noFill();
    
  // redness of fins, goes upto RED then back to BLACK
  if (FIN_REDNESS >= 255) {
    FIN_REDNESS_ANGRY = false;
  } else if (FIN_REDNESS <= 0) {
    FIN_REDNESS_ANGRY = true;
  }
  
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
  drawInnerCircle();
  
  drawBezierFins(FIN_REDNESS, FINS, finRotationClockWise);
}

void mouseClicked() {
  // toggles fin animated state on mouse click
  if (ANIMATED) {
    ANIMATED = false;
  } else {
    ANIMATED = true;
  }
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

RIP Sam,
CK
*/
