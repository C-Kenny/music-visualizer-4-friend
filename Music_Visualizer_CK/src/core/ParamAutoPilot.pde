/**
 * ParamAutoPilot — makes scenes carry themselves when nobody is driving.
 *
 * Operating a scene well means moving knobs slowly and hitting accents on
 * musical moments. This class encodes that skill generically: once every
 * input source (controller, keyboard, mouse, web) has been quiet for a
 * while, it gently drifts the active scene's SceneParam knobs — slow
 * Perlin-noise wander around where the operator left them, plus small
 * kicks on beat onsets so the motion follows the music.
 *
 * It writes the SAME SceneParam objects the operator does (the params are
 * the source of truth — see SceneParam.pde), so the moment any real input
 * arrives the drift fades out and manual control wins with no handover
 * glitch. It never synthesises button events, so the held-state vs
 * rising-edge rules in CLAUDE.md are not at risk.
 *
 * Scenes need zero extra code: anything that declares getParams() is
 * automatically autopilot-capable.
 *
 * Toggle with `:`  (enabled by default — sit-back venue experience).
 */
class ParamAutoPilot {

  // ── Tuning ────────────────────────────────────────────────────────────────
  final float IDLE_SECONDS_BEFORE_ENGAGE = 30;   // quiet time before drift starts
  final float FADE_IN_SECONDS            = 4;    // drift strength ramps up this long
  final float FADE_OUT_LERP              = 0.25; // per-frame fade toward 0 on input (fast)
  final float WANDER_SPAN                = 0.30; // knob roams ±30% of its range
  final float WANDER_CYCLES_PER_MINUTE   = 2.5;  // how fast the noise field is traversed
  final float FOLLOW_LERP                = 0.02; // per-frame chase toward wander target
  final float BEAT_KICK_SPAN             = 0.10; // beat impulse, fraction of knob range
  final float BEAT_KICK_DECAY            = 0.90; // impulse shrinks to this per frame
  final float STICK_MOVE_THRESHOLD_PX    = 6;    // analog jitter below this isn't "input"
  final float TRIGGER_MOVE_THRESHOLD     = 0.05;

  // ── State ─────────────────────────────────────────────────────────────────
  boolean enabled         = true;
  int     lastActivityFrame = 0;
  float   strength        = 0;     // 0 = hands off the knobs, 1 = fully drifting
  float   noiseTime       = 0;

  // Per-knob wander state, captured fresh each time drift engages or the
  // scene changes (so drift orbits the operator's last setting, not defaults).
  float[] wanderCenterNorm = new float[0];
  float[] noiseSeed        = new float[0];
  float[] beatKickNorm     = new float[0];
  int     capturedScene    = -1;
  boolean captured         = false;
  int     nextKickKnob     = 0;

  // Previous controller pose for "did a human touch this" detection.
  float prevLx, prevLy, prevRx, prevRy, prevLt, prevRt;

  // Any input source calls this; keyboard/mouse/web hooks live in the main
  // sketch and ParamRouter. Controller motion is detected inside tick().
  void noteActivity() {
    lastActivityFrame = frameCount;
  }

  void toggleEnabled() {
    enabled = !enabled;
    if (!enabled) strength = 0;
    lastActivityFrame = frameCount; // re-arm the idle timer either way
  }

  // Called once per logic tick, after getUserInput().
  void tick(Controller c) {
    if (!enabled) return;

    if (controllerTouched(c)) noteActivity();

    boolean idleLongEnough =
      (frameCount - lastActivityFrame) > IDLE_SECONDS_BEFORE_ENGAGE * 60;

    if (idleLongEnough) {
      strength = min(1, strength + 1.0 / (FADE_IN_SECONDS * 60));
    } else {
      strength = lerp(strength, 0, FADE_OUT_LERP);
      if (strength < 0.01) { strength = 0; captured = false; return; }
    }

    SceneParam[] knobs = activeParams();
    if (knobs.length == 0) { captured = false; return; }

    if (!captured || capturedScene != config.STATE
        || wanderCenterNorm.length != knobs.length) {
      captureBaseline(knobs);
    }

    // Quiet music drifts lazily, loud music drifts faster.
    float audioPush = (analyzer != null) ? constrain(analyzer.master, 0, 1) : 0;
    noiseTime += (WANDER_CYCLES_PER_MINUTE / 3600.0) * (0.4 + audioPush);

    boolean beatNow = (analyzer != null) && analyzer.isBeat;
    if (beatNow) {
      // Accent one knob per beat, rotating, in a random direction.
      int i = nextKickKnob % knobs.length;
      beatKickNorm[i] += BEAT_KICK_SPAN * (random(1) < 0.5 ? -1 : 1);
      nextKickKnob++;
    }

    for (int i = 0; i < knobs.length; i++) {
      float wander = (noise(noiseSeed[i], noiseTime) * 2 - 1) * WANDER_SPAN;
      float targetNorm = constrain(wanderCenterNorm[i] + wander + beatKickNorm[i], 0, 1);
      knobs[i].setNorm(lerp(knobs[i].norm(), targetNorm, FOLLOW_LERP * strength));
      beatKickNorm[i] *= BEAT_KICK_DECAY;
    }
  }

  void captureBaseline(SceneParam[] knobs) {
    wanderCenterNorm = new float[knobs.length];
    noiseSeed        = new float[knobs.length];
    beatKickNorm     = new float[knobs.length];
    for (int i = 0; i < knobs.length; i++) {
      wanderCenterNorm[i] = knobs[i].norm();
      noiseSeed[i]        = i * 37.7 + 5.13; // well-separated noise rows per knob
    }
    capturedScene = config.STATE;
    captured = true;
  }

  // True when sticks/triggers moved beyond jitter or any button is down.
  // Web + demo input is merged into the same Controller before tick() runs,
  // so remote drivers also count as "someone is at the wheel".
  boolean controllerTouched(Controller c) {
    if (c == null) return false;
    boolean moved =
         abs(c.lx - prevLx) > STICK_MOVE_THRESHOLD_PX
      || abs(c.ly - prevLy) > STICK_MOVE_THRESHOLD_PX
      || abs(c.rx - prevRx) > STICK_MOVE_THRESHOLD_PX
      || abs(c.ry - prevRy) > STICK_MOVE_THRESHOLD_PX
      || abs(c.lt - prevLt) > TRIGGER_MOVE_THRESHOLD
      || abs(c.rt - prevRt) > TRIGGER_MOVE_THRESHOLD;
    boolean pressed =
         c.aButton || c.bButton || c.xButton || c.yButton
      || c.lbButton || c.rbButton || c.backButton || c.startButton
      || c.dpadUpHeld || c.dpadDownHeld || c.dpadLeftHeld || c.dpadRightHeld
      || c.leftStickClickButton || c.rightStickClickButton;
    prevLx = c.lx; prevLy = c.ly; prevRx = c.rx; prevRy = c.ry;
    prevLt = c.lt; prevRt = c.rt;
    return moved || pressed;
  }

  boolean isDrifting() { return enabled && strength > 0.01; }

  // ── HUD ───────────────────────────────────────────────────────────────────
  String hudLine() {
    if (!isDrifting()) return null;
    return "PILOT drifting " + nf(round(strength * 100), 3) + "%";
  }
}
