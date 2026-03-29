class ShaderScene {
  PShader milkdropShader;
  boolean shaderLoaded = false;
  
  // Controller variables we will pass to the shader uniforms
  float panX = 0.0;
  float panY = 0.0;
  float twist = 0.0;
  
  ShaderScene() {
    loadMyShader();
  }
  
  void loadMyShader() {
    try {
      // In Processing, loadShader looks in the data/ folder automatically
      milkdropShader = loadShader("milkdrop_lesson.glsl");
      shaderLoaded = true;
      println("Successfully loaded the GPU Milkdrop Shader!");
    } catch (Exception e) {
      shaderLoaded = false;
      println("Failed to load shader: " + e.getMessage());
    }
  }

  void applyController(Controller c) {
    // We map the Left Stick axes (-1 to 1 natively) to variables we can push to GLSL
    float leftStickX = map(c.lx, 0, width, -1, 1);
    float leftStickY = map(c.ly, 0, height, -1, 1);
    
    // Right stick X will twist the kaleidoscope
    float rightStickX = map(c.rx, 0, width, -1, 1);
    
    // Applying deadzones so tiny stick drift doesn't move it continuously
    if (abs(leftStickX) > 0.1) panX -= leftStickX * 0.02; // Accumulate the pan overtime
    if (abs(leftStickY) > 0.1) panY += leftStickY * 0.02; // Processing Y is inverted from GLSL Y
    if (abs(rightStickX) > 0.1) twist += rightStickX * 0.05;
    
    // A button to center the pan and untwist
    if (c.a_just_pressed) {
      panX = 0.0;
      panY = 0.0;
      twist = 0.0;
    }
    
    // Y button to hot-reload the shader while debugging! (Awesome feature)
    if (c.y_just_pressed) {
      loadMyShader();
    }
  }

  void drawScene() {
    background(0); // Clear the frame buffer
    
    if (!shaderLoaded || milkdropShader == null) {
      fill(255, 0, 0);
      textSize(32);
      text("Shader Failed to Load! Check console.", width/2, height/2);
      return;
    }

    // Capture the audio analytics
    float basRaw = audio.normalisedAvg(2); // Low freq (bass)
    float midRaw = audio.normalisedAvg(8); // Mid freq
    float higRaw = audio.normalisedAvg(18); // High freq

    // 1. SET THE UNIFORMS (Talk to the GPU!)
    // Pass the standard screen and time values
    milkdropShader.set("u_resolution", float(width), float(height));
    milkdropShader.set("u_time", millis() / 1000.0);
    
    // Pass our music reaction layers
    milkdropShader.set("audio_bass", basRaw);
    milkdropShader.set("audio_mid", midRaw);
    milkdropShader.set("audio_high", higRaw);
    
    // Pass our controller variables
    milkdropShader.set("controller_pan", panX, panY);
    milkdropShader.set("controller_twist", twist);

    // 2. TELL PROCESSING TO USE THE GPU SHADER
    shader(milkdropShader);
    
    // 3. DRAW A CANVAS FOR THE GPU TO RENDER ON
    // We literally just draw a giant flat rectangle that covers the whole screen.
    // The GPU shader will overwrite this rectangle with pure math!
    noStroke();
    fill(255);
    rect(0, 0, width, height);
    
    // 4. RESET THE SHADER
    // Critical: If we don't reset the shader here, the text HUD and every other scene
    // in the application will try to be drawn using the Milkdrop GLSL logic which will break it!
    resetShader();

    // Now we can draw normal CPU graphics (like the text HUD) over top of the GPU art safely.
    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
    drawHud(basRaw, midRaw, higRaw);
  }

  // Our educational code overlay lines!
  String[] getCodeLines() {
    return new String[] {
      "// GPU MILKDROP LESSON",
      "void main() {",
      "  // Get normalized pixel coords centered at (0,0)",
      "  vec2 coord = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;",
      "  ",
      "  // 4x folding space recursive loop",
      "  float acc = 0.0;",
      "  for(float i=0.; i<4.; i++) {",
      "    coord = abs(coord); // mirror symmetry",
      "    coord = (coord * (1.3 + audio_bass*0.5)) - 0.5; // expansion",
      "    ",
      "    // Math rotation around axis",
      "    float s = sin(u_time*0.2 + controller_twist);",
      "    float c = cos(u_time*0.2 + controller_twist);",
      "    coord = vec2(coord.x*c - coord.y*s, coord.x*s + coord.y*c);",
      "    ",
      "    // Intense inverse ripples based on distance",
      "    float d = length(coord);",
      "    float wave = sin(d*8.0 - u_time*2.0 + audio_mid*2.0);",
      "    acc += (0.01 + audio_high*0.05) / abs(wave);",
      "  }",
      "  ",
      "  // Output time-shifting colors!",
      "  gl_FragColor = vec4(base_color * color_shift * acc, 1.0);",
      "}"
    };
  }

  void drawHud(float low, float mid, float high) {
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      fill(0, 125);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 380 * uiScale(), 8 + lh * 6);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: GPU Shader Lesson", 12, 12);
      text("low / mid / high (norm): " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh);
      text("controller twist: " + nf(twist, 1, 2) + "  pan X/Y: " + nf(panX, 1, 2) + " / " + nf(panY, 1, 2), 12, 12 + lh * 2);
      text("A center  Y hot-reload shader", 12, 12 + lh * 3);
      text("Press ` (backtick) to view the GLSL Shader lesson code overlay!", 12, 12 + lh * 4);
      text("FPS varies by GPU. CPU usage should be ~0%.", 12, 12 + lh * 5);
    popStyle();
  }
}
