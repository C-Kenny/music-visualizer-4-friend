/**
 * SceneGuard — crash resilience for scene rendering.
 *
 * Each frame's scene draw is wrapped in try/catch by the main draw loop. When a
 * scene throws, SceneGuard:
 *   1. Logs the stack trace to data/crash_log.txt (rotated ~1MB).
 *   2. Enters a recovery window — a black card with the scene name and error
 *      message is shown for RECOVERY_FRAMES frames.
 *   3. Tracks per-scene failure counts. After MAX_FAILURES_PER_SCENE hits, the
 *      scene is blacklisted for the rest of the session and the dispatch skips
 *      it automatically.
 *
 * The guard itself never throws — any failure during logging or card rendering
 * is swallowed so the render loop always progresses.
 */
class SceneGuard {
  static final int  MAX_FAILURES_PER_SCENE = 3;
  static final int  RECOVERY_FRAMES        = 60;
  static final long LOG_MAX_BYTES          = 1_048_576;

  int[]     failureCounts = new int[SCENE_COUNT];
  boolean[] blacklisted   = new boolean[SCENE_COUNT];
  String[]  lastErrorMsg  = new String[SCENE_COUNT];

  int    recoveryFramesLeft = 0;
  int    recoveringSceneId  = -1;
  String recoveringName     = "";
  String recoveringMsg      = "";

  boolean isRecovering()           { return recoveryFramesLeft > 0; }
  boolean isBlacklisted(int idx)   { return idx >= 0 && idx < SCENE_COUNT && blacklisted[idx]; }
  int     recoveringScene()        { return recoveringSceneId; }

  // Called by main dispatch when a scene throws.
  void recordFailure(int sceneIdx, Throwable t) {
    if (sceneIdx < 0 || sceneIdx >= SCENE_COUNT) return;
    failureCounts[sceneIdx]++;
    lastErrorMsg[sceneIdx] = t.getClass().getSimpleName() + ": " + t.getMessage();
    if (failureCounts[sceneIdx] >= MAX_FAILURES_PER_SCENE) {
      blacklisted[sceneIdx] = true;
      println("[GUARD] " + sceneName(sceneIdx) + " blacklisted after "
              + failureCounts[sceneIdx] + " failures this session.");
    }
    logException(sceneIdx, t);
    startRecovery(sceneIdx);
  }

  void startRecovery(int sceneIdx) {
    recoveringSceneId  = sceneIdx;
    recoveringName     = sceneName(sceneIdx);
    recoveringMsg      = (sceneIdx >= 0 && sceneIdx < SCENE_COUNT) ? lastErrorMsg[sceneIdx] : "";
    recoveryFramesLeft = RECOVERY_FRAMES;
  }

  // Advance recovery timer. Returns true when the window just ended — caller
  // should then decide whether to auto-skip (blacklisted) or retry.
  boolean tickRecovery() {
    if (recoveryFramesLeft <= 0) return false;
    recoveryFramesLeft--;
    return recoveryFramesLeft == 0;
  }

  void clearRecovery() {
    recoveringSceneId  = -1;
    recoveryFramesLeft = 0;
  }

  // Draws a recovery card onto the sceneBuffer. Caller owns beginDraw/endDraw.
  void drawRecoveryCard(PGraphics pg) {
    pg.background(0);
    if (monoFont != null) pg.textFont(monoFont);
    pg.textAlign(CENTER, CENTER);

    pg.fill(255, 60, 60, 230);
    pg.textSize(34);
    pg.text("scene recovering", pg.width / 2, pg.height / 2 - 48);

    pg.fill(255, 200);
    pg.textSize(20);
    pg.text(recoveringName, pg.width / 2, pg.height / 2 - 8);

    if (recoveringMsg != null && recoveringMsg.length() > 0) {
      pg.fill(255, 120);
      pg.textSize(13);
      String trimmed = recoveringMsg.length() > 140
                       ? recoveringMsg.substring(0, 140) + "\u2026"
                       : recoveringMsg;
      pg.text(trimmed, pg.width / 2, pg.height / 2 + 24);
    }

    if (recoveringSceneId >= 0 && recoveringSceneId < SCENE_COUNT) {
      pg.fill(255, 90);
      pg.textSize(11);
      pg.text("failures this session: " + failureCounts[recoveringSceneId]
              + (blacklisted[recoveringSceneId] ? "  \u2022  disabled" : ""),
              pg.width / 2, pg.height / 2 + 52);
    }
  }

  String sceneName(int idx) {
    if (idx < 0 || idx >= SCENE_COUNT || scenes[idx] == null) return "scene " + idx;
    return scenes[idx].getClass().getSimpleName();
  }

  void logException(int sceneIdx, Throwable t) {
    try {
      String logPath = dataPath("crash_log.txt");
      java.io.File f = new java.io.File(logPath);
      if (f.exists() && f.length() > LOG_MAX_BYTES) {
        f.renameTo(new java.io.File(logPath + ".old"));
      }
      java.io.FileWriter   fw = new java.io.FileWriter(logPath, true);
      java.io.PrintWriter  pw = new java.io.PrintWriter(fw);
      pw.println("=== " + new java.util.Date()
               + "  scene=" + sceneIdx + " " + sceneName(sceneIdx)
               + "  failCount=" + (sceneIdx >= 0 ? failureCounts[sceneIdx] : -1) + " ===");
      t.printStackTrace(pw);
      pw.println();
      pw.close();
      fw.close();
    } catch (Throwable ignored) {
      // Never let logging itself crash the recovery path.
    }
  }
}
