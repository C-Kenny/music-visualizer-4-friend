class BezierHeart {
  float animationAngle, animationSpeed, animationRange;

  float leftX1, leftY1;
  float leftX2, leftY2;
  float leftX3, leftY3;
  float leftX4, leftY4;

  float rightX1, rightY1;
  float rightX2, rightY2;
  float rightX3, rightY3;
  float rightX4, rightY4;

  float fillRed = random(255);
  float fillGreen = 100.0;
  float fillBlue = random(255);

  BezierHeart (float startAngle, float angleSpeed, float motionRange) {
    animationAngle = startAngle;
    animationSpeed = angleSpeed;
    animationRange = motionRange;

    leftX1 = 0;  leftY1 = 562;
    leftX2 = -443;    leftY2 = 88;
    leftX3 = -70;  leftY3 = 0;
    leftX4 = 0;  leftY4 = 178;

    rightX1 = 0;  rightY1 = 562;
    rightX2 = 388;  rightY2 = 58;
    rightX3 = 17;  rightY3 = 0;
    rightX4 = 0;  rightY4 = 178;
  }

  void updateAngle() {
    animationAngle += animationSpeed;
  }

  void updateFillColor(float newFillGreen) {
    fillGreen = newFillGreen;
  }

  void drawHeart(PGraphics pg, float xHeartOffset, float yHeartOffset, float scaleFactor) {
      pg.pushMatrix();
        pg.scale(scaleFactor);
        pg.translate(xHeartOffset, yHeartOffset);

        pg.fill(fillRed, fillGreen, fillBlue);
        pg.stroke(255, 1, 1);
        pg.strokeWeight(1.0);

        pg.bezier(
          leftX1,                        leftY1,
          leftX2 - (config.HEART_PULSE),        leftY2,
          leftX3 - (config.HEART_PULSE / 2.0),  leftY3,
          leftX4,                        leftY4
        );
        pg.bezier(
          rightX1,                        rightY1,
          rightX2 + (config.HEART_PULSE),        rightY2,
          rightX3 + (config.HEART_PULSE / 2.0),  rightY3,
          rightX4,                        rightY4
        );
      pg.popMatrix();
  }

}
