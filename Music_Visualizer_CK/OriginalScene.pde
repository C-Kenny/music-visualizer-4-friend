class OriginalScene implements IScene {
  DashedLines dash;
  float dash_dist;
  int s1Size;
  float s1OffsetX;

  // Background effects now encapsulated within the scene
  Tunnel tunnel;
  Plasma plasma;
  PolarPlasma polarPlasma;

  OriginalScene(PApplet parent) {
    this.tunnel = new Tunnel();
    this.plasma = new Plasma();
    this.polarPlasma = new PolarPlasma();
    dash = new DashedLines(parent);
    dash.pattern(130, 110);
    dash_dist    = 0;
    s1Size       = min(width, height);
    s1OffsetX    = (width - s1Size) / 2.0;

    // Initialize diamond variables formerly in Config.pde
    config.DIAMOND_DISTANCE_FROM_CENTER = s1Size * 0.07;
    config.DIAMOND_RIGHT_EDGE_X          = s1Size * 0.92;
    config.DIAMOND_LEFT_EDGE_X           = s1Size * 0.74;
    config.DIAMOND_RIGHT_EDGE_Y          = s1Size * 0.71;
    config.DIAMOND_LEFT_EDGE_Y           = s1Size * 0.92;
    config.MAX_DIAMOND_DISTANCE          = s1Size * 0.3;
    config.MIN_DIAMOND_DISTANCE          = s1Size * 0.1;
  }

  void applyController(Controller c) {
    config.BEZIER_Y_OFFSET = (c.ly - (height/2)) - 12;
    config.WAVE_MULTIPLIER = (c.ry % (height/5)) + 25;
    config.DIAMOND_WIDTH_OFFSET = ((c.rx - (height/10)) / 5.0) - 80;
    config.DIAMOND_HEIGHT_OFFSET = ((c.ry - (height/10)) / 5.0) - 80;

    try {
      float l_trigger_depletion = map(c.stick.getSlider("lt").getValue(), -1, 1, -2, 6);
      config.TUNNEL_ZOOM_INCREMENT += int(l_trigger_depletion);
    } catch (Exception e) {}

    if (c.a_just_pressed) config.RAINBOW_FINS = !config.RAINBOW_FINS;
    if (c.b_just_pressed) changeBlendMode();
    if (c.x_just_pressed) config.ANIMATED = !config.ANIMATED;
    if (c.y_just_pressed) config.finRotationClockWise = !config.finRotationClockWise;
    if (c.stick.getButton("Right Thumb").pressed()) config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
  }

  void drawDiamond(float dash_distanceFromCenter) {
    float innerXY = s1Size / 2.0 + config.DIAMOND_DISTANCE_FROM_CENTER;
    CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];
    strokeWeight(5);
    strokeCap(SQUARE);
    dash.quad(
      innerXY, innerXY,
      config.DIAMOND_RIGHT_EDGE_X + config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_RIGHT_EDGE_Y + config.DIAMOND_HEIGHT_OFFSET,
      s1Size, s1Size,
      config.DIAMOND_LEFT_EDGE_X - config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_LEFT_EDGE_Y - config.DIAMOND_HEIGHT_OFFSET
    );
  }

  void drawInnerDiamonds() {
    pushMatrix(); fill(0,0,0); scale(0.5, 0.5); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(0,0,0); scale(-0.5, 0.5); translate(-s1Size, 0); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(0,0,0); scale(-0.5,-0.5); translate(-s1Size, -s1Size); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(0,0,0); scale(0.5,-0.5); translate(0, -s1Size); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
  }

  void drawDiamonds() {
    pushMatrix(); fill(255, 76, 52); scale(-1,1); translate(-s1Size, 0); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(255, 76, 52); scale(1, 1); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(255, 76, 52); scale(-1,-1); translate(-s1Size, -s1Size); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
    pushMatrix(); fill(255, 76, 52); scale(1,-1); translate(0, -s1Size); drawDiamond(config.DIAMOND_DISTANCE_FROM_CENTER); popMatrix();
  }

  void drawInnerCircle() {
    ellipseMode(RADIUS);
    stroke(204, 39, 242);
    strokeWeight(8);
    noFill();
    h.ellipse(s1Size/2.0, s1Size/2.0, 110, 110);
  }

  void drawBezierFins(float redness, float fins, boolean finRotationClockWise) {
    strokeWeight(5);
    float xOffset = -20;
    float yOffset = config.BEZIER_Y_OFFSET;

    if (config.RAINBOW_FINS) colorMode(HSB, 360, 255, 255);
    for (int i = 0; i < fins; i++) {
      if (config.RAINBOW_FINS) {
        float hue = (((float)i / fins) * 360 + frameCount * 0.4 + config.GLOBAL_REDNESS * 60) % 360;
        stroke(hue, 220, 255);
        fill(config.APPEAR_HAND_DRAWN ? color(hue, 200, 200, 100) : color(0, 0));
      } else {
        stroke(7);
        if (config.APPEAR_HAND_DRAWN) fill(247, 9, 143, 100);
        else noFill();
      }

      pushMatrix();
        float rotationAmount = (2 * (i / fins) * PI);
        if (finRotationClockWise == true) {
          rotationAmount = 0 - rotationAmount;
        }
        translate(s1Size/2.0, s1Size/2.0);
        scale(1.75 * uiScale());
        float random_noise_spin = noise(i * 0.3, frameCount * 0.01);
        rotate( (radians(frameCount + random_noise_spin) / 2.0) );
        rotate(rotationAmount);
        bezier(-36 + xOffset,-126 + yOffset, -36 + xOffset,-126 + yOffset, 32 + xOffset,-118 + yOffset, 68 + xOffset,-52 + yOffset);
        bezier(-36 + xOffset,-126 + yOffset, -36 + xOffset,-126 + yOffset, -10 + xOffset,-88 + yOffset, -22 + xOffset,-52 + yOffset);
        bezier(-22 + xOffset,-52 + yOffset, -22 + xOffset,-52 + yOffset, 20 + xOffset,-74 + yOffset, 68 + xOffset,-52 + yOffset);
      popMatrix();
    }
    if (config.RAINBOW_FINS) colorMode(RGB, 255);
  }

  void applyBlendModeOnDrop(int intensityOutOfTen) {
    config.FIN_REDNESS_ANGRY = true;
    float randomNumber = random(1, 10);
    if (intensityOutOfTen > randomNumber) {
      changeBlendMode();
    }
  }

  void modifyDiamondCenterPoint(boolean closerToCenter) {
    if (closerToCenter) {
      config.DIAMOND_DISTANCE_FROM_CENTER = config.DIAMOND_DISTANCE_FROM_CENTER + (width * 0.02);
    } else {
      config.DIAMOND_DISTANCE_FROM_CENTER = config.DIAMOND_DISTANCE_FROM_CENTER - (width * 0.02);
    }
  }

  void drawScene() {
    // Dynamic viewport sizing to handle resizing
    s1Size = min(width, height);
    s1OffsetX = (width - s1Size) / 2.0;

    stroke(0);
    noStroke();

    if(config.BACKGROUND_ENABLED) {
      background(200);
    }

    clip((int)s1OffsetX, 0, s1Size, s1Size);
    pushMatrix();
    translate(s1OffsetX, 0);

    if (!config.EPILEPSY_MODE_ON) {
      h.setSeed(117);
      h1.setSeed(322);
      h2.setSeed(420);
    }

    stroke(216, 16, 246, 128);
    strokeWeight(8);

    int msSinceProgStart = millis();
    if (msSinceProgStart > config.LAST_FIN_CHECK + 10000) {
      config.canChangeFinDirection = true;
      config.LAST_FIN_CHECK = msSinceProgStart;
    }

    if (msSinceProgStart > config.LAST_PLASMA_CHECK + 10000) {
      config.canChangePlasmaFlow = true;
      config.PLASMA_INCREMENTING = !config.PLASMA_INCREMENTING;
      config.LAST_PLASMA_CHECK = msSinceProgStart;
    }

    splitFrequencyIntoLogBands();

    strokeWeight(2);
    stroke(255);

    if (analyzer.isBeat) {
      config.TUNNEL_ZOOM_INCREMENT = (config.TUNNEL_ZOOM_INCREMENT + 3) % 10000;
    }
    
    stroke(255);

    if (config.DIAMOND_DISTANCE_FROM_CENTER >= config.MAX_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = false;
    } else if (config.DIAMOND_DISTANCE_FROM_CENTER <= config.MIN_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = true;
    }

    if (config.APPEAR_HAND_DRAWN) {
      fill(255, 76, 52);
    } else {
      fill(255);
      if (config.BACKGROUND_ENABLED) background(200);
    }
    
    if (config.DRAW_TUNNEL) {
      tunnel.draw(config.TUNNEL_ZOOM_INCREMENT);
    }

    if (config.DRAW_PLASMA) {
      plasma.draw(config.PLASMA_SEED);
    }

    if (config.DRAW_POLAR_PLASMA) {
      polarPlasma.draw();
    }
    
    if (config.DRAW_DIAMONDS) {
      drawDiamonds();
      if (config.DRAW_INNER_DIAMONDS) {
        drawInnerDiamonds();
      }
    }

    if (config.FIN_REDNESS >= 255) {
      config.FIN_REDNESS_ANGRY = false;
    } else if (config.FIN_REDNESS <= 0) {
      config.FIN_REDNESS_ANGRY = true;
    }

    if (config.ANIMATED) {
      if (config.FIN_REDNESS_ANGRY) {
        config.FIN_REDNESS += 1;
        config.FINS += 0.02;
      } else {
        config.FIN_REDNESS -= 1;
        config.FINS -= 0.02;
      }
    }
    
    if (config.DRAW_FINS) {
        drawBezierFins(config.FIN_REDNESS, config.FINS, config.finRotationClockWise);
    }
    
    dash.offset(dash_dist);
    dash_dist = dash_dist + (.2 * config.DASH_LINE_SPEED);
    if (dash_dist >= 10000 || dash_dist <= -10000) {
      dash_dist = 0;
    }
    
    drawSongNameOnScreen(config.SONG_NAME, s1Size/2.0, s1Size-5);

    if (config.SCREEN_RECORDING) {
      saveFrame("/tmp/output/frames####.png");
    }

    float posx = map(audio.player.position(), 0, audio.player.length(), 0, s1Size);
    pushStyle();
      stroke(252,4,243);
      line(posx, s1Size, posx, s1Size * .975);
    popStyle();

    popMatrix();
    noClip();
  }

  void changeDashedLineSpeed(float amountToChange) {
    if (config.DASH_LINE_SPEED > config.DASH_LINE_SPEED_LIMIT) {
      config.DASH_LINE_SPEED_INCREASING = false;
    } else if (config.DASH_LINE_SPEED < -config.DASH_LINE_SPEED_LIMIT) {
      config.DASH_LINE_SPEED_INCREASING = true;
    }
    
    config.DASH_LINE_SPEED = config.DASH_LINE_SPEED_INCREASING ? config.DASH_LINE_SPEED + amountToChange: config.DASH_LINE_SPEED - amountToChange;
  }

  void splitFrequencyIntoLogBands() {
    // Phase 2: Use centralized analyzer instead of redundant FFT loops
    if (analyzer.bass > 0.9) {
      applyBlendModeOnDrop(3);
      changeDashedLineSpeed(0.2);
    }

    if (analyzer.mid > 0.8) {
      modifyDiamondCenterPoint(config.INCREMENT_DIAMOND_DISTANCE);
    }

    if (config.canChangeFinDirection && analyzer.high > 0.1) {
      changeFinRotation();
    }
    
    if (analyzer.master > 0.05) {
      changePlasmaFlow(1);
      changeDashedLineSpeed(0.1);
      if (random(1) < 0.05) config.PLASMA_INCREMENTING = !config.PLASMA_INCREMENTING;
    }
  }

  void changePlasmaFlow(int amountToChange){
      if (random(0, 10) > 6) {
        if (config.canChangePlasmaFlow) {
          if(config.PLASMA_INCREMENTING) {
              config.PLASMA_SEED = (config.PLASMA_SEED + abs(amountToChange))  % (config.PLASMA_SIZE/2 -1);
          } else {
              config.PLASMA_SEED = (config.PLASMA_SEED - amountToChange)  % (config.PLASMA_SIZE/2 -1);
          }
        }
      }
  }

  void onEnter() {
    background(200);
  }

  void onExit() {}

  void handleKey(char k) {
    if (k == 'd') {
      modifyDiamondCenterPoint(false);
    } else if (k == 'D') {
      modifyDiamondCenterPoint(true);
    } else if (k == 'r') {
      config.DIAMOND_RIGHT_EDGE_X += 20;
      config.DIAMOND_LEFT_EDGE_X -= 20;
    } else if (k == 'R') {
      config.DIAMOND_RIGHT_EDGE_X -= 20;
      config.DIAMOND_LEFT_EDGE_X += 20;
    } else if (k == 'f') {
      config.DRAW_FINS = !config.DRAW_FINS;
    } else if (k == 'F') {
      config.RAINBOW_FINS = !config.RAINBOW_FINS;
    } else if (k == 'x' || k == 'X') {
      config.ANIMATED = !config.ANIMATED;
    } else if (k == 'z' || k == 'Z') {
      config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
    } else if (k == 'y' || k == 'Y') {
      config.finRotationClockWise = !config.finRotationClockWise;
    } else if (k == 'b' || k == 'B') {
      changeBlendMode();
    }
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Original Scene (Mandala) ===",
      "// Logic: logarithmic FFT bands -> diamond depth & fin rotation",
      "dist = sin(t) * amplitude",
      "rotation = frameCount * speed + bass_energy"
    };
  }
}
