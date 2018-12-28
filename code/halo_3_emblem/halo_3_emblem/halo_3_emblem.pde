/*

Diamonds and circles intersect to form a Celtic Cross

*/

BezierPoint bezierPoint1;
BezierPoint bezierPoint2;
BezierPoint bezierPoint3;


void setup() {
  size(420, 420);
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
  bezierPoint1 = new BezierPoint(17, 42);
  bezierPoint2 = new BezierPoint(4, 24);
  bezierPoint3 = new BezierPoint(16, 27);

}

class BezierPoint {
  float x;
  float y;
  BezierPoint (float tempX, float tempY) {
    x = tempX;
    y = tempY;
  }
}

void drawDiamonds() {
  /*
  Coordinate System
  
  x -->
      0 1 2 3 4 5
  y  0 
  |  1
  v  2
     3
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
void draw() {
  // reset drawing params
  stroke(0);
  noStroke();
  fill(255);
  
  // bottom right diamond
  drawDiamonds();
  
  // bottom left diamond
  pushMatrix();
  fill(255);
  scale(-1,1);
  translate(-width, 0);
  drawDiamonds();
  popMatrix();
  
  // top left diamond
  pushMatrix();
  fill(255);
  scale(-1,-1);
  translate(-width, -height);
  drawDiamonds();
  popMatrix();
  
  // top right diamond
  pushMatrix();
  fill(255);
  scale(1,-1);
  translate(0, -height);
  drawDiamonds();
  popMatrix();
  
  // red inner circle
  ellipseMode(RADIUS);
  stroke(255, 0, 0);
  strokeWeight(10);
  noFill();
  ellipse(width/2.0, height/2.0, 100, 100);
  

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
