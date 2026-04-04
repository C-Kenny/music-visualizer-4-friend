import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

class Controller {
  ControlIO control;
  ControlDevice stick;

  // Hot-plug: retry finding the device every RECONNECT_INTERVAL frames
  int reconnectTimer   = 0;
  int RECONNECT_INTERVAL = 120; // ~2 s at 60 fps

  float lx, ly;
  float rx, ry;

  /** Left / right trigger depression, ~0 (released) … 1 (full). Absent axes stay 0. */
  float lt, rt;

  boolean a_button, b_button, x_button, y_button;
  boolean back_button, start_button;
  boolean lb_button, rb_button;

  boolean dpad_hat_switch_up, dpad_hat_switch_down, dpad_hat_switch_left, dpad_hat_switch_right;

  boolean lstickclick_button, rstickclick_button;

  // Rising-edge (just pressed) flags — true only on the first frame a button goes down
  boolean a_just_pressed, b_just_pressed, x_just_pressed, y_just_pressed;
  boolean back_just_pressed, start_just_pressed;
  boolean lb_just_pressed, rb_just_pressed;
  boolean lstickclick_just_pressed, rstickclick_just_pressed;
  boolean dpad_up_just_pressed, dpad_down_just_pressed, dpad_left_just_pressed, dpad_right_just_pressed;

  // Previous-frame button states for edge detection
  private boolean prev_a, prev_b, prev_x, prev_y;
  private boolean prev_back, prev_start;
  private boolean prev_lb, prev_rb;
  private boolean prev_lstickclick, prev_rstickclick;
  private boolean prev_dpad_up, prev_dpad_down, prev_dpad_left, prev_dpad_right;

  Controller(PApplet applet) {
    control = ControlIO.getInstance(applet);
    tryConnect();
  }

  // Attempt to find a matched device. Safe to call repeatedly.
  // First tries the config-matched device; falls back to the first device
  // that reports at least two sliders (i.e. a gamepad, not a keyboard).
  void tryConnect() {
    // Primary: config-file match
    try {
      stick = control.getMatchedDevice("joystick");
      if (stick != null) {
        println("[Controller] Matched device: " + stick.getName());
        return;
      }
    } catch (Exception e) {
      println("[Controller] getMatchedDevice failed: " + e.getMessage());
    }

    // Fallback: enumerate all devices and pick the first gamepad-like one
    stick = null;
    int n = 0;
    try { n = control.getNumberOfDevices(); } catch (Exception e) {}
    println("[Controller] No config match. Scanning " + n + " device(s)...");
    for (int i = 0; i < n; i++) {
      try {
        ControlDevice dev = control.getDevice(i);
        println("[Controller]   [" + i + "] " + dev.getName()
                + "  sliders=" + dev.getNumberOfSliders()
                + "  buttons=" + dev.getNumberOfButtons());
        // A gamepad needs at least 2 axes (lx, ly)
        if (stick == null && dev.getNumberOfSliders() >= 2) {
          stick = dev;
          println("[Controller] Using fallback device: " + stick.getName());
        }
      } catch (Exception e) {
        println("[Controller]   [" + i + "] error: " + e.getMessage());
      }
    }
  }

  boolean isConnected() {
    return stick != null;
  }

  // Print matched device name and all its controls — call once from setup for debugging
  void debugPrintControls() {
    println("=== Controller matched: " + stick.getName() + " ===");
    for (ControlInput inp : stick.getInputs()) {
      String type = (inp instanceof ControlHat) ? "HAT" : (inp instanceof ControlButton) ? "BUTTON" : "SLIDER";
      println("  " + type + ": '" + inp.getName() + "'");
    }
  }

  private float getSliderValue(String name, float defaultVal) {
    try {
      ControlInput inp = stick.getSlider(name);
      return (inp != null) ? inp.getValue() : defaultVal;
    } catch (Exception e) {
      return defaultVal;
    }
  }

  // Try primary name first (virtual name used by getMatchedDevice),
  // fall back to altName (hardware name used by getDevice fallback).
  private float getSliderValue(String name, String altName, float defaultVal) {
    try {
      ControlInput inp = stick.getSlider(name);
      if (inp != null) return inp.getValue();
    } catch (Exception e) {}
    try {
      ControlInput inp = stick.getSlider(altName);
      if (inp != null) return inp.getValue();
    } catch (Exception e) {}
    return defaultVal;
  }

  private boolean getButtonState(String name) {
    try {
      ControlInput inp = stick.getButton(name);
      return (inp != null) ? ((ControlButton)inp).pressed() : false;
    } catch (Exception e) {
      return false;
    }
  }


  void read() {
    // Hot-plug: if device was missing at startup or got disconnected, retry
    // periodically so the user doesn't need to restart the app.
    if (stick == null) {
      reconnectTimer++;
      if (reconnectTimer >= RECONNECT_INTERVAL) {
        reconnectTimer = 0;
        tryConnect();
      }
      return; // nothing to read yet
    }

    // Try virtual names first (getMatchedDevice path: "lx"/"ly"),
    // fall back to hardware names (getDevice fallback path: "x"/"y").
    float raw_x  = getSliderValue("lx", "x",  0);
    float raw_y  = getSliderValue("ly", "y",  0);
    float raw_rx = getSliderValue("rx", "rx", 0);
    float raw_ry = getSliderValue("ry", "ry", 0);
    float raw_z  = getSliderValue("z",  "z",  -1);
    float raw_rz = getSliderValue("rz", "rz", -1);
    lx = map(raw_x,  -1, 1, 0, width);
    ly = map(raw_y,  -1, 1, 0, height);
    rx = map(raw_rx, -1, 1, 0, width);
    ry = map(raw_ry, -1, 1, 0, height);
    lt = constrain(map(raw_z,  -1, 1, 0, 1), 0, 1);
    rt = constrain(map(raw_rz, -1, 1, 0, 1), 0, 1);

    // Corrected Button Mappings (A, B, X, Y)
    a_button = getButtonState("A");
    b_button = getButtonState("B");
    x_button = getButtonState("X");
    y_button = getButtonState("Y");


    // Hardware names confirmed by raw scan: LB="Left Thumb", RB="Right Thumb",
    // L3="Left Thumb 3", R3="Right Thumb 3", Back="Select"
    lb_button = getButtonState("Left Thumb");
    rb_button = getButtonState("Right Thumb");

    back_button  = getButtonState("Select");
    start_button = getButtonState("Unknown") || getButtonState("Mode");

    lstickclick_button = getButtonState("Left Thumb 3");
    rstickclick_button = getButtonState("Right Thumb 3");

    // D-Pad Hat
    try {
      ControlHat hat = stick.getHat("cooliehat: pov");
      if (hat == null) hat = stick.getHat("dpad");
      
      if (hat != null) {
        dpad_hat_switch_up    = hat.up();
        dpad_hat_switch_down  = hat.down();
        dpad_hat_switch_left  = hat.left();
        dpad_hat_switch_right = hat.right();
      }
    } catch (Exception e) { /* Hat missing */ }

    // Compute rising-edge flags
    a_just_pressed = a_button && !prev_a;
    b_just_pressed = b_button && !prev_b;
    x_just_pressed = x_button && !prev_x;
    y_just_pressed = y_button && !prev_y;
    back_just_pressed = back_button && !prev_back;
    start_just_pressed = start_button && !prev_start;
    lb_just_pressed = lb_button && !prev_lb;
    rb_just_pressed = rb_button && !prev_rb;
    lstickclick_just_pressed = lstickclick_button && !prev_lstickclick;
    rstickclick_just_pressed = rstickclick_button && !prev_rstickclick;
    dpad_up_just_pressed = dpad_hat_switch_up && !prev_dpad_up;
    dpad_down_just_pressed = dpad_hat_switch_down && !prev_dpad_down;
    dpad_left_just_pressed = dpad_hat_switch_left && !prev_dpad_left;
    dpad_right_just_pressed = dpad_hat_switch_right && !prev_dpad_right;

    // Save current state for next frame
    prev_a = a_button; prev_b = b_button; prev_x = x_button; prev_y = y_button;
    prev_back = back_button; prev_start = start_button;
    prev_lb = lb_button; prev_rb = rb_button;
    prev_lstickclick = lstickclick_button; prev_rstickclick = rstickclick_button;
    prev_dpad_up = dpad_hat_switch_up; prev_dpad_down = dpad_hat_switch_down;
    prev_dpad_left = dpad_hat_switch_left; prev_dpad_right = dpad_hat_switch_right;
  }
}