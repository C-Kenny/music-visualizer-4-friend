/**
 * scene_lobsters.js — Lobster Scene 🦞
 * An original creative scene by xdd the AI, celebrating the web launch.
 *
 * Features:
 *   - 4 animated vector-drawn lobsters (bezier body, claws, legs, antennae, eyes)
 *   - Velocity-based free swimming with autonomous wander behaviour
 *   - Lobsters wrap around screen edges
 *   - Body rotates to face direction of travel
 *   - Keyboard: WASD / arrow keys steer, Space scatters
 *   - Gamepad: left stick steers, A scatters, B gathers to center
 *   - Underwater ambiance: animated blue-green gradient, rising bubbles
 *   - Music reactivity:
 *       - Bass: body scale surges to 1.3×, velocity kick (dart forward)
 *       - Beat onset: claws snap, orange-red flash for ~15 frames
 *       - High freq: whole antennae oscillate wildly
 *       - Mid freq: walking speed increases noticeably
 *       - Sustained bass: bubbles spawn faster and move quicker
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

    // Keyboard held-key flags — set by keyPressed/keyReleased in sketch.js
    this.keyLeftHeld  = false;
    this.keyRightHeld = false;
    this.keyUpHeld    = false;
    this.keyDownHeld  = false;

    // Current audio energy levels (stored so bubbles can read them)
    this.currentBassEnergy = 0;
    this.currentMidEnergy  = 0;
  }

  /** Lazy init — call once p5 & canvas dimensions are known. */
  init(p) {
    if (this.initialized) return;
    this.initialized = true;

    // Pre-allocate particle pool
    this.particles = [];
    for (let poolIndex = 0; poolIndex < this.PARTICLE_POOL_SIZE; poolIndex++) {
      this.particles.push({
        active: false, x: 0, y: 0, vx: 0, vy: 0,
        life: 0, maxLife: 30, r: 255, g: 80, b: 20, size: 4
      });
    }

    // Pre-allocate shockwave pool
    this.shockwaves = [];
    for (let poolIndex = 0; poolIndex < this.SHOCKWAVE_POOL_SIZE; poolIndex++) {
      this.shockwaves.push({
        active: false, x: 0, y: 0, r: 0, maxR: 150, life: 0, maxLife: 40
      });
    }

    // Create bubbles
    this.bubbles = [];
    for (let bubbleIndex = 0; bubbleIndex < this.BUBBLE_COUNT; bubbleIndex++) {
      this.bubbles.push(this._newBubble(p, true));
    }

    // Create 4 lobsters at different starting positions
    const startPositions = [
      { x: p.width * 0.18, y: p.height * 0.45, scale: 1.0,  speed: 0.7, phase: 0    },
      { x: p.width * 0.42, y: p.height * 0.3,  scale: 0.85, speed: 0.5, phase: 1.2  },
      { x: p.width * 0.68, y: p.height * 0.55, scale: 1.1,  speed: 0.6, phase: 2.5  },
      { x: p.width * 0.82, y: p.height * 0.35, scale: 0.75, speed: 0.9, phase: 0.7  },
    ];

    this.lobsters = startPositions.map(pos => new Lobster(pos));
  }

  _newBubble(p, randomY) {
    // When sustained bass is high, bubbles spawn faster and move quicker.
    // currentBassEnergy may not be set on very first call, default to 0.
    const bassBoost = this.currentBassEnergy || 0;
    return {
      x: p.random(p.width),
      y: randomY ? p.random(p.height) : p.height + 10,
      r: p.random(3, 12),
      // Speed boosted when bass is pumping
      speed: p.random(0.5, 2.0) + bassBoost * 1.5,
      wobble: p.random(0, Math.PI * 2),
      wobbleSpeed: p.random(0.02, 0.06),
      alpha: p.random(80, 180),
    };
  }

  /** Spawn particles from a world position (claw tip, scatter, etc.). */
  _spawnParticles(worldX, worldY, count) {
    let spawnedCount = 0;
    for (let poolIndex = 0; poolIndex < this.particles.length && spawnedCount < count; poolIndex++) {
      const particle = this.particles[poolIndex];
      if (!particle.active) {
        particle.active = true;
        particle.x = worldX;
        particle.y = worldY;
        const angle = Math.random() * Math.PI * 2;
        const speed = 2 + Math.random() * 5;
        particle.vx = Math.cos(angle) * speed;
        particle.vy = Math.sin(angle) * speed - 2; // slight upward bias
        particle.life    = 0;
        particle.maxLife = 25 + Math.floor(Math.random() * 20);
        // Random orange/red/yellow hues
        particle.r = 220 + Math.random() * 35;
        particle.g = 50  + Math.random() * 120;
        particle.b = 0   + Math.random() * 40;
        particle.size = 3 + Math.random() * 5;
        spawnedCount++;
      }
    }
  }

  /** Spawn a shockwave ring. */
  _spawnShockwave(worldX, worldY) {
    for (let poolIndex = 0; poolIndex < this.shockwaves.length; poolIndex++) {
      const shockwave = this.shockwaves[poolIndex];
      if (!shockwave.active) {
        shockwave.active  = true;
        shockwave.x       = worldX;
        shockwave.y       = worldY;
        shockwave.r       = 0;
        shockwave.maxR    = 120 + Math.random() * 80;
        shockwave.life    = 0;
        shockwave.maxLife = 40;
        return;
      }
    }
  }

  /**
   * Give every lobster a high-speed velocity kick outward from the screen center,
   * and spawn a burst of particles from each one.
   * Called by Space key and gamepad A button.
   */
  scatterLobsters() {
    const centerX = (typeof width  !== 'undefined') ? width  / 2 : 400;
    const centerY = (typeof height !== 'undefined') ? height / 2 : 300;

    for (const lobster of this.lobsters) {
      // Direction: from center toward lobster (or random if lobster is exactly at center)
      const directionX = lobster.x - centerX;
      const directionY = lobster.y - centerY;
      const distance   = Math.sqrt(directionX * directionX + directionY * directionY);
      const scatterSpeed = 8 + Math.random() * 4;

      if (distance > 5) {
        lobster.targetVelocityX = (directionX / distance) * scatterSpeed;
        lobster.targetVelocityY = (directionY / distance) * scatterSpeed;
        lobster.velocityX       = lobster.targetVelocityX;
        lobster.velocityY       = lobster.targetVelocityY;
      } else {
        // Lobster is very close to center — scatter in random direction
        const randomAngle = Math.random() * Math.PI * 2;
        lobster.targetVelocityX = Math.cos(randomAngle) * scatterSpeed;
        lobster.targetVelocityY = Math.sin(randomAngle) * scatterSpeed;
        lobster.velocityX       = lobster.targetVelocityX;
        lobster.velocityY       = lobster.targetVelocityY;
      }

      // Big particle burst from each lobster's position
      this._spawnParticles(lobster.x, lobster.y, 20);
    }
  }

  /**
   * Steer all lobsters' target velocity toward the screen center.
   * Called by gamepad B button.
   */
  gatherLobsters() {
    const centerX = (typeof width  !== 'undefined') ? width  / 2 : 400;
    const centerY = (typeof height !== 'undefined') ? height / 2 : 300;

    for (const lobster of this.lobsters) {
      const directionX = centerX - lobster.x;
      const directionY = centerY - lobster.y;
      const distance   = Math.sqrt(directionX * directionX + directionY * directionY);

      if (distance > 10) {
        const gatherSpeed = lobster.maxSpeed;
        lobster.targetVelocityX = (directionX / distance) * gatherSpeed;
        lobster.targetVelocityY = (directionY / distance) * gatherSpeed;
      }
    }
  }

  /** Main draw — called every frame by sketch.js */
  draw(p) {
    this.init(p);
    this.frameCount++;

    const canvasWidth  = p.width;
    const canvasHeight = p.height;

    // ── Audio analysis ────────────────────────────────────────────────────────
    audio.forward();
    const beatOnset = audio.beat.isOnset();

    // Bass energy (bands 0-5) for body pulse and bubble boost
    let bassEnergy = 0;
    for (let bandIndex = 0; bandIndex < Math.min(6, audio.fft.avgSize()); bandIndex++) {
      bassEnergy += audio.fft.getAvg(bandIndex);
    }
    bassEnergy = Math.min(bassEnergy / 6 * 200, 1); // normalise 0..1
    this.currentBassEnergy = bassEnergy;

    // Mid-freq energy (bands ~20-50%) for walking speed
    let midEnergy = 0;
    const midStart = Math.floor(audio.fft.avgSize() * 0.2);
    const midEnd   = Math.floor(audio.fft.avgSize() * 0.5);
    for (let bandIndex = midStart; bandIndex < midEnd; bandIndex++) {
      midEnergy += audio.fft.getAvg(bandIndex);
    }
    const midBandCount = midEnd - midStart;
    midEnergy = midBandCount > 0 ? Math.min(midEnergy / midBandCount * 250, 1) : 0;
    this.currentMidEnergy = midEnergy;

    // High-freq energy (bands 60%+) for antenna oscillation
    let hiFreqEnergy = 0;
    const hiStart = Math.floor(audio.fft.avgSize() * 0.6);
    for (let bandIndex = hiStart; bandIndex < audio.fft.avgSize(); bandIndex++) {
      hiFreqEnergy += audio.fft.getAvg(bandIndex);
    }
    const hiBandCount = audio.fft.avgSize() - hiStart;
    hiFreqEnergy = hiBandCount > 0 ? Math.min(hiFreqEnergy / hiBandCount * 300, 1) : 0;

    // ── Keyboard steering — nudge all lobsters' target velocity ───────────────
    // Flags are set by keyPressed/keyReleased in sketch.js
    if (this.keyLeftHeld || this.keyRightHeld || this.keyUpHeld || this.keyDownHeld) {
      for (const lobster of this.lobsters) {
        if (this.keyLeftHeld)  lobster.targetVelocityX -= 0.5;
        if (this.keyRightHeld) lobster.targetVelocityX += 0.5;
        if (this.keyUpHeld)    lobster.targetVelocityY -= 0.5;
        if (this.keyDownHeld)  lobster.targetVelocityY += 0.5;
      }
    }

    // ── Underwater gradient background ────────────────────────────────────────
    this._drawBackground(p, bassEnergy);

    // ── Bubbles ───────────────────────────────────────────────────────────────
    this._updateDrawBubbles(p, bassEnergy);

    // ── Shockwaves ────────────────────────────────────────────────────────────
    for (const shockwave of this.shockwaves) {
      if (!shockwave.active) continue;
      shockwave.r += shockwave.maxR / shockwave.maxLife;
      shockwave.life++;
      if (shockwave.life >= shockwave.maxLife) { shockwave.active = false; continue; }
      const shockwaveAlpha = p.map(shockwave.life, 0, shockwave.maxLife, 200, 0);
      p.push();
      p.noFill();
      p.stroke(255, 180, 50, shockwaveAlpha);
      p.strokeWeight(3);
      p.ellipse(shockwave.x, shockwave.y, shockwave.r * 2, shockwave.r * 2);
      p.pop();
    }

    // ── Lobsters ──────────────────────────────────────────────────────────────
    for (const lobster of this.lobsters) {
      if (beatOnset) {
        lobster.triggerBeat();
        this._spawnParticles(lobster.clawLPos.x, lobster.clawLPos.y, 8);
        this._spawnParticles(lobster.clawRPos.x, lobster.clawRPos.y, 8);
        this._spawnShockwave(lobster.x, lobster.y);
      }
      lobster.update(this.frameCount, bassEnergy, hiFreqEnergy, midEnergy, canvasWidth, canvasHeight);
      lobster.draw(p);
    }

    // ── Particles ─────────────────────────────────────────────────────────────
    for (const particle of this.particles) {
      if (!particle.active) continue;
      particle.x  += particle.vx;
      particle.y  += particle.vy;
      particle.vy += 0.15; // gravity
      particle.life++;
      if (particle.life >= particle.maxLife) { particle.active = false; continue; }
      const particleAlpha = p.map(particle.life, 0, particle.maxLife, 255, 0);
      const fadeFraction  = 1 - particle.life / particle.maxLife;
      p.push();
      p.noStroke();
      p.fill(particle.r, particle.g, particle.b, particleAlpha);
      p.ellipse(particle.x, particle.y, particle.size * fadeFraction * 2);
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
    const animTime = this.frameCount * 0.003;
    const topR  = Math.round(0  + Math.sin(animTime)       * 10);
    const topG  = Math.round(20 + Math.sin(animTime * 0.7) * 15);
    const topB  = Math.round(40 + Math.sin(animTime * 0.5) * 20 + bassEnergy * 15);
    const botR  = Math.round(0  + Math.sin(animTime + 1)   * 8);
    const botG  = Math.round(40 + Math.cos(animTime * 0.6) * 20);
    const botB  = Math.round(80 + Math.cos(animTime * 0.4) * 30 + bassEnergy * 20);

    // Draw gradient via horizontal strips
    const gradientSteps = 40;
    for (let stepIndex = 0; stepIndex < gradientSteps; stepIndex++) {
      const frac = stepIndex / gradientSteps;
      const redVal   = p.lerp(topR, botR, frac);
      const greenVal = p.lerp(topG, botG, frac);
      const blueVal  = p.lerp(topB, botB, frac);
      p.noStroke();
      p.fill(redVal, greenVal, blueVal);
      p.rect(0, (stepIndex / gradientSteps) * p.height, p.width, p.height / gradientSteps + 1);
    }

    // Subtle caustic light patterns
    p.noFill();
    for (let causticIndex = 0; causticIndex < 6; causticIndex++) {
      const cx = p.width  * (0.1 + 0.15 * causticIndex + Math.sin(animTime * 0.3 + causticIndex) * 0.05);
      const cy = p.height * (0.1 + Math.cos(animTime * 0.2 + causticIndex * 1.3) * 0.1);
      const causticR = 30 + causticIndex * 20 + Math.sin(animTime + causticIndex) * 15;
      p.stroke(100, 200, 220, 15);
      p.strokeWeight(1);
      p.ellipse(cx, cy, causticR * 2, causticR * 2);
    }
  }

  _updateDrawBubbles(p, bassEnergy) {
    for (let bubbleIndex = 0; bubbleIndex < this.bubbles.length; bubbleIndex++) {
      const bubble = this.bubbles[bubbleIndex];
      bubble.y      -= bubble.speed;
      bubble.wobble += bubble.wobbleSpeed;
      const wobbleX = bubble.x + Math.sin(bubble.wobble) * 3;

      if (bubble.y < -bubble.r * 2) {
        // Respawn at bottom — sustained bass makes new bubbles faster
        this.bubbles[bubbleIndex] = this._newBubble(p, false);
        continue;
      }

      p.push();
      p.noFill();
      p.stroke(180, 230, 255, bubble.alpha);
      p.strokeWeight(1.5);
      p.ellipse(wobbleX, bubble.y, bubble.r * 2, bubble.r * 2);
      // Bubble highlight
      p.stroke(255, 255, 255, bubble.alpha * 0.6);
      p.strokeWeight(1);
      p.ellipse(wobbleX - bubble.r * 0.25, bubble.y - bubble.r * 0.25, bubble.r * 0.5, bubble.r * 0.5);
      p.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lobster class — drawn entirely with vector graphics
// ─────────────────────────────────────────────────────────────────────────────
class Lobster {
  constructor({ x, y, scale, speed, phase }) {
    // World position — updated every frame by velocity
    this.x     = x;
    this.y     = y;
    this.scale = scale;

    // Animation speed for visual bobbing/swaying (unrelated to swimming velocity)
    this.animSpeed = speed;
    this.phase     = phase;

    // ── Velocity-based swimming ──────────────────────────────────────────────
    this.velocityX       = (Math.random() - 0.5) * 2;  // pixels per frame
    this.velocityY       = (Math.random() - 0.5) * 1;
    this.targetVelocityX = this.velocityX;  // actual velocity lerps toward this
    this.targetVelocityY = this.velocityY;
    this.facingAngle     = 0;              // current body rotation (radians, 0=right)
    this.wanderAngle     = Math.random() * Math.PI * 2; // autonomous swim direction
    this.wanderTimer     = 0;             // frames until next wander direction change
    // Each lobster swims at a slightly different max speed for variety
    this.maxSpeed = 0.8 + Math.random() * 1.2;  // 0.8..2.0 pixels per frame

    // ── Visual animation phases ──────────────────────────────────────────────
    this.bobPhase  = phase;   // drives gentle vertical float for the drawing
    this.swimPhase = phase;   // drives horizontal sway in the drawing
    this.legPhase  = phase;   // drives walking leg animation

    // ── Music reactivity state ───────────────────────────────────────────────
    this.clawSnap        = 0;   // 0..1 — snaps to 1 on beat, then decays
    this.bodyPulse       = 0;   // 0..1 — driven continuously by bass energy
    this.flashAlpha      = 0;   // orange beat-flash intensity (decays each frame)
    this.beatFlashFrames = 0;   // countdown: orange-red body flash for ~15 frames on beat
    this.antennaEnergy   = 0;   // high-freq energy driving antenna oscillation

    // Pre-computed claw world positions (updated each draw for particle spawning)
    this.clawLPos = { x: 0, y: 0 };
    this.clawRPos = { x: 0, y: 0 };
  }

  /** Called by SceneLobsters on beat onset. Snaps claws, flashes, kicks velocity. */
  triggerBeat() {
    this.clawSnap        = 1.0;
    this.flashAlpha      = 1.0;
    this.beatFlashFrames = 15;  // orange-red flash lasts 15 frames

    // Velocity kick — lobster darts forward in its current swimming direction
    const currentSpeed = Math.sqrt(this.velocityX * this.velocityX + this.velocityY * this.velocityY);
    const kickStrength = 4.0;
    if (currentSpeed > 0.1) {
      // Kick along current direction of travel
      this.velocityX += (this.velocityX / currentSpeed) * kickStrength;
      this.velocityY += (this.velocityY / currentSpeed) * kickStrength;
    } else {
      // Not moving yet — kick in wander direction
      this.velocityX += Math.cos(this.wanderAngle) * kickStrength;
      this.velocityY += Math.sin(this.wanderAngle) * kickStrength;
    }
    // Also push target so the kick doesn't immediately get smoothed away
    this.targetVelocityX = this.velocityX;
    this.targetVelocityY = this.velocityY;
  }

  /**
   * Update physics and animation state.
   * @param {number} frameCount    - global frame counter
   * @param {number} bassEnergy    - 0..1 bass frequency energy
   * @param {number} hiFreqEnergy  - 0..1 high frequency energy
   * @param {number} midEnergy     - 0..1 mid frequency energy (drives leg speed)
   * @param {number} canvasWidth   - for edge wrapping
   * @param {number} canvasHeight  - for edge wrapping
   */
  update(frameCount, bassEnergy, hiFreqEnergy, midEnergy, canvasWidth, canvasHeight) {
    // ── Autonomous wander direction ──────────────────────────────────────────
    // Count down and pick a new random swim direction every 120–240 frames.
    this.wanderTimer--;
    if (this.wanderTimer <= 0) {
      this.wanderAngle  = Math.random() * Math.PI * 2;
      // Random reset interval so lobsters don't all change direction simultaneously
      this.wanderTimer  = 120 + Math.floor(Math.random() * 120);
    }

    // ── Steer target velocity toward wander direction ─────────────────────
    // A small nudge each frame accumulates into a gradual direction change.
    const wanderNudgeStrength = 0.04;
    this.targetVelocityX += Math.cos(this.wanderAngle) * wanderNudgeStrength;
    this.targetVelocityY += Math.sin(this.wanderAngle) * wanderNudgeStrength;

    // Clamp target velocity so it doesn't exceed maxSpeed
    const targetMagnitude = Math.sqrt(
      this.targetVelocityX * this.targetVelocityX +
      this.targetVelocityY * this.targetVelocityY
    );
    if (targetMagnitude > this.maxSpeed) {
      this.targetVelocityX = (this.targetVelocityX / targetMagnitude) * this.maxSpeed;
      this.targetVelocityY = (this.targetVelocityY / targetMagnitude) * this.maxSpeed;
    }

    // ── Lerp actual velocity toward target (smoothing factor ~0.03) ──────────
    // Low value = sluggish but smooth; higher = snappier response.
    const velocitySmoothFactor = 0.03;
    this.velocityX += (this.targetVelocityX - this.velocityX) * velocitySmoothFactor;
    this.velocityY += (this.targetVelocityY - this.velocityY) * velocitySmoothFactor;

    // Also clamp actual velocity (can spike above maxSpeed after a bass kick)
    const actualMagnitude = Math.sqrt(
      this.velocityX * this.velocityX +
      this.velocityY * this.velocityY
    );
    const speedCap = this.maxSpeed * 3; // allow 3× burst from bass kicks, then cap
    if (actualMagnitude > speedCap) {
      this.velocityX = (this.velocityX / actualMagnitude) * speedCap;
      this.velocityY = (this.velocityY / actualMagnitude) * speedCap;
    }

    // ── Move ──────────────────────────────────────────────────────────────────
    this.x += this.velocityX;
    this.y += this.velocityY;

    // ── Wrap around screen edges ──────────────────────────────────────────────
    // Buffer of 100px so lobsters fully exit before reappearing on the other side.
    if (this.x < -100)              this.x = canvasWidth  + 100;
    if (this.x > canvasWidth  + 100) this.x = -100;
    if (this.y < -100)              this.y = canvasHeight + 100;
    if (this.y > canvasHeight + 100) this.y = -100;

    // ── Smoothly rotate facing angle toward direction of travel ───────────────
    // atan2 gives 0=right, π/2=down, etc. (standard math angle)
    if (actualMagnitude > 0.1) {
      const desiredFacingAngle = Math.atan2(this.velocityY, this.velocityX);

      // Compute the shortest angular delta (handles wrap-around at ±π)
      let angleDelta = desiredFacingAngle - this.facingAngle;
      while (angleDelta >  Math.PI) angleDelta -= Math.PI * 2;
      while (angleDelta < -Math.PI) angleDelta += Math.PI * 2;

      // Lerp toward desired angle — faster when speed is high
      this.facingAngle += angleDelta * 0.05;
    }

    // ── Animation phases ─────────────────────────────────────────────────────
    this.bobPhase  += this.animSpeed * 0.015;
    this.swimPhase += this.animSpeed * 0.008;

    // Leg walking speed scales with current movement speed + mid-freq energy
    // Base rate: 0.03. Movement adds up to ~0.1. Mid energy adds up to ~0.08.
    const legSpeedBoost = actualMagnitude * 0.05 + midEnergy * 0.08;
    this.legPhase += 0.03 + legSpeedBoost;

    // ── Music reactivity state updates ────────────────────────────────────────
    this.bodyPulse    = bassEnergy;
    this.antennaEnergy = hiFreqEnergy;

    // Decay claw snap and flash
    this.clawSnap   *= 0.85;
    this.flashAlpha *= 0.88;
    if (this.beatFlashFrames > 0) this.beatFlashFrames--;
  }

  draw(p) {
    const scaleSize = this.scale;

    // The lobster body is drawn vertically by default (rostrum at top, tail at bottom).
    // Adding π/2 converts from "0=right" swimming angle to "0=up" draw orientation.
    // So a lobster swimming right (angle=0) rotates π/2 to face right — correct.
    const drawRotation = this.facingAngle + Math.PI / 2;

    // Gentle visual bob (purely cosmetic, position is controlled by velocity)
    const visualBobOffset = Math.sin(this.bobPhase) * 4;

    p.push();
    p.translate(this.x, this.y + visualBobOffset);
    p.rotate(drawRotation);

    // ── Beat flash overlay — bright orange-red for ~15 frames ────────────────
    // beatFlashFrames is a countdown; flashAlpha is a smooth exponential decay.
    // Both are triggered simultaneously in triggerBeat().
    if (this.beatFlashFrames > 0) {
      p.noStroke();
      // Stronger flash than before — more saturated orange
      p.fill(255, 60, 0, (this.beatFlashFrames / 15) * 180);
      p.ellipse(0, 0, 180 * scaleSize, 90 * scaleSize);
    } else if (this.flashAlpha > 0.05) {
      // Tail-end smooth fade after countdown expires
      p.noStroke();
      p.fill(255, 80, 20, this.flashAlpha * 100);
      p.ellipse(0, 0, 160 * scaleSize, 80 * scaleSize);
    }

    // ── Bass pulse scale — surges to 1.3× for dramatic effect ────────────────
    // Multiplied by base scale so larger/smaller lobsters pulse proportionally.
    const bassScalePulse = 1 + this.bodyPulse * 0.3; // 1.0x → 1.3x
    p.scale(bassScalePulse);

    this._drawBody(p, scaleSize);
    this._drawTailFan(p, scaleSize);
    this._drawLegs(p, scaleSize);
    this._drawClaws(p, scaleSize);
    this._drawAntennae(p, scaleSize);
    this._drawEyes(p, scaleSize);

    p.pop();

    // ── Update claw world positions for particle spawning ─────────────────────
    // These are approximate — we compute the claw offset in local space and
    // rotate it manually to get world coords.  Avoids needing createVector.
    const localClawOffsetX = -74 * scaleSize; // left claw x in local space
    const localClawOffsetY = -7  * scaleSize;
    const cosAngle = Math.cos(drawRotation);
    const sinAngle = Math.sin(drawRotation);
    this.clawLPos.x = this.x + localClawOffsetX * cosAngle - localClawOffsetY * sinAngle;
    this.clawLPos.y = this.y + localClawOffsetX * sinAngle + localClawOffsetY * cosAngle;
    this.clawRPos.x = this.x + (-localClawOffsetX) * cosAngle - localClawOffsetY * sinAngle;
    this.clawRPos.y = this.y + (-localClawOffsetX) * sinAngle + localClawOffsetY * cosAngle;
  }

  _lobsterColor(p, alpha) {
    // Deep red-orange, brightens on beat flash
    const flashBrightness = 1 + this.flashAlpha * 0.6 + (this.beatFlashFrames / 15) * 0.8;
    p.fill(
      Math.min(255, 180 * flashBrightness),
      Math.min(255, 40  * flashBrightness),
      Math.min(255, 20  * flashBrightness),
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
    for (let segIndex = 0; segIndex < 5; segIndex++) {
      const segY = 10 * s + segIndex * 12 * s;
      const segW = (55 - segIndex * 4) * s;
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
    for (let fanIndex = -2; fanIndex <= 2; fanIndex++) {
      const fanAngle = fanIndex * 0.28;
      const fanLen   = (fanIndex === 0 ? 28 : 22) * s;
      const fanWid   = (fanIndex === 0 ? 18 : 14) * s;
      p.push();
      p.rotate(fanAngle);
      p.ellipse(0, fanLen * 0.6, fanWid, fanLen);
      p.pop();
    }
    p.pop();
  }

  _drawLegs(p, s) {
    // 8 walking legs (4 pairs, each side)
    p.stroke(130, 25, 12);
    p.strokeWeight(1.5);
    p.noFill();

    for (let pairIndex = 0; pairIndex < 4; pairIndex++) {
      const legRootY = (-5 + pairIndex * 12) * s;
      // Each pair has a phase offset so they alternate like real walking
      const legSwingOffset = pairIndex * 0.4;
      const legSwing = Math.sin(this.legPhase + legSwingOffset) * 8 * s;

      // Left leg
      p.push();
      p.translate(-28 * s, legRootY);
      p.bezier(
        0, 0,
        -15 * s, 5 * s + legSwing,
        -28 * s, 12 * s + legSwing,
        -36 * s, 20 * s + legSwing * 0.5
      );
      p.pop();

      // Right leg (swings opposite phase for realistic alternating gait)
      p.push();
      p.translate(28 * s, legRootY);
      p.bezier(
        0, 0,
        15 * s, 5 * s - legSwing,
        28 * s, 12 * s - legSwing,
        36 * s, 20 * s - legSwing * 0.5
      );
      p.pop();
    }
  }

  _drawClaws(p, s) {
    // Two large front claws (chelipeds)
    // clawSnap drives how open/closed the claw is (1.0 = fully snapped shut)
    const snapAngle = this.clawSnap * 0.5;

    for (const side of [-1, 1]) {
      p.push();
      p.translate(side * 32 * s, -22 * s);

      // Arm (merus + carpus)
      p.stroke(110, 18, 8);
      p.strokeWeight(2);
      this._lobsterColor(p);

      p.push();
      p.rotate(side * 0.35);
      // Upper arm — bezier from shoulder to claw junction
      p.bezier(
        0, 0,
        side * 18 * s, -5 * s,
        side * 35 * s, 5 * s,
        side * 42 * s, 15 * s
      );

      // Claw tip transform — translate to claw junction
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

      p.pop();
    }
  }

  _drawAntennae(p, s) {
    // Long antennae — whole antenna swings wildly with high-freq energy.
    // Previously only the tip wiggled; now all control points oscillate.
    //
    // antennaEnergy 0..1 drives the swing amplitude.
    // bobPhase adds a slow base sway so they're never perfectly still.
    const slowSway     = Math.sin(this.bobPhase * 3) * 5 * s;
    const wildSwingAmt = this.antennaEnergy * 60 * s;  // up to 60px swing at full energy

    // Each control point gets progressively more swing (tip swings most)
    p.stroke(140, 30, 15);
    p.strokeWeight(1.2);
    p.noFill();

    // Left antenna
    p.bezier(
      -12 * s,        -48 * s,                             // root (fixed at head)
      -30 * s + wildSwingAmt * 0.3, -90 * s + slowSway,   // mid 1 — moderate swing
      -60 * s + wildSwingAmt * 0.7, -130 * s + slowSway * 0.5, // mid 2 — bigger
      -90 * s + wildSwingAmt,       -160 * s + slowSway   // tip — maximum swing
    );

    // Right antenna (swings opposite for visual interest)
    p.bezier(
       12 * s,        -48 * s,
       30 * s - wildSwingAmt * 0.3, -90 * s - slowSway,
       60 * s - wildSwingAmt * 0.7, -130 * s - slowSway * 0.5,
       90 * s - wildSwingAmt,       -160 * s - slowSway
    );

    // Short antennules (small decorative pair, barely move)
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

// Global singleton — referenced by sketch.js
const sceneLobsters = new SceneLobsters();
