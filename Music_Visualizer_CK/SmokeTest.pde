// SmokeTest.pde — automated smoke-test harness
//
// Activate by creating Music_Visualizer_CK/.smoketest (or ../.smoketest)
// then running the sketch normally.  The harness:
//   1. Calls onEnter() for each scene
//   2. Runs BASELINE_FRAMES of drawScene() with neutral controller state
//   3. Injects every controller input (stick extremes, buttons, triggers)
//      calling applyController() + drawScene() for each
//   4. Calls handleKey() with every safe keyboard character + drawScene()
//   5. Calls onExit() then moves to the next scene
//
// Any uncaught exception is recorded.  A pass/fail report is printed to
// the console when all scenes are done and the loop is stopped.
//
// Typical run time: ~35 s at 60 fps (≈ 92 frames × 23 scenes).
//
// Usage:
//   touch Music_Visualizer_CK/.smoketest
//   ./run.sh           # also set .devmode or .devsong so no file-picker appears

boolean SMOKE_TEST_MODE = false;
SmokeTestRunner smokeTestRunner;

// ── Phase index constants (global so inner class can use them) ─────────────
final int ST_PHASE_ENTER         = 0;
final int ST_PHASE_DRAW_BASELINE = 1;
final int ST_PHASE_CONTROLLER    = 2;
final int ST_PHASE_KEYBOARD      = 3;
final int ST_PHASE_EXIT          = 4;

// Number of distinct controller test cases (must match applyControllerInput switch)
final int ST_CTRL_INPUT_COUNT = 32;

boolean isSmokeTestMode() {
  String[] candidates = {
    sketchPath() + "/.smoketest",
    sketchPath() + "/../.smoketest",
    System.getProperty("user.dir") + "/.smoketest"
  };
  for (String path : candidates) {
    if (new java.io.File(path).exists()) return true;
  }
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────

class SmokeTestRunner {

  int phase        = ST_PHASE_ENTER;
  int currentScene = 0;
  int frameInPhase = 0;
  int inputIdx     = 0;

  int passCount = 0;
  ArrayList<String> failures = new ArrayList<String>();

  // Frames of plain drawScene() to run before exercising inputs
  final int BASELINE_FRAMES = 5;

  // Keys to exercise — deliberately excludes q/Q/x/X (exit app)
  // and n/N (song navigation, needs a loaded songList)
  final char[] TEST_KEYS = {
    'h', 'H', 's', 'S', 'l', 'L', '`', 'g', 'G',
    't', 'T', 'p', 'P', ' ',
    'a', 'A', 'b', 'B', 'c', 'C', 'd', 'D',
    'e', 'E', 'f', 'F', 'r', 'R', 'u', 'U',
    'v', 'V', 'w', 'W', 'z', 'Z', 'k', 'K',
    'm', 'M', 'i', 'I', 'j', 'J', 'o', 'O',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'
  };

  // ── Main tick — called once per draw() frame ──────────────────────────────
  void tick(PGraphics pg) {
    if (currentScene >= SCENE_ORDER.length) {
      printReport();
      exit();     // terminate the sketch so smoketest.sh can read the result file
      return;
    }

    int sceneIdx  = SCENE_ORDER[currentScene];
    IScene scene  = scenes[sceneIdx];
    String sName  = scene.getClass().getSimpleName();
    char k = 0; // declared outside switch to satisfy Processing's preprocessor

    switch (phase) {

      case ST_PHASE_ENTER:
        try {
          scene.onEnter();
          passCount++;
        } catch (Exception e) {
          logFailure(sName, "onEnter()", e);
        }
        phase = ST_PHASE_DRAW_BASELINE;
        frameInPhase = 0;
        break;

      case ST_PHASE_DRAW_BASELINE:
        resetControllerToNeutral();
        drawSceneGuarded(pg, scene, sName, "baseline frame " + frameInPhase);
        // Also exercise getCodeLines() (can NPE / OOB on bad array construction)
        if (frameInPhase == 0) {
          try {
            String[] lines = scene.getCodeLines();
            if (lines == null) throw new NullPointerException("getCodeLines() returned null");
            passCount++;
          } catch (Exception e) {
            logFailure(sName, "getCodeLines()", e);
          }
        }
        frameInPhase++;
        if (frameInPhase >= BASELINE_FRAMES) {
          phase = ST_PHASE_CONTROLLER;
          inputIdx = 0;
        }
        break;

      case ST_PHASE_CONTROLLER:
        if (inputIdx >= ST_CTRL_INPUT_COUNT) {
          phase = ST_PHASE_KEYBOARD;
          inputIdx = 0;
          break;
        }
        resetControllerToNeutral();
        applyControllerInput(inputIdx);
        try {
          scene.applyController(controller);
          passCount++;
        } catch (Exception e) {
          logFailure(sName, "applyController() [" + ctrlInputName(inputIdx) + "]", e);
        }
        drawSceneGuarded(pg, scene, sName, "after ctrl " + ctrlInputName(inputIdx));
        inputIdx++;
        break;

      case ST_PHASE_KEYBOARD:
        if (inputIdx >= TEST_KEYS.length) {
          phase = ST_PHASE_EXIT;
          break;
        }
        k = TEST_KEYS[inputIdx];
        try {
          scene.handleKey(k);
          passCount++;
        } catch (Exception e) {
          logFailure(sName, "handleKey(" + k + ")", e);
        }
        drawSceneGuarded(pg, scene, sName, "after handleKey(" + k + ")");
        inputIdx++;
        break;

      case ST_PHASE_EXIT:
        try {
          scene.onExit();
          passCount++;
        } catch (Exception e) {
          logFailure(sName, "onExit()", e);
        }
        println("[SMOKE] scene " + sceneIdx + " (" + sName + ") done — failures so far: " + failures.size());
        currentScene++;
        phase = ST_PHASE_ENTER;
        break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void drawSceneGuarded(PGraphics pg, IScene scene, String sName, String ctx) {
    try {
      pg.beginDraw();
      pg.background(0);
      pg.pushMatrix();
      scene.drawScene(pg);
      pg.popMatrix();
      pg.endDraw();
      passCount++;
    } catch (Exception e) {
      // Attempt graceful recovery so the buffer stays valid for next tick
      try { pg.popMatrix(); } catch (Exception ignored) {}
      try { pg.endDraw();   } catch (Exception ignored) {}
      logFailure(sName, "drawScene() [" + ctx + "]", e);
    }
  }

  void logFailure(String scene, String method, Exception e) {
    String msg = "[FAIL] " + scene + "." + method
               + "  →  " + e.getClass().getSimpleName() + ": " + e.getMessage();
    failures.add(msg);
    println(msg);
    e.printStackTrace();
  }

  // Reset every controller field to a safe neutral state before each test case
  void resetControllerToNeutral() {
    controller.lx = width  * 0.5;
    controller.ly = height * 0.5;
    controller.rx = width  * 0.5;
    controller.ry = height * 0.5;
    controller.lt = 0;
    controller.rt = 0;
    controller.aButton = false;  controller.aJustPressed = false;
    controller.bButton = false;  controller.bJustPressed = false;
    controller.xButton = false;  controller.xJustPressed = false;
    controller.yButton = false;  controller.yJustPressed = false;
    controller.lbButton = false; controller.lbJustPressed = false;
    controller.rbButton = false; controller.rbJustPressed = false;
    controller.backButton  = false; controller.backJustPressed  = false;
    controller.startButton = false; controller.startJustPressed = false;
    controller.leftStickClickButton  = false; controller.leftStickClickJustPressed  = false;
    controller.rightStickClickButton  = false; controller.rightStickClickJustPressed  = false;
    controller.dpadUpHeld    = false; controller.dpadUpJustPressed    = false;
    controller.dpadDownHeld  = false; controller.dpadDownJustPressed  = false;
    controller.dpadLeftHeld  = false; controller.dpadLeftJustPressed  = false;
    controller.dpadRightHeld = false; controller.dpadRightJustPressed = false;
  }

  // ── 32 controller test cases ──────────────────────────────────────────────
  // Covers: stick extremes, trigger values, every button held and just-pressed
  void applyControllerInput(int idx) {
    switch (idx) {
      // Left stick extremes
      case 0:  controller.lx = 0;       break;
      case 1:  controller.lx = width;   break;
      case 2:  controller.ly = 0;       break;
      case 3:  controller.ly = height;  break;
      // Right stick extremes
      case 4:  controller.rx = 0;       break;
      case 5:  controller.rx = width;   break;
      case 6:  controller.ry = 0;       break;
      case 7:  controller.ry = height;  break;
      // Left trigger
      case 8:  controller.lt = 0;    break;
      case 9:  controller.lt = 0.5;  break;
      case 10: controller.lt = 1.0;  break;
      // Right trigger
      case 11: controller.rt = 0;    break;
      case 12: controller.rt = 0.5;  break;
      case 13: controller.rt = 1.0;  break;
      // Face buttons — held
      case 14: controller.aButton = true; break;
      case 15: controller.bButton = true; break;
      case 16: controller.xButton = true; break;
      case 17: controller.yButton = true; break;
      // Shoulder buttons — held
      case 18: controller.lbButton = true; break;
      case 19: controller.rbButton = true; break;
      // Face buttons — just pressed (rising edge)
      case 20: controller.aButton = true; controller.aJustPressed = true; break;
      case 21: controller.bButton = true; controller.bJustPressed = true; break;
      case 22: controller.xButton = true; controller.xJustPressed = true; break;
      case 23: controller.yButton = true; controller.yJustPressed = true; break;
      // Shoulder buttons — just pressed
      case 24: controller.lbButton = true; controller.lbJustPressed = true; break;
      case 25: controller.rbButton = true; controller.rbJustPressed = true; break;
      // D-pad (just pressed)
      case 26: controller.dpadUpHeld    = true; controller.dpadUpJustPressed    = true; break;
      case 27: controller.dpadDownHeld  = true; controller.dpadDownJustPressed  = true; break;
      case 28: controller.dpadLeftHeld  = true; controller.dpadLeftJustPressed  = true; break;
      case 29: controller.dpadRightHeld = true; controller.dpadRightJustPressed = true; break;
      // Stick clicks
      case 30: controller.leftStickClickButton = true; controller.leftStickClickJustPressed = true; break;
      case 31: controller.rightStickClickButton = true; controller.rightStickClickJustPressed = true; break;
    }
  }

  String ctrlInputName(int idx) {
    String[] names = {
      "lx=0", "lx=width", "ly=0", "ly=height",
      "rx=0", "rx=width", "ry=0", "ry=height",
      "lt=0", "lt=0.5",   "lt=1",
      "rt=0", "rt=0.5",   "rt=1",
      "A held", "B held", "X held", "Y held",
      "LB held", "RB held",
      "A just_pressed", "B just_pressed", "X just_pressed", "Y just_pressed",
      "LB just_pressed", "RB just_pressed",
      "dpad_up", "dpad_down", "dpad_left", "dpad_right",
      "lstick_click", "rstick_click"
    };
    return (idx >= 0 && idx < names.length) ? names[idx] : ("input#" + idx);
  }

  // ── Final report ─────────────────────────────────────────────────────────
  // Writes a machine-readable result file (.smoketest_result) that
  // smoketest.sh reads to produce coloured pass/fail output and exit code.
  void printReport() {
    boolean passed = failures.size() == 0;
    String resultPath = sketchPath(".smoketest_result");

    // Write result file first so smoketest.sh can always read it even if
    // console output was partially lost
    try {
      java.io.PrintWriter pw = new java.io.PrintWriter(resultPath);
      pw.println(passed ? "PASS" : "FAIL");
      pw.println("scenes="   + SCENE_ORDER.length);
      pw.println("checks="   + passCount);
      pw.println("failures=" + failures.size());
      for (String f : failures) pw.println(f);
      pw.close();
    } catch (Exception e) {
      println("[SMOKE] Warning: could not write result file: " + e.getMessage());
    }

    // Also print to console
    println();
    println("╔══════════════════════════════════════════════════╗");
    println("║            SMOKE TEST COMPLETE                   ║");
    println("╠══════════════════════════════════════════════════╣");
    println("║  Scenes tested  : " + nf(SCENE_ORDER.length, 3) + "                            ║");
    println("║  Checks passed  : " + nf(passCount, 3) + "                            ║");
    println("║  Failures found : " + nf(failures.size(), 3) + "                            ║");
    println("╠══════════════════════════════════════════════════╣");
    if (passed) {
      println("║  ALL CHECKS PASSED — no exceptions thrown        ║");
    } else {
      println("║  FAILURES:                                       ║");
      for (String f : failures) println("  " + f);
    }
    println("╚══════════════════════════════════════════════════╝");
    println("[SMOKE] Result written to: " + resultPath);
    println();
  }
}
