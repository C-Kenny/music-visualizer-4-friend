/* //<>//

Diamonds and circles intersect to form a Celtic Cross

Source image dimensions: 70x70 px
Output image dimensions: 420x420 px

Ratio 1:6

*/



void setup() {
  size(420, 420);
  smooth();
  //size(1420, 1420);

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
  // red inner circle
  ellipseMode(RADIUS);
  stroke(255, 0, 0);
  strokeWeight(8);
  noFill();
  ellipse(width/2.0, height/2.0, 110, 110);
}

void drawBezierFins() {
  stroke(255, 0, 0);
  strokeWeight(6);
  
  int fins = 8;
  float xOffset = -20;
  float yOffset = -50;
  // we encapsulate the Beziers in a shape, so can be filled
  for (int i=0; i<fins; i++) {
    println("Drawing bezier: " + i);
    pushMatrix();
    
    float rotationAmount = 2 * i / fins * PI;
    
    translate(210, 210);
    rotate(rotationAmount);
    beginShape();
    /*
    .
      .
        .
         .
          .
    */
    // from Inkscape trace
    // M 26,6 C 26,6 37,8 43,17
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
    
    // From Inkscape
    // M 26,6 C 26,6 30,13 28,17
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
    
    // From Inkscape
    // M 28,17 C 28,17 35,14 43,17
    bezier(
      -22 + xOffset,-52 + yOffset,
      -22 + xOffset,-52 + yOffset,
      20 + xOffset,-74 + yOffset,
      68 + xOffset,-52 + yOffset
    );
      
    
    endShape();

    popMatrix();
  }
  
}

void draw() {
  // reset drawing params
  stroke(0);
  noStroke();
  fill(255);
  
  // bottom right diamond
  drawDiamond();
  
  // draw rest of diamonds, by rotating canvas
  drawDiamonds();
  
  // red circle, of which the bezier shapes touch
  drawInnerCircle();
  
  drawBezierFins();
 
}
