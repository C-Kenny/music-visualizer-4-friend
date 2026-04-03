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

  void drawBezierHeart(PGraphics pg, float xHeartOffset, float yHeartOffset, float s) {
      pg.pushMatrix();
        pg.scale(s);
        pg.translate(xHeartOffset, yHeartOffset);

        pg.fill(bezier_heart_fill_color_r, bezier_heart_fill_color_g, bezier_heart_fill_color_b);
        pg.stroke(255, 1, 1);
        pg.strokeWeight(1.0);

        pg.bezier(
          bezier_heart_l_x1,                        bezier_heart_l_y1,
          bezier_heart_l_x2 - (config.HEART_PULSE),        bezier_heart_l_y2,
          bezier_heart_l_x3 - (config.HEART_PULSE / 2.0),  bezier_heart_l_y3,
          bezier_heart_l_x4,                        bezier_heart_l_y4
        );
        pg.bezier(
          bezier_heart_r_x1,                        bezier_heart_r_y1,
          bezier_heart_r_x2 + (config.HEART_PULSE),        bezier_heart_r_y2,
          bezier_heart_r_x3 + (config.HEART_PULSE / 2.0),  bezier_heart_r_y3,
          bezier_heart_r_x4,                        bezier_heart_r_y4
        );
      pg.popMatrix();
  }

}
