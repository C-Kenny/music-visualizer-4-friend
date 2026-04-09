import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;
import java.lang.reflect.*;

class Controller {
  PApplet applet;
  ControlIO control;
  ControlDevice stick;

  // Hot-plug: retry finding the device every RECONNECT_INTERVAL frames
  int reconnectTimer   = 0;
  int RECONNECT_INTERVAL = 120; // ~2 s at 60 fps
  int connectedRescanTimer = 0;
  int CONNECTED_RESCAN_INTERVAL = 600; // ~10 s at 60 fps
  int rebindingTimer = 0;
  int REBIND_INTERVAL = 120; // ~2 s at 60 fps
  int consecutiveReadErrors = 0;
  int MAX_READ_ERRORS_BEFORE_RECONNECT = 15;
  boolean hadReadError = false;

  // Post-hard-reset cooldown: give the OS time to re-enumerate USB before retrying
  int hardResetCooldown = 0;
  int HARD_RESET_COOLDOWN_FRAMES = 300; // ~5 s at 60 fps
  int consecutiveHardResets = 0;
  int MAX_HARD_RESETS_BEFORE_BACKOFF = 3;
  boolean needsFreshEnumeration = false; // true after hard reset; forces JInput re-scan on every tryConnect

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
    } catch (Exception e) {
      return null;
    }
  }

  private boolean nativePollHealthy() {
    Object nativeController = getUnderlyingController();
    if (nativeController == null) return false;
    try {
      Method pollMethod = nativeController.getClass().getMethod("poll");
      Object result = pollMethod.invoke(nativeController);
      if (result instanceof Boolean) return ((Boolean) result).booleanValue();
    } catch (Exception e) {
      return false;
    }
    return false;
  }

  // Prefer real gamepads over generic HID devices when config matching fails.
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
    if (stick != null) {
      println("[Controller] Disconnecting device '" + stick.getName() + "' : " + reason);
    } else {
      println("[Controller] Disconnecting device: " + reason);
    }
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

    // Tear down: close device + dispose ControlIO
    try {
      if (stick != null) {
        try { stick.close(); } catch (Exception e) {}
      }
      if (control != null) control.dispose();
    } catch (Exception e) {
      println("[Controller] ControlIO dispose failed: " + e.getMessage());
    }
    // Null both singletons so the NEXT ControlIO.getInstance() forces fresh native enumeration
    try {
      Field instanceField = ControlIO.class.getDeclaredField("instance");
      instanceField.setAccessible(true);
      instanceField.set(null, null);
    } catch (Exception e) {
      println("[Controller] ControlIO singleton reset failed: " + e.getMessage());
    }
    try {
      Class<?> envClass = Class.forName("net.java.games.input.ControllerEnvironment");
      Field envField = envClass.getDeclaredField("instance");
      envField.setAccessible(true);
      envField.set(null, null);
      println("[Controller] JInput + ControlIO singletons nulled");
    } catch (Exception e) {
      println("[Controller] JInput environment reset failed: " + e.getMessage());
    }
    // Don't rebuild ControlIO here — the device list would be stale (controller unplugged).
    // Set control = null so tryConnect() rebuilds it fresh after the cooldown,
    // by which time the user has (hopefully) replugged the controller.
    control = null;
    stick = null;
    needsFreshEnumeration = true;
    resetInputState();
    consecutiveReadErrors = 0;
    hadReadError = false;
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    rebindingTimer = 0;

    // Cooldown: give the OS time to re-enumerate USB before we try to reconnect
    int cooldown = HARD_RESET_COOLDOWN_FRAMES;
    if (consecutiveHardResets > MAX_HARD_RESETS_BEFORE_BACKOFF) {
      cooldown *= 2;
      println("[Controller] Too many hard resets (" + consecutiveHardResets + "), backing off to " + cooldown + " frames");
    }
    hardResetCooldown = cooldown;
    println("[Controller] Waiting " + cooldown + " frames before reconnect attempt");
  }

  // Select the best gamepad-like device from ControlIO enumeration.
  private ControlDevice findBestDevice(boolean verbose) {
    ControlDevice best = null;
    int bestScore = -9999;
    int n = 0;
    try { n = control.getNumberOfDevices(); } catch (Exception e) {}
    if (verbose) println("[Controller] Scanning " + n + " device(s)...");

    for (int i = 0; i < n; i++) {
      try {
        ControlDevice dev = control.getDevice(i);
        String name = "";
        try { name = dev.getName().toLowerCase(); } catch (Exception e) {}
        int sliders = dev.getNumberOfSliders();
        int buttons = dev.getNumberOfButtons();
        int score = scoreDevice(dev);
        if (verbose) {
          println("[Controller]   [" + i + "] " + dev.getName()
                  + "  sliders=" + sliders
                  + "  buttons=" + buttons
                  + "  score=" + score);
        }

        if (sliders < 2 || buttons < 1) continue;

        // Hard-reject non-gamepad devices even if they pass slider/button threshold
        if (stringContainsAny(name, new String[]{"mouse", "keyboard", "touchpad", "trackpoint", "power button"})) continue;

        // Require a minimum positive score — peripherals like mice can score 0
        if (score < 5) continue;

        // Prefer keeping the current device name when available.
        try {
          if (stick != null && dev.getName().equals(stick.getName())) score += 30;
        } catch (Exception e) {}

        if (score > bestScore) {
          bestScore = score;
          best = dev;
          if (verbose) println("[Controller] New candidate: " + best.getName());
        }
      } catch (Exception e) {
        if (verbose) println("[Controller]   [" + i + "] error: " + e.getMessage());
      }
    }

    return best;
  }

  private ControlDevice findMatchedDeviceSilent() {
    try {
      return control.getMatchedDeviceSilent("joystick");
    } catch (Exception e) {
      return null;
    }
  }

  private void refreshDeviceHandleFromScan() {
    ControlDevice best = findMatchedDeviceSilent();
    if (best == null) best = findBestDevice(false);
    if (best == null) {
      disconnectAndReset("no gamepad found during refresh");
      return;
    }

    boolean changed = (stick == null);
    String oldName = "";
    String newName = "";
    try { oldName = (stick != null) ? stick.getName() : ""; } catch (Exception e) {}
    try { newName = best.getName(); } catch (Exception e) {}
    if (!changed && oldName != null && newName != null && !oldName.equals(newName)) {
      changed = true;
    }

    stick = best;
    reconnectTimer = 0;
    connectedRescanTimer = 0;
    consecutiveReadErrors = 0;
    hadReadError = false;

    if (changed) {
      println("[Controller] Rebound device: " + newName);
      resetInputState();
    }
  }

  private void resetInputState() {
    lx = width * 0.5;
    ly = height * 0.5;
    rx = width * 0.5;
    ry = height * 0.5;
    lt = 0;
    rt = 0;

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

    previousA = previousB = previousX = previousY = false;
    previousBack = previousStart = false;
    previousLb = previousRb = false;
    previousLeftStickClick = previousRightStickClick = false;
    previousDpadUp = previousDpadDown = previousDpadLeft = previousDpadRight = false;
  }

  // Attempt to find a matched device. Safe to call repeatedly.
  // Uses silent enumeration so controller reconnects do not trigger
  // any interactive GameControlPlus device-selection UI.
  void tryConnect() {
    // After a hard reset, force fresh JInput enumeration on EVERY attempt
    // so we pick up newly-plugged devices. ControlIO caches its device list,
    // so we must null both singletons and rebuild each time.
    if (needsFreshEnumeration) {
      // Tear down existing ControlIO if present (from a previous failed tryConnect)
      if (control != null) {
        try { control.dispose(); } catch (Exception e) {}
      }
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
      try {
        println("[Controller] Rebuilding ControlIO with fresh device enumeration...");
        control = ControlIO.getInstance(applet);
      } catch (Exception e) {
        println("[Controller] ControlIO re-init failed: " + e.getMessage());
        return;
      }
    }

    ControlDevice matched = findMatchedDeviceSilent();
    if (matched != null) {
      stick = matched;
      needsFreshEnumeration = false;
      onConnected("matched-silent");
      return;
    }

    stick = findBestDevice(true);
    if (stick != null) {
      needsFreshEnumeration = false;
      onConnected("scan");
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

  // Try primary name first (virtual name used by getMatchedDevice),
  // fall back to altName (hardware name used by getDevice fallback).
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
    try {
      ControlInput inp = stick.getButton(name);
      return (inp != null) ? ((ControlButton)inp).pressed() : false;
    } catch (Exception e) {
      if (shouldCountAsReadError(e)) hadReadError = true;
      return false;
    }
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

    // Hot-plug: if device was missing at startup or got disconnected, retry
    // periodically so the user doesn't need to restart the app.
    if (stick == null) {
      // Respect post-hard-reset cooldown
      if (hardResetCooldown > 0) {
        hardResetCooldown--;
        return;
      }
      reconnectTimer++;
      if (reconnectTimer >= RECONNECT_INTERVAL) {
        reconnectTimer = 0;
        tryConnect();
      }
      return; // nothing to read yet
    }

    // Probe native JInput health directly. GameControlPlus can keep reporting
    // a non-null device while internal poll() has already failed after replug.
    if (!nativePollHealthy()) {
      nativePollFailedThisFrame = true;
      consecutiveReadErrors++;
      if (consecutiveReadErrors >= MAX_READ_ERRORS_BEFORE_RECONNECT) {
        hardResetControlIO("native poll unhealthy");
        return;
      }
    }

    // Periodic health checks even while connected help recover from stale
    // handles after unplug/replug on Linux.
    connectedRescanTimer++;
    if (connectedRescanTimer >= CONNECTED_RESCAN_INTERVAL) {
      connectedRescanTimer = 0;
      try {
        if (stick.getName() == null || stick.getName().length() == 0) {
          disconnectAndReset("device name probe failed");
          return;
        }
      } catch (Exception e) {
        disconnectAndReset("device probe exception: " + e.getMessage());
        return;
      }
    }

    // Proactively refresh the underlying handle even when reads don't throw.
    // This recovers from poll failures where stick remains non-null.
    rebindingTimer++;
    if (rebindingTimer >= REBIND_INTERVAL) {
      rebindingTimer = 0;
      refreshDeviceHandleFromScan();
      if (stick == null) return;
    }

    hadReadError = false;

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

    // Try virtual names (a/b/x/y) and common hardware aliases.
    aButton = getButtonState("a", "A") || getButtonState("Button 0");
    bButton = getButtonState("b", "B") || getButtonState("Button 1");
    xButton = getButtonState("x", "X") || getButtonState("Button 2");
    yButton = getButtonState("y", "Y") || getButtonState("Button 3");


    // Hardware names confirmed by raw scan: LB="Left Thumb", RB="Right Thumb",
    // L3="Left Thumb 3", R3="Right Thumb 3", Back="Select"
    lbButton = getButtonState("lb", "Left Thumb") || getButtonState("Button 4");
    rbButton = getButtonState("rb", "Right Thumb") || getButtonState("Button 5");

    backButton  = getButtonState("back", "Select") || getButtonState("Button 6");
    startButton = getButtonState("start", "Unknown") || getButtonState("Mode") || getButtonState("Button 7");

    leftStickClickButton = getButtonState("lstickclick", "Left Thumb 3") || getButtonState("Button 8");
    rightStickClickButton = getButtonState("rstickclick", "Right Thumb 3") || getButtonState("Button 9");

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
    } catch (Exception e) { if (shouldCountAsReadError(e)) hadReadError = true; }

    if (hadReadError) {
      consecutiveReadErrors++;
      if (consecutiveReadErrors >= MAX_READ_ERRORS_BEFORE_RECONNECT) {
        hardResetControlIO("too many read errors while connected");
        return;
      }
    } else if (!nativePollFailedThisFrame) {
      consecutiveReadErrors = 0;
    }

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

  // Returns true only when all listed buttons are currently held.
  boolean chord(boolean... buttons) {
    if (buttons.length == 0) return false;
    for (boolean b : buttons) {
      if (!b) return false;
    }
    return true;
  }
}