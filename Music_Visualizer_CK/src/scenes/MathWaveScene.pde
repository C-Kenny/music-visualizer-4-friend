import ddf.minim.ugens.*;

/**
 * MathWaveScene
 *
 * Generates audio directly from mathematical functions (sine, square, triangle, sawtooth)
 * and visualises the waveform it's producing. Meta: the same functions that drive
 * every other scene are here made audible and visible simultaneously.
 *
 * Top panel  — analytical waveform of f(t) drawn across the screen
 * Bottom panel — oscilloscope of the actual PCM samples being synthesised
 *
 * The two panels should be identical. That's the point.
 *
 * Wave timbres:
 *   Sine     — pure tone, 1 harmonic
 *   Square   — hollow/buzzy, odd harmonics at 1/n amplitude
 *   Triangle — soft/mellow, odd harmonics at 1/n² amplitude
 *   Sawtooth — bright/rich, all harmonics at 1/n amplitude
 *
 * Controller:
 *   LStick ↕   — frequency (80–2400 Hz, log scale)
 *   RStick ↕   — amplitude (0–100%)
 *   A           — Sine
 *   B           — Square
 *   X           — Triangle
 *   Y           — Sawtooth
 *   LB / RB     — octave down / up (×0.5 / ×2)
 */
class MathWaveScene implements IScene {

  // ── Audio synthesis ──────────────────────────────────────────────────────────
  AudioOutput out;
  Oscil        wave;

  // ── State ────────────────────────────────────────────────────────────────────
  int   waveType    = 0;      // 0=sine 1=square 2=triangle 3=saw
  float targetFreq  = 220.0;
  float currentFreq = 220.0;
  float targetAmp   = 0.5;
  float currentAmp  = 0.5;

  float            prevGain          = 0;
  boolean          needsAudioInit    = false;
  volatile boolean audioInitRunning  = false;  // background thread guard

  // Visual phase: scrolls independently of audio frequency so the waveform
  // appears to animate at a readable speed rather than a blur.
  float vizPhase    = 0;
  static final float VIZ_CYCLES  = 2.5;  // cycles visible across screen
  static final float VIZ_SPEED   = 0.012; // radians per frame visual scroll

  // ── Wave metadata ────────────────────────────────────────────────────────────
  final String[] WAVE_NAME    = {"Sine",          "Square",              "Triangle",           "Sawtooth"};
  final String[] WAVE_FORMULA = {"sin(2\u03c0t)", "sgn(sin(2\u03c0t))", "\u222bsquare(t) dt", "2(t mod 1) \u2212 1"};
  final color[]  WAVE_COLOR   = {
    color(0, 220, 255),   // sine     — cyan
    color(0, 255, 140),   // square   — green
    color(255, 140, 0),   // triangle — amber
    color(220, 0, 255)    // saw      — magenta
  };

  // ── onEnter / onExit ─────────────────────────────────────────────────────────

  void onEnter() {
    prevGain = audio.getGain();
    audio.setGain(-80);      // mute song — safer than pause(), no stream lifecycle change

    needsAudioInit = true;  // always re-init on entry — out is closed in onExit()
  }

  // Spawns a daemon thread to call getLineOut() so the render loop never blocks.
  // Audio appears silently 1-2 frames after entering the scene.
  // If the user exits before init finishes, audioInitRunning=false aborts the set.
  void initAudio() {
    needsAudioInit    = false;
    audioInitRunning  = true;
    Thread t = new Thread(new Runnable() {
      public void run() {
        AudioOutput newOut = audio.minim.getLineOut();
        if (!audioInitRunning) {
          if (newOut != null) newOut.close();  // scene exited before init finished
          return;
        }
        if (newOut != null) {
          Oscil newWave = new Oscil(currentFreq, currentAmp, Waves.SINE);
          newWave.patch(newOut);
          out  = newOut;
          wave = newWave;
        }
        audioInitRunning = false;
      }
    });
    t.setDaemon(true);
    t.start();
  }

  void onExit() {
    needsAudioInit   = false;
    audioInitRunning = false;             // signal background thread to abort
    if (wave != null && out != null) wave.unpatch(out);
    if (out  != null) { out.close(); out = null; }  // close — no background thread while idle
    wave = null;
    audio.setGain(prevGain);
  }

  // ── Switch wave type ──────────────────────────────────────────────────────────

  void switchWave(int newType) {
    if (out == null) return;
    waveType = newType;
    wave.unpatch(out);
    Waveform wf;
    switch (waveType) {
      case 1:  wf = Waves.SQUARE;    break;
      case 2:  wf = Waves.TRIANGLE;  break;
      case 3:  wf = Waves.SAW;       break;
      default: wf = Waves.SINE;      break;
    }
    wave = new Oscil(currentFreq, currentAmp, wf);
    wave.patch(out);
  }

  // ── Evaluate waveform at normalised position ──────────────────────────────────
  // at ∈ [0,1] within one cycle → [-1,1]. Mirrors what the Waveform tables do.

  float evalWave(float at) {
    at = ((at % 1.0) + 1.0) % 1.0; // wrap to [0,1]
    switch (waveType) {
      case 0: return sin(at * TWO_PI);                           // sine
      case 1: return at < 0.5 ? 1.0 : -1.0;                    // square
      case 2: return at < 0.5 ? (at * 4.0 - 1.0)               // triangle
                              : (3.0 - at * 4.0);
      case 3: return at * 2.0 - 1.0;                            // sawtooth
      default: return sin(at * TWO_PI);
    }
  }

  // ── Controller ────────────────────────────────────────────────────────────────

  void applyController(Controller c) {
    // Wave type — rising edge only
    if (c.aJustPressed) switchWave(0);
    if (c.bJustPressed) switchWave(1);
    if (c.xJustPressed) switchWave(2);
    if (c.yJustPressed) switchWave(3);

    // Octave shift
    if (c.lbJustPressed) targetFreq = constrain(targetFreq * 0.5, 80, 2400);
    if (c.rbJustPressed) targetFreq = constrain(targetFreq * 2.0, 80, 2400);

    // Frequency — LStick Y, log scale 80..2400 Hz
    float lStick = 1.0 - (c.ly / (float) height); // 0=bottom 1=top
    float logMin = log(80)   / log(2);
    float logMax = log(2400) / log(2);
    targetFreq = pow(2, lerp(logMin, logMax, lStick));

    // Amplitude — RStick Y
    float rStick = 1.0 - (c.ry / (float) height);
    targetAmp = constrain(rStick, 0.0, 1.0);
  }

  void handleKey(char k) {
    switch (k) {
      case 'a': case 'A': switchWave(0); break;
      case 'b': case 'B': switchWave(1); break;
      case 'x': case 'X': switchWave(2); break;
      case 'y': case 'Y': switchWave(3); break;
      case ',':            targetFreq = constrain(targetFreq * 0.5, 80, 2400); break; // octave down
      case '.':            targetFreq = constrain(targetFreq * 2.0, 80, 2400); break; // octave up
    }
  }

  // ── Draw ──────────────────────────────────────────────────────────────────────

  void drawScene(PGraphics pg) {
    if (needsAudioInit) initAudio();  // kicks off background thread, returns immediately

    // Smooth freq / amplitude
    currentFreq = lerp(currentFreq, targetFreq, 0.04);
    currentAmp  = lerp(currentAmp,  targetAmp,  0.06);
    if (wave != null) {
      wave.setFrequency(currentFreq);
      wave.setAmplitude(currentAmp);
    }

    vizPhase += VIZ_SPEED;

    pg.beginDraw();
    pg.background(8, 8, 14);
    pg.blendMode(BLEND);

    float splitY   = pg.height * 0.65;
    color  wCol    = WAVE_COLOR[waveType];

    // ── Grid ──────────────────────────────────────────────────────────────────
    drawGrid(pg, splitY, wCol);

    // ── Analytical waveform ───────────────────────────────────────────────────
    drawAnalyticalWave(pg, splitY, wCol);

    // ── Divider ───────────────────────────────────────────────────────────────
    pg.noFill();
    pg.stroke(wCol, 40);
    pg.strokeWeight(1);
    pg.line(0, splitY, pg.width, splitY);

    // ── Oscilloscope panel — actual PCM buffer ─────────────────────────────────
    drawOscilloscope(pg, splitY, wCol);

    // ── Labels ────────────────────────────────────────────────────────────────
    drawLabels(pg, splitY, wCol);

    pg.endDraw();
  }

  // ── Grid ──────────────────────────────────────────────────────────────────────

  void drawGrid(PGraphics pg, float panelH, color wCol) {
    float midY  = panelH * 0.5;
    float ampH  = panelH * 0.40;

    pg.stroke(255, 255, 255, 20);
    pg.strokeWeight(1);

    // Horizontal grid lines: 0, ±0.5, ±1
    for (float v : new float[]{-1.0, -0.5, 0.0, 0.5, 1.0}) {
      float y = midY - v * ampH;
      pg.line(0, y, pg.width, y);
    }

    // Zero line slightly brighter
    pg.stroke(255, 255, 255, 50);
    pg.line(0, midY, pg.width, midY);

    // Vertical cycle markers
    pg.stroke(255, 255, 255, 15);
    for (int c = 0; c <= (int)VIZ_CYCLES; c++) {
      float x = pg.width * c / VIZ_CYCLES;
      pg.line(x, 0, x, panelH);
    }
  }

  // ── Analytical waveform ───────────────────────────────────────────────────────

  void drawAnalyticalWave(PGraphics pg, float panelH, color wCol) {
    float midY = panelH * 0.5;
    float ampH = panelH * 0.40;
    int   res  = pg.width; // one sample per pixel

    // Outer glow pass
    pg.noFill();
    pg.stroke(red(wCol), green(wCol), blue(wCol), 35);
    pg.strokeWeight(8 * uiScale());
    pg.beginShape();
    for (int i = 0; i <= res; i++) {
      float at  = (vizPhase / TWO_PI + (float)i / res * VIZ_CYCLES) % 1.0;
      float val = evalWave(at < 0 ? at + 1 : at);
      pg.vertex(i, midY - val * ampH);
    }
    pg.endShape();

    // Core line
    pg.stroke(red(wCol), green(wCol), blue(wCol), 220);
    pg.strokeWeight(2.5 * uiScale());
    pg.beginShape();
    for (int i = 0; i <= res; i++) {
      float at  = (vizPhase / TWO_PI + (float)i / res * VIZ_CYCLES) % 1.0;
      if (at < 0) at += 1;
      float val = evalWave(at);
      pg.vertex(i, midY - val * ampH);
    }
    pg.endShape();

    // ±1 labels on axis
    pg.fill(255, 255, 255, 60);
    pg.textFont(monoFont);
    pg.textSize(9 * uiScale());
    pg.textAlign(LEFT, CENTER);
    pg.text("+1", 6, midY - ampH);
    pg.text(" 0", 6, midY);
    pg.text("-1", 6, midY + ampH);
  }

  // ── Oscilloscope — actual audio buffer ────────────────────────────────────────

  void drawOscilloscope(PGraphics pg, float startY, color wCol) {
    if (out == null) return;
    float panelH = pg.height - startY;
    float midY   = startY + panelH * 0.5;
    float ampH   = panelH * 0.38;

    // Label
    pg.fill(255, 255, 255, 50);
    pg.textFont(monoFont);
    pg.textSize(9 * uiScale());
    pg.textAlign(RIGHT, TOP);
    pg.text("PCM output", pg.width - 8, startY + 6);

    // Draw buffer
    int bufSize = out.mix.size();
    if (bufSize == 0) return;

    pg.noFill();
    pg.stroke(red(wCol), green(wCol), blue(wCol), 30);
    pg.strokeWeight(6 * uiScale());
    pg.beginShape();
    for (int i = 0; i < bufSize; i++) {
      float x   = map(i, 0, bufSize - 1, 0, pg.width);
      float val = out.mix.get(i);
      pg.vertex(x, midY - val * ampH);
    }
    pg.endShape();

    pg.stroke(red(wCol), green(wCol), blue(wCol), 190);
    pg.strokeWeight(1.5 * uiScale());
    pg.beginShape();
    for (int i = 0; i < bufSize; i++) {
      float x   = map(i, 0, bufSize - 1, 0, pg.width);
      float val = out.mix.get(i);
      pg.vertex(x, midY - val * ampH);
    }
    pg.endShape();
  }

  // ── Labels ────────────────────────────────────────────────────────────────────

  void drawLabels(PGraphics pg, float splitY, color wCol) {
    float ts = uiScale();
    pg.textFont(monoFont);

    // Wave name — top left, large
    pg.fill(red(wCol), green(wCol), blue(wCol), 220);
    pg.textSize(22 * ts);
    pg.textAlign(LEFT, TOP);
    pg.text(WAVE_NAME[waveType], 18 * ts, 14 * ts);

    // Formula — centre, semi-transparent
    pg.fill(255, 255, 255, 100);
    pg.textSize(16 * ts);
    pg.textAlign(CENTER, TOP);
    pg.text("f(t) = " + WAVE_FORMULA[waveType], pg.width * 0.5, 16 * ts);

    // Frequency + note name — top right
    pg.fill(255, 255, 255, 180);
    pg.textSize(14 * ts);
    pg.textAlign(RIGHT, TOP);
    pg.text(nf(currentFreq, 0, 1) + " Hz  " + freqToNote(currentFreq), pg.width - 14 * ts, 14 * ts);

    // Amplitude — below freq
    pg.fill(255, 255, 255, 120);
    pg.textSize(11 * ts);
    pg.text("amp " + nf(currentAmp * 100, 0, 0) + "%", pg.width - 14 * ts, 34 * ts);

    // Bottom legend — wave type selector
    String[] labels = {"[A] sine", "[B] square", "[X] triangle", "[Y] saw"};
    float gap = pg.width / 5.0;
    for (int i = 0; i < 4; i++) {
      if (i == waveType) {
        pg.fill(red(WAVE_COLOR[i]), green(WAVE_COLOR[i]), blue(WAVE_COLOR[i]), 220);
      } else {
        pg.fill(255, 255, 255, 60);
      }
      pg.textSize(11 * ts);
      pg.textAlign(CENTER, BOTTOM);
      pg.text(labels[i], gap * (i + 1), pg.height - 10 * ts);
    }
  }

  // ── Frequency → note name ─────────────────────────────────────────────────────

  String freqToNote(float hz) {
    String[] names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
    int midi   = round(12 * (log(hz / 440.0) / log(2)) + 69);
    int octave = midi / 12 - 1;
    int note   = ((midi % 12) + 12) % 12;
    return names[note] + octave;
  }

  // ── IScene stubs ──────────────────────────────────────────────────────────────

  String[] getCodeLines() {
    return new String[]{
      "=== Math Wave Scene ===",
      "",
      "Generates audio from a pure",
      "mathematical function, then",
      "visualises the exact PCM",
      "samples being synthesised.",
      "",
      "Top panel   : f(t) analytical",
      "Bottom panel: raw audio buffer",
      "",
      "Both panels show the same signal.",
      "That is the point.",
      "",
      "Keys: A sine  B square  X tri  Y saw",
      "      , octave-  . octave+",
      "",
      "Sine    : 1 harmonic, pure tone",
      "Square  : odd harmonics, 1/n",
      "Triangle: odd harmonics, 1/n\u00b2",
      "Sawtooth: all harmonics, 1/n",
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("LStick \u2195", "Frequency (80\u20132400 Hz)"),
      new ControllerLayout("RStick \u2195", "Amplitude"),
      new ControllerLayout("A",             "Sine"),
      new ControllerLayout("B",             "Square"),
      new ControllerLayout("X",             "Triangle"),
      new ControllerLayout("Y",             "Sawtooth"),
      new ControllerLayout("LB",            "Octave down"),
      new ControllerLayout("RB",            "Octave up"),
    };
  }
}
