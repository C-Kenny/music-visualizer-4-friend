// Music Visualizer — Web MVP
// p5.js port of Music_Visualizer_CK (Processing 4 / Java)
//
// Scenes ported:
//   0  Oscilloscope  (original state 5)
//   1  Radial FFT    (original state 11)
//   2  Aurora Ribbons(original state 10)
//   3  Spirograph    (original state 12)
//
// Controls:
//   ← / →       prev / next scene
//   1-4         jump to scene directly
//   Space       pause / resume
//   Scene-specific keys shown in each scene's HUD

// ─── Top-level state ─────────────────────────────────────────────────────────

let audio, config;
let scenes = [];
let soundFile = null;

const SCENE_NAMES = ['Oscilloscope', 'Radial FFT', 'Aurora Ribbons', 'Spirograph'];

// ─── Audio Wrapper ───────────────────────────────────────────────────────────
// Mirrors the Processing Audio class API so scene code barely changes.

class AudioWrapper {
  constructor() {
    this._p5fft   = new p5.FFT(0.8, 1024);
    this._numBands = 32;
    this._bands    = new Array(this._numBands).fill(0);
    this._bandMax  = new Array(this._numBands).fill(0.001);
    this._waveform = new Array(1024).fill(0);

    // Pre-compute log-spaced band edge frequencies: 20 Hz → 22 kHz
    this._bandEdges = [];
    for (let i = 0; i <= this._numBands; i++) {
      this._bandEdges.push(20 * Math.pow(22000 / 20, i / this._numBands));
    }

    // Beat detection: energy history + cooldown
    this._energyHist    = new Array(43).fill(0);
    this._histIdx       = 0;
    this._beatCooldown  = 0;
    this._isBeat        = false;

    // Public API matching Processing Audio class
    const self = this;
    this.fft = {
      avgSize: ()  => self._numBands,
      getAvg:  (i) => self._bands[constrain(floor(i), 0, self._numBands - 1)]
    };
    this.beat = {
      isOnset: () => self._isBeat
    };
    this.player = {
      bufferSize: () => 1024,
      // Waveform L/R: use phase-shifted mono for a Lissajous-like figure
      left:  { get: (i) => self._waveform[i % 1024] },
      right: { get: (i) => self._waveform[(i + 128) % 1024] }
    };
  }

  forward() {
    // Analyse current audio frame
    let spectrum = this._p5fft.analyze();      // 1024 bins, 0–255
    let wf       = this._p5fft.waveform(1024); // 1024 samples, −1…+1
    for (let i = 0; i < 1024; i++) this._waveform[i] = wf[i] || 0;

    // Map FFT bins → 32 log-averaged bands (like Minim logAverages)
    let bins = spectrum.length; // 1024
    for (let b = 0; b < this._numBands; b++) {
      let startBin = floor(this._bandEdges[b]     / (22050 / bins));
      let endBin   = floor(this._bandEdges[b + 1] / (22050 / bins));
      startBin = constrain(startBin, 0, bins - 1);
      endBin   = constrain(endBin, startBin + 1, bins);
      let sum = 0;
      for (let j = startBin; j < endBin; j++) sum += spectrum[j];
      // Scale 0-255 → roughly 0-20 (matches Minim getAvg range for typical music)
      this._bands[b] = (sum / (endBin - startBin)) * (20 / 255);
      this._bandMax[b] = Math.max(this._bandMax[b] * 0.997, this._bands[b]);
    }

    // Beat detection: compare bass energy to running average
    this._beatCooldown = max(0, this._beatCooldown - 1);
    let bassEnergy = this._p5fft.getEnergy(60, 250);
    this._energyHist[this._histIdx] = bassEnergy;
    this._histIdx = (this._histIdx + 1) % this._energyHist.length;
    let avg = this._energyHist.reduce((a, v) => a + v) / this._energyHist.length;
    this._isBeat = bassEnergy > avg * 1.35 && this._beatCooldown === 0 && bassEnergy > 45;
    if (this._isBeat) this._beatCooldown = 15;
  }

  normalisedAvg(band) {
    let raw = this._bands[constrain(floor(band), 0, this._numBands - 1)];
    if (this._bandMax[band] < 0.0001) return 0;
    return constrain(raw / this._bandMax[band], 0, 1);
  }
}

// ─── Config ──────────────────────────────────────────────────────────────────

class Config {
  constructor() {
    this.STATE     = 0;
    this.SONG_NAME = '';
    this.SHOW_CODE = false;
  }
}

// ─── Shared utilities ────────────────────────────────────────────────────────

function uiScale() {
  return Math.max(1.0, Math.min(width, height) / 1080.0);
}

function drawSongNameOnScreen(songName, nameX, nameY) {
  if (!songName) return;
  textSize(24 * uiScale());
  textAlign(CENTER);
  fill(0);
  text(songName, nameX + 2, nameY + 2);
  fill(255);
  text(songName, nameX, nameY);
}

// ─── Scene 0: Oscilloscope / Lissajous ───────────────────────────────────────
// Ported from OscilloscopeScene.pde (original state 5).
// L/R audio channels → X/Y axes. Simulated stereo via phase-shifted mono.
// Vignette clips accumulation outside a circular viewport.
// Canvas fades and resets every CYCLE_SECONDS.

class OscilloscopeScene {
  constructor() {
    this.gainX      = 2.2;
    this.gainY      = 2.2;
    this.trailAlpha = 28;
    this.brightness = 1.0;
    this.hue        = 180;
    this.pulse      = 0;

    this.CYCLE_SECONDS   = 20;
    this.FADE_OUT_FRAMES = 50;
    this.cycleStartMs    = 0;
    this.fadingOut       = false;
    this.fadeOutFrame    = 0;
  }

  adjustGainX(delta)  { this.gainX      = constrain(this.gainX + delta, 0.5, 6.0); }
  adjustGainY(delta)  { this.gainY      = constrain(this.gainY + delta, 0.5, 6.0); }
  adjustTrail(delta)  { this.trailAlpha = constrain(this.trailAlpha + delta, 5, 120); }
  adjustBrightness(d) { this.brightness = constrain(this.brightness + d, 0.2, 2.0); }

  drawScene() {
    let bufSize = audio.player.bufferSize();
    let fftSize = audio.fft.avgSize();
    let cx = width  / 2.0;
    let cy = height / 2.0;
    let vigR = min(width, height) * 0.44;

    if (this.cycleStartMs === 0) this.cycleStartMs = millis();
    let elapsed = millis() - this.cycleStartMs;
    if (!this.fadingOut && elapsed >= this.CYCLE_SECONDS * 1000) {
      this.fadingOut    = true;
      this.fadeOutFrame = 0;
    }

    let bassEnd = max(1, floor(fftSize / 6));
    let midEnd  = max(bassEnd + 1, floor(fftSize / 2));
    let bassAmp = 0, midAmp = 0, highAmp = 0;
    for (let i = 0;       i < bassEnd; i++) bassAmp += audio.fft.getAvg(i);
    for (let i = bassEnd; i < midEnd;  i++) midAmp  += audio.fft.getAvg(i);
    for (let i = midEnd;  i < fftSize; i++) highAmp += audio.fft.getAvg(i);
    bassAmp /= bassEnd;
    midAmp  /= max(1, midEnd  - bassEnd);
    highAmp /= max(1, fftSize - midEnd);
    let amplitude = (bassAmp + midAmp + highAmp) / 3.0;

    if (audio.beat.isOnset()) this.pulse = 1.0;
    this.pulse *= 0.90;
    this.hue = (this.hue + 0.5) % 360;

    // Phosphor trail: fade the whole canvas each frame
    let dynamicFade = this.fadingOut
      ? map(this.fadeOutFrame, 0, this.FADE_OUT_FRAMES, this.trailAlpha + midAmp * 8, 255)
      : this.trailAlpha + midAmp * 8;
    colorMode(RGB, 255);
    noStroke();
    fill(0, 0, 0, constrain(dynamicFade, 5, 255));
    rect(0, 0, width, height);

    if (this.fadingOut) {
      this.fadeOutFrame++;
      if (this.fadeOutFrame >= this.FADE_OUT_FRAMES) {
        background(0);
        this.fadingOut    = false;
        this.cycleStartMs = millis();
      }
      this._drawVignette(cx, cy, vigR);
      this._drawHUD(elapsed, vigR);
      drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
      return;
    }

    let xRange = (width  / 2.0) * this.gainX * (1.0 + highAmp * 0.4);
    let yRange = (height / 2.0) * this.gainY * (1.0 + bassAmp * 0.4);

    let strokeB    = constrain(this.brightness * 220 + this.pulse * 35, 80, 255);
    let weight     = constrain(1.0 + amplitude * 3.5, 0.8, 5.0);
    let dynamicHue = (this.hue + bassAmp * 30 - highAmp * 30 + 360) % 360;

    colorMode(HSB, 360, 255, 255, 255);
    stroke(dynamicHue, 200, floor(strokeB), 210);
    strokeWeight(weight);
    noFill();

    beginShape();
    for (let i = 0; i < bufSize; i++) {
      let x = cx + audio.player.left.get(i)  * xRange;
      let y = cy + audio.player.right.get(i) * yRange;
      vertex(x, y);
    }
    endShape();

    colorMode(RGB, 255);
    noStroke();
    fill(255, 220, 80, floor(this.pulse * 200));
    ellipse(cx, cy, 4 + this.pulse * 28, 4 + this.pulse * 28);

    this._drawVignette(cx, cy, vigR);
    this._drawHUD(elapsed, vigR);
    drawSongNameOnScreen(config.SONG_NAME, width / 2, height - 5);
  }

  _drawVignette(cx, cy, vigR) {
    colorMode(RGB, 255);
    noStroke();
    fill(0, 0, 0, 160);
    // Full-screen rect with a circular hole punched through it
    beginShape();
      vertex(0,     0);
      vertex(width, 0);
      vertex(width, height);
      vertex(0,     height);
      beginContour();
        for (let i = 0; i < 80; i++) {
          let a = -TWO_PI * i / 80;   // CCW = hole direction
          vertex(cx + cos(a) * vigR, cy + sin(a) * vigR);
        }
      endContour();
    endShape(CLOSE);

    noFill();
    stroke(255, 40);
    strokeWeight(1.2 * uiScale());
    ellipse(cx, cy, vigR * 2, vigR * 2);
  }

  _drawHUD(elapsedMs, vigR) {
    let cx = width / 2.0, cy = height / 2.0;
    let progress = constrain(elapsedMs / (this.CYCLE_SECONDS * 1000), 0, 1);
    let arcR = vigR + 6 * uiScale();

    colorMode(RGB, 255);
    noFill();
    stroke(255, 255, 255, 35);
    strokeWeight(2.5 * uiScale());
    ellipse(cx, cy, arcR * 2, arcR * 2);
    stroke(200, 220, 255, 120);
    arc(cx, cy, arcR * 2, arcR * 2, -HALF_PI, -HALF_PI + TWO_PI * progress);

    push();
      let ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 120); noStroke(); rectMode(CORNER);
      rect(8, 8, 240 * uiScale(), mg + lh * 5);
      fill(255); textSize(ts); textAlign(LEFT, TOP);
      text('Scene: Oscilloscope',                              12, 8 + mg);
      text('gainX: ' + nf(this.gainX, 1, 2)      + '  [ / ]', 12, 8 + mg + lh);
      text('gainY: ' + nf(this.gainY, 1, 2)      + '  - / =', 12, 8 + mg + lh * 2);
      text('trail: ' + nf(this.trailAlpha, 1, 1) + "  ; / '",  12, 8 + mg + lh * 3);
      let secLeft = max(0, this.CYCLE_SECONDS - floor(elapsedMs / 1000));
      text('reset in: ' + secLeft + 's' + (this.fadingOut ? '  (fading…)' : ''), 12, 8 + mg + lh * 4);
    pop();
  }
}

// ─── Scene 1: Radial FFT ─────────────────────────────────────────────────────
// Ported from RadialFFTScene.pde (original state 11).
// FFT spectrum as tapered spikes arranged in a rotating circle.

class RadialFFTScene {
  constructor() {
    this.rotation    = 0.0;
    this.rotSpeed    = 0.001;  // signed: + = CW, − = CCW
    this.scaleMult   = 1.0;
    this.beatPulse   = 0.0;
    this.spread      = 1.0;
    this.hueShift    = 0.0;
    this.palette     = 0;
    this.smoothAmp   = null;
    this.initialised = false;
  }

  reverseDirection() { this.rotSpeed = -this.rotSpeed; }
  adjustSpeed(delta) { this.rotSpeed = constrain(this.rotSpeed + delta, -0.015, 0.015); }
  cyclePalette()     { this.palette  = (this.palette + 1) % 4; }

  drawScene() {
    if (!this.initialised) {
      this.smoothAmp   = new Array(audio.fft.avgSize()).fill(0);
      this.initialised = true;
    }

    let N = audio.fft.avgSize();
    let bassEnd = max(1, floor(N / 6));
    let midEnd  = max(bassEnd + 1, floor(N / 2));
    let rawBass = 0, rawMid = 0, rawHigh = 0;

    for (let i = 0; i < N; i++) {
      let raw = audio.fft.getAvg(i);
      this.smoothAmp[i] = lerp(this.smoothAmp[i], raw * this.scaleMult, 0.25);
    }
    for (let i = 0;       i < bassEnd; i++) rawBass += this.smoothAmp[i];
    for (let i = bassEnd; i < midEnd;  i++) rawMid  += this.smoothAmp[i];
    for (let i = midEnd;  i < N;       i++) rawHigh += this.smoothAmp[i];
    rawBass /= bassEnd;
    rawMid  /= max(1, midEnd - bassEnd);
    rawHigh /= max(1, N - midEnd);

    if (audio.beat.isOnset()) {
      this.beatPulse = 1.0;
      this.hueShift  = (this.hueShift + random(40, 90)) % 360;
    }
    this.beatPulse *= 0.88;
    this.rotation  += this.rotSpeed + (this.rotSpeed >= 0 ? 1 : -1) * rawMid * 0.00008;

    background(4, 6, 16);

    colorMode(HSB, 360, 255, 255, 255);
    noStroke();
    let cx = width / 2.0, cy = height / 2.0;
    let maxR = min(width, height) * 0.62;
    for (let r = 5; r >= 1; r--) {
      fill(240, 180, 30, 8 + r * 3 + rawBass * 2);
      ellipse(cx, cy, maxR * r * 0.22 * 2, maxR * r * 0.22 * 2);
    }

    let innerR   = min(width, height) * (0.12 * this.spread);
    let outerR   = min(width, height) * 0.46;
    let burstOff = this.beatPulse * min(width, height) * 0.04;

    push();
    translate(cx, cy);

    for (let i = 0; i < N; i++) {
      let ang    = TWO_PI * i / N + this.rotation;
      let amp    = constrain(this.smoothAmp[i], 0, 28);
      let barLen = map(amp, 0, 14, 0, outerR - innerR);
      let inner  = innerR + burstOff;
      let outer  = inner + barLen;
      let halfW  = (TWO_PI / N) * 0.42;

      let t     = i / (N - 1);
      let hue   = this._getBarHue(t, amp);
      let sat   = constrain(200 + rawHigh * 5, 0, 255);
      let bri   = constrain(180 + amp * 3.5, 0, 255);
      let alpha = constrain(180 + amp * 4, 0, 255);

      fill(hue, sat, bri, alpha);
      beginShape(TRIANGLES);
        vertex(cos(ang - halfW) * inner, sin(ang - halfW) * inner);
        vertex(cos(ang + halfW) * inner, sin(ang + halfW) * inner);
        vertex(cos(ang)         * outer, sin(ang)         * outer);
      endShape();

      let mirrorLen   = barLen * 0.45;
      let mirrorInner = inner - mirrorLen;
      if (mirrorInner > 0) {
        fill(hue, sat, constrain(bri * 0.7, 0, 255), constrain(alpha * 0.5, 0, 255));
        beginShape(TRIANGLES);
          vertex(cos(ang - halfW) * inner,       sin(ang - halfW) * inner);
          vertex(cos(ang + halfW) * inner,       sin(ang + halfW) * inner);
          vertex(cos(ang)         * mirrorInner, sin(ang)         * mirrorInner);
        endShape();
      }
    }

    // Central glow disc
    let glowR = innerR * 0.7 + rawBass * 1.2 + this.beatPulse * innerR * 0.12;
    fill((this.hueShift + 20) % 360, 140, 255, 10 + this.beatPulse * 28);
    ellipse(0, 0, glowR * 2.4, glowR * 2.4);
    fill(this.hueShift % 360, 180, 255, 55 + this.beatPulse * 35);
    ellipse(0, 0, glowR * 1.4, glowR * 1.4);
    fill(0, 0, 255, 130 + this.beatPulse * 50);
    ellipse(0, 0, glowR * 0.45, glowR * 0.45);

    pop();
    colorMode(RGB, 255);

    let palNames = ['Spectrum', 'Heat', 'Ice', 'Mono'];
    push();
      let ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 160); noStroke(); rectMode(CORNER);
      rect(8, 8, 310 * uiScale(), mg + lh * 5);
      fill(255, 180, 80); textSize(ts); textAlign(LEFT, TOP);
      text('Radial FFT  (' + N + ' bands)',                          12, 8 + mg);
      fill(255, 220, 180);
      text('Palette: ' + palNames[this.palette] + '  (y cycle)',     12, 8 + mg + lh);
      text('Scale:   ' + nf(this.scaleMult, 1, 2),                   12, 8 + mg + lh * 2);
      text('Spin:    ' + nf(this.rotSpeed, 1, 4) + '  (r reverse)',  12, 8 + mg + lh * 3);
      text('← → scene  1-4 jump  space pause',                       12, 8 + mg + lh * 4);
    pop();

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  _getBarHue(t, amp) {
    switch (this.palette) {
      case 1:  return map(t, 0, 1, 0,   55);
      case 2:  return map(t, 0, 1, 175, 255);
      case 3:  return 160;
      default: return (this.hueShift + t * 270) % 360;
    }
  }
}

// ─── Scene 2: Aurora Ribbons ─────────────────────────────────────────────────
// Ported from AuroraRibbonsScene.pde (original state 10).
// Layered triangle-strip curtains with noise-driven sway, ADD blending.

class AuroraRibbonsScene {
  constructor() {
    this.drift             = 0.0;
    this.wind              = 0.35;
    this.ribbonLengthScale = 1.0;
    this.hueOffset         = 190;
    this.turbulence        = 1.0;
    this.beatFlash         = 0.0;
    this.beatSplit         = 0.0;

    this.lowFloor  = 0.4;  this.lowCeil  = 7.0;
    this.midFloor  = 0.3;  this.midCeil  = 6.0;
    this.highFloor = 0.2;  this.highCeil = 5.0;

    this.paletteIndex    = 0;
    this.paletteNames    = ['Arctic', 'Neon', 'Sunset', 'Void'];
    this.paletteHueShift = [0, 28, -32, 180];
    this.paletteSatMult  = [0.70, 1.15, 0.95, 0.55];
    this.paletteBriMult  = [1.05, 1.20, 1.10, 0.78];
  }

  triggerFlash() { this.beatFlash = 1.0; this.beatSplit = 1.0; }
  cyclePalette()  { this.paletteIndex = (this.paletteIndex + 1) % this.paletteNames.length; }

  _bandEnergy(startNorm, endNorm) {
    let n = max(1, audio.fft.avgSize());
    let s = constrain(floor(n * startNorm), 0, n - 1);
    let e = constrain(floor(n * endNorm), s + 1, n);
    let total = 0;
    for (let i = s; i < e; i++) total += audio.fft.getAvg(i);
    return total / max(1, e - s);
  }

  _normalizeAdaptive(raw, band) {
    let f, c;
    if (band === 0) {
      this.lowFloor = lerp(this.lowFloor, min(this.lowFloor, raw), 0.035);
      this.lowCeil  = lerp(this.lowCeil,  max(this.lowCeil * 0.997, raw), 0.04);
      f = this.lowFloor; c = this.lowCeil;
    } else if (band === 1) {
      this.midFloor = lerp(this.midFloor, min(this.midFloor, raw), 0.035);
      this.midCeil  = lerp(this.midCeil,  max(this.midCeil * 0.997, raw), 0.04);
      f = this.midFloor; c = this.midCeil;
    } else {
      this.highFloor = lerp(this.highFloor, min(this.highFloor, raw), 0.035);
      this.highCeil  = lerp(this.highCeil,  max(this.highCeil * 0.997, raw), 0.04);
      f = this.highFloor; c = this.highCeil;
    }
    return constrain((raw - f) / max(0.001, c - f), 0, 1);
  }

  drawScene() {
    background(4, 6, 14);
    blendMode(BLEND);

    let lowRaw  = this._bandEnergy(0.00, 0.20);
    let midRaw  = this._bandEnergy(0.20, 0.55);
    let highRaw = this._bandEnergy(0.55, 1.00);
    let low  = this._normalizeAdaptive(lowRaw,  0);
    let mid  = this._normalizeAdaptive(midRaw,  1);
    let high = this._normalizeAdaptive(highRaw, 2);

    if (audio.beat.isOnset()) { this.triggerFlash(); this.drift += 0.35; }
    this.beatFlash *= 0.90;
    this.beatSplit *= 0.86;
    this.drift     += 0.0035 * this.wind * (1.0 + high * 0.9);

    colorMode(HSB, 360, 255, 255, 255);
    noStroke();

    let pSat = this.paletteSatMult[this.paletteIndex];
    let pBri = this.paletteBriMult[this.paletteIndex];
    let pHue = this.paletteHueShift[this.paletteIndex];

    // Dark sky gradient
    for (let i = 0; i < 7; i++) {
      let yy    = map(i, 0, 6, 0, height);
      let bgHue = (this.hueOffset + pHue + 220 + i * 2) % 360;
      fill(bgHue, constrain((170 - i * 18) * pSat * 0.8, 0, 255), constrain((20 + i * 8) * pBri, 0, 255), 255);
      rect(0, yy, width, height / 7.0 + 1);
    }

    blendMode(ADD);
    for (let layer = 0; layer < 6; layer++) {
      let layerMix      = layer / 5.0;
      let len           = (height * (0.22 + layerMix * 0.12)) * this.ribbonLengthScale * (1.0 + low * 0.32);
      let spacing       = max(8, width / 70.0);
      let freq          = (0.004 + layerMix * 0.003) * this.turbulence;
      let speed         = 0.35 + layerMix * 0.6 + high * 0.35;
      let swayAmp       = (34 + layer * 12 + high * 22) * this.turbulence;
      let splitStrength = (10 + layer * 8) * this.beatSplit;

      beginShape(TRIANGLE_STRIP);
      for (let x = 0; x <= width + spacing; x += spacing) {
        let nx         = x * freq;
        let n1         = noise(nx + this.drift * speed,        frameCount * 0.0035 + layer * 13.0);
        let n2         = noise(nx + this.drift * speed + 33.0, frameCount * 0.0045 + layer * 19.0);
        let sway       = (n1 - 0.5) * swayAmp;
        let centerSide = (x < width * 0.5) ? -1.0 : 1.0;
        let topY       = map(n2, 0, 1, -20, 45 + layer * 14);
        let bottomY    = topY + len + (n1 - 0.5) * (65 + low * 35.0);
        let hue        = (this.hueOffset + pHue + layer * 17 + sin(frameCount * 0.01 + x * 0.015) * 16 + mid * 26) % 360;
        let sat        = constrain((170 + 65 * (1.0 - layerMix)) * pSat, 0, 255);
        let bri        = constrain((145 + layer * 14 + high * 90) * pBri, 0, 255);
        let split      = centerSide * splitStrength;

        fill(hue, sat, bri, 42 + layer * 10 + this.beatFlash * 65);
        vertex(x + sway + split, topY);
        fill(hue, sat * 0.8, bri * 0.8, 8 + layer * 3 + this.beatFlash * 20);
        vertex(x + sway * 0.35 + split * 0.38, bottomY);
      }
      endShape();
    }

    this._drawMist(high, pHue, pSat, pBri);

    if (this.beatFlash > 0.01) {
      blendMode(SCREEN);
      fill((this.hueOffset + pHue + 120) % 360, 40, 255, 80 * this.beatFlash);
      rect(0, 0, width, height);
    }

    blendMode(BLEND);
    colorMode(RGB, 255);
    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
    this._drawHud(low, mid, high);
  }

  _drawMist(highNorm, pHue, pSat, pBri) {
    let pCount = floor(24 + highNorm * 42);
    for (let i = 0; i < pCount; i++) {
      let t   = frameCount * 0.004 + i * 0.17;
      let x   = noise(i * 2.7, t + this.drift * 0.2) * width;
      let y   = height * (0.22 + noise(i * 5.1, t * 0.9) * 0.72);
      let r   = 1.2 + noise(i * 7.3, t * 1.1) * (2.0 + highNorm * 5.5);
      let hue = (this.hueOffset + pHue + noise(i * 9.7, t * 0.6) * 55) % 360;
      fill(hue, constrain((90 + highNorm * 120) * pSat, 0, 255), constrain((130 + highNorm * 105) * pBri, 0, 255), 10 + highNorm * 45);
      ellipse(x, y, r * 2, r * 2);
    }
  }

  _drawHud(low, mid, high) {
    push();
      let ts = 11 * uiScale(), lh = ts * 1.3;
      fill(0, 125); noStroke(); rectMode(CORNER);
      rect(8, 8, 390 * uiScale(), 8 + lh * 6.2);
      fill(255); textSize(ts); textAlign(LEFT, TOP);
      text('Scene: Aurora Ribbons',  12, 12);
      text('low/mid/high: ' + nf(low,1,2) + ' / ' + nf(mid,1,2) + ' / ' + nf(high,1,2), 12, 12 + lh);
      text('wind: ' + nf(this.wind,1,2) + '  len: ' + nf(this.ribbonLengthScale,1,2) + 'x', 12, 12 + lh * 2);
      text('turbulence: ' + nf(this.turbulence,1,2) + '  hue: ' + nf(this.hueOffset,1,1), 12, 12 + lh * 3);
      text('palette: ' + this.paletteNames[this.paletteIndex] + '  (k cycle)', 12, 12 + lh * 4);
      text('← → scene  1-4 jump  space pause', 12, 12 + lh * 5);
    pop();
  }
}

// ─── Scene 3: Spirograph ─────────────────────────────────────────────────────
// Ported from SpirographScene.pde (original state 12).
// Hypotrochoid drawn incrementally. Beat → next preset.

class SpirographScene {
  constructor() {
    this.t          = 0;
    this.tSpeed     = 0.04;
    this.curveR     = 0;
    this.curveScale = 1.0;
    this.bigR       = 5;
    this.smallR     = 3;
    this.penD       = 0;

    this.presets = [
      [5,3],[7,3],[8,3],[7,4],[9,4],
      [11,4],[7,5],[9,5],[11,6],[13,5],
      [8,5],[10,3],[12,5],[13,7],[6,5]
    ];
    this.presetIdx = 0;

    this.MAX_TRAIL = 8000;
    this.trailX    = new Float32Array(this.MAX_TRAIL);
    this.trailY    = new Float32Array(this.MAX_TRAIL);
    this.trailHead = 0;
    this.trailLen  = 0;

    this.fadeAlpha  = 1.0;
    this.fading     = false;

    this.smoothBass = 0;
    this.smoothMid  = 0;
    this.smoothHigh = 0;
    this.dNudge     = 0.0;
    this.speedMult  = 1.0;
    this.hueShift   = 0.0;
    this.palette    = 0;

    this.loadPreset(0);
  }

  loadPreset(idx) {
    this.presetIdx = idx % this.presets.length;
    this.bigR      = this.presets[this.presetIdx][0];
    this.smallR    = this.presets[this.presetIdx][1];
    this.curveR    = min(width, height) * 0.38;
    this.penD      = this.curveR * this.smallR / this.bigR * random(0.75, 1.15);
    this.t         = 0;
    this.trailHead = 0;
    this.trailLen  = 0;
    this.fading    = false;
    this.fadeAlpha = 1.0;
  }

  closingT() {
    let g = this._gcd(this.bigR, this.smallR);
    return TWO_PI * (this.bigR / g);
  }

  _gcd(a, b) {
    while (b !== 0) { let tmp = b; b = a % b; a = tmp; }
    return a;
  }

  cyclePalette() { this.palette = (this.palette + 1) % 4; }

  drawScene() {
    let fftSize = audio.fft.avgSize();
    let bassEnd = max(1, floor(fftSize / 6));
    let midEnd  = max(bassEnd + 1, floor(fftSize / 2));
    let rawBass = 0, rawMid = 0, rawHigh = 0;
    for (let i = 0;       i < bassEnd; i++) rawBass += audio.fft.getAvg(i);
    for (let i = bassEnd; i < midEnd;  i++) rawMid  += audio.fft.getAvg(i);
    for (let i = midEnd;  i < fftSize; i++) rawHigh += audio.fft.getAvg(i);
    rawBass /= bassEnd;
    rawMid  /= max(1, midEnd - bassEnd);
    rawHigh /= max(1, fftSize - midEnd);

    this.smoothBass = lerp(this.smoothBass, rawBass, 0.18);
    this.smoothMid  = lerp(this.smoothMid,  rawMid,  0.12);
    this.smoothHigh = lerp(this.smoothHigh, rawHigh, 0.22);
    this.hueShift   = (this.hueShift + 0.12 + this.smoothMid * 0.06) % 360;

    if (audio.beat.isOnset()) this.fading = true;

    if (!this.fading) {
      let speed = (this.tSpeed + this.smoothMid * 0.003) * this.speedMult;
      let steps = max(1, floor(speed / 0.01));
      let dt    = speed / steps;
      for (let s = 0; s < steps; s++) {
        this.t += dt;
        let d = this.penD + this.dNudge + this.smoothBass * (this.curveR * 0.025);
        let x = (this.curveR - this.curveR * this.smallR / this.bigR) * cos(this.t)
              + d * cos((this.bigR - this.smallR) / this.smallR * this.t);
        let y = (this.curveR - this.curveR * this.smallR / this.bigR) * sin(this.t)
              - d * sin((this.bigR - this.smallR) / this.smallR * this.t);
        this.trailX[this.trailHead] = x;
        this.trailY[this.trailHead] = y;
        this.trailHead = (this.trailHead + 1) % this.MAX_TRAIL;
        this.trailLen  = min(this.trailLen + 1, this.MAX_TRAIL);
      }
      if (this.t >= this.closingT() + 0.05) this.fading = true;
    }

    if (this.fading) {
      this.fadeAlpha -= 0.025;
      if (this.fadeAlpha <= 0) this.loadPreset(this.presetIdx + 1);
    }

    // Phosphor persistence
    colorMode(RGB, 255);
    noStroke();
    fill(0, 0, 0, this.fading ? 80 : 45);
    rectMode(CORNER);
    rect(0, 0, width, height);

    colorMode(HSB, 360, 255, 255, 255);
    let cx = width / 2.0, cy = height / 2.0;
    strokeWeight(1.5 + this.smoothHigh * 0.08);
    noFill();

    let startIdx = (this.trailHead - this.trailLen + this.MAX_TRAIL) % this.MAX_TRAIL;
    let prevX = 0, prevY = 0;
    for (let i = 0; i < this.trailLen; i++) {
      let idx = (startIdx + i) % this.MAX_TRAIL;
      let age = i / max(1, this.trailLen - 1);
      let px  = cx + this.trailX[idx] * this.curveScale;
      let py  = cy + this.trailY[idx] * this.curveScale;
      if (i === 0) { prevX = px; prevY = py; continue; }

      stroke(
        this._getTrailHue(age),
        constrain(200 + this.smoothHigh * 8, 0, 255),
        constrain(160 + age * 90 + this.smoothHigh * 6, 0, 255),
        constrain((age * 200 + 30) * this.fadeAlpha, 0, 255)
      );
      line(prevX, prevY, px, py);
      prevX = px; prevY = py;
    }

    if (this.trailLen > 0 && !this.fading) {
      let tipIdx = (this.trailHead - 1 + this.MAX_TRAIL) % this.MAX_TRAIL;
      let tx = cx + this.trailX[tipIdx] * this.curveScale;
      let ty = cy + this.trailY[tipIdx] * this.curveScale;
      noStroke();
      fill(this.hueShift, 100, 255, 200);
      ellipse(tx, ty, 8 + this.smoothHigh, 8 + this.smoothHigh);
      fill(0, 0, 255, 220);
      ellipse(tx, ty, 4, 4);
    }

    colorMode(RGB, 255);
    let palNames = ['Cycle', 'Warm', 'Cool', 'Mono'];
    push();
      let ts = 11 * uiScale(), lh = ts * 1.3, mg = 4 * uiScale();
      fill(0, 160); noStroke(); rectMode(CORNER);
      rect(8, 8, 320 * uiScale(), mg + lh * 6);
      fill(200, 180, 255); textSize(ts); textAlign(LEFT, TOP);
      text('Spirograph  R=' + this.bigR + ' r=' + this.smallR,     12, 8 + mg);
      fill(220, 210, 255);
      text('Palette: ' + palNames[this.palette] + '  (p cycle)',    12, 8 + mg + lh);
      text('Speed:   ' + nf(this.speedMult, 1, 2),                  12, 8 + mg + lh * 2);
      text('Pen:     ' + nf(this.penD + this.dNudge, 1, 1),         12, 8 + mg + lh * 3);
      text('Scale:   ' + nf(this.curveScale, 1, 2),                  12, 8 + mg + lh * 4);
      text('a = new curve   ' + nf(this.t / this.closingT() * 100, 1, 0) + '%', 12, 8 + mg + lh * 5);
    pop();
    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
  }

  _getTrailHue(age) {
    switch (this.palette) {
      case 1:  return map(age, 0, 1, 10,  60);
      case 2:  return map(age, 0, 1, 180, 260);
      case 3:  return 270;
      default: return (this.hueShift + age * 180) % 360;
    }
  }
}

// ─── p5.js lifecycle ─────────────────────────────────────────────────────────

function setup() {
  createCanvas(windowWidth, windowHeight);
  colorMode(RGB, 255);
  frameRate(60);

  config = new Config();
  audio  = new AudioWrapper();

  scenes.push(new OscilloscopeScene());   // 0
  scenes.push(new RadialFFTScene());      // 1
  scenes.push(new AuroraRibbonsScene());  // 2
  scenes.push(new SpirographScene());     // 3

  // Landing screen
  background(0);
  fill(160);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(16);
  text('Load a song to begin', width / 2, height / 2);
}

function draw() {
  audio.forward();

  if (!soundFile) {
    background(0);
    fill(130);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(16 * uiScale());
    text('Load a song to begin  →', width / 2, height / 2);
    return;
  }

  switch (config.STATE) {
    case 0: scenes[0].drawScene(); break;
    case 1: scenes[1].drawScene(); break;
    case 2: scenes[2].drawScene(); break;
    case 3: scenes[3].drawScene(); break;
  }
}

function keyPressed() {
  // Ensure AudioContext is running on key press
  getAudioContext().resume();

  // Scene navigation
  if (keyCode === RIGHT_ARROW) { nextScene(); return false; }
  if (keyCode === LEFT_ARROW)  { prevScene(); return false; }
  if (key === '1') switchScene(0);
  if (key === '2') switchScene(1);
  if (key === '3') switchScene(2);
  if (key === '4') switchScene(3);

  // Pause / resume
  if (key === ' ') { togglePlay(); return false; }

  // Oscilloscope (scene 0)
  if (config.STATE === 0) {
    if (key === '[') scenes[0].adjustGainX(0.2);
    if (key === ']') scenes[0].adjustGainX(-0.2);
    if (key === '-' || key === '_') scenes[0].adjustGainY(-0.2);
    if (key === '=' || key === '+') scenes[0].adjustGainY(0.2);
    if (key === ';') scenes[0].adjustTrail(-3);
    if (key === "'") scenes[0].adjustTrail(3);
  }

  // Radial FFT (scene 1)
  if (config.STATE === 1) {
    if (key === 'r' || key === 'R') scenes[1].reverseDirection();
    if (key === 'y' || key === 'Y') scenes[1].cyclePalette();
    if (key === '[') scenes[1].adjustSpeed(-0.001);
    if (key === ']') scenes[1].adjustSpeed(0.001);
  }

  // Aurora (scene 2)
  if (config.STATE === 2) {
    if (key === 'k' || key === 'K') scenes[2].cyclePalette();
  }

  // Spirograph (scene 3)
  if (config.STATE === 3) {
    if (key === 'a' || key === 'A') scenes[3].fading = true;
    if (key === 'p' || key === 'P') scenes[3].cyclePalette();
  }
}

function mousePressed() {
  // Ensure AudioContext starts on first click (browser autoplay policy)
  getAudioContext().resume();
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
}

// ─── Public API (called from index.html button handlers) ─────────────────────

function nextScene() { switchScene((config.STATE + 1) % scenes.length); }
function prevScene() { switchScene((config.STATE - 1 + scenes.length) % scenes.length); }

function switchScene(n) {
  config.STATE = n;
  let el = document.getElementById('scene-name');
  if (el) el.textContent = SCENE_NAMES[n];
}

function togglePlay() {
  if (!soundFile) return;
  if (soundFile.isPlaying()) soundFile.pause();
  else soundFile.loop();
  _updatePlayBtn();
}

function loadAudioFile(file) {
  getAudioContext().resume();

  // Stop and release previous sound
  if (soundFile) {
    try { soundFile.stop(); soundFile.disconnect(); } catch (e) {}
    soundFile = null;
  }

  let url = URL.createObjectURL(file);
  config.SONG_NAME = file.name.replace(/\.[^.]+$/, '');

  soundFile = loadSound(url, () => {
    // Callback fires once loaded
    audio._p5fft.setInput(soundFile);
    soundFile.loop();

    let songEl = document.getElementById('song-name');
    if (songEl) songEl.textContent = config.SONG_NAME;

    let playBtn = document.getElementById('btn-play');
    if (playBtn) playBtn.disabled = false;

    _updatePlayBtn();
  }, (err) => {
    console.error('Failed to load audio:', err);
    let songEl = document.getElementById('song-name');
    if (songEl) songEl.textContent = 'Load error — try another file';
    soundFile = null;
  });
}

function _updatePlayBtn() {
  let btn = document.getElementById('btn-play');
  if (!btn) return;
  btn.textContent = (soundFile && soundFile.isPlaying()) ? '⏸ Pause' : '▶ Play';
}
