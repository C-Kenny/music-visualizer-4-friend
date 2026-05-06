/**
 * FrameWatchdog — detects render-thread stalls and attributes them to the
 * scene that was on screen when the stall began.
 *
 * Why a watchdog when SceneGuard already wraps draw in try/catch?
 * SceneGuard catches *exceptions*. A scene that hangs in an infinite loop or
 * blocks on I/O never throws — the render thread just stops. The watchdog
 * runs on its own daemon thread, polling a volatile timestamp updated at the
 * top of every draw(). If the gap exceeds STALL_THRESHOLD_MS, the stall is
 * recorded.
 *
 * The watchdog cannot interrupt the animation thread (doing so would corrupt
 * the GL context). It can only react when draw() resumes. On resume, the
 * main loop calls consumeStall() and, if a stall was flagged, charges a
 * failure to the suspect scene via SceneGuard and force-switches to a safe
 * scene. Repeated stalls eventually blacklist the scene.
 */
class FrameWatchdog {
  static final long STALL_THRESHOLD_MS = 2000;
  static final long POLL_MS            = 500;

  volatile long    lastTickMs      = 0;
  volatile int     lastSceneId     = -1;
  volatile boolean stallReported   = false;
  volatile long    stallDurationMs = 0;
  volatile int     stallSceneId    = -1;

  Thread           thread;
  volatile boolean running = false;

  void start() {
    if (running) return;
    running    = true;
    lastTickMs = System.currentTimeMillis();
    thread = new Thread(new Runnable() {
      public void run() {
        while (running) {
          try { Thread.sleep(POLL_MS); } catch (InterruptedException ie) { return; }
          long now = System.currentTimeMillis();
          long gap = now - lastTickMs;
          if (gap > STALL_THRESHOLD_MS && !stallReported) {
            stallReported   = true;
            stallDurationMs = gap;
            stallSceneId    = lastSceneId;
            System.err.println("[WATCHDOG] frame stall " + gap
                               + "ms in scene " + stallSceneId);
          }
        }
      }
    }, "FrameWatchdog");
    thread.setDaemon(true);
    thread.start();
  }

  void stop() {
    running = false;
    if (thread != null) thread.interrupt();
  }

  // Called at the very top of draw() every frame.
  void tick(int sceneId) {
    lastTickMs  = System.currentTimeMillis();
    lastSceneId = sceneId;
  }

  // One-shot: returns true exactly once after a stall is reported.
  boolean consumeStall() {
    if (!stallReported) return false;
    stallReported = false;
    return true;
  }
}
