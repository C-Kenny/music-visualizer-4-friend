PImage img;

int GREEN_GLOBAL = 200;
int BLUE_GLOBAL = 255;

int MODIFIER  = -1;


void setup() {
  size(420, 420);
  img = loadImage("h3_emblem.jpg");
}

// We can see here that the source file is so small + jagged edges
// This is good motivation for drawing the emblem as code
void draw() {
  if (GREEN_GLOBAL >= 255) {
    MODIFIER  = -1;
  }
  if (GREEN_GLOBAL <=1 ) {
    MODIFIER  = 1;
  }
  
  if (second() % 6 == 0) {
    tint(6,6,6);
  } else {
    tint(GREEN_GLOBAL-BLUE_GLOBAL,GREEN_GLOBAL,BLUE_GLOBAL);
  }

    
  
  background(0);
  image(img,0,0,420,420);
  println("GREEN_GLOBAL: " + GREEN_GLOBAL);
  println("BLUE_GLOBAL: " + BLUE_GLOBAL);

  
  GREEN_GLOBAL = GREEN_GLOBAL + MODIFIER ;
  BLUE_GLOBAL = BLUE_GLOBAL + (MODIFIER *2);
}
