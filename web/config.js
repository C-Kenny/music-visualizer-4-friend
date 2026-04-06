/**
 * config.js — Global configuration state (mirrors Config.pde)
 * All scene logic reads/writes properties on the global `config` object.
 */

const Config = {
  // ── Title bar / UI ───────────────────────────────────────────────────────────
  TITLE_BAR: "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (p)lasma, (s)top, (w)ave, (>)diamonds, (/)fins, (n)ext, (N)shuffle",

  // ── Scene state ──────────────────────────────────────────────────────────────
  STATE: 0,        // 0 = file picker, 1 = Scene 1 (Fins), 11 = Lobster

  // ── Song info ────────────────────────────────────────────────────────────────
  SONG_PLAYING: false,
  SONG_NAME: "",

  // ── Fins (bezier petals / mandala) ───────────────────────────────────────────
  DRAW_FINS: true,
  FINS: 8.0,                  // number of fins (can be fractional for animation)
  FIN_REDNESS: 1,
  FIN_REDNESS_ANGRY: true,
  ANIMATED: true,
  finRotationClockWise: false,
  canChangeFinDirection: true,
  LAST_FIN_CHECK: 0,
  BEZIER_Y_OFFSET: -50,
  RAINBOW_FINS: false,

  // ── Diamonds ─────────────────────────────────────────────────────────────────
  DRAW_DIAMONDS: true,
  DRAW_INNER_DIAMONDS: false,
  DIAMOND_DISTANCE_FROM_CENTER: 0,   // init'd after s1Size known
  DIAMOND_WIDTH_OFFSET: 0.0,
  DIAMOND_HEIGHT_OFFSET: 0.0,
  DIAMOND_RIGHT_EDGE_X: 0,
  DIAMOND_LEFT_EDGE_X: 0,
  DIAMOND_RIGHT_EDGE_Y: 0,
  DIAMOND_LEFT_EDGE_Y: 0,
  MAX_DIAMOND_DISTANCE: 0,
  MIN_DIAMOND_DISTANCE: 0,
  INCREMENT_DIAMOND_DISTANCE: true,

  // ── Waveform ─────────────────────────────────────────────────────────────────
  DRAW_WAVEFORM: true,
  WAVE_MULTIPLIER: 50.0,

  // ── Backgrounds ──────────────────────────────────────────────────────────────
  BACKGROUND_ENABLED: true,
  MANDALA_DARK_MODE: false,
  DRAW_TUNNEL: false,
  DRAW_PLASMA: false,
  DRAW_POLAR_PLASMA: false,
  TUNNEL_ZOOM_INCREMENT: 400,

  // ── Plasma ───────────────────────────────────────────────────────────────────
  PLASMA_SIZE: 128,
  PLASMA_SEED: 0,
  PLASMA_INCREMENTING: true,
  canChangePlasmaFlow: false,
  LAST_PLASMA_CHECK: 0,

  // ── Blend modes ──────────────────────────────────────────────────────────────
  CURRENT_BLEND_MODE_INDEX: 0,

  // ── Dashed lines ─────────────────────────────────────────────────────────────
  DASH_LINE_SPEED: 0.5,
  DASH_LINE_SPEED_LIMIT: 69,
  DASH_LINE_SPEED_INCREASING: true,

  // ── Pulse ────────────────────────────────────────────────────────────────────
  PULSE_VALUE: 19.0,

  // ── FFT / Audio ──────────────────────────────────────────────────────────────
  bandsPerOctave: 4,
  GLOBAL_REDNESS: 0.0,

  // ── Misc ─────────────────────────────────────────────────────────────────────
  LOGGING_ENABLED: false,

  /**
   * Call once s1Size is known to initialise geometry constants.
   * @param {number} s1Size - size of the square canvas region
   */
  initForSize(s1Size) {
    this.DIAMOND_DISTANCE_FROM_CENTER = s1Size * 0.07;
    this.DIAMOND_RIGHT_EDGE_X = s1Size * 0.92;
    this.DIAMOND_LEFT_EDGE_X  = s1Size * 0.74;
    this.DIAMOND_RIGHT_EDGE_Y = s1Size * 0.71;
    this.DIAMOND_LEFT_EDGE_Y  = s1Size * 0.92;
    this.MAX_DIAMOND_DISTANCE = s1Size * 0.3;
    this.MIN_DIAMOND_DISTANCE = s1Size * 0.1;
  }
};
