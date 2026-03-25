/**
 * scene11.js — Lobster Scene 🦞
 * An original creative scene by xdd the AI, celebrating the web launch.
 *
 * Features:
 *   - 4 animated vector-drawn lobsters (bezier body, claws, legs, antennae, eyes)
 *   - Underwater ambiance: animated blue-green gradient, rising bubbles
 *   - Music reactivity: body pulses with bass, claws snap on beats,
 *     antennae wiggle with high-frequency FFT energy
 *   - Beat: bright red flash + particle burst from claws + shockwave ring
 *   - Object pool for particles (pre-allocated, no new() per frame)
 *   - "🦾 xdd" watermark bottom-right
 */

class SceneLobsters {
  constructor() {
    this.lobsters  = [];
    this.bubbles   = [];
    this.particles = [];    // pre-allocated pool
    this.shockwaves= [];    // pre-allocated pool

    this.PARTICLE_POOL_SIZE  = 300;
    this.SHOCKWAVE_POOL_SIZE = 20;
    this.BUBBLE_COUNT = 40;

    this.initialized = false;
    this.frameCount  = 0;

    // Pre-compute gradient colours (updated per frame but stored to avoid alloc)
    this._gradColors = [];
  }

  /** Lazy init — call once p5 & canvas dimensions are known. */
  init(p) {
    if (this.initialized) return;
    this.initialized = true;

    // Pre-allocate particle pool
    this.particles = [];
    for (let i = 0; i < this.PARTICLE_POOL_SIZE; i++) {
      this.particles.push({ active: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, maxLife: 30, r: 255, g: 80, b: 20, size: 4 });
    }

    // Pre-allocate shockwave pool
    this.shockwaves = [];
    for (let i = 0; i < this.SHOCKWAVE_POOL_SIZE; i++) {
      this.shockwaves.push({ active: false, x: 0, y: 0, r: 0, maxR: 150, life: 0, maxLife: 40 });
    }

    // Create bubbles
    this.bubbles = [];
    for (let i = 0; i < this.BUBBLE_COUNT; i++) {
      this.bubbles.push(this._newBubble(p, true));
    }

    // Create 4 lobsters at different positions
    const positions = [
      { x: p.width * 0.18, y: p.height * 0.45, scale: 1.0,  speed: 0.7, phase: 0    },
      { x: p.width * 0.42, y: p.height * 0.3,  scale: 0.85, speed: 0.5, phase: 1.2  },
      { x: p.width * 0.68, y: p.height * 0.55, scale: 1.1,  speed: 0.6, phase: 2.5  },
      { x: p.width * 0.82, y: p.height * 0.35, scale: 0.75, speed: 0.9, phase: 0.7  },
    ];

    this.lobsters = positions.map(pos => new Lobster(pos));
  }

  _newBubble(p, randomY) {
    return {
      x: p.random(p.width),
      y: randomY ? p.random(p.height) : p.height + 10,
      r: p.random(3, 12),
      speed: p.random(0.5, 2.0),
      wobble: p.random(0, Math.PI * 2),
      wobbleSpeed: p.random(0.02, 0.06),
      alpha: p.random(80, 180),
    };
  }

  /** Spawn particles from a lobster claw position. */
  _spawnParticles(x, y, count) {
    let spawned = 0;
    for (let i = 0; i < this.particles.length && spawned < count; i++) {
      const p = this.particles[i];
      if (!p.active) {
        p.active = true;
        p.x = x; p.y = y;
        const angle = Math.random() * Math.PI * 2;
        const speed = 2 + Math.random() * 5;
        p.vx = Math.cos(angle) * speed;
        p.vy = Math.sin(angle) * speed - 2; // slight upward bias
        p.life = 0;
        p.maxLife = 25 + Math.floor(Math.random() * 20);
        // Random orange/red/yellow hues
        p.r = 220 + Math.random() * 35;
        p.g = 50  + Math.random() * 120;
        p.b = 0   + Math.random() * 40;
        p.size = 3 + Math.random() * 5;
        spawned++;
      }
    }
  }

  /** Spawn a shockwave ring. */
  _spawnShockwave(x, y) {
    for (let i = 0; i < this.shockwaves.length; i++) {
      const sw = this.shockwaves[i];
      if (!sw.active) {
        sw.active = true;
        sw.x = x; sw.y = y;
        sw.r = 0;
        sw.maxR = 120 + Math.random() * 80;
        sw.life = 0;
        sw.maxLife = 40;
        return;
      }
    }
  }

  /** Main draw — called every frame by sketch.js */
  draw(p) {
    this.init(p);
    this.frameCount++;

    // ── Audio analysis ────────────────────────────────────────────────────────
    audio.forward();
    const beatOnset = audio.beat.isOnset();

    // Bass energy (bands 0-5) for body pulse
    let bassEnergy = 0;
    for (let i = 0; i < Math.min(6, audio.fft.avgSize()); i++) {
      bassEnergy += audio.fft.getAvg(i);
    }
    bassEnergy = Math.min(bassEnergy / 6 * 200, 1); // normalise 0..1

    // High-freq energy (bands 25+) for antenna wiggle
    let hiEnergy = 0;
    const hiStart = Math.floor(audio.fft.avgSize() * 0.6);
    for (let i = hiStart; i < audio.fft.avgSize(); i++) {
      hiEnergy += audio.fft.getAvg(i);
    }
    const hiCount = audio.fft.avgSize() - hiStart;
    hiEnergy = hiCount > 0 ? Math.min(hiEnergy / hiCount * 300, 1) : 0;

    // ── Underwater gradient background ────────────────────────────────────────
    this._drawBackground(p, bassEnergy);

    // ── Bubbles ───────────────────────────────────────────────────────────────
    this._updateDrawBubbles(p);

    // ── Shockwaves ────────────────────────────────────────────────────────────
    for (const sw of this.shockwaves) {
      if (!sw.active) continue;
      sw.r += sw.maxR / sw.maxLife;
      sw.life++;
      if (sw.life >= sw.maxLife) { sw.active = false; continue; }
      const alpha = p.map(sw.life, 0, sw.maxLife, 200, 0);
      p.push();
      p.noFill();
      p.stroke(255, 180, 50, alpha);
      p.strokeWeight(3);
      p.ellipse(sw.x, sw.y, sw.r * 2, sw.r * 2);
      p.pop();
    }

    // ── Lobsters ──────────────────────────────────────────────────────────────
    for (const lob of this.lobsters) {
      if (beatOnset) {
        lob.triggerBeat();
        this._spawnParticles(lob.clawLPos.x, lob.clawLPos.y, 8);
        this._spawnParticles(lob.clawRPos.x, lob.clawRPos.y, 8);
        this._spawnShockwave(lob.x, lob.y);
      }
      lob.update(this.frameCount, bassEnergy, hiEnergy);
      lob.draw(p);
    }

    // ── Particles ─────────────────────────────────────────────────────────────
    for (const pt of this.particles) {
      if (!pt.active) continue;
      pt.x += pt.vx;
      pt.y += pt.vy;
      pt.vy += 0.15; // gravity
      pt.life++;
      if (pt.life >= pt.maxLife) { pt.active = false; continue; }
      const alpha = p.map(pt.life, 0, pt.maxLife, 255, 0);
      const fade = 1 - pt.life / pt.maxLife;
      p.push();
      p.noStroke();
      p.fill(pt.r, pt.g, pt.b, alpha);
      p.ellipse(pt.x, pt.y, pt.size * fade * 2);
      p.pop();
    }

    // ── Watermark ─────────────────────────────────────────────────────────────
    p.push();
    p.textSize(14);
    p.textAlign(p.RIGHT, p.BOTTOM);
    p.fill(255, 255, 255, 60);
    p.noStroke();
    p.text('🦾 xdd', p.width - 12, p.height - 8);
    p.pop();
  }

  _drawBackground(p, bassEnergy) {
    // Slow-shifting blue-green gradient
    const t = this.frameCount * 0.003;
    const topR  = Math.round(0  + Math.sin(t)       * 10);
    const topG  = Math.round(20 + Math.sin(t * 0.7) * 15);
    const topB  = Math.round(40 + Math.sin(t * 0.5) * 20 + bassEnergy * 15);
    const botR  = Math.round(0  + Math.sin(t + 1)   * 8);
    const botG  = Math.round(40 + Math.cos(t * 0.6) * 20);
    const botB  = Math.round(80 + Math.cos(t * 0.4) * 30 + bassEnergy * 20);

    // Draw gradient via horizontal strips
    const steps = 40;
    for (let i = 0; i < steps; i++) {
      const frac = i / steps;
      const r = p.lerp(topR, botR, frac);
      const g = p.lerp(topG, botG, frac);
      const b = p.lerp(topB, botB, frac);
      p.noStroke();
      p.fill(r, g, b);
      p.rect(0, (i / steps) * p.height, p.width, p.height / steps + 1);
    }

    // Subtle caustic light patterns
    p.noFill();
    for (let i = 0; i < 6; i++) {
      const cx = p.width  * (0.1 + 0.15 * i + Math.sin(t * 0.3 + i) * 0.05);
      const cy = p.height * (0.1 + Math.cos(t * 0.2 + i * 1.3) * 0.1);
      const r  = 30 + i * 20 + Math.sin(t + i) * 15;
      p.stroke(100, 200, 220, 15);
      p.strokeWeight(1);
      p.ellipse(cx, cy, r * 2, r * 2);
    }
  }

  _updateDrawBubbles(p) {
    for (let i = 0; i < this.bubbles.length; i++) {
      const b = this.bubbles[i];
      b.y -= b.speed;
      b.wobble += b.wobbleSpeed;
      const wx = b.x + Math.sin(b.wobble) * 3;

      if (b.y < -b.r * 2) {
        this.bubbles[i] = this._newBubble(p, false);
        continue;
      }

      p.push();
      p.noFill();
      p.stroke(180, 230, 255, b.alpha);
      p.strokeWeight(1.5);
      p.ellipse(wx, b.y, b.r * 2, b.r * 2);
      // Bubble highlight
      p.stroke(255, 255, 255, b.alpha * 0.6);
      p.strokeWeight(1);
      p.ellipse(wx - b.r * 0.25, b.y - b.r * 0.25, b.r * 0.5, b.r * 0.5);
      p.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lobster class — drawn entirely with vector graphics
// ─────────────────────────────────────────────────────────────────────────────
class Lobster {
  constructor({ x, y, scale, speed, phase }) {
    this.x     = x;
    this.y     = y;
    this.scale = scale;
    this.speed = speed;
    this.phase = phase;  // animation phase offset

    // Swimming motion
    this.bobPhase  = phase;
    this.swimPhase = phase;

    // Claw snap state
    this.clawSnap     = 0;     // 0..1, snaps to 1 on beat, decays
    this.bodyPulse    = 0;     // 0..1, bass energy
    this.flashAlpha   = 0;     // beat flash intensity (decays)
    this.antennaWave  = 0;     // high-freq energy for antenna wiggle

    // Pre-computed claw world positions (updated each frame for particle spawning)
    this.clawLPos = { x: 0, y: 0 };
    this.clawRPos = { x: 0, y: 0 };

    // Walking leg phase
    this.legPhase = phase;
  }

  triggerBeat() {
    this.clawSnap   = 1.0;
    this.flashAlpha = 1.0;
  }

  update(frame, bassEnergy, hiEnergy) {
    // Bob up and down
    this.bobPhase  += this.speed * 0.015;
    this.swimPhase += this.speed * 0.008;
    this.legPhase  += this.speed * 0.05;

    this.bodyPulse  = bassEnergy;
    this.antennaWave = hiEnergy;

    // Decay claw snap and flash
    this.clawSnap   *= 0.85;
    this.flashAlpha *= 0.88;
  }

  draw(p) {
    const s  = this.scale;
    const bx = this.x + Math.sin(this.swimPhase) * 30;
    const by = this.y + Math.sin(this.bobPhase)  * 15;
    const tilt = Math.sin(this.swimPhase) * 0.08; // gentle side tilt

    p.push();
    p.translate(bx, by);
    p.rotate(tilt);

    // Beat flash overlay
    if (this.flashAlpha > 0.05) {
      p.noStroke();
      p.fill(255, 80, 20, this.flashAlpha * 120);
      p.ellipse(0, 0, 160 * s, 80 * s);
    }

    // Pulse scale from bass
    const ps = 1 + this.bodyPulse * 0.12;
    p.scale(ps);

    this._drawBody(p, s);
    this._drawTailFan(p, s);
    this._drawLegs(p, s);
    this._drawClaws(p, s, bx, by);
    this._drawAntennae(p, s);
    this._drawEyes(p, s);

    p.pop();
  }

  _lobsterColor(p, alpha) {
    // Deep red-orange, brighter on flash
    const bright = 1 + this.flashAlpha * 0.5;
    p.fill(
      Math.min(255, 180 * bright),
      Math.min(255, 40  * bright),
      Math.min(255, 20  * bright),
      alpha || 255
    );
  }

  _drawBody(p, s) {
    p.push();
    // Main carapace — segmented oval
    p.strokeWeight(1.5);
    p.stroke(120, 20, 10);
    this._lobsterColor(p);

    // Abdomen segments (back)
    for (let i = 0; i < 5; i++) {
      const segY = 10 * s + i * 12 * s;
      const segW = (55 - i * 4) * s;
      const segH = 11 * s;
      p.ellipse(0, segY, segW, segH);
    }

    // Cephalothorax (main shell)
    p.ellipse(0, -10 * s, 60 * s, 45 * s);

    // Rostrum (pointy nose)
    p.stroke(120, 20, 10);
    p.strokeWeight(1.5);
    p.fill(160, 30, 15);
    p.triangle(
      -5 * s, -28 * s,
       5 * s, -28 * s,
       0,     -50 * s
    );

    // Shell ridge lines
    p.stroke(120, 20, 10, 120);
    p.strokeWeight(1);
    p.noFill();
    p.arc(0, -10 * s, 50 * s, 35 * s, -p.PI * 0.7, -p.PI * 0.3);
    p.arc(0, -10 * s, 40 * s, 25 * s, -p.PI * 0.6, -p.PI * 0.4);

    p.pop();
  }

  _drawTailFan(p, s) {
    p.push();
    p.translate(0, 68 * s);
    p.stroke(110, 15, 8);
    p.strokeWeight(1.2);
    this._lobsterColor(p);

    // 5 tail fan segments
    for (let i = -2; i <= 2; i++) {
      const angle = i * 0.28;
      const len   = (i === 0 ? 28 : 22) * s;
      const wid   = (i === 0 ? 18 : 14) * s;
      p.push();
      p.rotate(angle);
      p.ellipse(0, len * 0.6, wid, len);
      p.pop();
    }
    p.pop();
  }

  _drawLegs(p, s) {
    // 8 walking legs (4 pairs, each side)
    p.stroke(130, 25, 12);
    p.strokeWeight(1.5);
    p.noFill();

    for (let i = 0; i < 4; i++) {
      const legY = (-5 + i * 12) * s;
      const legPhaseOffset = i * 0.4;
      const swing = Math.sin(this.legPhase + legPhaseOffset) * 8 * s;

      // Left leg
      p.push();
      p.translate(-28 * s, legY);
      p.bezier(
        0, 0,
        -15 * s, 5 * s + swing,
        -28 * s, 12 * s + swing,
        -36 * s, 20 * s + swing * 0.5
      );
      p.pop();

      // Right leg
      p.push();
      p.translate(28 * s, legY);
      p.bezier(
        0, 0,
        15 * s, 5 * s - swing,
        28 * s, 12 * s - swing,
        36 * s, 20 * s - swing * 0.5
      );
      p.pop();
    }
  }

  _drawClaws(p, s, worldX, worldY) {
    // Two large front claws (chelipeds)
    const snapAngle = this.clawSnap * 0.5; // how open the claw is

    for (const side of [-1, 1]) {
      p.push();
      p.translate(side * 32 * s, -22 * s);

      // Arm (merus + carpus)
      p.stroke(110, 18, 8);
      p.strokeWeight(2);
      this._lobsterColor(p);

      p.push();
      p.rotate(side * 0.35);
      // Upper arm
      p.bezier(
        0, 0,
        side * 18 * s, -5 * s,
        side * 35 * s, 5 * s,
        side * 42 * s, 15 * s
      );

      // Claw tip transform
      p.translate(side * 42 * s, 15 * s);
      p.rotate(side * 0.2);

      // Fixed finger (dactylus)
      p.push();
      p.rotate(snapAngle * 0.5);
      p.ellipse(0, 0, 28 * s, 12 * s);
      p.ellipse(side * 14 * s, -4 * s, 16 * s, 7 * s);
      p.pop();

      // Moveable finger (pollex) — snaps shut on beat
      p.push();
      p.rotate(-snapAngle);
      p.ellipse(0, 6 * s, 24 * s, 9 * s);
      p.ellipse(side * 12 * s, 10 * s, 14 * s, 6 * s);
      p.pop();
      p.pop();

      // Record claw world position for particle spawns (plain math, no createVector needed)
      const cwx = side * 32 * s + side * 42 * s;
      const cwy = -22 * s + 15 * s;
      if (side === -1) {
        this.clawLPos.x = worldX + cwx;
        this.clawLPos.y = worldY + cwy;
      } else {
        this.clawRPos.x = worldX + cwx;
        this.clawRPos.y = worldY + cwy;
      }
      p.pop();
    }
  }

  _drawAntennae(p, s) {
    // Two long antennae — wiggle with hi-freq energy
    const wiggle = this.antennaWave * 20 * s;
    const baseWave = Math.sin(this.bobPhase * 3) * 5 * s;

    p.stroke(140, 30, 15);
    p.strokeWeight(1.2);
    p.noFill();

    // Left antenna
    p.bezier(
      -12 * s, -48 * s,
      -30 * s, -90 * s + baseWave,
      -60 * s, -130 * s + wiggle,
      -90 * s, -160 * s + baseWave + wiggle
    );

    // Right antenna
    p.bezier(
       12 * s, -48 * s,
       30 * s, -90 * s - baseWave,
       60 * s, -130 * s - wiggle,
       90 * s, -160 * s - baseWave - wiggle
    );

    // Short antennules (small pair)
    p.strokeWeight(0.8);
    p.line(-8 * s, -45 * s, -22 * s, -70 * s);
    p.line( 8 * s, -45 * s,  22 * s, -70 * s);
  }

  _drawEyes(p, s) {
    // Eyes on stalks
    p.stroke(80, 10, 5);
    p.strokeWeight(1.2);

    // Stalks
    p.line(-16 * s, -32 * s, -20 * s, -42 * s);
    p.line( 16 * s, -32 * s,  20 * s, -42 * s);

    // Eyeballs
    p.fill(10, 10, 10);
    p.ellipse(-20 * s, -44 * s, 9 * s, 9 * s);
    p.ellipse( 20 * s, -44 * s, 9 * s, 9 * s);

    // Cornea highlight
    p.fill(255, 255, 255, 200);
    p.noStroke();
    p.ellipse(-18 * s, -46 * s, 3 * s, 3 * s);
    p.ellipse( 22 * s, -46 * s, 3 * s, 3 * s);
  }
}

// Global singleton
const sceneLobsters = new SceneLobsters();
