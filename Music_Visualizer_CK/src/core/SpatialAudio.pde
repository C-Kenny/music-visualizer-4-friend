/**
 * SpatialAudio - detects "8D audio": tracks where in the stereo field the
 * sound currently sits and whether it is circling the listener's head.
 *
 * How it works, in plain words:
 *  1. Compare loudness of the left and right channels → "pan"
 *     (-1 hard left .. +1 hard right).
 *  2. Check which ear the sound ARRIVES at first. Sound from the left reaches
 *     the left channel a fraction of a millisecond before the right. This is
 *     the second pan clue, and it catches delay-based 8D mixes that the
 *     loudness check alone misses.
 *  3. Rhythm check: keep the last 25 seconds of pan in a ring buffer and ask
 *     "does this movement repeat itself?" by sliding the recent pan curve
 *     over its own past (autocorrelation). Real 8D audio sweeps in steady
 *     laps, so the curve matches itself one lap later (score near 1).
 *     Ordinary stereo wanders randomly and never matches (score near 0).
 *     The score, times how WIDE the pan actually sways, drives orbitStrength.
 *     Validated offline against real tracks: a true 8D mix scores ~0.8 for
 *     ~90% of its runtime; five ordinary tracks (live, slowed+reverb,
 *     city pop, OST, hardstyle) all stay at 0%.
 *  4. Full 360° angle - pan alone can't tell front from behind, but while
 *     orbiting, pan traces a sine wave and the DIRECTION pan is moving
 *     disambiguates: rising through center = crossing in front, falling
 *     through center = crossing behind.
 *
 * What scenes read (all smoothed, safe to read every frame):
 *   spatial.pan                -1 hard left .. +1 hard right
 *   spatial.azimuth            angle around the head in radians. 0 = front,
 *                              +HALF_PI = right, PI = behind, -HALF_PI = left.
 *                              Grows continuously lap after lap, so it can be
 *                              fed straight into rotate().
 *   spatial.angularVelocity    radians per logic frame the azimuth is moving
 *   spatial.orbitStrength      0..1 confidence the sound is truly circling.
 *                              Multiply your effect by this so normal stereo
 *                              tracks don't wobble. Needs the 25 s history to
 *                              fill before it can rise (intro is always calm).
 *   spatial.orbitPeriodSeconds seconds for one full lap (when orbiting)
 *   spatial.width              stereo width: 0 mono .. 1 fully decorrelated
 *
 * Updated once per 60 Hz logic tick from the main draw loop, right after
 * analyzer.update(). Gain-independent (works in FILE and DEVICE mode) because
 * every measure is a ratio between the two channels.
 */
class SpatialAudio {
  // ── What scenes read ──────────────────────────────────────────────────────
  float pan                = 0;
  float azimuth            = 0;
  float angularVelocity    = 0;
  float orbitStrength      = 0;
  float orbitPeriodSeconds = 0;
  float width              = 0;

  // ── Tuning ────────────────────────────────────────────────────────────────
  final float LOGIC_FRAMES_PER_SECOND = 60.0;     // update() runs on the fixed logic tick
  final float QUIET_FLOOR             = 0.0008;   // both channels below this = silence
  final float EAR_DELAY_MAX_SECONDS   = 0.0009;   // sound needs ~0.9 ms to cross a head
  final float LOUDNESS_PAN_WEIGHT     = 0.7;      // trust loudness difference this much...
  final float ARRIVAL_PAN_WEIGHT      = 0.3;      // ...and arrival-time difference this much
  final float PAN_SMOOTHING           = 0.12;     // per-frame ease toward the raw reading
  final int   SAMPLE_STRIDE           = 4;        // analyse every 4th sample (plenty)
  final int   LAG_STRIDE              = 2;        // try every 2nd alignment offset

  // Rhythm check (orbit detection)
  final int   HISTORY_EVERY_N_FRAMES  = 5;        // store pan at 12 Hz...
  final int   HISTORY_SIZE            = 300;      // ...so 300 slots = 25 s of memory
  final int   RHYTHM_CHECK_EVERY_N_FRAMES = 15;   // re-score 4× per second
  final float LAP_MIN_SECONDS         = 1.5;      // faster than this = tremolo, not 8D
  final float LAP_MAX_SECONDS         = 15;       // slower than this = just a long fade
  final float RHYTHM_SCORE_FLOOR      = 0.45;     // self-match below this = not repeating
  final float RHYTHM_SCORE_FULL      = 0.70;      // self-match above this = clearly laps
  final float SWAY_FLOOR              = 0.06;     // pan must sway at least this much...
  final float SWAY_FULL               = 0.12;     // ...and this much counts as full swing
  final float ORBIT_FADE_IN           = 0.02;     // ~1 s ramp when an orbit is confirmed
  final float ORBIT_FADE_OUT          = 0.015;    // slightly gentler release
  final float AZIMUTH_EASE            = 0.08;     // how hard azimuth chases its target
  final float PHASE_CORRECTION_GAIN   = 0.02;     // how hard the spinning phase is
                                                  // nudged to stay matched to the
                                                  // heard pan (bigger = twitchier)

  // ── Internal state ────────────────────────────────────────────────────────
  private float   _previousPan = 0;
  private float   _panVelocity = 0;               // smoothed pan change per frame
  private float[] _panHistory  = new float[HISTORY_SIZE];  // ring buffer, 12 Hz
  private float[] _orderedPan  = new float[HISTORY_SIZE];  // scratch: oldest→newest
  private int     _historyIndex  = 0;
  private int     _historyFilled = 0;
  private int     _frameCounter  = 0;
  private float   _rhythmScore   = 0;             // 0..1 how well pan repeats itself
  private float   _panSway       = 0;             // spread of pan over the history
  private float   _orbitPhase    = 0;             // free-spinning phase of the lap

  void update(Audio audio) {
    boolean haveSignal = false;
    if (audio != null) {
      AudioBuffer leftEar  = audio.left();
      AudioBuffer rightEar = audio.right();
      if (leftEar != null && rightEar != null) {
        int sampleCount = min(leftEar.size(), rightEar.size());
        if (sampleCount >= 64) {
          haveSignal = measurePan(audio, leftEar, rightEar, sampleCount);
        }
      }
    }
    if (!haveSignal) {
      // Silence / no buffers: drift back to neutral, never snap.
      _previousPan = pan;
      pan          = lerp(pan, 0, 0.05);
      _panVelocity *= 0.9;
      width        = lerp(width, 0, 0.02);
    }

    // History + rhythm check run on EVERY tick (silence counts as pan 0 - 
    // a long quiet break should erode the orbit, not freeze it).
    _frameCounter++;
    if (_frameCounter % HISTORY_EVERY_N_FRAMES == 0) {
      _panHistory[_historyIndex] = pan;
      _historyIndex  = (_historyIndex + 1) % HISTORY_SIZE;
      _historyFilled = min(_historyFilled + 1, HISTORY_SIZE);
    }
    if (_frameCounter % RHYTHM_CHECK_EVERY_N_FRAMES == 0 && _historyFilled >= HISTORY_SIZE) {
      scoreRhythm();
    }

    // Confidence = "the pan repeats itself" × "the pan actually moves".
    float target = ramp(_rhythmScore, RHYTHM_SCORE_FLOOR, RHYTHM_SCORE_FULL)
                 * ramp(_panSway,     SWAY_FLOOR,         SWAY_FULL);
    orbitStrength = lerp(orbitStrength, target,
                         target > orbitStrength ? ORBIT_FADE_IN : ORBIT_FADE_OUT);

    // ── Angle around the head ────────────────────────────────────────────
    // While orbiting, the angle comes from a phase-locked spin: a phase that
    // turns at the song's lap rate on its own momentum, gently nudged so its
    // sine stays matched to the heard pan. The momentum is what keeps the
    // comet from wiggling - deriving the angle directly from pan + its
    // per-frame speed flaps between front and behind whenever the pan
    // pauses at the sides (measured: 13% of frames reversed direction;
    // phase-locked: 0.2%).
    float targetAngle;
    if (orbitStrength > 0.4 && orbitPeriodSeconds > 0) {
      _orbitPhase += TWO_PI / (orbitPeriodSeconds * LOGIC_FRAMES_PER_SECOND);
      // Where SHOULD the pan be if our phase is right? sin(phase). Compare
      // with what we actually hear (scaled to ±1 by the recent sway) and
      // nudge the phase to close the gap.
      float swayPeak  = max(_panSway * 1.414, 0.05);  // RMS → sine peak
      float heardPan  = constrain(pan / swayPeak, -1, 1);
      float phaseNudge = (heardPan - sin(_orbitPhase)) * cos(_orbitPhase)
                       * PHASE_CORRECTION_GAIN;
      _orbitPhase += phaseNudge;
      targetAngle = wrapAngle(_orbitPhase);
    } else {
      // No orbit - just place the sound in the front half, left to right.
      targetAngle = asin(constrain(pan, -1, 1));
      _orbitPhase = azimuth;   // stay synced for a clean handover when an orbit starts
    }
    // Always turn the SHORT way toward the target so laps accumulate smoothly
    // instead of snapping back through zero.
    float turn = wrapAngle(targetAngle - wrapAngle(azimuth));
    float step = turn * AZIMUTH_EASE;
    azimuth += step;
    angularVelocity = lerp(angularVelocity, step, 0.1);
  }

  // Reads one logic tick of audio and refreshes pan / width.
  // Returns false when the buffers are too quiet to trust.
  private boolean measurePan(Audio audio, AudioBuffer leftEar, AudioBuffer rightEar,
                             int sampleCount) {
    // 1. Loudness per ear
    float leftEnergy = 0, rightEnergy = 0;
    int counted = 0;
    for (int i = 0; i < sampleCount; i += SAMPLE_STRIDE) {
      float l = leftEar.get(i), r = rightEar.get(i);
      leftEnergy  += l * l;
      rightEnergy += r * r;
      counted++;
    }
    float leftLoudness  = sqrt(leftEnergy / counted);
    float rightLoudness = sqrt(rightEnergy / counted);
    if (leftLoudness + rightLoudness < QUIET_FLOOR) return false;

    float loudnessPan = (rightLoudness - leftLoudness) / (rightLoudness + leftLoudness);

    // 2. Arrival-time pan: slide the two channels past each other a few
    // samples at a time and find the offset where they line up best. If the
    // right channel is a delayed copy of the left, the sound hit the left
    // ear first.
    float sampleRate = 44100;
    if (audio.isUsingDeviceInput && audio.audioInput != null) {
      sampleRate = audio.audioInput.sampleRate();
    } else if (audio.player != null) {
      sampleRate = audio.player.sampleRate();
    }
    int maxLag = max(4, (int) (sampleRate * EAR_DELAY_MAX_SECONDS));
    float bestMatch = -2;
    int   bestLag   = 0;
    for (int lag = -maxLag; lag <= maxLag; lag += LAG_STRIDE) {
      float sum = 0;
      int startIndex = max(0, -lag);
      int endIndex   = min(sampleCount, sampleCount - lag);
      int pairs = 0;
      for (int i = startIndex; i < endIndex; i += SAMPLE_STRIDE) {
        sum += leftEar.get(i) * rightEar.get(i + lag);
        pairs++;
      }
      float match = (pairs > 0) ? sum / pairs : 0;
      if (match > bestMatch) { bestMatch = match; bestLag = lag; }
    }
    // Positive best lag = right channel lags behind = sound is on the left.
    float arrivalPan = constrain(-bestLag / (float) maxLag, -1, 1);

    // How alike the channels are at their best alignment. Identical channels
    // (mono) score 1 → width 0. Unrelated channels score ~0 → width 1.
    float similarity = bestMatch / max(leftLoudness * rightLoudness, 0.000001);
    width = lerp(width, constrain(1 - similarity, 0, 1), 0.1);

    // 3. Combine the two pan clues and smooth
    float rawPan = constrain(loudnessPan * LOUDNESS_PAN_WEIGHT
                           + arrivalPan  * ARRIVAL_PAN_WEIGHT, -1, 1);
    _previousPan = pan;
    pan = lerp(pan, rawPan, PAN_SMOOTHING);
    _panVelocity = lerp(_panVelocity, pan - _previousPan, 0.1);
    return true;
  }

  // Does the recent pan movement repeat itself? Compare the 25 s pan curve
  // against itself shifted by every plausible lap time; the best match
  // becomes _rhythmScore and its shift becomes the lap estimate.
  private void scoreRhythm() {
    // Unroll the ring buffer oldest→newest and remove the average so a
    // sound parked off-center doesn't look like movement.
    float mean = 0;
    for (int i = 0; i < HISTORY_SIZE; i++) {
      _orderedPan[i] = _panHistory[(_historyIndex + i) % HISTORY_SIZE];
      mean += _orderedPan[i];
    }
    mean /= HISTORY_SIZE;
    float energy = 0;
    for (int i = 0; i < HISTORY_SIZE; i++) {
      _orderedPan[i] -= mean;
      energy += _orderedPan[i] * _orderedPan[i];
    }
    _panSway = sqrt(energy / HISTORY_SIZE);
    if (_panSway < SWAY_FLOOR * 0.5) { _rhythmScore = 0; return; }

    float historyRate = LOGIC_FRAMES_PER_SECOND / HISTORY_EVERY_N_FRAMES; // 12 Hz
    int lagMin = (int) (LAP_MIN_SECONDS * historyRate);
    int lagMax = (int) (LAP_MAX_SECONDS * historyRate);
    float bestScore = 0;
    int   bestLag   = 0;
    for (int lag = lagMin; lag < lagMax; lag += 2) {
      float dot = 0, energyA = 0, energyB = 0;
      int overlap = HISTORY_SIZE - lag;
      for (int i = 0; i < overlap; i++) {
        float a = _orderedPan[i], b = _orderedPan[i + lag];
        dot += a * b;
        energyA += a * a;
        energyB += b * b;
      }
      float score = dot / max(sqrt(energyA * energyB), 0.000001);
      if (score > bestScore) { bestScore = score; bestLag = lag; }
    }
    _rhythmScore = bestScore;
    if (bestLag > 0 && bestScore > RHYTHM_SCORE_FLOOR) {
      float lapSeconds = bestLag / historyRate;
      orbitPeriodSeconds = (orbitPeriodSeconds <= 0)
                         ? lapSeconds
                         : lerp(orbitPeriodSeconds, lapSeconds, 0.2);
    }
  }

  // 0 below lo, 1 above hi, straight line in between.
  private float ramp(float x, float lo, float hi) {
    return constrain((x - lo) / (hi - lo), 0, 1);
  }

  // Fold any angle into -PI..PI.
  private float wrapAngle(float a) {
    while (a >  PI) a -= TWO_PI;
    while (a < -PI) a += TWO_PI;
    return a;
  }

  // One-line readout for scene HUDs.
  String debugLine() {
    if (orbitStrength < 0.05) {
      return "8D: flat  pan " + nf(pan, 1, 2);
    }
    return "8D: orbit " + round(orbitStrength * 100) + "%  lap "
         + nf(orbitPeriodSeconds, 1, 1) + "s  angle "
         + round(degrees(wrapAngle(azimuth))) + "°";
  }
}
