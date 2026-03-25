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
  sceneMandala.p = pg1;
  sceneMandala.init(s1Size);

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
  sceneMandala.p = pg1;
  sceneMandala.init(s1Size);
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
      _drawSceneMandala();
      break;

    case 11:
      _drawSceneLobsters();
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

function _drawSceneMandala() {
  // Dark sides
  background(15);

  // Draw into off-screen buffer
  const bm = BLEND_MODES[Config.CURRENT_BLEND_MODE_INDEX % BLEND_MODES.length];
  pg1.blendMode(bm);
  sceneMandala.draw(pg1);

  // Blit centered square onto main canvas
  blendMode(BLEND);
  image(pg1, s1OffsetX, 0, s1Size, s1Size);
}

function _drawSceneLobsters() {
  // Scene 11 draws directly to main canvas (full-screen).
  // In p5 global mode, drawing functions are on the window object.
  // We pass a proxy that delegates to p5 globals so sceneLobsters can call p.fill(), etc.
  sceneLobsters.draw(_globalP5Proxy);
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

  for (let sceneIndex = 0; sceneIndex < scenes.length; sceneIndex++) {
    const [id, name] = scenes[sceneIndex];
    const active = Config.STATE === parseInt(id);
    const cx = slotW * sceneIndex + slotW / 2;
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
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const lineText = lines[lineIndex];
    if (lineText.startsWith('===')) fill(0, 255, 120);
    else if (lineText === '')       fill(0, 0, 0, 0);
    else                            fill(180, 255, 180);
    noStroke();
    text(lineText, bx + pad, by + pad + lineIndex * lh);
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
      sceneMandala.plasma = new PlasmaEffect(pg1, s1Size, s1Size);
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
  let randomIndex;
  // Keep picking until we land on a different song than the one currently playing
  do { randomIndex = Math.floor(Math.random() * _songQueue.length); } while (randomIndex === _songIndex);
  _songIndex = randomIndex;
  audio.loadFile(_songQueue[_songIndex]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Gamepad controller input (mirrors getUserInput in Processing)
// ─────────────────────────────────────────────────────────────────────────────

function _handleControllerInput() {
  const c = controller;

  // D-pad background toggles
  if (c.dpad_hat_switch_up)    { Config.DRAW_TUNNEL = !Config.DRAW_TUNNEL; if (Config.DRAW_TUNNEL) _enableOneBg('tunnel'); }
  if (c.dpad_hat_switch_left)  { Config.DRAW_PLASMA = !Config.DRAW_PLASMA; if (Config.DRAW_PLASMA) { _enableOneBg('plasma'); sceneMandala.plasma = new PlasmaEffect(pg1, s1Size, s1Size); } }
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
  const dropZoneEl      = document.getElementById('drop-zone');
  const fileInputEl     = document.getElementById('file-input');
  const pickerUIEl      = document.getElementById('picker-ui');
  const fileButtonEl    = document.getElementById('btn-file');
  const micButtonEl     = document.getElementById('btn-mic');
  const systemButtonEl  = document.getElementById('btn-system');
  const errorToastEl    = document.getElementById('error-msg');
  const systemNoteEl    = document.getElementById('system-note');

  // Firefox-specific elements
  const firefoxHelpOverlayEl = document.getElementById('firefox-help-overlay');
  const firefoxHelpGotItBtn  = document.getElementById('firefox-help-got-it-btn');
  const firefoxMicBadgeEl    = document.getElementById('firefox-mic-badge');

  // Device picker elements
  const devicePickerEl       = document.getElementById('device-picker');
  const devicePickerLabelEl  = document.getElementById('device-picker-label');
  const deviceSelectEl       = document.getElementById('device-select');
  const deviceConnectBtn     = document.getElementById('device-connect-btn');
  const deviceCancelBtn      = document.getElementById('device-cancel-btn');

  if (!dropZoneEl || !fileInputEl || !pickerUIEl) return;

  // Detect Firefox — it doesn't support getDisplayMedia() for system audio
  const isFirefoxBrowser = navigator.userAgent.toLowerCase().includes('firefox');

  // ── Apply Firefox-specific UI tweaks ────────────────────────────────────
  if (isFirefoxBrowser) {
    // Grey out the System button and explain why
    systemButtonEl.classList.add('firefox-unsupported');
    systemButtonEl.title = 'Not supported in Firefox — use Mic with a virtual audio device instead';

    // Show the badge on the Mic button pointing users toward the right option
    if (firefoxMicBadgeEl) firefoxMicBadgeEl.style.display = 'block';

    // Replace the generic system-audio note with a Firefox-specific one
    if (systemNoteEl) {
      systemNoteEl.innerHTML = 'Firefox detected — System audio isn\'t available.<br>' +
        'Click <strong style="color:#ccc">🎤 Mic</strong> and select your monitor/loopback device instead.';
    }
  }

  // ── Helper: show error toast for a few seconds ───────────────────────────
  function showErrorToast(errorMessage) {
    if (!errorToastEl) return;
    errorToastEl.textContent = errorMessage;
    errorToastEl.style.display = 'block';
    setTimeout(() => { errorToastEl.style.display = 'none'; }, 5000);
  }

  // ── Firefox help overlay: open / close ──────────────────────────────────
  function showFirefoxHelpOverlay() {
    if (!firefoxHelpOverlayEl) return;
    firefoxHelpOverlayEl.classList.add('visible');
  }

  function hideFirefoxHelpOverlay() {
    if (!firefoxHelpOverlayEl) return;
    firefoxHelpOverlayEl.classList.remove('visible');
  }

  if (firefoxHelpGotItBtn) {
    firefoxHelpGotItBtn.addEventListener('click', () => {
      hideFirefoxHelpOverlay();
      // Highlight the Mic button so the user knows where to go next
      if (micButtonEl) {
        micButtonEl.focus();
        micButtonEl.style.borderColor = '#ff9933';
        setTimeout(() => { micButtonEl.style.borderColor = ''; }, 1800);
      }
    });
  }

  // Dismiss overlay with Escape key
  document.addEventListener('keydown', (keyEvent) => {
    if (keyEvent.key === 'Escape' && firefoxHelpOverlayEl &&
        firefoxHelpOverlayEl.classList.contains('visible')) {
      hideFirefoxHelpOverlay();
    }
  });

  // ── File button → open file dialog ──────────────────────────────────────
  if (fileButtonEl) fileButtonEl.addEventListener('click', () => fileInputEl.click());

  // ── Drop zone click → open file dialog ──────────────────────────────────
  dropZoneEl.addEventListener('click', () => fileInputEl.click());

  // ── File input change ────────────────────────────────────────────────────
  fileInputEl.addEventListener('change', (changeEvent) => {
    const selectedFiles = Array.from(changeEvent.target.files);
    if (selectedFiles.length > 0) _loadFiles(selectedFiles);
  });

  // ── Drag-and-drop ────────────────────────────────────────────────────────
  dropZoneEl.addEventListener('dragover', (dragEvent) => {
    dragEvent.preventDefault();
    dropZoneEl.classList.add('drag-over');
  });
  dropZoneEl.addEventListener('dragleave', () => dropZoneEl.classList.remove('drag-over'));
  dropZoneEl.addEventListener('drop', (dropEvent) => {
    dropEvent.preventDefault();
    dropZoneEl.classList.remove('drag-over');
    const droppedAudioFiles = Array.from(dropEvent.dataTransfer.files).filter(
      droppedFile => /\.(mp3|wav|flac|ogg|aac|m4a)$/i.test(droppedFile.name)
    );
    if (droppedAudioFiles.length > 0) _loadFiles(droppedAudioFiles);
  });

  // ── Device picker: show with discovered audio inputs ─────────────────────
  //
  // We enumerate devices *before* asking for permission — on first call this
  // usually returns unlabelled entries. After getUserMedia() grants access,
  // labels become available. We do a quick permission-first approach: request
  // a throwaway stream to unlock labels, then enumerate properly.
  async function showDevicePickerForMic() {
    devicePickerEl.classList.add('visible');
    deviceSelectEl.innerHTML = '<option value="">Loading devices…</option>';
    deviceConnectBtn.disabled = true;

    try {
      // Request a temporary stream just to unlock device labels in the browser.
      // Without this, enumerateDevices() returns empty labels on most browsers.
      const labelUnlockStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      labelUnlockStream.getTracks().forEach(track => track.stop());
    } catch (permissionError) {
      // If permission is denied here, we'll surface it later when connecting.
      console.warn('[device picker] Could not unlock device labels:', permissionError.message);
    }

    const allMediaDevices    = await navigator.mediaDevices.enumerateDevices();
    const audioInputDevices  = allMediaDevices.filter(device => device.kind === 'audioinput');

    deviceSelectEl.innerHTML = '';

    if (audioInputDevices.length === 0) {
      // No devices found — add a placeholder and let the connect button try anyway
      const placeholderOption = document.createElement('option');
      placeholderOption.value = '';
      placeholderOption.textContent = 'Default microphone';
      deviceSelectEl.appendChild(placeholderOption);
    } else {
      audioInputDevices.forEach(audioDevice => {
        const deviceOption = document.createElement('option');
        deviceOption.value = audioDevice.deviceId;
        // Fall back to a generic label if the browser won't tell us the name
        deviceOption.textContent = audioDevice.label || `Microphone (${audioDevice.deviceId.slice(0, 8)}…)`;
        deviceSelectEl.appendChild(deviceOption);
      });
    }

    // On Firefox, tell users specifically to look for the Monitor entry
    if (isFirefoxBrowser && devicePickerLabelEl) {
      devicePickerLabelEl.textContent =
        '🎤 Select audio source (choose "Monitor of…" for system audio on Linux):';
    } else if (devicePickerLabelEl) {
      devicePickerLabelEl.textContent = '🎤 Audio input device:';
    }

    deviceConnectBtn.disabled = false;
  }

  function hideDevicePicker() {
    devicePickerEl.classList.remove('visible');
  }

  // ── Mic button ───────────────────────────────────────────────────────────
  if (micButtonEl) {
    micButtonEl.addEventListener('click', async () => {
      // Show device picker so user can choose their input (e.g. loopback monitor)
      await showDevicePickerForMic();
    });
  }

  // ── Device picker: Connect button ────────────────────────────────────────
  if (deviceConnectBtn) {
    deviceConnectBtn.addEventListener('click', async () => {
      const selectedDeviceId = deviceSelectEl.value;
      hideDevicePicker();

      try {
        micButtonEl.disabled = true;
        micButtonEl.style.opacity = '0.6';
        await audio.setSourceMic(selectedDeviceId || null);
        _launchVisualizer();
      } catch (micError) {
        console.error('[mic] Connection failed:', micError);
        showErrorToast('Microphone access denied or unavailable: ' + micError.message);
      } finally {
        micButtonEl.disabled = false;
        micButtonEl.style.opacity = '';
      }
    });
  }

  // ── Device picker: Cancel button ─────────────────────────────────────────
  if (deviceCancelBtn) {
    deviceCancelBtn.addEventListener('click', () => hideDevicePicker());
  }

  // ── System audio button ──────────────────────────────────────────────────
  if (systemButtonEl) {
    systemButtonEl.addEventListener('click', async () => {
      // On Firefox, getDisplayMedia() doesn't capture system audio at all.
      // Show the help panel instead of attempting a call that will silently fail.
      if (isFirefoxBrowser) {
        showFirefoxHelpOverlay();
        return;
      }

      try {
        systemButtonEl.disabled = true;
        systemButtonEl.style.opacity = '0.6';
        await audio.setSourceSystem();
        _launchVisualizer();
      } catch (systemAudioError) {
        console.error('[system audio] Capture failed:', systemAudioError);
        showErrorToast('System audio unavailable: ' + systemAudioError.message);
      } finally {
        systemButtonEl.disabled = false;
        systemButtonEl.style.opacity = '';
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
 * to the global-mode p5 functions.  SceneLobsters expects a p5-like object.
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
      const windowProperty = window[prop];
      return (typeof windowProperty === 'function') ? windowProperty.bind(window) : windowProperty;
    }
    return undefined;
  }
});
