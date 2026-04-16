class OriginalScene implements IScene {
  DashedLines dash;
  float dashDistance;
  int s1Size;
  float s1OffsetX;

  // Background effects now encapsulated within the scene
  Tunnel tunnel;
  Plasma plasma;
  PolarPlasma polarPlasma;

  // ── Audio triggers ────────────────────────────────────────────────────────
  // Bass sustain → accelerate tunnel zoom.  Beat onset → twist burst.
  TriggerEngine bassTrigger = new TriggerEngine(0.7, 0.06, 0.03);
  float twistValue     = 0;   // 0..1, fired on beat, decays at 0.10/frame
  int   tunnelTwistOff = 0;   // passed to Tunnel.draw() (0..32)

  // Background cycling (D-pad L/R)
  int backgroundMode = 4; // 0=None(Stacking), 1=Clear, 2=Tunnel, 3=Plasma, 4=Polar, 5=All
  
  OriginalScene(PApplet parent) {
    this.tunnel = new Tunnel();
    this.plasma = new Plasma();
    this.polarPlasma = new PolarPlasma();
    dash = new DashedLines(parent);
    dash.pattern(130, 110);
    dashDistance    = 0;
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
    // Map full stick range → configured parameter bounds so any screen resolution
    // gives the same feel. Old formula (ly - height/2) overflowed ±540 on 1080p,
    // making the fins fly off screen with any movement.
    config.BEZIER_Y_OFFSET    = map(c.ly, 0, height, config.MIN_BEZIER_Y_OFFSET, config.MAX_BEZIER_Y_OFFSET);
    config.WAVE_MULTIPLIER    = map(c.ry, 0, height, 10, 300);
    config.DIAMOND_WIDTH_OFFSET  = map(c.rx, 0, width,  -120, 120);
    config.DIAMOND_HEIGHT_OFFSET = map(c.ry, 0, height, -120, 120);

    try {
      float leftTriggerDepletion = map(c.stick.getSlider("lt").getValue(), -1, 1, -2, 6);
      config.TUNNEL_ZOOM_INCREMENT += int(leftTriggerDepletion);
    } catch (Exception e) {}

    if (c.aJustPressed) config.RAINBOW_FINS = !config.RAINBOW_FINS;
    if (c.bJustPressed) changeBlendMode();
    if (c.xJustPressed || c.leftStickClickJustPressed) config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;
    if (c.yJustPressed) config.finRotationClockWise = !config.finRotationClockWise;
    if (c.rightStickClickJustPressed) config.DRAW_INNER_DIAMONDS = !config.DRAW_INNER_DIAMONDS;
    
    if (c.dpadRightJustPressed) cycleBackgroundMode(1);
    if (c.dpadLeftJustPressed)  cycleBackgroundMode(-1);
  }
  
  void cycleBackgroundMode(int dir) {
    backgroundMode = (backgroundMode + dir + 6) % 6;
    config.BACKGROUND_ENABLED = (backgroundMode != 0);
    config.DRAW_TUNNEL       = (backgroundMode == 2 || backgroundMode == 5);
    config.DRAW_PLASMA       = (backgroundMode == 3 || backgroundMode == 5);
    config.DRAW_POLAR_PLASMA = (backgroundMode == 4 || backgroundMode == 5);
  }

  void drawDiamond(PGraphics pg, float dashDistanceFromCenter) {
    float innerXY = s1Size / 2.0 + config.DIAMOND_DISTANCE_FROM_CENTER;
    CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];
    pg.strokeWeight(5);
    pg.strokeCap(SQUARE);
    // DashedLines 'dash' usually draws to the current graphics context 'g'
    // but we'll try to ensure it follows the pg buffer.
    pg.quad(
      innerXY, innerXY,
      config.DIAMOND_RIGHT_EDGE_X + config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_RIGHT_EDGE_Y + config.DIAMOND_HEIGHT_OFFSET,
      s1Size, s1Size,
      config.DIAMOND_LEFT_EDGE_X - config.DIAMOND_WIDTH_OFFSET, config.DIAMOND_LEFT_EDGE_Y - config.DIAMOND_HEIGHT_OFFSET
    );
  }

  void drawInnerDiamonds(PGraphics pg) {
    pg.pushMatrix(); pg.fill(0,0,0); pg.scale(0.5, 0.5); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(0,0,0); pg.scale(-0.5, 0.5); pg.translate(-s1Size, 0); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(0,0,0); pg.scale(-0.5,-0.5); pg.translate(-s1Size, -s1Size); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(0,0,0); pg.scale(0.5,-0.5); pg.translate(0, -s1Size); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
  }

  void drawDiamonds(PGraphics pg) {
    pg.pushMatrix(); pg.fill(255, 76, 52); pg.scale(-1,1); pg.translate(-s1Size, 0); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(255, 76, 52); pg.scale(1, 1); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(255, 76, 52); pg.scale(-1,-1); pg.translate(-s1Size, -s1Size); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
    pg.pushMatrix(); pg.fill(255, 76, 52); pg.scale(1,-1); pg.translate(0, -s1Size); drawDiamond(pg, config.DIAMOND_DISTANCE_FROM_CENTER); pg.popMatrix();
  }

  void drawInnerCircle(PGraphics pg) {
    pg.ellipseMode(RADIUS);
    pg.stroke(204, 39, 242);
    pg.strokeWeight(8);
    pg.noFill();
    // HandyRenderer usually requires setGraphics(pg) or just draws to current context
    h.ellipse(s1Size/2.0, s1Size/2.0, 110, 110);
  }

  void drawBezierFins(PGraphics pg, float redness, float fins, boolean finRotationClockWise) {
    pg.strokeWeight(5);
    float xOffset = -20;
    float yOffset = config.BEZIER_Y_OFFSET;

    if (config.RAINBOW_FINS) pg.colorMode(HSB, 360, 255, 255);
    for (int i = 0; i < fins; i++) {
      if (config.RAINBOW_FINS) {
        float hue = (((float)i / fins) * 360 + config.logicalFrameCount * 0.4 + config.GLOBAL_REDNESS * 60) % 360;
        pg.stroke(hue, 220, 255);
        pg.fill(config.APPEAR_HAND_DRAWN ? color(hue, 200, 200, 100) : color(0, 0));
      } else {
        pg.stroke(7);
        if (config.APPEAR_HAND_DRAWN) pg.fill(247, 9, 143, 100);
        else pg.noFill();
      }

      pg.pushMatrix();
        float rotationAmount = (2 * (i / fins) * PI);
        if (finRotationClockWise == true) {
          rotationAmount = 0 - rotationAmount;
        }
        pg.translate(s1Size/2.0, s1Size/2.0);
        pg.scale(1.75 * uiScale());
        float random_noise_spin = noise(i * 0.3, config.logicalFrameCount * 0.01);
        pg.rotate( (radians(config.logicalFrameCount + random_noise_spin) / 2.0) );
        pg.rotate(rotationAmount);
        pg.bezier(-36 + xOffset,-126 + yOffset, -36 + xOffset,-126 + yOffset, 32 + xOffset,-118 + yOffset, 68 + xOffset,-52 + yOffset);
        pg.bezier(-36 + xOffset,-126 + yOffset, -36 + xOffset,-126 + yOffset, -10 + xOffset,-88 + yOffset, -22 + xOffset,-52 + yOffset);
        pg.bezier(-22 + xOffset,-52 + yOffset, -22 + xOffset,-52 + yOffset, 20 + xOffset,-74 + yOffset, 68 + xOffset,-52 + yOffset);
      pg.popMatrix();
    }
    if (config.RAINBOW_FINS) pg.colorMode(RGB, 255);
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

  void drawScene(PGraphics pg) {
    // Correct viewport sizing to handle resizing
    s1Size = min(pg.width, pg.height);
    s1OffsetX = (pg.width - s1Size) / 2.0;

    pg.stroke(0);
    pg.noStroke();

    if(config.BACKGROUND_ENABLED) {
      pg.background(200);
    }
    
    // HandyRenderer usually needs to be explicitly told which buffer to draw to
    h.setGraphics(pg);
    h1.setGraphics(pg);
    h2.setGraphics(pg);

    // Tunnel writes directly to pg.pixels[], bypassing transforms, so it must
    // be drawn before the translate and receives the square bounds explicitly.
    if (config.DRAW_TUNNEL) {
      tunnel.draw(pg, config.TUNNEL_ZOOM_INCREMENT, tunnelTwistOff, (int)s1OffsetX, s1Size);
    }

    pg.pushMatrix();
    pg.translate(s1OffsetX, 0);

    if (!config.EPILEPSY_MODE_ON) {
      h.setSeed(117);
      h1.setSeed(322);
      h2.setSeed(420);
    }

    pg.stroke(216, 16, 246, 128);
    pg.strokeWeight(8);

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

    pg.strokeWeight(2);
    pg.stroke(255);

    if (analyzer.isBeat) {
      config.TUNNEL_ZOOM_INCREMENT = (config.TUNNEL_ZOOM_INCREMENT + 3) % 10000;
    }
    
    pg.stroke(255);

    if (config.DIAMOND_DISTANCE_FROM_CENTER >= config.MAX_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = false;
    } else if (config.DIAMOND_DISTANCE_FROM_CENTER <= config.MIN_DIAMOND_DISTANCE) {
      config.INCREMENT_DIAMOND_DISTANCE = true;
    }

    if (config.APPEAR_HAND_DRAWN) {
      pg.fill(255, 76, 52);
    } else {
      pg.fill(255);
      if (config.BACKGROUND_ENABLED) pg.background(200);
    }
    
    if (config.DRAW_PLASMA) {
      pg.pushMatrix(); pg.translate(-s1OffsetX, 0); // Reverse shift for background element
      plasma.draw(pg, config.PLASMA_SEED);
      pg.popMatrix();
    }

    if (config.DRAW_POLAR_PLASMA) {
      pg.pushMatrix(); pg.translate(-s1OffsetX, 0); // Reverse shift for background element
      polarPlasma.draw(pg);
      pg.popMatrix();
    }

    if (config.DRAW_WAVEFORM) {
      float r_line = (config.logicalFrameCount % 255) / 10.0;
      float g_line = (config.logicalFrameCount % 255) - 75;
      float b_line = (config.logicalFrameCount % 255);
      int wBufSz = audio.player.bufferSize();
      pg.pushStyle();
        pg.strokeWeight(4);
        pg.strokeCap(ROUND);
        pg.stroke(r_line, g_line, b_line);
        for (int i = 0; i < wBufSz - 1; i++) {
          float x1 = map(i,   0, wBufSz, 0, s1Size);
          float x2 = map(i+1, 0, wBufSz, 0, s1Size);
          pg.line(x1, s1Size/2.0 + audio.player.right.get(i)   * config.WAVE_MULTIPLIER,
                  x2, s1Size/2.0 + audio.player.right.get(i+1) * config.WAVE_MULTIPLIER);
        }
      pg.popStyle();
    }

    if (config.DRAW_DIAMONDS) {
      pg.pushMatrix();
        drawDiamonds(pg);
        if (config.DRAW_INNER_DIAMONDS) {
          pg.pushMatrix(); drawInnerDiamonds(pg); pg.popMatrix();
          pg.pushMatrix(); pg.translate(0, s1Size/2.0); drawInnerDiamonds(pg); pg.popMatrix();
          pg.pushMatrix(); pg.translate(s1Size/2.0, 0); drawInnerDiamonds(pg); pg.popMatrix();
          pg.pushMatrix(); pg.translate(s1Size/2.0, s1Size/2.0); drawInnerDiamonds(pg); pg.popMatrix();
        }
      pg.popMatrix();
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
        drawBezierFins(pg, config.FIN_REDNESS, config.FINS, config.finRotationClockWise);
    }
    
    dash.offset(dashDistance);
    dashDistance = dashDistance + (.2 * config.DASH_LINE_SPEED);
    if (dashDistance >= 10000 || dashDistance <= -10000) {
      dashDistance = 0;
    }
    
    drawSongNameOnScreen(pg, config.SONG_NAME, s1Size/2.0, s1Size-5);

    if (config.SCREEN_RECORDING) {
      pg.save("/tmp/output/frames####.png");
    }

    float posx = map(audio.player.position(), 0, audio.player.length(), 0, s1Size);
    pg.pushStyle();
      pg.stroke(252,4,243);
      pg.line(posx, s1Size, posx, s1Size * .975);
    pg.popStyle();

    pg.popMatrix(); // end square canvas translate

    // ── top-left HUD (outside the square translate so it sits at canvas coords) ──
    sceneHUD(pg, "Mandala", new String[]{
      "fins: " + nf(config.FINS, 1, 1) + "  blend: " + modeNames[config.CURRENT_BLEND_MODE_INDEX],
      "w waveform  x stacking  f fins  b blend  A rainbow  Y flip"
    });
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

    // ── TriggerEngine: bass sustain → accelerate tunnel zoom ──────────────
    if (config.DRAW_TUNNEL) {
      bassTrigger.update(analyzer.bass);
      config.TUNNEL_ZOOM_INCREMENT += (int)(bassTrigger.getValue() * 6);
    }

    // ── Beat twist burst ───────────────────────────────────────────────────
    if (analyzer.isBeat) twistValue = 1.0;
    twistValue    = lerp(twistValue, 0, 0.10);
    tunnelTwistOff = (int)(twistValue * 32);

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
    } else if (k == 'w' || k == 'W') {
      config.DRAW_WAVEFORM = !config.DRAW_WAVEFORM;
    } else if (k == 'x' || k == 'X') {
      config.BACKGROUND_ENABLED = !config.BACKGROUND_ENABLED;  // stacking / trails mode
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
      "rotation = config.logicalFrameCount * speed + bass_energy"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {
      new ControllerLayout("LStick ↕", "Oscillation amplitude"),
      new ControllerLayout("RStick ↔", "Scroll speed (vertical offset)"),
      new ControllerLayout("D-Pad ↔",  "Cycle Background FX"),
      new ControllerLayout("LB/RB",    "Rotate through scenes")
    };
  }
}
