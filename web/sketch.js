/**
 * sketch.js — Main p5.js entry point
 *
 * State machine:
 *   0  = file picker (wait for song load)
 *   1  = Scene 1: Fins / Diamonds / Waveform
 *   11 = Scene 11: Lobsters 🦞
 *
 * All scenes draw into an off-screen p5.Graphics buffer then blit to canvas,
 * so scenes never need to worry about canvas size differences.
 */

// ── p5.js instance-mode sketch ───────────────────────────────────────────────
// We use global mode (default) because all scene files expect globals like
// p5 drawing functions.  The global `p` alias is set in setup().

let pg1;          // Graphics buffer for Scene 1 (s1Size × s1Size square)
let s1Size = 0;   // side length of Scene 1 square
let s1OffsetX = 0;
let _p5ref = null;  // captured p5 instance (for passing to scenes in global mode)

// Scene transition toast
let toastMessage   = '';
let toastAlpha     = 0;
const TOAST_FADE   = 120; // frames to fade out

// Keyboard shortcut overlay
let showHelp = false;

// Scene names for nav bar and toast
const SCENE_NAMES = {
  1:  'Scene 1 — Fins / Mandala',
  11: 'Lobsters 🦞',
};

const SCENE_ORDER = [1, 11];

// Blend mode constant lookup (populated in setup)
let BLEND_MODES = [];

function setup() {
  // Full-screen canvas, no scrollbars
  const cnv = createCanvas(windowWidth, windowHeight);
  cnv.style('display', 'block');
  frameRate(120);
  _p5ref = this || window; // capture p5 context for global-mode scenes
  textFont('monospace');

  s1Size    = min(width, height);
  s1OffsetX = (width - s1Size) / 2.0;

  // Create off-screen buffer for Scene 1
  pg1 = createGraphics(s1Size, s1Size);
  pg1.pixelDensity(1); // keep pixel arrays manageable

  // Scene 1: inject p5 instance and init geometry
  scene1.p = pg1;
  scene1.init(s1Size);

  // Blend mode constants
  BLEND_MODES = [BLEND, ADD, SUBTRACT, EXCLUSION, DIFFERENCE, MULTIPLY, SCREEN, REPLACE];

  // Wire up file picker events
  _setupFilePicker();
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
  s1Size    = min(width, height);
  s1OffsetX = (width - s1Size) / 2.0;

  // Rebuild Scene 1 buffer at new size
  pg1.remove();
  pg1 = createGraphics(s1Size, s1Size);
  pg1.pixelDensity(1);
  scene1.p = pg1;
  scene1.init(s1Size);
}

function draw() {
  // Update FPS in title bar every 100 frames
  if (frameCount % 100 === 0) {
    document.title = `fps: ${int(frameRate())} | Music Visualizer`;
  }

  // Gamepad input
  if (controller.isConnected()) {
    controller.read();
    _handleControllerInput();
  }

  switch (Config.STATE) {
    case 0:
      // File picker UI — handled by HTML/CSS, just show a dark background
      background(10);
      break;

    case 1:
      _drawScene1();
      break;

    case 11:
      _drawScene11();
      break;

    default:
      background(0);
  }

  // ── Bottom nav bar ────────────────────────────────────────────────────────
  _drawNavBar();

  // ── Scene name toast ──────────────────────────────────────────────────────
  if (toastAlpha > 0) {
    _drawToast();
    toastAlpha -= 255 / TOAST_FADE;
  }

  // ── Help overlay ──────────────────────────────────────────────────────────
  if (showHelp) {
    _drawHelpOverlay();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene rendering
// ─────────────────────────────────────────────────────────────────────────────

function _drawScene1() {
  // Dark sides
  background(15);

  // Draw into off-screen buffer
  const bm = BLEND_MODES[Config.CURRENT_BLEND_MODE_INDEX % BLEND_MODES.length];
  pg1.blendMode(bm);
  scene1.draw(pg1);

  // Blit centered square onto main canvas
  blendMode(BLEND);
  image(pg1, s1OffsetX, 0, s1Size, s1Size);
}

function _drawScene11() {
  // Scene 11 draws directly to main canvas (full-screen).
  // In p5 global mode, drawing functions are on the window object.
  // We pass a proxy that delegates to p5 globals so scene11 can call p.fill(), etc.
  scene11.draw(_globalP5Proxy);
}

// ─────────────────────────────────────────────────────────────────────────────
// UI helpers
// ─────────────────────────────────────────────────────────────────────────────

function _drawNavBar() {
  const barH = 36;
  const barY = height - barH;

  push();
  noStroke();
  fill(0, 0, 0, 160);
  rect(0, barY, width, barH);

  textSize(13);
  textAlign(CENTER, CENTER);

  const scenes = Object.entries(SCENE_NAMES);
  // Reserve right side for source badge
  const badgeW = 90;
  const navW   = width - badgeW;
  const slotW  = navW / scenes.length;

  for (let i = 0; i < scenes.length; i++) {
    const [id, name] = scenes[i];
    const active = Config.STATE === parseInt(id);
    const cx = slotW * i + slotW / 2;
    const cy = barY + barH / 2;

    if (active) {
      fill(255, 160, 50, 220);
      noStroke();
      rect(slotW * i + 2, barY + 3, slotW - 4, barH - 6, 4);
      fill(10);
    } else {
      fill(180, 180, 180, 200);
    }
    text(name, cx, cy);
  }

  // ── Source type badge (right side of nav bar) ─────────────────────────
  const srcLabels = { file: '📁 File', mic: '🎤 Mic', system: '🖥️ System' };
  const srcLabel  = srcLabels[audio.sourceType] || audio.sourceType;
  const bx = width - badgeW;

  noStroke();
  fill(30, 30, 30, 200);
  rect(bx + 4, barY + 4, badgeW - 8, barH - 8, 4);

  fill(160, 200, 160, 220);
  textSize(11);
  textAlign(CENTER, CENTER);
  text(srcLabel, bx + badgeW / 2, barY + barH / 2);

  pop();
}

function _drawToast() {
  push();
  const alpha = constrain(toastAlpha, 0, 255);
  textSize(28);
  textAlign(CENTER, CENTER);

  // Shadow
  fill(0, 0, 0, alpha * 0.6);
  text(toastMessage, width / 2 + 2, height / 2 + 2);

  // Main text
  fill(255, 220, 80, alpha);
  text(toastMessage, width / 2, height / 2);
  pop();
}

function _drawHelpOverlay() {
  const lines = [
    '=== KEYBOARD SHORTCUTS ===',
    '',
    '1          →  Scene 1 (Fins / Mandala)',
    '-          →  Scene 11 (Lobsters 🦞)',
    '',
    't          →  toggle tunnel background',
    'p          →  toggle plasma background',
    'P          →  toggle polar plasma',
    'b          →  cycle blend mode',
    'f / F      →  flip fin rotation direction',
    'd / D      →  diamond distance closer / farther',
    '>          →  toggle diamonds',
    '/          →  toggle fins',
    'w / W      →  toggle waveform',
    's / S      →  play / pause',
    'n          →  next song (if multiple loaded)',
    'N          →  shuffle song',
    '← / →      →  skip -10s / +10s',
    '↑ / ↓      →  volume up / down',
    '?          →  toggle this help overlay',
    '',
    '=== GAMEPAD ===',
    'LB / RB    →  prev / next scene',
    'A          →  rainbow fins',
    'B          →  cycle blend mode',
    'Start      →  play',
    'Back       →  pause',
    'D-pad ↑    →  toggle tunnel',
    'D-pad ←    →  toggle plasma',
    'D-pad →    →  toggle polar plasma',
  ];

  push();
  const lh = 22;
  const pad = 20;
  const bw = 480;
  const bh = pad * 2 + lines.length * lh;
  const bx = (width - bw) / 2;
  const by = (height - bh) / 2;

  fill(0, 0, 0, 210);
  noStroke();
  rect(bx, by, bw, bh, 8);

  stroke(0, 200, 80, 160);
  strokeWeight(1.5);
  noFill();
  rect(bx, by, bw, bh, 8);

  textAlign(LEFT, TOP);
  textSize(13);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith('===')) fill(0, 255, 120);
    else if (line === '')       fill(0, 0, 0, 0);
    else                       fill(180, 255, 180);
    noStroke();
    text(line, bx + pad, by + pad + i * lh);
  }
  pop();
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene switching
// ─────────────────────────────────────────────────────────────────────────────

function switchScene(id) {
  if (Config.STATE === id) return;
  Config.STATE = id;
  const name = SCENE_NAMES[id] || `Scene ${id}`;
  toastMessage = name;
  toastAlpha   = 255;
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard input
// ─────────────────────────────────────────────────────────────────────────────

function keyPressed() {
  // Ignore keys until audio source is active (except ?)
  if (Config.STATE === 0 && key !== '?') return;

  // ── Scene switching ─────────────────────────────────────────────────────
  if (key === '1') switchScene(1);
  if (key === '-') switchScene(11);

  // ── Background toggles ──────────────────────────────────────────────────
  if (key === 't' || key === 'T') {
    Config.DRAW_TUNNEL = !Config.DRAW_TUNNEL;
    if (Config.DRAW_TUNNEL) _enableOneBg('tunnel');
  }
  if (key === 'p') {
    Config.DRAW_PLASMA = !Config.DRAW_PLASMA;
    if (Config.DRAW_PLASMA) {
      _enableOneBg('plasma');
      // Rebuild plasma with new random seed
      scene1.plasma = new PlasmaEffect(pg1, s1Size, s1Size);
    }
  }
  if (key === 'P') {
    Config.DRAW_POLAR_PLASMA = !Config.DRAW_POLAR_PLASMA;
    if (Config.DRAW_POLAR_PLASMA) _enableOneBg('polar_plasma');
  }

  // ── Blend mode ──────────────────────────────────────────────────────────
  if (key === 'b' || key === 'B') {
    Config.CURRENT_BLEND_MODE_INDEX =
      (Config.CURRENT_BLEND_MODE_INDEX + 1) % BLEND_MODES.length;
  }

  // ── Fins ────────────────────────────────────────────────────────────────
  if (key === 'f' || key === 'F') {
    Config.finRotationClockWise = !Config.finRotationClockWise;
    Config.canChangeFinDirection = false;
  }

  // ── Diamonds ────────────────────────────────────────────────────────────
  if (key === 'd') {
    Config.DIAMOND_DISTANCE_FROM_CENTER -= width * 0.02;
  }
  if (key === 'D') {
    Config.DIAMOND_DISTANCE_FROM_CENTER += width * 0.02;
  }
  if (key === '>' || key === '.') {
    Config.DRAW_DIAMONDS = !Config.DRAW_DIAMONDS;
  }

  // ── Waveform ────────────────────────────────────────────────────────────
  if (key === 'w' || key === 'W') {
    Config.DRAW_WAVEFORM = !Config.DRAW_WAVEFORM;
  }

  // ── Fins toggle ─────────────────────────────────────────────────────────
  if (key === '/') {
    Config.DRAW_FINS = !Config.DRAW_FINS;
  }

  // ── Playback ────────────────────────────────────────────────────────────
  if (key === 's' || key === 'S') {
    if (Config.SONG_PLAYING) {
      audio.pause();
    } else {
      audio.play();
    }
  }

  // ── Help overlay ─────────────────────────────────────────────────────────
  if (key === '?') {
    showHelp = !showHelp;
  }

  // ── Arrow keys (coded) ──────────────────────────────────────────────────
  if (keyCode === LEFT_ARROW)  audio.skip(-10000);
  if (keyCode === RIGHT_ARROW) audio.skip(10000);
  if (keyCode === UP_ARROW) {
    audio.setGain(audio.getGain() + 5);
  }
  if (keyCode === DOWN_ARROW) {
    audio.setGain(audio.getGain() - 5);
  }

  // ── Next / shuffle ──────────────────────────────────────────────────────
  // (single-file mode: these are no-ops unless multiple files are queued)
  if (key === 'n') _nextSong();
  if (key === 'N') _shuffleSong();

  // Prevent browser default (e.g. space bar scrolling)
  return false;
}

function _enableOneBg(which) {
  Config.DRAW_TUNNEL      = (which === 'tunnel');
  Config.DRAW_PLASMA      = (which === 'plasma');
  Config.DRAW_POLAR_PLASMA = (which === 'polar_plasma');
}

// ─────────────────────────────────────────────────────────────────────────────
// Song management (multi-file queue)
// ─────────────────────────────────────────────────────────────────────────────

let _songQueue = [];
let _songIndex = 0;

function _nextSong() {
  if (_songQueue.length < 2) return;
  _songIndex = (_songIndex + 1) % _songQueue.length;
  audio.loadFile(_songQueue[_songIndex]);
}

function _shuffleSong() {
  if (_songQueue.length < 2) return;
  let i;
  do { i = Math.floor(Math.random() * _songQueue.length); } while (i === _songIndex);
  _songIndex = i;
  audio.loadFile(_songQueue[_songIndex]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Gamepad controller input (mirrors getUserInput in Processing)
// ─────────────────────────────────────────────────────────────────────────────

function _handleControllerInput() {
  const c = controller;

  // D-pad background toggles
  if (c.dpad_hat_switch_up)    { Config.DRAW_TUNNEL = !Config.DRAW_TUNNEL; if (Config.DRAW_TUNNEL) _enableOneBg('tunnel'); }
  if (c.dpad_hat_switch_left)  { Config.DRAW_PLASMA = !Config.DRAW_PLASMA; if (Config.DRAW_PLASMA) { _enableOneBg('plasma'); scene1.plasma = new PlasmaEffect(pg1, s1Size, s1Size); } }
  if (c.dpad_hat_switch_right) { Config.DRAW_POLAR_PLASMA = !Config.DRAW_POLAR_PLASMA; if (Config.DRAW_POLAR_PLASMA) _enableOneBg('polar_plasma'); }
  if (c.dpad_hat_switch_down)  { Config.DRAW_TUNNEL = false; Config.DRAW_PLASMA = false; Config.DRAW_POLAR_PLASMA = false; }

  // Scene 1: stick controls
  if (Config.STATE === 1) {
    Config.BEZIER_Y_OFFSET  = (c.ly - height/2) - 12;
    Config.WAVE_MULTIPLIER  = (c.ry % (height/5)) + 25;
    Config.DIAMOND_WIDTH_OFFSET  = ((c.rx - height/10) / 5.0) - 80;
    Config.DIAMOND_HEIGHT_OFFSET = ((c.ry - height/10) / 5.0) - 80;
  }

  if (c.b_just_pressed) {
    Config.CURRENT_BLEND_MODE_INDEX = (Config.CURRENT_BLEND_MODE_INDEX + 1) % BLEND_MODES.length;
  }
  if (c.a_just_pressed) Config.RAINBOW_FINS = !Config.RAINBOW_FINS;
  if (c.y_just_pressed) { Config.finRotationClockWise = !Config.finRotationClockWise; }
  if (c.back_just_pressed)  audio.pause();
  if (c.start_just_pressed) audio.play();
  if (c.lb_just_pressed) {
    const idx = SCENE_ORDER.indexOf(Config.STATE);
    const prev = SCENE_ORDER[(idx - 1 + SCENE_ORDER.length) % SCENE_ORDER.length];
    switchScene(prev);
  }
  if (c.rb_just_pressed) {
    const idx = SCENE_ORDER.indexOf(Config.STATE);
    const next = SCENE_ORDER[(idx + 1) % SCENE_ORDER.length];
    switchScene(next);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File picker wiring
// ─────────────────────────────────────────────────────────────────────────────

function _setupFilePicker() {
  const dropZone    = document.getElementById('drop-zone');
  const fileInput   = document.getElementById('file-input');
  const pickerUI    = document.getElementById('picker-ui');
  const btnFile     = document.getElementById('btn-file');
  const btnMic      = document.getElementById('btn-mic');
  const btnSystem   = document.getElementById('btn-system');
  const errorMsg    = document.getElementById('error-msg');

  if (!dropZone || !fileInput || !pickerUI) return;

  // ── Helper: show error temporarily ──────────────────────────────────
  function showError(msg) {
    if (!errorMsg) return;
    errorMsg.textContent = msg;
    errorMsg.style.display = 'block';
    setTimeout(() => { errorMsg.style.display = 'none'; }, 5000);
  }

  // ── File button → open file dialog ──────────────────────────────────
  if (btnFile) btnFile.addEventListener('click', () => fileInput.click());

  // ── Drop zone click → open file dialog ──────────────────────────────
  dropZone.addEventListener('click', () => fileInput.click());

  // ── File input change ────────────────────────────────────────────────
  fileInput.addEventListener('change', (e) => {
    const files = Array.from(e.target.files);
    if (files.length > 0) _loadFiles(files);
  });

  // ── Drag-and-drop ────────────────────────────────────────────────────
  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('drag-over');
  });
  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag-over'));
  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    const files = Array.from(e.dataTransfer.files).filter(f =>
      /\.(mp3|wav|flac|ogg|aac|m4a)$/i.test(f.name)
    );
    if (files.length > 0) _loadFiles(files);
  });

  // ── Mic button ───────────────────────────────────────────────────────
  if (btnMic) {
    btnMic.addEventListener('click', async () => {
      try {
        btnMic.disabled = true;
        btnMic.style.opacity = '0.6';
        await audio.setSourceMic();
        _launchVisualizer();
      } catch(err) {
        console.error('Mic error:', err);
        showError('Microphone access denied or unavailable: ' + err.message);
      } finally {
        btnMic.disabled = false;
        btnMic.style.opacity = '';
      }
    });
  }

  // ── System audio button ──────────────────────────────────────────────
  if (btnSystem) {
    btnSystem.addEventListener('click', async () => {
      try {
        btnSystem.disabled = true;
        btnSystem.style.opacity = '0.6';
        await audio.setSourceSystem();
        _launchVisualizer();
      } catch(err) {
        console.error('System audio error:', err);
        showError('System audio unavailable: ' + err.message);
      } finally {
        btnSystem.disabled = false;
        btnSystem.style.opacity = '';
      }
    });
  }
}

async function _loadFiles(files) {
  _songQueue = files;
  _songIndex = 0;
  await audio.loadFile(files[0]);
  _launchVisualizer();
}

function _launchVisualizer() {
  // Hide picker, show canvas full-screen
  const pickerUI = document.getElementById('picker-ui');
  if (pickerUI) pickerUI.style.display = 'none';

  Config.STATE = 1;
  switchScene(1);
}

/**
 * _globalP5Proxy — a thin proxy object that delegates p5 drawing calls
 * to the global-mode p5 functions.  Scene11 expects a p5-like object.
 *
 * In global mode, p5 installs all drawing functions directly on window,
 * so we just make an object that forwards everything to window.
 */
const _globalP5Proxy = new Proxy({}, {
  get(target, prop) {
    // Special width/height properties
    if (prop === 'width')  return width;
    if (prop === 'height') return height;
    // p5 constants & functions live on window in global mode
    if (prop in window) {
      const v = window[prop];
      return (typeof v === 'function') ? v.bind(window) : v;
    }
    return undefined;
  }
});
