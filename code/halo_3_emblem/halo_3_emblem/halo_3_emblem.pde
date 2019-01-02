/*

Diamonds and circles intersect to form a Celtic Cross

Source image dimensions: 70x70 px
Output image dimensions: 420x420 px

Ratio 1:6

*/



void setup() {
  size(420, 420);
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
  
  // we encapsulate the Beziers in a shape, so can be filled
  for (int i=0; i<8; i++) {
    println("Drawing bezier: " + i);
    pushMatrix();
    
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
      156,36,
      156,36,
      222,48,
      258,102
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
      156,36,
      156,36,
      180,78,
      168,102
    );
    
    /*
             
     ,......,
    .        .
    */
    
    // From Inkscape
    // M 28,17 C 28,17 35,14 43,17
    bezier(
      168,102,
      168,102,
      210,84,
      258,102
    );
      
    
    endShape();
    translate(width/2, height/2);
    float rotationAmount = 0.25 * PI;
    rotate(rotationAmount);

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
  
  drawBezierFins(); //<>//


  /*
  // draw the inner circle with a "fat" stroke
  strokeWeight(20);
  // assuming center mode
  ellipse(width/2, height/2, 100, 100);

  // reset that stroke fatness
  strokeWeight(1);
  // make sure we'll be rotating about the center of the sketch
  translate(width/2, height/2);
  // and then start drawing eight 'teeth'
  for (int i=0; i<8; i++) {
    beginShape();
    // we know where p1, p2, and p3 are.
    vertex(bezierPoint1.x, bezierPoint1.y);
    // and we "guessed" at c1, c2, c3, and c4.
    bezierVertex(c1.x, c1.y, c2.y, c2.y, bezierPoint2.x, bezierPoint2.y);
    bezierVertex(c3.x, c3.y, c4.y, c4.y, bezierPoint3.x, bezierPoint3.y);
    // We leave the shape "open" in case you want both stroke and fill
    endShape();
    // we're drawing eight teeth, so we need to rotate by 2*PI/8 each time
    rotate(0.25 * PI);
  }
  */
 
}
