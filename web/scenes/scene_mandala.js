/**
 * scene1.js — Fins / Diamonds / Waveform (port of Scene 1 from Processing)
 *
 * Draws into a centered square of side s1Size.
 * All coordinates are relative to (0,0) at the top-left of that square.
 * The caller (sketch.js) calls scene1.draw(pg) each frame where pg is a p5
 * graphics buffer of size s1Size × s1Size.
 */

class SceneMandala {
  constructor(p5instance) {
    this.p = p5instance;

    // Scene-local state
    this.frameCount = 0;
    this.dashDist = 0;
    this.DASH_PATTERN = 130;
    this.DASH_GAP = 110;

    // Tunnel & Plasma (lazy-init when first enabled)
    this.tunnel = null;
    this.plasma = null;
    this.polarPlasma = null;

    // Blend mode map (mirrors Processing modes array)
    // p5.js blend mode constants accessed via p5 instance
    this.modeNames = [
      'BLEND', 'ADD', 'SUBTRACT', 'EXCLUSION',
      'DIFFERENCE', 'MULTIPLY', 'SCREEN',
      'REPLACE'
    ];

    // Particle pool for beat bursts (not used in this scene, but wired up)
  }

  /** Call once s1Size is known so we can init tunnel/plasma lookup tables. */
  init(s1Size) {
    this.s1Size = s1Size;
    Config.initForSize(s1Size);
    this.tunnel = new TunnelEffect(this.p, s1Size, s1Size);
    this.plasma = new PlasmaEffect(this.p, s1Size, s1Size);
    this.polarPlasma = new PolarPlasmaEffect(this.p, s1Size, s1Size);
  }

  /** Called every frame by sketch.js.  pg = p5.Graphics buffer. */
  draw(pg) {
    const p = pg; // treat the graphics buffer as the drawing surface
    const s = this.s1Size;
    this.frameCount++;

    // ── Background ────────────────────────────────────────────────────────────
    // When no special background is active, fill with light grey (matches original Processing bg).
    // Using background() here fully clears the buffer each frame — which is what we want.
    // The pg1.clear() in sketch.js handles the alpha reset; this paints the visible colour.
    if (Config.BACKGROUND_ENABLED && !Config.DRAW_TUNNEL && !Config.DRAW_PLASMA && !Config.DRAW_POLAR_PLASMA) {
      // Dark background — fins and diamonds are mostly light/bright colours so dark gives
      // much better contrast than the original Processing grey (200). Press 'g' to toggle.
      p.background(18);
    } else if (!Config.DRAW_TUNNEL && !Config.DRAW_PLASMA && !Config.DRAW_POLAR_PLASMA) {
      // Background disabled — let blend modes stack on black
      p.background(0);
    }

    // ── Tunnel background ─────────────────────────────────────────────────────
    if (Config.DRAW_TUNNEL && this.tunnel) {
      this.tunnel.draw(p, Config.TUNNEL_ZOOM_INCREMENT, this.frameCount);
    }

    // ── Plasma background ─────────────────────────────────────────────────────
    if (Config.DRAW_PLASMA && this.plasma) {
      this.plasma.draw(p, Config.PLASMA_SEED, this.frameCount);
    }

    // ── Polar Plasma ──────────────────────────────────────────────────────────
    if (Config.DRAW_POLAR_PLASMA && this.polarPlasma) {
      this.polarPlasma.draw(p, this.frameCount);
    }

    // ── Audio analysis → react ────────────────────────────────────────────────
    audio.forward();

    // Beat → tunnel zoom
    if (audio.beat.isOnset()) {
      Config.TUNNEL_ZOOM_INCREMENT = (Config.TUNNEL_ZOOM_INCREMENT + 3) % 10000;
      this._applyBlendModeOnDrop(7);
    }

    this._splitFrequencyIntoLogBands();

    // Diamond distance clamping
    if (Config.DIAMOND_DISTANCE_FROM_CENTER >= Config.MAX_DIAMOND_DISTANCE) {
      Config.INCREMENT_DIAMOND_DISTANCE = false;
    } else if (Config.DIAMOND_DISTANCE_FROM_CENTER <= Config.MIN_DIAMOND_DISTANCE) {
      Config.INCREMENT_DIAMOND_DISTANCE = true;
    }

    // ── Animated fin count ────────────────────────────────────────────────────
    if (Config.ANIMATED) {
      if (Config.FIN_REDNESS_ANGRY) {
        Config.FIN_REDNESS += 1;
        Config.FINS += 0.02;
      } else {
        Config.FIN_REDNESS -= 1;
        Config.FINS -= 0.02;
      }
      if (Config.FIN_REDNESS >= 255) Config.FIN_REDNESS_ANGRY = false;
      else if (Config.FIN_REDNESS <= 0) Config.FIN_REDNESS_ANGRY = true;
    }

    // Periodic timer: allow fin direction change every 10 s
    const now = performance.now();
    if (now > Config.LAST_FIN_CHECK + 10000) {
      Config.canChangeFinDirection = true;
      Config.LAST_FIN_CHECK = now;
    }
    if (now > Config.LAST_PLASMA_CHECK + 10000) {
      Config.canChangePlasmaFlow = true;
      Config.PLASMA_INCREMENTING = !Config.PLASMA_INCREMENTING;
      Config.LAST_PLASMA_CHECK = now;
    }

    // ── Waveform ──────────────────────────────────────────────────────────────
    if (Config.DRAW_WAVEFORM) {
      this._drawWaveform(p, s);
    }

    // ── Diamonds ──────────────────────────────────────────────────────────────
    if (Config.DRAW_DIAMONDS) {
      p.push();
      this._drawDiamonds(p, s);
      p.pop();
    }

    // ── Bezier Fins ───────────────────────────────────────────────────────────
    if (Config.DRAW_FINS) {
      this._drawBezierFins(p, s, Config.FIN_REDNESS, Config.FINS, Config.finRotationClockWise);
    }

    // ── Dashed line offset ────────────────────────────────────────────────────
    this.dashDist += 0.2 * Config.DASH_LINE_SPEED;
    if (this.dashDist >= 10000 || this.dashDist <= -10000) this.dashDist = 0;

    // Song name is displayed in the nav bar by sketch.js — no need to draw it here too

    // ── Playback position bar ─────────────────────────────────────────────────
    if (audio.ready) {
      const dur = audio.player.length();
      if (dur > 0) {
        const posx = p.map(audio.player.position(), 0, dur, 0, s);
        p.push();
        p.stroke(252, 4, 243);
        p.strokeWeight(2);
        p.line(posx, s, posx, s * 0.975);
        p.pop();
      }
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  _drawWaveform(p, s) {
    const mix = audio.player.mix;
    const bufSz = mix.length;
    const r = (this.frameCount % 255) / 10.0;
    const g = (this.frameCount % 255) - 75;
    const b = (this.frameCount % 255);
    p.push();
    p.strokeWeight(4);
    p.strokeCap(p.ROUND);
    p.stroke(r, g, b);
    p.noFill();
    for (let i = 0; i < bufSz - 1; i++) {
      const x1 = p.map(i,   0, bufSz, 0, s);
      const x2 = p.map(i+1, 0, bufSz, 0, s);
      const y1 = s/2 + mix[i]   * Config.WAVE_MULTIPLIER;
      const y2 = s/2 + mix[i+1] * Config.WAVE_MULTIPLIER;
      p.line(x1, y1, x2, y2);
    }
    p.pop();
  }

  /** Draw a single dashed quad corner. Mirrors drawDiamond() in Processing. */
  _drawDashedQuad(p, x1, y1, x2, y2, x3, y3, x4, y4) {
    // Simulate dashed lines with segmented line drawing
    const pts = [[x1,y1],[x2,y2],[x3,y3],[x4,y4],[x1,y1]];
    for (let seg = 0; seg < 4; seg++) {
      const ax = pts[seg][0], ay = pts[seg][1];
      const bx = pts[seg+1][0], by = pts[seg+1][1];
      const len = Math.sqrt((bx-ax)**2+(by-ay)**2);
      let d = (this.dashDist % (this.DASH_PATTERN + this.DASH_GAP));
      if (d < 0) d += this.DASH_PATTERN + this.DASH_GAP;
      while (d < len) {
        const t0 = d / len;
        const t1 = Math.min((d + this.DASH_PATTERN) / len, 1);
        p.line(
          ax + t0*(bx-ax), ay + t0*(by-ay),
          ax + t1*(bx-ax), ay + t1*(by-ay)
        );
        d += this.DASH_PATTERN + this.DASH_GAP;
      }
    }
  }

  _drawOneDiamond(p, s, flipX, flipY) {
    const c = s / 2.0 + Config.DIAMOND_DISTANCE_FROM_CENTER;
    const rex = Config.DIAMOND_RIGHT_EDGE_X + Config.DIAMOND_WIDTH_OFFSET;
    const rey = Config.DIAMOND_RIGHT_EDGE_Y + Config.DIAMOND_HEIGHT_OFFSET;
    const lex = Config.DIAMOND_LEFT_EDGE_X  - Config.DIAMOND_WIDTH_OFFSET;
    const ley = Config.DIAMOND_LEFT_EDGE_Y  - Config.DIAMOND_HEIGHT_OFFSET;

    // Apply flip transformation
    const fx = flipX ? -1 : 1;
    const fy = flipY ? -1 : 1;
    const ox = flipX ? s : 0;
    const oy = flipY ? s : 0;

    const tx = (v) => ox + fx * v;
    const ty = (v) => oy + fy * v;

    this._drawDashedQuad(p,
      tx(c),   ty(c),
      tx(rex), ty(rey),
      tx(s),   ty(s),
      tx(lex), ty(ley)
    );
  }

  _drawDiamonds(p, s) {
    p.strokeWeight(5);
    p.strokeCap(p.SQUARE);
    p.stroke(255, 76, 52);
    p.noFill();

    // Four corners
    this._drawOneDiamond(p, s, false, false);
    this._drawOneDiamond(p, s, true,  false);
    this._drawOneDiamond(p, s, false, true);
    this._drawOneDiamond(p, s, true,  true);
  }

  _drawBezierFins(p, s, redness, fins, clockWise) {
    const xOffset = -20;
    const yOffset = Config.BEZIER_Y_OFFSET;

    if (Config.RAINBOW_FINS) p.colorMode(p.HSB, 360, 255, 255);

    p.strokeWeight(5);

    for (let i = 0; i < fins; i++) {
      if (Config.RAINBOW_FINS) {
        const hue = ((i / fins) * 360 + this.frameCount * 0.4 + Config.GLOBAL_REDNESS * 60) % 360;
        p.stroke(hue, 220, 255);
        p.noFill();
      } else {
        p.stroke(7);
        p.noFill();
      }

      p.push();
      let rotAmt = (2 * (i / fins) * Math.PI);
      if (clockWise) rotAmt = -rotAmt;

      p.translate(s/2, s/2);
      p.scale(1.75);
      // Add small per-frame random noise spin (same seed each frame for consistency)
      const noise = 0.01 + (((i * 7 + this.frameCount * 3) % 100) / 100) * 0.98;
      p.rotate(this.frameCount / 2.0 + noise);
      p.rotate(rotAmt);

      p.bezier(
        -36 + xOffset, -126 + yOffset,
        -36 + xOffset, -126 + yOffset,
         32 + xOffset, -118 + yOffset,
         68 + xOffset,  -52 + yOffset
      );
      p.bezier(
        -36 + xOffset, -126 + yOffset,
        -36 + xOffset, -126 + yOffset,
        -10 + xOffset,  -88 + yOffset,
        -22 + xOffset,  -52 + yOffset
      );
      p.bezier(
        -22 + xOffset,  -52 + yOffset,
        -22 + xOffset,  -52 + yOffset,
         20 + xOffset,  -74 + yOffset,
         68 + xOffset,  -52 + yOffset
      );
      p.pop();
    }

    if (Config.RAINBOW_FINS) p.colorMode(p.RGB, 255);
  }

  _drawSongName(p, s) {
    const name = Config.SONG_NAME || '';
    p.push();
    p.textSize(18);
    p.textAlign(p.CENTER, p.BOTTOM);
    p.fill(0);
    p.text(name, s/2 + 2, s - 3);
    p.fill(255);
    p.text(name, s/2, s - 5);
    p.pop();
  }

  _applyBlendModeOnDrop(intensity) {
    Config.FIN_REDNESS_ANGRY = true;
    if (Math.random() * 10 < intensity) {
      this._changeBlendMode();
    }
  }

  _changeBlendMode() {
    const len = this.modeNames.length;
    Config.CURRENT_BLEND_MODE_INDEX = (Config.CURRENT_BLEND_MODE_INDEX + 1) % len;
  }

  _splitFrequencyIntoLogBands() {
    const size = audio.fft.avgSize();
    for (let i = 0; i < size; i++) {
      const amplitude = audio.fft.getAvg(i);
      const bandDB = 20 * Math.log10(Math.max(1e-10, 2 * amplitude / audio.fft.timeSize()));

      if (i >= 0 && i <= 5 && bandDB > -10) {
        this._applyBlendModeOnDrop(3);
        this._changeDashedLineSpeed(0.2);
      }

      if (i >= 6 && i <= 15 && bandDB > -27) {
        this._modifyDiamondCenterPoint(Config.INCREMENT_DIAMOND_DISTANCE);
      }

      if (Config.canChangeFinDirection && i >= 16 && i <= 35 && bandDB > -150) {
        Config.finRotationClockWise = !Config.finRotationClockWise;
        Config.canChangeFinDirection = false;
      }

      if (i >= 35 && i <= 36 && bandDB > -130) {
        this._changePlasmaFlow(1);
        this._changeDashedLineSpeed(0.1);
      }

      if (i >= 40 && i <= 41 && bandDB > -130) {
        Config.PLASMA_INCREMENTING = !Config.PLASMA_INCREMENTING;
      }
    }
  }

  _changeDashedLineSpeed(amount) {
    if (Config.DASH_LINE_SPEED > Config.DASH_LINE_SPEED_LIMIT) {
      Config.DASH_LINE_SPEED_INCREASING = false;
    } else if (Config.DASH_LINE_SPEED < -Config.DASH_LINE_SPEED_LIMIT) {
      Config.DASH_LINE_SPEED_INCREASING = true;
    }
    if (Config.DASH_LINE_SPEED_INCREASING) {
      Config.DASH_LINE_SPEED += amount;
    } else {
      Config.DASH_LINE_SPEED -= amount;
    }
  }

  _modifyDiamondCenterPoint(closer) {
    const delta = (typeof width !== 'undefined' ? width : 1200) * 0.02;
    if (closer) {
      Config.DIAMOND_DISTANCE_FROM_CENTER += delta;
    } else {
      Config.DIAMOND_DISTANCE_FROM_CENTER -= delta;
    }
  }

  _changePlasmaFlow(amount) {
    if (Math.random() * 10 > 6 && Config.canChangePlasmaFlow) {
      const max = Config.PLASMA_SIZE / 2 - 1;
      if (Config.PLASMA_INCREMENTING) {
        Config.PLASMA_SEED = (Config.PLASMA_SEED + Math.abs(amount)) % max;
      } else {
        Config.PLASMA_SEED = ((Config.PLASMA_SEED - amount) % max + max) % max;
      }
    }
  }

  /** Get the p5 blend mode constant for the current index. */
  getBlendMode(p) {
    const modes = [
      p.BLEND, p.ADD, p.SUBTRACT, p.EXCLUSION,
      p.DIFFERENCE, p.MULTIPLY, p.SCREEN, p.REPLACE
    ];
    return modes[Config.CURRENT_BLEND_MODE_INDEX % modes.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tunnel effect — pixel shader with pre-computed lookup table
// Mirrors Tunnel.pde exactly.
// ─────────────────────────────────────────────────────────────────────────────
class TunnelEffect {
  constructor(p, w, h) {
    this.w = w;
    this.h = h;
    this.TEX_SIZE = 128;

    // Pre-compute texture (once)
    this.texture = new Uint32Array(this.TEX_SIZE * this.TEX_SIZE);
    for (let j = 0; j < this.TEX_SIZE; j++) {
      for (let i = 0; i < this.TEX_SIZE; i++) {
        const r = (i ^ j) & 0xff;
        let g = (((i >> 6) & 1) ^ ((j >> 6) & 1)) ? 255 : 0;
        g = ((g * 5 + 3 * r) >> 3) & 0xff;
        this.texture[this.TEX_SIZE * j + i] = 0xff000000 | (g << 16) | (g << 8) | g;
      }
    }

    // Pre-compute lookup table (once)
    this.lut = new Int32Array(w * h);
    for (let j = h - 1; j > 0; j--) {
      for (let i = w - 1; i > 0; i--) {
        const x = -1.0 + i * (2.0 / w);
        const y =  1.0 - j * (2.0 / h);
        const rr = Math.sqrt(x*x + y*y);
        const a  = Math.atan2(x, y);
        const u = 1.0 / rr;
        const v = a / Math.PI;
        let ww = rr * rr;
        if (ww > 1.0) ww = 1.0;
        const iu = (u * 255) & 0xff;
        const iv = (v * 255 + 255) & 0xff;  // shift to positive
        const iw = (ww * 255) & 0xff;
        this.lut[w * j + i] = (iw << 16) | (iv << 8) | iu;
      }
    }
  }

  draw(p, tunnelZoomIncrement, frame) {
    p.loadPixels();
    const tex = this.texture;
    const lut = this.lut;
    const pix = p.pixels;
    const maskSz = (this.TEX_SIZE * this.TEX_SIZE) - 1;
    const timeShift = (frame + tunnelZoomIncrement) << 1;

    for (let i = 0; i < this.w * this.h; i++) {
      const val = lut[i];
      if (val === 0) continue; // avoid div-by-zero at center
      const iu = val & 0xff;
      const iv = (val >> 8) & 0xff;
      const iw = (val >> 16) & 0xff;
      const texIdx = ((iu + iv * 256 + timeShift)) & maskSz;
      const col = tex[texIdx] & 0xffffff;
      const base = i * 4;
      pix[base]   = (col >> 16) & 0xff;
      pix[base+1] = (col >> 8)  & 0xff;
      pix[base+2] =  col        & 0xff;
      pix[base+3] = iw;  // alpha = distance fog
    }
    p.updatePixels();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plasma effect — animated colour palette cycling
// Mirrors Plasma.pde exactly.
// ─────────────────────────────────────────────────────────────────────────────
class PlasmaEffect {
  constructor(p, w, h) {
    this.w = w;
    this.h = h;
    const PLASMA_SIZE = Config.PLASMA_SIZE; // 128

    // Build colour palette
    this.pal = new Uint32Array(PLASMA_SIZE);
    for (let i = 0; i < PLASMA_SIZE; i++) {
      const s1 = Math.sin(i * Math.PI / 25);
      const r = Math.round(128 + s1 * 128);
      const g = Math.round(Math.random() * 255);
      const bv = Math.round(Math.random() * 255);
      this.pal[i] = 0xff000000 | (r << 16) | (g << 8) | bv;
    }

    // Pre-compute class map (normalised index 0..PLASMA_SIZE-1)
    this.cls = new Uint8Array(w * h);
    const bubbleSize = 24 + Math.random() * 104;
    for (let x = 0; x < w; x++) {
      for (let y = 0; y < h; y++) {
        const v = (
          (127.5 + 127.5 * Math.sin(x / bubbleSize)) +
          (127.5 + 127.5 * Math.cos(y / bubbleSize)) +
          (127.5 + 127.5 * Math.sin(Math.sqrt(x*x + y*y) / bubbleSize))
        ) / 4;
        this.cls[x + y * w] = Math.floor(v) & (PLASMA_SIZE - 1);
      }
    }
  }

  draw(p, plasmaSeed, _frame) {
    p.loadPixels();
    const pix = p.pixels;
    const cls = this.cls;
    const pal = this.pal;
    const mask = Config.PLASMA_SIZE - 1;

    for (let i = 0; i < cls.length; i++) {
      const c = pal[(cls[i] + plasmaSeed) & mask];
      const base = i * 4;
      pix[base]   = (c >> 16) & 0xff;
      pix[base+1] = (c >> 8)  & 0xff;
      pix[base+2] =  c        & 0xff;
      pix[base+3] = 255;
    }
    p.updatePixels();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Polar Plasma — rotating radial plasma pattern
// ─────────────────────────────────────────────────────────────────────────────
class PolarPlasmaEffect {
  constructor(p, w, h) {
    this.w = w;
    this.h = h;
    const PLASMA_SIZE = Config.PLASMA_SIZE;
    const cx = w / 2, cy = h / 2;

    this.pal = new Uint32Array(PLASMA_SIZE);
    for (let i = 0; i < PLASMA_SIZE; i++) {
      const t = i / PLASMA_SIZE;
      const r = Math.round(128 + 127 * Math.sin(t * Math.PI * 2));
      const g = Math.round(128 + 127 * Math.sin(t * Math.PI * 2 + 2.094));
      const bv= Math.round(128 + 127 * Math.sin(t * Math.PI * 2 + 4.189));
      this.pal[i] = 0xff000000 | (r << 16) | (g << 8) | bv;
    }

    this.cls = new Float32Array(w * h);
    for (let x = 0; x < w; x++) {
      for (let y = 0; y < h; y++) {
        const dx = x - cx, dy = y - cy;
        const r = Math.sqrt(dx*dx + dy*dy) / (w * 0.4);
        const a = Math.atan2(dy, dx) / (Math.PI * 2) + 0.5;
        this.cls[x + y*w] = (r + a) * PLASMA_SIZE;
      }
    }
  }

  draw(p, frame) {
    p.loadPixels();
    const pix = p.pixels;
    const cls = this.cls;
    const pal = this.pal;
    const mask = Config.PLASMA_SIZE - 1;
    const shift = frame >> 1;

    for (let i = 0; i < cls.length; i++) {
      const c = pal[(Math.floor(cls[i]) + shift) & mask];
      const base = i * 4;
      pix[base]   = (c >> 16) & 0xff;
      pix[base+1] = (c >> 8)  & 0xff;
      pix[base+2] =  c        & 0xff;
      pix[base+3] = 255;
    }
    p.updatePixels();
  }
}

// Export as global
const sceneMandala = new SceneMandala(null); // p5 instance injected later in sketch.js
