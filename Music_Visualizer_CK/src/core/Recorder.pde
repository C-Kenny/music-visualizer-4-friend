/**
 * Recorder — pipe the live composite to ffmpeg for mp4 capture.
 *
 * Design constraints:
 *   - Cannot block the render thread. saveFrame() pauses every 16ms call,
 *     murders FPS. Instead we hand frame buffers to a worker thread that
 *     writes them to ffmpeg's stdin pipe.
 *   - 30 fps target, half-resolution. 1080p @ 30 raw is ~250 MB/s — too
 *     hot for a single pipe. Halving each axis quarters the bandwidth.
 *   - Backpressure: if the writer falls behind, drop frames rather than
 *     stall. Recording an artistically-perfect file is less important than
 *     not killing the show.
 *
 * Hotkey (wired in main keyPressed):
 *   F5   start / stop recording
 *
 * Output: data/recordings/visualizer_<timestamp>.mp4
 */
class Recorder {
  static final int   TARGET_FPS         = 30;
  static final float SCALE              = 0.5;
  static final int   QUEUE_CAPACITY     = 4;
  static final long  FRAME_INTERVAL_MS  = 1000L / TARGET_FPS;

  boolean running = false;
  long    startMs = 0;
  int     framesWritten = 0;
  int     framesDropped = 0;
  long    lastFrameMs   = 0;
  String  outPath       = "";
  int     outW          = 0;
  int     outH          = 0;

  Process       proc;
  java.io.OutputStream pipe;
  java.util.concurrent.ArrayBlockingQueue<byte[]> queue;
  Thread        writer;
  PGraphics     scaleBuf;

  void toggle() {
    if (running) stop();
    else         start();
  }

  void start() {
    if (running) return;

    int w = (int)(width * SCALE) & ~1;  // ffmpeg yuv420p needs even dims
    int h = (int)(height * SCALE) & ~1;
    if (w <= 0 || h <= 0) {
      println("[REC] window not initialised yet, skipping");
      return;
    }
    outW = w; outH = h;

    String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2)
                 + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
    java.io.File outDir = new java.io.File(userDataPath("recordings"));
    if (!outDir.exists()) outDir.mkdirs();
    outPath = new java.io.File(outDir, "visualizer_" + stamp + ".mp4").getAbsolutePath();

    String[] cmd = {
      "ffmpeg",
      "-y",
      "-f", "rawvideo",
      "-pix_fmt", "argb",
      "-s", w + "x" + h,
      "-r", "" + TARGET_FPS,
      "-i", "-",
      "-an",
      "-c:v", "libx264",
      "-preset", "veryfast",
      "-pix_fmt", "yuv420p",
      "-movflags", "+faststart",
      outPath
    };

    try {
      ProcessBuilder pb = new ProcessBuilder(cmd);
      pb.redirectErrorStream(true);
      // Log next to the mp4 so a broken capture is easy to diagnose.
      pb.redirectOutput(new java.io.File(outPath + ".log"));
      proc = pb.start();
      pipe = proc.getOutputStream();
    } catch (Exception e) {
      println("[REC] failed to spawn ffmpeg: " + e);
      proc = null;
      pipe = null;
      return;
    }

    queue         = new java.util.concurrent.ArrayBlockingQueue<byte[]>(QUEUE_CAPACITY);
    framesWritten = 0;
    framesDropped = 0;
    startMs       = System.currentTimeMillis();
    lastFrameMs   = 0;
    running       = true;

    writer = new Thread(new Runnable() {
      public void run() {
        try {
          while (running || !queue.isEmpty()) {
            byte[] buf = queue.poll(200, java.util.concurrent.TimeUnit.MILLISECONDS);
            if (buf == null) continue;
            pipe.write(buf);
            framesWritten++;
          }
        } catch (Throwable t) {
          println("[REC] writer thread error: " + t);
        } finally {
          try { if (pipe != null) pipe.close(); } catch (Throwable ignored) {}
        }
      }
    }, "RecorderWriter");
    writer.setDaemon(true);
    writer.start();

    println("[REC] recording -> " + outPath + " (" + w + "x" + h + " @" + TARGET_FPS + ")");
  }

  // Called every frame from main draw(). Throttles to TARGET_FPS and pushes
  // a downscaled copy to the writer.
  void tick(PGraphics src) {
    if (!running || src == null) return;

    long now = System.currentTimeMillis();
    if (now - lastFrameMs < FRAME_INTERVAL_MS) return;
    lastFrameMs = now;

    if (scaleBuf == null || scaleBuf.width != outW || scaleBuf.height != outH) {
      scaleBuf = createGraphics(outW, outH, P2D);
      scaleBuf.smooth(0);
    }
    scaleBuf.beginDraw();
    scaleBuf.background(0);
    scaleBuf.imageMode(CORNER);
    scaleBuf.image(src, 0, 0, outW, outH);
    scaleBuf.endDraw();
    scaleBuf.loadPixels();

    int n = scaleBuf.pixels.length;
    byte[] buf = new byte[n * 4];
    for (int i = 0; i < n; i++) {
      int p = scaleBuf.pixels[i];
      int o = i * 4;
      buf[o    ] = (byte)((p >> 24) & 0xff); // A
      buf[o + 1] = (byte)((p >> 16) & 0xff); // R
      buf[o + 2] = (byte)((p >> 8)  & 0xff); // G
      buf[o + 3] = (byte)(p         & 0xff); // B
    }

    // Non-blocking offer — drop frame on backpressure rather than stall draw.
    if (!queue.offer(buf)) framesDropped++;
  }

  void stop() {
    if (!running) return;
    running = false;
    println("[REC] stopping... wrote " + framesWritten + " frames, dropped " + framesDropped);
    try {
      if (writer != null) writer.join(3000);
    } catch (InterruptedException ignored) {}
    try {
      if (proc != null) proc.waitFor();
    } catch (InterruptedException ignored) {}
    println("[REC] saved: " + outPath);
    proc = null;
    pipe = null;
    writer = null;
    queue = null;
  }

  String statusLabel() {
    if (!running) return "OFF";
    long elapsed = (System.currentTimeMillis() - startMs) / 1000;
    return "REC " + nf((int)(elapsed / 60), 2) + ":" + nf((int)(elapsed % 60), 2)
         + " [" + framesWritten + "f" + (framesDropped > 0 ? " -" + framesDropped : "") + "]";
  }
}
