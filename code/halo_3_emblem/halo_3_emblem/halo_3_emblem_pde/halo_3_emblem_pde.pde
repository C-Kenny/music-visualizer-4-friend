/*
 
Diamonds and circles intersect to form a Celtic Cross
 
Source image dimensions: 70x70 px
Output image dimensions: 420x420 px
 
Ratio 1:6
 
*/

import ddf.minim.*;
import ddf.minim.analysis.*;
 
Minim minim;
AudioPlayer player;
BeatDetect beat;
FFT fft;

// GLOBALS
boolean FIN_REDNESS_ANGRY = true;
boolean ANIMATED = true;

int[] modes = new int[]{
  BLEND, ADD, SUBTRACT, 
  EXCLUSION,
};

int CURRENT_BLEND_MODE_INDEX = 0;

String[] modeNames = new String[]{
  "BLEND", "ADD", "SUBTRACT",
  "EXLCUSION"  
};

float FINS = 8.0;
float rad = 70; 

int FIN_REDNESS = 1;

// the number of bands per octave
int bandsPerOctave = 4;
 
boolean finRotationClockWise = true;



void setup() {
  size(420, 420);
  smooth();
  frameRate(60);
  surface.setTitle("(Click) animates ");
  
  minim = new Minim(this);
  //player = minim.loadFile("song.mp3");
  player = minim.loadFile("Salmonella Dub - For the Love of It (Pitch Black Version).mp3");
  
  player.play();
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
  //fft.logAverages(22, bandsPerOctave);
 
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
  
    
  */
}
 
 
void drawDiamond() {
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
 
  // bottom right diamond
  quad(
    240,240,
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
  drawDiamond();
  popMatrix();
  
  // top left diamond
  pushMatrix();
  fill(255);
  scale(-1,-1);
  translate(-width, -height);
  drawDiamond();
  popMatrix();
  
  // top right diamond
  pushMatrix();
  fill(255);
  scale(1,-1);
  translate(0, -height);
  drawDiamond();
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
  println("Fins are rotating clockwise? " + finRotationClockWise);
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
  float randomNumber = random(0, 10);
  
  if (intensityOutOfTen > randomNumber) {
    println("Changing blendMode. From: " + modeNames[CURRENT_BLEND_MODE_INDEX]);
    blendMode(modes[int(randomNumber)]);
    println("Changed blendMode to: " + modeNames[int(randomNumber)]); //<>//
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
}
    
void keyPressed() {
  if (key == 'b' || key == 'B') {
    changeBlendMode();
  }
  if (key == 'f' || key == 'F') {
    changeFinRotation();
  }
}

void draw() {
  // reset drawing params
  stroke(0);
  noStroke();
  background(200);
  
  // first perform a forward fft on one of song's mix buffers
  fft.forward(player.mix);
 
  stroke(255, 0, 0, 128);
  strokeWeight(8);
  
  // draw the spectrum as a series of vertical lines
  // I multiple the value of getBand by 4 
  // so that we can see the lines better
 
 
  int blendModeIntensity = 4;
  //println("MAX specSize: " + fft.specSize());
  
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
   
  // bottom right diamond
  fill(255);
  drawDiamond();
  
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
  // toggles animated state
  if (ANIMATED) {
    ANIMATED = false;
  } else {
    ANIMATED = true;
  }
}
