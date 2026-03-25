/**
 * controller.js — Browser Gamepad API wrapper mirroring Controller.pde
 *
 * Usage:
 *   controller.read()          call once per frame
 *   controller.isConnected()   → bool
 *   controller.lx/ly/rx/ry     → mapped to screen coords (0..width, 0..height)
 *   controller.*_just_pressed  → rising-edge boolean flags (true for one frame)
 *   controller.dpad_hat_switch_up/down/left/right
 */
class GamepadController {
  constructor() {
    // Axis values mapped to screen coordinates
    this.lx = 0; this.ly = 0;
    this.rx = 0; this.ry = 0;

    // Raw axis values (-1..1)
    this._lxRaw = 0; this._lyRaw = 0;
    this._rxRaw = 0; this._ryRaw = 0;

    // Rising-edge button flags (true for exactly one frame)
    this.a_just_pressed          = false;
    this.b_just_pressed          = false;
    this.x_just_pressed          = false;
    this.y_just_pressed          = false;
    this.lb_just_pressed         = false;
    this.rb_just_pressed         = false;
    this.back_just_pressed       = false;
    this.start_just_pressed      = false;
    this.lstickclick_just_pressed = false;
    this.rstickclick_just_pressed = false;

    // D-pad (held state)
    this.dpad_hat_switch_up    = false;
    this.dpad_hat_switch_down  = false;
    this.dpad_hat_switch_left  = false;
    this.dpad_hat_switch_right = false;

    // Previous button states for rising-edge detection
    this._prev = {};

    // Listen for gamepad connections
    window.addEventListener('gamepadconnected',    (e) => console.log('[controller] connected:', e.gamepad.id));
    window.addEventListener('gamepaddisconnected', (e) => console.log('[controller] disconnected:', e.gamepad.id));
  }

  isConnected() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const pad of pads) {
      if (pad && pad.connected) return true;
    }
    return false;
  }

  _getGamepad() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const pad of pads) {
      if (pad && pad.connected) return pad;
    }
    return null;
  }

  /**
   * Call once per frame.  Reads the first connected gamepad and updates all
   * public fields.  Rising-edge flags are reset here so they're true for
   * exactly one frame.
   *
   * Standard Gamepad mapping (button indices):
   *   0=A, 1=B, 2=X, 3=Y, 4=LB, 5=RB, 6=LT, 7=RT,
   *   8=Back/Select, 9=Start, 10=L-click, 11=R-click,
   *   12=DPad↑, 13=DPad↓, 14=DPad←, 15=DPad→
   * Axes: 0=LX, 1=LY, 2=RX, 3=RY
   */
  read() {
    // Reset rising-edge flags
    this.a_just_pressed          = false;
    this.b_just_pressed          = false;
    this.x_just_pressed          = false;
    this.y_just_pressed          = false;
    this.lb_just_pressed         = false;
    this.rb_just_pressed         = false;
    this.back_just_pressed       = false;
    this.start_just_pressed      = false;
    this.lstickclick_just_pressed = false;
    this.rstickclick_just_pressed = false;
    this.dpad_hat_switch_up    = false;
    this.dpad_hat_switch_down  = false;
    this.dpad_hat_switch_left  = false;
    this.dpad_hat_switch_right = false;

    const pad = this._getGamepad();
    if (!pad) return;

    const B = pad.buttons;
    const A = pad.axes;

    // ── Axes → screen coords ──────────────────────────────────────────────────
    // Apply dead zone
    const dead = 0.12;
    const ax = (v) => Math.abs(v) < dead ? 0 : v;

    this._lxRaw = ax(A[0] || 0);
    this._lyRaw = ax(A[1] || 0);
    this._rxRaw = ax(A[2] || 0);
    this._ryRaw = ax(A[3] || 0);

    // Map -1..1 → 0..width / 0..height (matching Processing Controller.pde)
    this.lx = (this._lxRaw + 1) / 2 * (typeof width  !== 'undefined' ? width  : window.innerWidth);
    this.ly = (this._lyRaw + 1) / 2 * (typeof height !== 'undefined' ? height : window.innerHeight);
    this.rx = (this._rxRaw + 1) / 2 * (typeof width  !== 'undefined' ? width  : window.innerWidth);
    this.ry = (this._ryRaw + 1) / 2 * (typeof height !== 'undefined' ? height : window.innerHeight);

    // ── Rising-edge helper ────────────────────────────────────────────────────
    const pressed = (idx) => B[idx] ? B[idx].pressed : false;
    const rising  = (key, idx) => {
      const cur = pressed(idx);
      const was = this._prev[key] || false;
      this._prev[key] = cur;
      return cur && !was;
    };

    this.a_just_pressed          = rising('a',  0);
    this.b_just_pressed          = rising('b',  1);
    this.x_just_pressed          = rising('x',  2);
    this.y_just_pressed          = rising('y',  3);
    this.lb_just_pressed         = rising('lb', 4);
    this.rb_just_pressed         = rising('rb', 5);
    this.back_just_pressed       = rising('back', 8);
    this.start_just_pressed      = rising('start', 9);
    this.lstickclick_just_pressed = rising('lsc', 10);
    this.rstickclick_just_pressed = rising('rsc', 11);

    // D-pad: rising-edge for toggles (same pattern)
    this.dpad_hat_switch_up    = rising('dpu', 12);
    this.dpad_hat_switch_down  = rising('dpd', 13);
    this.dpad_hat_switch_left  = rising('dpl', 14);
    this.dpad_hat_switch_right = rising('dpr', 15);
  }

  debugPrintControls() {
    console.log('[controller] Controls:');
    console.log('  LX/LY: fin Y offset / wave amplitude');
    console.log('  RX/RY: diamond width/height offset');
    console.log('  A: toggle rainbow fins');
    console.log('  B: cycle blend mode');
    console.log('  LB/RB: prev/next scene');
    console.log('  Start/Back: play/stop');
    console.log('  D-pad: tunnel/plasma/polar/clear');
  }
}

// Global singleton
const controller = new GamepadController();
