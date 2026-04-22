// Prism Orbit scene — audio-reactive lattice intended to feel pleasing to both
// humans and machines. Switch to it with the '7' key.

class PrismCodexScene implements IScene {
  float spin = 0.0;
  float beatGlow = 0.0;
  float beatFlash = 0.0;       // sharp fast-decay flash for beams + center
  float bassPulse = 0.0;       // smoothed bass for radius breathing
  float spinKick = 0.0;        // brief spin boost on beat
  float ringDirSign = 1.0;     // flips on hard beats for direction reversal
  float hueShift = 0.0;        // walks over time + on high energy
  float triggerHue = 0.0;      // LT contribution
  float triggerDensity = 0.0;  // RT contribution → cross-link beams
  float burstPhase = 0.0;      // radial burst expansion (0..1)
  int beatCounter = 0;
  float latticeDrift = 0.0;
  float spinSpeed   = 0.0025; // controllable (default matches original)
  float driftSpeed  = 0.35;   // controllable latticeDrift increment

  // Pre-allocated node buffers — reused every frame to avoid per-frame array allocation
  float[][] nodeX = { new float[6], new float[10], new float[14] };
  float[][] nodeY = { new float[6], new float[10], new float[14] };

  PrismCodexScene() {}

  void applyController(Controller c) {
    // L Stick ↕ → spin speed (up = faster)
    float ly = map(c.ly, 0, height, -1, 1);
    spinSpeed = map(ly, -1, 1, 0.010, 0.0003);

    // R Stick ↕ → lattice drift speed (up = faster)
    float ry = map(c.ry, 0, height, -1, 1);
    driftSpeed = map(ry, -1, 1, 2.0, 0.05);

    // Triggers: LT shifts hue, RT adds beam cross-links
    triggerHue     = lerp(triggerHue,     c.lt, 0.15);
    triggerDensity = lerp(triggerDensity, c.rt, 0.15);

    // A button → inject a manual glow + flash + burst
    if (c.aJustPressed) { beatGlow = 1.0; beatFlash = 1.0; burstPhase = 1.0; }
    // B button → flip ring rotation direction immediately
    if (c.bJustPressed) ringDirSign = -ringDirSign;
  }

  String[] getCodeLines() {
    return new String[] {
      "=== Prism Orbit ===",
      "",
      "// Three orbit rings, each driven by a different frequency range",
      "ring_radius = base_radius * (1 + band_energy * 0.18 + beat_glow * 0.05)",
      "node_angle  = time + ring_index_offset + node_index * TWO_PI / node_count",
      "",
      "// Each node projects beams to nearby nodes on the next ring",
      "beam_alpha  = 40 + 140 * similarity(low_energy, high_energy)",
      "beam_weight = 1 + 2.5 * combined_energy",
      "",
      "// Background grid drifts diagonally to suggest machine vision",
      "grid_offset = config.logicalFrameCount * 0.35",
      "",
      "// Beat onset injects a white pulse into the center prism",
      "beat_glow *= 0.92 between beats"
    };
  }

  void drawScene(PGraphics pg) {
    if (analyzer.isBeat) {
      beatGlow = 1.0;
      beatFlash = 1.0;
      spinKick = 1.0;
      beatCounter++;
      // Every 4th beat: hard hit — flip rotation direction + radial burst
      if (beatCounter % 4 == 0) {
        ringDirSign = -ringDirSign;
        burstPhase = 1.0;
      }
    }
    beatGlow  *= 0.92;
    beatFlash *= 0.78;          // faster decay = sharper blink
    spinKick  *= 0.90;
    burstPhase *= 0.94;
    bassPulse = lerp(bassPulse, analyzer.bass, 0.18);
    hueShift += 0.4 + analyzer.high * 1.5 + triggerHue * 3.0;

    spin += spinSpeed * (1.0 + spinKick * 4.0 + bassPulse * 0.8);
    latticeDrift += driftSpeed;

    float lowEnergy = getAverageBandEnergy(0.00, 0.18);
    float midEnergy = getAverageBandEnergy(0.18, 0.52);
    float highEnergy = getAverageBandEnergy(0.52, 1.00);
    float masterEnergy = (lowEnergy + midEnergy + highEnergy) / 3.0;

    drawBackdrop(pg, lowEnergy, midEnergy, highEnergy);

    pg.pushMatrix();
      pg.translate(pg.width / 2.0, pg.height / 2.0);
      drawOrbitLattice(pg, lowEnergy, midEnergy, highEnergy);
      drawCentralPrism(pg, lowEnergy, midEnergy, highEnergy, masterEnergy);
    pg.popMatrix();

    drawHud(pg, lowEnergy, midEnergy, highEnergy, masterEnergy);
    drawSongNameOnScreen(pg, config.SONG_NAME, pg.width / 2.0, pg.height - 5);
  }

  float getAverageBandEnergy(float startNorm, float endNorm) {
    int specLen = analyzer.spectrum.length;
    int start = constrain(int(specLen * startNorm), 0, specLen - 1);
    int end = constrain(int(specLen * endNorm), start + 1, specLen);
    float total = 0;
    for (int i = start; i < end; i++) {
      total += analyzer.spectrum[i];
    }
    return constrain(total / max(1, end - start) * 14.0, 0, 14);
  }

  void drawBackdrop(PGraphics pg, float lowEnergy, float midEnergy, float highEnergy) {
    float diagPulse = 25 + highEnergy * 8 + beatGlow * 55;
    float gridStep = max(42, min(pg.width, pg.height) * 0.055);

    pg.background(3, 7, 18);
    pg.noStroke();
    for (int i = 0; i < 6; i++) {
      float radius = min(pg.width, pg.height) * (0.18 + i * 0.12);
      float alpha = 8 + i * 5 + beatGlow * 8;
      pg.fill(20 + i * 8, 30 + i * 10, 60 + i * 15, alpha);
      pg.ellipse(pg.width / 2.0, pg.height / 2.0, radius * 2.3, radius * 1.55);
    }

    pg.strokeWeight(1);
    for (float x = -pg.width; x < pg.width * 2; x += gridStep) {
      float shifted = x + (latticeDrift % gridStep);
      pg.stroke(60, 110, 160, 26 + lowEnergy * 5);
      pg.line(shifted, 0, shifted + pg.height, pg.height);
      pg.stroke(120, 80, 170, 16 + highEnergy * 5);
      pg.line(shifted, pg.height, shifted + pg.height, 0);
    }

    pg.noStroke();
    pg.fill(150, 220, 255, 16 + midEnergy * 5);
    pg.rectMode(CENTER);
    pg.rect(pg.width / 2.0, pg.height / 2.0, pg.width * 0.94, diagPulse);
    pg.rect(pg.width / 2.0, pg.height / 2.0, diagPulse, pg.height * 0.78);
    pg.rectMode(CORNER);
  }

  void drawOrbitLattice(PGraphics pg, float lowEnergy, float midEnergy, float highEnergy) {
    float[] energies = { lowEnergy, midEnergy, highEnergy };
    int[] nodeCounts = { 6, 10, 14 };
    float baseRadius = min(pg.width, pg.height) * 0.13;

    for (int ring = 0; ring < 3; ring++) {
      float ringEnergy = energies[ring];
      float radius = baseRadius * (ring + 1)
        * (1.0 + ringEnergy * 0.05 + beatGlow * 0.04 + bassPulse * 0.18 + burstPhase * 0.25);
      float ringRotation = spin * ringDirSign * (ring % 2 == 0 ? 1.0 : -1.35) + ring * PI / 7.0;

      pg.noFill();
      pg.stroke(80 + ring * 50, 120 + ring * 35, 220 + ring * 10, 85);
      pg.strokeWeight(1.5 + ringEnergy * 0.22);
      pg.ellipse(0, 0, radius * 2, radius * 2);

      for (int i = 0; i < nodeCounts[ring]; i++) {
        float angle = ringRotation + TWO_PI * i / nodeCounts[ring];
        float wobble = sin(config.logicalFrameCount * 0.02 + i + ring * 0.7) * (8 + ringEnergy * 1.8);
        float x = cos(angle) * (radius + wobble);
        float y = sin(angle) * (radius + wobble);
        nodeX[ring][i] = x;
        nodeY[ring][i] = y;
      }
    }

    // beams between neighboring rings — RT trigger and burst add cross-links
    int extraLinks = (int)(triggerDensity * 3 + burstPhase * 2);
    for (int ring = 0; ring < 2; ring++) {
      int nextLen = nodeX[ring + 1].length;
      for (int i = 0; i < nodeX[ring].length; i++) {
        for (int k = 0; k <= 1 + extraLinks; k++) {
          int target = (i + k) % nextLen;
          drawBeam(pg, nodeX[ring][i], nodeY[ring][i], nodeX[ring + 1][target], nodeY[ring + 1][target],
            energies[ring], energies[ring + 1], ring);
        }
      }
    }
    // Burst: bright radial spokes from center to outer ring on every hard beat
    if (burstPhase > 0.05) {
      pg.stroke(255, 255, 255, 200 * burstPhase);
      pg.strokeWeight(1.0 + burstPhase * 2.0);
      int outer = nodeX.length - 1;
      for (int i = 0; i < nodeX[outer].length; i++) {
        pg.line(0, 0, nodeX[outer][i] * (0.4 + burstPhase * 0.6), nodeY[outer][i] * (0.4 + burstPhase * 0.6));
      }
    }

    // nodes last so they sit above beams
    pg.noStroke();
    for (int ring = 0; ring < 3; ring++) {
      for (int i = 0; i < nodeX[ring].length; i++) {
        float halo = 11 + energies[ring] * 1.6 + beatGlow * 12;
        pg.fill(80 + ring * 55, 180 + ring * 20, 255, 28);
        pg.ellipse(nodeX[ring][i], nodeY[ring][i], halo * 2.2, halo * 2.2);
        pg.fill(185 + ring * 22, 215, 255);
        pg.ellipse(nodeX[ring][i], nodeY[ring][i], halo * 0.52, halo * 0.52);
      }
    }
  }

  void drawBeam(PGraphics pg, float x1, float y1, float x2, float y2, float e1, float e2, int ring) {
    float similarity = 1.0 - min(1.0, abs(e1 - e2) / 8.0);
    float alpha = 35 + similarity * 90 + beatGlow * 28 + beatFlash * 110;
    float weight = 0.8 + (e1 + e2) * 0.12 + beatFlash * 1.6;
    pg.colorMode(HSB, 360, 100, 100, 255);
    float hue = (200 + ring * 35 + hueShift * 0.6) % 360;
    pg.stroke(hue, 70 - beatFlash * 40, 100, alpha);
    pg.strokeWeight(weight);
    pg.line(x1, y1, x2, y2);
    pg.colorMode(RGB, 255);
  }

  void drawCentralPrism(PGraphics pg, float lowEnergy, float midEnergy, float highEnergy, float masterEnergy) {
    float prismRadius = min(pg.width, pg.height)
      * (0.07 + lowEnergy * 0.003 + beatGlow * 0.012 + bassPulse * 0.045 + beatFlash * 0.025);
    float innerRadius = prismRadius * 0.52;
    float prismRotation = -spin * 2.6 * ringDirSign;

    for (int layer = 0; layer < 3; layer++) {
      float layerRadius = prismRadius + layer * 18 + highEnergy * (2 + layer);
      float alpha = 50 + layer * 28 + beatGlow * 55;
      pg.noFill();
      pg.stroke(120 + layer * 35, 230 - layer * 30, 255, alpha);
      pg.strokeWeight(1.4 + layer * 0.45);
      pg.beginShape();
      for (int i = 0; i < 6; i++) {
        float a = prismRotation + TWO_PI * i / 6.0;
        pg.vertex(cos(a) * layerRadius, sin(a) * layerRadius);
      }
      pg.endShape(CLOSE);
    }

    pg.noStroke();
    pg.fill(255, 255, 255, 38 + beatGlow * 70);
    pg.ellipse(0, 0, prismRadius * 2.0, prismRadius * 2.0);

    pg.fill(35, 220, 255, 130);
    pg.beginShape();
    for (int i = 0; i < 3; i++) {
      float a = prismRotation + PI / 6.0 + TWO_PI * i / 3.0;
      pg.vertex(cos(a) * prismRadius, sin(a) * prismRadius);
    }
    pg.endShape(CLOSE);

    pg.fill(255, 120, 240, 150);
    pg.beginShape();
    for (int i = 0; i < 3; i++) {
      float a = prismRotation - PI / 6.0 + TWO_PI * i / 3.0;
      pg.vertex(cos(a) * innerRadius, sin(a) * innerRadius);
    }
    pg.endShape(CLOSE);

    pg.fill(255, 255, 255, 160 + beatGlow * 60);
    pg.ellipse(0, 0, 10 + masterEnergy * 2.5, 10 + masterEnergy * 2.5);
  }

  void drawHud(PGraphics pg, float lowEnergy, float midEnergy, float highEnergy, float masterEnergy) {
    sceneHUD(pg, "Prism Orbit", new String[]{
      "low / mid / high: " + nf(lowEnergy,1,2) + " / " + nf(midEnergy,1,2) + " / " + nf(highEnergy,1,2),
      "master: " + nf(masterEnergy,1,2) + "  beat glow: " + nf(beatGlow,1,2)
    });
  }

  void onEnter() {
    background(0);
  }

  void onExit() {}

  void handleKey(char k) {}

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[] {};
  }
}
