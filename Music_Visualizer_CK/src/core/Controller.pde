import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;
import java.lang.reflect.*;

/**
 * Controller — Robust gamepad handling for Processing.
 * 
 * Supports hot-plugging, calibration, and advanced chord detection.
 * Chords (multiple buttons) mark participating buttons as 'wasChorded'
 * to suppress their individual 'justReleased' actions.
 */
class Controller {
  PApplet applet;
  ControlIO control;
  ControlDevice stick;

  // Hot-plug: retry finding the device periodically
  int reconnectTimer   = 0;
  int RECONNECT_INTERVAL = 120;
  int connectedRescanTimer = 0;
  int CONNECTED_RESCAN_INTERVAL = 600;
  int rebindingTimer = 0;
  int REBIND_INTERVAL = 120;
  int consecutiveReadErrors = 0;
  int MAX_READ_ERRORS_BEFORE_RECONNECT = 15;
  boolean hadReadError = false;

  int hardResetCooldown = 0;
  int HARD_RESET_COOLDOWN_FRAMES = 300;
  int consecutiveHardResets = 0;
  int MAX_HARD_RESETS_BEFORE_BACKOFF = 3;
  boolean needsFreshEnumeration = false;

  float lx, ly, rx, ry;
  float lxOffset, lyOffset, rxOffset, ryOffset;
  float ltOffset, rtOffset;
  float lt, rt;

  // Button States (Held)
  boolean aButton, bButton, xButton, yButton;
  boolean backButton, startButton;
  boolean lbButton, rbButton;
  boolean dpadUpHeld, dpadDownHeld, dpadLeftHeld, dpadRightHeld;
  boolean leftStickClickButton, rightStickClickButton;

  // Rising Edge (Just Pressed)
  boolean aJustPressed, bJustPressed, xJustPressed, yJustPressed;
  boolean backJustPressed, startJustPressed;
  boolean lbJustPressed, rbJustPressed;
  boolean leftStickClickJustPressed, rightStickClickJustPressed;
  boolean dpadUpJustPressed, dpadDownJustPressed, dpadLeftJustPressed, dpadRightJustPressed;

  // Falling Edge (Just Released)
  boolean aJustReleased, bJustReleased, xJustReleased, yJustReleased;
  boolean backJustReleased, startJustReleased;
  boolean lbJustReleased, rbJustReleased;
  boolean leftStickClickJustReleased, rightStickClickJustReleased;
  boolean dpadUpJustReleased, dpadDownJustReleased, dpadLeftJustReleased, dpadRightJustReleased;

  // Chord Tracking: flags that a button was used as part of a chord since it was pressed.
  // Useful for suppressing individual actions on release.
  boolean aWasChorded, bWasChorded, xWasChorded, yWasChorded;
  boolean backWasChorded, startWasChorded;
  boolean lbWasChorded, rbWasChorded;
  boolean l3WasChorded, r3WasChorded;
  boolean dUpWasChorded, dDownWasChorded, dLeftWasChorded, dRightWasChorded;

  // Previous-frame button states for edge detection
  private boolean previousA, previousB, previousX, previousY;
  private boolean previousBack, previousStart;
  private boolean previousLb, previousRb;
  private boolean previousL3, previousR3;
  private boolean previousDUp, previousDDown, previousDLeft, previousDRight;

  Controller(PApplet applet) {
    this.applet = applet;
    control = ControlIO.getInstance(applet);
    tryConnect();
  }

  private void onConnected(String source) {
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    rebindingTimer = 0;
    consecutiveReadErrors = 0;
    consecutiveHardResets = 0;
    hardResetCooldown = 0;
    hadReadError = false;
    resetInputState();
    if (stick != null) {
      println("[Controller] Connected via " + source + ": " + stick.getName());
    }
  }

  private boolean stringContainsAny(String source, String[] needles) {
    if (source == null) return false;
    String s = source.toLowerCase();
    for (String n : needles) {
      if (s.indexOf(n) >= 0) return true;
    }
    return false;
  }

  private boolean shouldCountAsReadError(Exception e) {
    if (e == null) return false;
    String msg = e.getMessage();
    if (msg == null) return false;
    String m = msg.toLowerCase();
    return m.indexOf("failed to poll") >= 0
        || m.indexOf("device key states") >= 0
        || m.indexOf("not acquired") >= 0
        || m.indexOf("disconnected") >= 0
        || m.indexOf("invalid device") >= 0;
  }

  private Object getUnderlyingController() {
    if (stick == null) return null;
    try {
      Field field = stick.getClass().getDeclaredField("controller");
      field.setAccessible(true);
      return field.get(stick);
    } catch (Exception e) { return null; }
  }

  private boolean nativePollHealthy() {
    Object nativeController = getUnderlyingController();
    if (nativeController == null) return false;
    try {
      Method pollMethod = nativeController.getClass().getMethod("poll");
      Object result = pollMethod.invoke(nativeController);
      if (result instanceof Boolean) return ((Boolean) result).booleanValue();
    } catch (Exception e) { return false; }
    return false;
  }

  private int scoreDevice(ControlDevice dev) {
    if (dev == null) return -9999;
    int score = 0;
    String name = "";
    int sliders = 0;
    int buttons = 0;
    try { name = dev.getName(); } catch (Exception e) {}
    try { sliders = dev.getNumberOfSliders(); } catch (Exception e) {}
    try { buttons = dev.getNumberOfButtons(); } catch (Exception e) {}
    score += sliders * 2;
    score += buttons;
    if (stringContainsAny(name, new String[]{"xbox", "x-box", "gamepad", "controller", "pad"})) score += 25;
    if (stringContainsAny(name, new String[]{"keyboard", "mouse", "touchpad", "trackpoint"})) score -= 40;
    if (sliders >= 4) score += 10;
    if (buttons >= 6) score += 10;
    return score;
  }

  private void disconnectAndReset(String reason) {
    if (stick != null) println("[Controller] Disconnecting device '" + stick.getName() + "' : " + reason);
    else println("[Controller] Disconnecting device: " + reason);
    stick = null;
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    rebindingTimer = 0;
    consecutiveReadErrors = 0;
    hadReadError = false;
    resetInputState();
  }

  private void hardResetControlIO(String reason) {
    consecutiveHardResets++;
    println("[Controller] Hard reset ControlIO (attempt " + consecutiveHardResets + "): " + reason);
    try {
      if (stick != null) { try { stick.close(); } catch (Exception e) {} }
      if (control != null) control.dispose();
    } catch (Exception e) { println("[Controller] ControlIO dispose failed: " + e.getMessage()); }
    try {
      Field instanceField = ControlIO.class.getDeclaredField("instance");
      instanceField.setAccessible(true);
      instanceField.set(null, null);
    } catch (Exception e) {}
    try {
      Class<?> envClass = Class.forName("net.java.games.input.ControllerEnvironment");
      Field envField = envClass.getDeclaredField("instance");
      envField.setAccessible(true);
      envField.set(null, null);
    } catch (Exception e) {}
    control = null;
    stick = null;
    needsFreshEnumeration = true;
    resetInputState();
    consecutiveReadErrors = 0;
    hadReadError = false;
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    rebindingTimer = 0;
    int cooldown = HARD_RESET_COOLDOWN_FRAMES;
    if (consecutiveHardResets > MAX_HARD_RESETS_BEFORE_BACKOFF) cooldown *= 2;
    hardResetCooldown = cooldown;
  }

  private ControlDevice findBestDevice(boolean verbose) {
    ControlDevice best = null;
    int bestScore = -9999;
    int n = 0;
    try { n = control.getNumberOfDevices(); } catch (Exception e) {}
    for (int i = 0; i < n; i++) {
      try {
        ControlDevice dev = control.getDevice(i);
        String name = "";
        try { name = dev.getName().toLowerCase(); } catch (Exception e) {}
        int sliders = dev.getNumberOfSliders();
        int buttons = dev.getNumberOfButtons();
        int score = scoreDevice(dev);
        if (sliders < 2 || buttons < 1) continue;
        if (stringContainsAny(name, new String[]{"mouse", "keyboard", "touchpad", "trackpoint", "power button"})) continue;
        if (score < 5) continue;
        try { if (stick != null && dev.getName().equals(stick.getName())) score += 30; } catch (Exception e) {}
        if (score > bestScore) { bestScore = score; best = dev; }
      } catch (Exception e) {}
    }
    return best;
  }

  private ControlDevice findMatchedDeviceSilent() {
    try { return control.getMatchedDeviceSilent("joystick"); } catch (Exception e) { return null; }
  }

  private void refreshDeviceHandleFromScan() {
    ControlDevice best = findMatchedDeviceSilent();
    if (best == null) best = findBestDevice(false);
    if (best == null) { disconnectAndReset("no gamepad found during refresh"); return; }
    boolean changed = (stick == null);
    String oldName = (stick != null) ? stick.getName() : "";
    String newName = best.getName();
    if (!changed && oldName != null && newName != null && !oldName.equals(newName)) changed = true;
    stick = best;
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    consecutiveReadErrors = 0;
    hadReadError = false;
    if (changed) { println("[Controller] Rebound device: " + newName); resetInputState(); }
  }

  private void resetInputState() {
    lx = width * 0.5; ly = height * 0.5; rx = width * 0.5; ry = height * 0.5;
    lt = 0; rt = 0;
    aButton = bButton = xButton = yButton = false;
    backButton = startButton = false;
    lbButton = rbButton = false;
    dpadUpHeld = dpadDownHeld = dpadLeftHeld = dpadRightHeld = false;
    leftStickClickButton = rightStickClickButton = false;

    aJustPressed = bJustPressed = xJustPressed = yJustPressed = false;
    backJustPressed = startJustPressed = false;
    lbJustPressed = rbJustPressed = false;
    leftStickClickJustPressed = rightStickClickJustPressed = false;
    dpadUpJustPressed = dpadDownJustPressed = dpadLeftJustPressed = dpadRightJustPressed = false;

    aJustReleased = bJustReleased = xJustReleased = yJustReleased = false;
    backJustReleased = startJustReleased = false;
    lbJustReleased = rbJustReleased = false;
    leftStickClickJustReleased = rightStickClickJustReleased = false;
    dpadUpJustReleased = dpadDownJustReleased = dpadLeftJustReleased = dpadRightJustReleased = false;

    aWasChorded = bWasChorded = xWasChorded = yWasChorded = false;
    backWasChorded = startWasChorded = false;
    lbWasChorded = rbWasChorded = false;
    l3WasChorded = r3WasChorded = false;
    dUpWasChorded = dDownWasChorded = dLeftWasChorded = dRightWasChorded = false;

    previousA = previousB = previousX = previousY = false;
    previousBack = previousStart = false;
    previousLb = previousRb = false;
    previousL3 = previousR3 = false;
    previousDUp = previousDDown = previousDLeft = previousDRight = false;
    
    lxOffset = lyOffset = rxOffset = ryOffset = 0;
    ltOffset = rtOffset = 0;
  }

  void calibrate() {
    if (stick == null) return;
    println("[Controller] Calibrating offsets...");
    lxOffset = getSliderValue("lx", "x",  0); lyOffset = getSliderValue("ly", "y",  0);
    rxOffset = getSliderValue("rx", "rx", 0); ryOffset = getSliderValue("ry", "ry", 0);
    ltOffset = getSliderValue("z",  "z",  -1); rtOffset = getSliderValue("rz", "rz", -1);
  }

  void tryConnect() {
    if (needsFreshEnumeration) {
      if (control != null) { try { control.dispose(); } catch (Exception e) {} }
      try {
        Field instanceField = ControlIO.class.getDeclaredField("instance");
        instanceField.setAccessible(true);
        instanceField.set(null, null);
      } catch (Exception e) {}
      try {
        Class<?> envClass = Class.forName("net.java.games.input.ControllerEnvironment");
        Field envField = envClass.getDeclaredField("instance");
        envField.setAccessible(true);
        envField.set(null, null);
      } catch (Exception e) {}
      control = null;
    }
    if (control == null) {
      try { control = ControlIO.getInstance(applet); } catch (Exception e) { return; }
    }
    ControlDevice matched = findMatchedDeviceSilent();
    if (matched != null) { stick = matched; needsFreshEnumeration = false; onConnected("matched-silent"); return; }
    stick = findBestDevice(true);
    if (stick != null) { needsFreshEnumeration = false; onConnected("scan"); }
  }

  boolean isConnected() { return stick != null; }

  // Print matched device name and all its controls — call once from setup for debugging
  void debugPrintControls() {
    if (stick == null) return;
    println("=== Controller matched: " + stick.getName() + " ===");
    for (ControlInput inp : stick.getInputs()) {
      String type = (inp instanceof ControlHat) ? "HAT" : (inp instanceof ControlButton) ? "BUTTON" : "SLIDER";
      println("  " + type + ": '" + inp.getName() + "'");
    }
  }


  private float getSliderValue(String name, String altName, float defaultVal) {
    try {
      ControlInput inp = stick.getSlider(name);
      if (inp != null) return inp.getValue();
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }
    try {
      ControlInput inp = stick.getSlider(altName);
      if (inp != null) return inp.getValue();
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }
    return defaultVal;
  }

  private boolean getButtonState(String name) {
    return getButtonState(name, "");
  }

  private boolean getButtonState(String name, String altName) {
    try {
      ControlInput inp = stick.getButton(name);
      if (inp != null) return ((ControlButton)inp).pressed();
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }
    try {
      ControlInput inp = stick.getButton(altName);
      if (inp != null) return ((ControlButton)inp).pressed();
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }
    return false;
  }

  void read() {
    boolean nativePollFailedThisFrame = false;
    if (stick == null) {
      if (hardResetCooldown > 0) { hardResetCooldown--; return; }
      reconnectTimer++;
      if (reconnectTimer >= RECONNECT_INTERVAL) { reconnectTimer = 0; tryConnect(); }
      return;
    }
    if (!nativePollHealthy()) {
      nativePollFailedThisFrame = true;
      consecutiveReadErrors++;
      if (consecutiveReadErrors >= MAX_READ_ERRORS_BEFORE_RECONNECT) { hardResetControlIO("native poll unhealthy"); return; }
    }
    connectedRescanTimer++;
    if (connectedRescanTimer >= CONNECTED_RESCAN_INTERVAL) {
      connectedRescanTimer = 0;
      try { if (stick.getName() == null || stick.getName().length() == 0) { disconnectAndReset("device probe fail"); return; } }
      catch (Exception e) { disconnectAndReset("device probe exception"); return; }
    }
    rebindingTimer++;
    if (rebindingTimer >= REBIND_INTERVAL) { rebindingTimer = 0; refreshDeviceHandleFromScan(); if (stick == null) return; }
    hadReadError = false;

    float raw_x  = getSliderValue("lx", "x",  0)  - lxOffset;
    float raw_y  = getSliderValue("ly", "y",  0)  - lyOffset;
    float raw_rx = getSliderValue("rx", "rx", 0)  - rxOffset;
    float raw_ry = getSliderValue("ry", "ry", 0)  - ryOffset;
    float raw_z  = getSliderValue("z",  "z",  -1) - ltOffset;
    float raw_rz = getSliderValue("rz", "rz", -1) - rtOffset;
    float DEADZONE = 0.08;
    if (abs(raw_x) < DEADZONE)  raw_x = 0; if (abs(raw_y) < DEADZONE)  raw_y = 0;
    if (abs(raw_rx) < DEADZONE) raw_rx = 0; if (abs(raw_ry) < DEADZONE) raw_ry = 0;
    if (abs(raw_z) < DEADZONE)  raw_z = 0; if (abs(raw_rz) < DEADZONE) raw_rz = 0;
    lx = map(raw_x,  -1, 1, 0, width); ly = map(raw_y,  -1, 1, 0, height);
    rx = map(raw_rx, -1, 1, 0, width); ry = map(raw_ry, -1, 1, 0, height);
    lt = constrain(map(raw_z,  0, 1, 0, 1), 0, 1); rt = constrain(map(raw_rz, 0, 1, 0, 1), 0, 1);

    aButton = getButtonState("a", "A") || getButtonState("Button 0", "");
    bButton = getButtonState("b", "B") || getButtonState("Button 1", "");
    xButton = getButtonState("x", "X") || getButtonState("Button 2", "");
    yButton = getButtonState("y", "Y") || getButtonState("Button 3", "");
    lbButton = getButtonState("lb", "Left Thumb") || getButtonState("Button 4", "");
    rbButton = getButtonState("rb", "Right Thumb") || getButtonState("Button 5", "");
    backButton  = getButtonState("back", "Select") || getButtonState("Button 6", "");
    startButton = getButtonState("start", "Unknown") || getButtonState("Mode") || getButtonState("Button 7", "");
    leftStickClickButton = getButtonState("lstickclick", "Left Thumb 3") || getButtonState("Button 8", "");
    rightStickClickButton = getButtonState("rstickclick", "Right Thumb 3") || getButtonState("Button 9", "");

    try {
      ControlHat hat = stick.getHat("cooliehat: pov");
      if (hat == null) hat = stick.getHat("dpad");
      if (hat != null) {
        dpadUpHeld    = hat.up(); dpadDownHeld  = hat.down();
        dpadLeftHeld  = hat.left(); dpadRightHeld = hat.right();
      }
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }

    if (hadReadError) {
      consecutiveReadErrors++;
      if (consecutiveReadErrors >= MAX_READ_ERRORS_BEFORE_RECONNECT) { hardResetControlIO("read errors"); return; }
    } else if (!nativePollFailedThisFrame) { consecutiveReadErrors = 0; }

    // Edge Detection
    aJustPressed = aButton && !previousA; aJustReleased = !aButton && previousA;
    bJustPressed = bButton && !previousB; bJustReleased = !bButton && previousB;
    xJustPressed = xButton && !previousX; xJustReleased = !xButton && previousX;
    yJustPressed = yButton && !previousY; yJustReleased = !yButton && previousY;
    backJustPressed = backButton && !previousBack; backJustReleased = !backButton && previousBack;
    startJustPressed = startButton && !previousStart; startJustReleased = !startButton && previousStart;
    lbJustPressed = lbButton && !previousLb; lbJustReleased = !lbButton && previousLb;
    rbJustPressed = rbButton && !previousRb; rbJustReleased = !rbButton && previousRb;
    leftStickClickJustPressed = leftStickClickButton && !previousL3; leftStickClickJustReleased = !leftStickClickButton && previousL3;
    rightStickClickJustPressed = rightStickClickButton && !previousR3; rightStickClickJustReleased = !rightStickClickButton && previousR3;
    dpadUpJustPressed = dpadUpHeld && !previousDUp; dpadUpJustReleased = !dpadUpHeld && previousDUp;
    dpadDownJustPressed = dpadDownHeld && !previousDDown; dpadDownJustReleased = !dpadDownHeld && previousDDown;
    dpadLeftJustPressed = dpadLeftHeld && !previousDLeft; dpadLeftJustReleased = !dpadLeftHeld && previousDLeft;
    dpadRightJustPressed = dpadRightHeld && !previousDRight; dpadRightJustReleased = !dpadRightHeld && previousDRight;

    // Reset chord flags on Press
    if (aJustPressed) aWasChorded = false; if (bJustPressed) bWasChorded = false;
    if (xJustPressed) xWasChorded = false; if (yJustPressed) yWasChorded = false;
    if (lbJustPressed) lbWasChorded = false; if (rbJustPressed) rbWasChorded = false;
    if (backJustPressed) backWasChorded = false; if (startJustPressed) startWasChorded = false;
    if (leftStickClickJustPressed) l3WasChorded = false; if (rightStickClickJustPressed) r3WasChorded = false;
    if (dpadUpJustPressed) dUpWasChorded = false; if (dpadDownJustPressed) dDownWasChorded = false;
    if (dpadLeftJustPressed) dLeftWasChorded = false; if (dpadRightJustPressed) dRightWasChorded = false;

    previousA = aButton; previousB = bButton; previousX = xButton; previousY = yButton;
    previousBack = backButton; previousStart = startButton;
    previousLb = lbButton; previousRb = rbButton;
    previousL3 = leftStickClickButton; previousR3 = rightStickClickButton;
    previousDUp = dpadUpHeld; previousDDown = dpadDownHeld;
    previousDLeft = dpadLeftHeld; previousDRight = dpadRightHeld;
  }

  /**
   * chord — Returns true if all passed buttons are held.
   * Participants should be manually marked as 'wasChorded' in the sketch
   * to suppress their individual actions on release.
   */
  boolean chord(boolean... buttons) {
    if (buttons.length < 2) return false;
    for (boolean b : buttons) if (!b) return false;
    return true;
  }
}