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

  boolean aButton, bButton, xButton, yButton;
  boolean backButton, startButton;
  boolean lbButton, rbButton;

  boolean dpadUpHeld, dpadDownHeld, dpadLeftHeld, dpadRightHeld;

  boolean leftStickClickButton, rightStickClickButton;

  // Rising-edge (just pressed) flags — true only on the first frame a button goes down
  boolean aJustPressed, bJustPressed, xJustPressed, yJustPressed;
  boolean backJustPressed, startJustPressed;
  boolean lbJustPressed, rbJustPressed;
  boolean leftStickClickJustPressed, rightStickClickJustPressed;
  boolean dpadUpJustPressed, dpadDownJustPressed, dpadLeftJustPressed, dpadRightJustPressed;

  // Previous-frame button states for edge detection
  private boolean previousA, previousB, previousX, previousY;
  private boolean previousBack, previousStart;
  private boolean previousLb, previousRb;
  private boolean previousLeftStickClick, previousRightStickClick;
  private boolean previousDpadUp, previousDpadDown, previousDpadLeft, previousDpadRight;

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
    aButton = getButtonState("A");
    bButton = getButtonState("B");
    xButton = getButtonState("X");
    yButton = getButtonState("Y");


    // Hardware names confirmed by raw scan: LB="Left Thumb", RB="Right Thumb",
    // L3="Left Thumb 3", R3="Right Thumb 3", Back="Select"
    lbButton = getButtonState("Left Thumb");
    rbButton = getButtonState("Right Thumb");

    backButton  = getButtonState("Select");
    startButton = getButtonState("Unknown") || getButtonState("Mode");

    leftStickClickButton = getButtonState("Left Thumb 3");
    rightStickClickButton = getButtonState("Right Thumb 3");

    // D-Pad Hat
    try {
      ControlHat hat = stick.getHat("cooliehat: pov");
      if (hat == null) hat = stick.getHat("dpad");
      
      if (hat != null) {
        dpadUpHeld    = hat.up();
        dpadDownHeld  = hat.down();
        dpadLeftHeld  = hat.left();
        dpadRightHeld = hat.right();
      }
    } catch (Exception e) { /* Hat missing */ }

    // Compute rising-edge flags
    aJustPressed = aButton && !previousA;
    bJustPressed = bButton && !previousB;
    xJustPressed = xButton && !previousX;
    yJustPressed = yButton && !previousY;
    backJustPressed = backButton && !previousBack;
    startJustPressed = startButton && !previousStart;
    lbJustPressed = lbButton && !previousLb;
    rbJustPressed = rbButton && !previousRb;
    leftStickClickJustPressed = leftStickClickButton && !previousLeftStickClick;
    rightStickClickJustPressed = rightStickClickButton && !previousRightStickClick;
    dpadUpJustPressed = dpadUpHeld && !previousDpadUp;
    dpadDownJustPressed = dpadDownHeld && !previousDpadDown;
    dpadLeftJustPressed = dpadLeftHeld && !previousDpadLeft;
    dpadRightJustPressed = dpadRightHeld && !previousDpadRight;

    // Save current state for next frame
    previousA = aButton; previousB = bButton; previousX = xButton; previousY = yButton;
    previousBack = backButton; previousStart = startButton;
    previousLb = lbButton; previousRb = rbButton;
    previousLeftStickClick = leftStickClickButton; previousRightStickClick = rightStickClickButton;
    previousDpadUp = dpadUpHeld; previousDpadDown = dpadDownHeld;
    previousDpadLeft = dpadLeftHeld; previousDpadRight = dpadRightHeld;
  }
}