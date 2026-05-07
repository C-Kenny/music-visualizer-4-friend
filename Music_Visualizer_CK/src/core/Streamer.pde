/**
 * Streamer — push live composite + audio to MediaMTX so any browser on the
 * LAN can watch (TV, phone, second laptop). No Chromecast needed.
 *
 * Pipeline:
 *   render thread → push downscaled rgba → ffmpeg subprocess
 *   ffmpeg muxes audio (pulse sink-monitor) → encodes H.264 + AAC
 *   ffmpeg pushes RTSP → MediaMTX
 *   MediaMTX serves WebRTC (low-latency) + HLS (universal fallback)
 *   stream.html tries WebRTC, falls back to HLS automatically
 *
 * Latency:
 *   WebRTC path : 100–300 ms
 *   HLS path    : 1–3 s
 *
 * Audio source: pulse default sink monitor → captures whatever the laptop
 * actually plays, regardless of FILE/DEVICE visualizer mode.
 *
 * Bootstrap: requires MediaMTX binary in user data dir or on PATH. Run
 * `./install-stream.sh` once to fetch it.
 *
 * Hotkey:
 *   F6  start / stop streaming
 */
class Streamer {
  static final int   TARGET_FPS         = 30;
  static final float SCALE              = 0.5;
  static final int   QUEUE_CAPACITY     = 4;
  static final long  FRAME_INTERVAL_MS  = 1000L / TARGET_FPS;
  static final String STREAM_NAME       = "visualizer";

  boolean running = false;
  long    startMs = 0;
  int     framesPushed   = 0;
  int     framesDropped  = 0;
  long    lastFrameMs    = 0;
  int     outW = 0, outH = 0;
  String  lastError = "";
  String  audioSource = "";
  String  mediamtxPath = "";

  Process mediamtx;
  Process ffmpeg;
  java.io.OutputStream pipe;
  java.util.concurrent.ArrayBlockingQueue<byte[]> queue;
  Thread writer;
  PGraphics scaleBuf;

  void toggle() { if (running) stop(); else start(); }

  void start() {
    if (running) return;
    int w = (int)(width * SCALE) & ~1;
    int h = (int)(height * SCALE) & ~1;
    if (w <= 0 || h <= 0) { lastError = "window not ready"; println("[STREAM] " + lastError); return; }
    outW = w; outH = h;
    lastError = "";

    mediamtxPath = locateMediaMTX();
    if (mediamtxPath == null) {
      lastError = "MediaMTX not found — run ./install-stream.sh";
      println("[STREAM] " + lastError);
      return;
    }

    if (!startMediaMTX()) return;

    audioSource = detectPulseMonitor();

    String[] cmd = buildFFmpegCmd(w, h);
    try {
      ProcessBuilder pb = new ProcessBuilder(cmd);
      pb.redirectError(new java.io.File(userDataPath("stream_ffmpeg.log")));
      ffmpeg = pb.start();
      pipe = ffmpeg.getOutputStream();
    } catch (Exception e) {
      lastError = "ffmpeg spawn failed: " + e.getMessage();
      println("[STREAM] " + lastError);
      stopMediaMTX();
      return;
    }

    queue = new java.util.concurrent.ArrayBlockingQueue<byte[]>(QUEUE_CAPACITY);
    framesPushed = framesDropped = 0;
    startMs = System.currentTimeMillis();
    lastFrameMs = 0;
    running = true;

    writer = new Thread(new Runnable() {
      public void run() {
        try {
          while (running || !queue.isEmpty()) {
            byte[] buf = queue.poll(200, java.util.concurrent.TimeUnit.MILLISECONDS);
            if (buf == null) continue;
            pipe.write(buf);
            framesPushed++;
          }
        } catch (Throwable t) {
          if (running) println("[STREAM] writer error: " + t);
        } finally {
          try { if (pipe != null) pipe.close(); } catch (Throwable ignored) {}
        }
      }
    }, "StreamerWriter");
    writer.setDaemon(true);
    writer.start();

    println("[STREAM] live  " + w + "x" + h + " @" + TARGET_FPS
          + "  audio: " + (audioSource.isEmpty() ? "none" : audioSource)
          + "  → http://<lan>:8080/stream.html");
  }

  String[] buildFFmpegCmd(int w, int h) {
    java.util.List<String> args = new java.util.ArrayList<String>();
    args.add("ffmpeg");
    args.add("-loglevel"); args.add("warning");
    // Video in: rawvideo from sketch
    args.add("-f"); args.add("rawvideo");
    args.add("-pix_fmt"); args.add("argb");
    args.add("-s"); args.add(w + "x" + h);
    args.add("-r"); args.add("" + TARGET_FPS);
    args.add("-i"); args.add("-");
    // Audio in: pulse sink monitor (system audio output capture)
    if (!audioSource.isEmpty()) {
      args.add("-f"); args.add("pulse");
      args.add("-thread_queue_size"); args.add("1024");
      args.add("-i"); args.add(audioSource);
    }
    // Encode: tuned for ultra-low latency
    args.add("-c:v"); args.add("libx264");
    args.add("-preset"); args.add("ultrafast");
    args.add("-tune"); args.add("zerolatency");
    args.add("-pix_fmt"); args.add("yuv420p");
    args.add("-g"); args.add("" + (TARGET_FPS));    // 1s GOP for low LL-HLS lag
    args.add("-keyint_min"); args.add("" + TARGET_FPS);
    args.add("-x264-params"); args.add("scenecut=0:nal-hrd=cbr");
    args.add("-b:v"); args.add("3500k");
    args.add("-maxrate"); args.add("3500k");
    args.add("-bufsize"); args.add("3500k");
    if (!audioSource.isEmpty()) {
      // libopus required for WebRTC playback — AAC works for HLS but is
      // dropped by browsers' WebRTC stack. Opus covers both.
      args.add("-c:a"); args.add("libopus");
      args.add("-b:a"); args.add("128k");
      args.add("-ac"); args.add("2");
      args.add("-ar"); args.add("48000");
    }
    args.add("-f"); args.add("rtsp");
    args.add("-rtsp_transport"); args.add("tcp");
    args.add("rtsp://127.0.0.1:8554/" + STREAM_NAME);
    return args.toArray(new String[0]);
  }

  boolean startMediaMTX() {
    if (isPortListening(8554)) {
      println("[STREAM] MediaMTX already running on :8554, reusing");
      return true;
    }
    try {
      // Run with cwd = dir containing the binary, so mediamtx finds its
      // sibling mediamtx.yml (install-stream.sh drops both there).
      java.io.File binFile = new java.io.File(mediamtxPath);
      java.io.File cwd = binFile.getParentFile() != null ? binFile.getParentFile()
                                                         : new java.io.File(userDataPath(""));
      ProcessBuilder pb = new ProcessBuilder(mediamtxPath);
      pb.directory(cwd);
      pb.redirectError(new java.io.File(userDataPath("mediamtx.log")));
      pb.redirectOutput(new java.io.File(userDataPath("mediamtx.log")));
      mediamtx = pb.start();
    } catch (Exception e) {
      lastError = "MediaMTX spawn failed: " + e.getMessage();
      println("[STREAM] " + lastError);
      return false;
    }
    // Wait up to 4s for RTSP port to come up
    long deadline = System.currentTimeMillis() + 4000;
    while (System.currentTimeMillis() < deadline) {
      if (isPortListening(8554)) return true;
      try { Thread.sleep(100); } catch (InterruptedException ie) { return false; }
    }
    lastError = "MediaMTX failed to bind :8554 (see mediamtx.log)";
    println("[STREAM] " + lastError);
    stopMediaMTX();
    return false;
  }

  void stopMediaMTX() {
    if (mediamtx != null) {
      mediamtx.destroy();
      try { mediamtx.waitFor(); } catch (InterruptedException ignored) {}
      mediamtx = null;
    }
  }

  boolean isPortListening(int port) {
    java.net.Socket s = null;
    try {
      s = new java.net.Socket();
      s.connect(new java.net.InetSocketAddress("127.0.0.1", port), 200);
      return true;
    } catch (Exception e) {
      return false;
    } finally {
      if (s != null) try { s.close(); } catch (Exception ignored) {}
    }
  }

  // Check (1) user data dir, (2) real XDG dir (run.sh overrides MV_USER_DATA_DIR),
  // (3) repo root, (4) PATH.
  String locateMediaMTX() {
    String home = System.getProperty("user.home");
    String xdg  = System.getenv("XDG_CONFIG_HOME");
    String xdgDir = (xdg != null && xdg.length() > 0 ? xdg : home + "/.config") + "/music-visualizer";

    String[] candidates = {
      userDataPath("mediamtx"),
      xdgDir + "/mediamtx",
      sketchPath("../mediamtx"),
      sketchPath("../../mediamtx")
    };
    for (String c : candidates) {
      java.io.File f = new java.io.File(c);
      if (f.exists() && f.canExecute()) return c;
    }
    String pathEnv = System.getenv("PATH");
    if (pathEnv != null) {
      for (String dir : pathEnv.split(java.io.File.pathSeparator)) {
        java.io.File f = new java.io.File(dir, "mediamtx");
        if (f.exists() && f.canExecute()) return f.getAbsolutePath();
      }
    }
    return null;
  }

  // Default sink monitor = whatever the laptop speakers are playing. Captures
  // visualizer audio regardless of FILE/DEVICE mode.
  String detectPulseMonitor() {
    try {
      Process p = new ProcessBuilder("pactl", "get-default-sink").redirectErrorStream(true).start();
      java.io.BufferedReader r = new java.io.BufferedReader(new java.io.InputStreamReader(p.getInputStream()));
      String sink = r.readLine();
      p.waitFor();
      if (sink != null && sink.length() > 0) return sink.trim() + ".monitor";
    } catch (Exception ignored) {}
    return "";
  }

  // Called every frame from main draw().
  void tick(PGraphics src) {
    if (!running || src == null) return;
    // Detect dead ffmpeg (broken pipe, MediaMTX evicted publisher, etc.) and
    // stop cleanly so the operator dashboard surfaces the failure.
    if (ffmpeg != null && !ffmpeg.isAlive()) {
      lastError = "ffmpeg exited (code " + ffmpeg.exitValue() + ") — see stream_ffmpeg.log";
      println("[STREAM] " + lastError);
      stop();
      return;
    }
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
      buf[o    ] = (byte)((p >> 24) & 0xff);
      buf[o + 1] = (byte)((p >> 16) & 0xff);
      buf[o + 2] = (byte)((p >> 8)  & 0xff);
      buf[o + 3] = (byte)(p         & 0xff);
    }
    if (!queue.offer(buf)) framesDropped++;
  }

  void stop() {
    if (!running) return;
    running = false;
    println("[STREAM] stopping... pushed=" + framesPushed + " dropped=" + framesDropped);
    try { if (writer != null) writer.join(2000); } catch (InterruptedException ignored) {}
    try { if (ffmpeg != null) { ffmpeg.destroy(); ffmpeg.waitFor(); } } catch (InterruptedException ignored) {}
    stopMediaMTX();
    ffmpeg = null; pipe = null; writer = null; queue = null;
  }

  String statusLabel() {
    if (!running) {
      if (!lastError.isEmpty()) return "STREAM ERR: " + lastError;
      return "STREAM OFF";
    }
    long elapsed = (System.currentTimeMillis() - startMs) / 1000;
    return "STREAM " + nf((int)(elapsed / 60), 2) + ":" + nf((int)(elapsed % 60), 2)
         + " [" + framesPushed + "f" + (framesDropped > 0 ? " -" + framesDropped : "") + "]";
  }
}
