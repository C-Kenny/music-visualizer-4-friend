/**
 * Streamer - push live composite + audio to MediaMTX so any browser on the
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
  // Deeper queue absorbs sketch frame-pacing hitches (~0.4s at 30fps) so the
  // video pipe to ffmpeg never starves - a starved video input is what stalls
  // the shared muxer and makes the AUDIO stutter on the listener's end.
  static final int   QUEUE_CAPACITY     = 12;
  static final String STREAM_NAME       = "visualizer";

  // --- Profiles ------------------------------------------------------------
  // NORMAL: high quality for good LAN. VENUE: low-bandwidth for congested/weak
  // venue WiFi - smaller frame, fewer fps, much lower bitrate. Switch with F7.
  static final int PROFILE_NORMAL = 0;
  static final int PROFILE_VENUE  = 1;
  int profile = PROFILE_NORMAL;

  int   profileFps()       { return profile == PROFILE_VENUE ? 24    : 30;    }
  float profileScale()     { return profile == PROFILE_VENUE ? 0.45  : 0.6;   }
  int   profileBitrateK()  { return profile == PROFILE_VENUE ? 1500  : 4000;  }
  int   profileMaxrateK()  { return profile == PROFILE_VENUE ? 1800  : 4500;  }
  String profileName()     { return profile == PROFILE_VENUE ? "VENUE" : "NORMAL"; }

  // Active fps after adaptive throttling. Steps down when frames drop (writer /
  // ffmpeg can't keep up), recovers when the link catches its breath.
  int  targetFps      = 30;
  long frameIntervalMs = 1000L / 30;
  long lastAdaptMs    = 0;
  int  dropsAtLastAdapt = 0;

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
  // Queue carries raw int[] pixel snapshots (cheap arraycopy on the render
  // thread). The writer thread does the ARGB byte-packing + pipe write, keeping
  // the per-pixel loop OFF the render thread so it can't cause frame hitches.
  java.util.concurrent.ArrayBlockingQueue<int[]> queue;
  java.util.concurrent.ArrayBlockingQueue<int[]> framePool;
  Thread writer;
  PGraphics scaleBuf;

  void toggle() { if (running) stop(); else start(); }

  void start() {
    if (running) return;
    float scale = profileScale();
    int w = (int)(width * scale) & ~1;
    int h = (int)(height * scale) & ~1;
    if (w <= 0 || h <= 0) { lastError = "window not ready"; println("[STREAM] " + lastError); return; }
    outW = w; outH = h;
    lastError = "";

    // Reset adaptive throttle to the profile's nominal fps.
    targetFps = profileFps();
    frameIntervalMs = 1000L / targetFps;
    lastAdaptMs = 0;
    dropsAtLastAdapt = 0;

    mediamtxPath = locateMediaMTX();
    if (mediamtxPath == null) {
      lastError = "MediaMTX not found - run ./install-stream.sh";
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

    queue = new java.util.concurrent.ArrayBlockingQueue<int[]>(QUEUE_CAPACITY);
    // Buffer pool: render thread borrows an int[] to copy pixels into, writer
    // returns it after the pipe write. Eliminates the per-frame clone()/alloc
    // (~3MB/frame) that was the render-thread GC churn behind stream chop.
    framePool = new java.util.concurrent.ArrayBlockingQueue<int[]>(QUEUE_CAPACITY + 2);
    framesPushed = framesDropped = 0;
    startMs = System.currentTimeMillis();
    lastFrameMs = 0;
    running = true;

    final int fw = w, fh = h;
    writer = new Thread(new Runnable() {
      public void run() {
        byte[] buf = new byte[fw * fh * 4];   // reused - no per-frame allocation
        try {
          while (running || !queue.isEmpty()) {
            int[] px = queue.poll(200, java.util.concurrent.TimeUnit.MILLISECONDS);
            if (px == null) continue;
            int n = px.length;
            for (int i = 0; i < n; i++) {
              int p = px[i];
              int o = i << 2;
              buf[o    ] = (byte)((p >> 24) & 0xff);   // A
              buf[o + 1] = (byte)((p >> 16) & 0xff);   // R
              buf[o + 2] = (byte)((p >> 8)  & 0xff);   // G
              buf[o + 3] = (byte)( p        & 0xff);   // B
            }
            pipe.write(buf, 0, n * 4);
            framesPushed++;
            framePool.offer(px);   // recycle (drop if pool full - never blocks)
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

    println("[STREAM] live  " + w + "x" + h + " @" + targetFps
          + "  profile=" + profileName() + " " + profileBitrateK() + "k"
          + "  audio: " + (audioSource.isEmpty() ? "none" : audioSource)
          + "  → http://<lan>:8080/stream.html");
  }

  String[] buildFFmpegCmd(int w, int h) {
    java.util.List<String> args = new java.util.ArrayList<String>();
    args.add("ffmpeg");
    args.add("-loglevel"); args.add("warning");
    // Video in: rawvideo from sketch. Use wallclock timestamps so jittery
    // sketch frame pacing doesn't desync against the audio capture.
    args.add("-thread_queue_size"); args.add("2048");
    args.add("-fflags"); args.add("+genpts+nobuffer");
    args.add("-use_wallclock_as_timestamps"); args.add("1");
    args.add("-f"); args.add("rawvideo");
    args.add("-pix_fmt"); args.add("argb");
    args.add("-s"); args.add(w + "x" + h);
    args.add("-r"); args.add("" + targetFps);
    args.add("-i"); args.add("-");
    // Audio in: pulse sink monitor (system audio output capture).
    if (!audioSource.isEmpty()) {
      args.add("-f"); args.add("pulse");
      args.add("-thread_queue_size"); args.add("4096");
      args.add("-fragment_size"); args.add("960");   // ~5ms @ 48kHz/stereo/s16
      args.add("-i"); args.add(audioSource);
    }
    // Encode: smooth low-latency. CFR + small GOP = fast WiFi-drop recovery.
    args.add("-vsync"); args.add("cfr");
    args.add("-c:v"); args.add("libx264");
    args.add("-preset"); args.add("ultrafast");
    args.add("-tune"); args.add("zerolatency");
    args.add("-pix_fmt"); args.add("yuv420p");
    args.add("-g"); args.add("" + targetFps);          // 1s GOP
    args.add("-keyint_min"); args.add("" + (targetFps / 2));
    args.add("-x264-params"); args.add("scenecut=0:nal-hrd=cbr:bframes=0:rc-lookahead=0:sync-lookahead=0:sliced-threads=1");
    // Bitrate per profile: NORMAL trades bandwidth for sharpness on good LAN;
    // VENUE drops to ~1.5Mbit so congested venue WiFi stops dropping packets
    // (the chop viewers see). VBV buffer = 1s so quality holds between keyframes.
    args.add("-b:v"); args.add(profileBitrateK() + "k");
    args.add("-maxrate"); args.add(profileMaxrateK() + "k");
    args.add("-bufsize"); args.add(profileBitrateK() + "k");
    if (!audioSource.isEmpty()) {
      args.add("-c:a"); args.add("libopus");
      args.add("-b:a"); args.add("128k");
      args.add("-ac"); args.add("2");
      args.add("-ar"); args.add("48000");
      args.add("-application"); args.add("audio");      // full-quality (not lowdelay) - smoother
      args.add("-frame_duration"); args.add("20");
      // async=1000 lets the resampler stretch/squeeze up to 1000 samples/sec to
      // track drift WITHOUT dropping/inserting silence (the audible stutter).
      args.add("-af"); args.add("aresample=async=1000:first_pts=0");
    }
    // CRITICAL for smooth audio: never let the muxer hold back one stream
    // waiting to interleave the other. Without this, a late video frame freezes
    // the audio too - the "stop/start" the listener hears. flush_packets pushes
    // each packet out immediately for low latency.
    args.add("-max_interleave_delta"); args.add("0");
    args.add("-flush_packets"); args.add("1");
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
      lastError = "ffmpeg exited (code " + ffmpeg.exitValue() + ") - see stream_ffmpeg.log";
      println("[STREAM] " + lastError);
      stop();
      return;
    }
    long now = System.currentTimeMillis();
    adapt(now);
    if (now - lastFrameMs < frameIntervalMs) return;
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

    // Render thread only does a fast arraycopy into a pooled buffer; the writer
    // thread packs bytes and recycles the buffer. No per-frame allocation.
    int n = scaleBuf.pixels.length;
    int[] snap = framePool.poll();
    if (snap == null || snap.length != n) snap = new int[n];
    System.arraycopy(scaleBuf.pixels, 0, snap, 0, n);
    if (!queue.offer(snap)) { framesDropped++; framePool.offer(snap); }
  }

  // Adaptive fps: if frames are dropping (writer/ffmpeg/network can't keep up),
  // step the capture rate down so what we DO send is paced smoothly instead of
  // jittering. Recover slowly toward the profile's nominal fps when drops stop.
  void adapt(long now) {
    if (lastAdaptMs == 0) { lastAdaptMs = now; dropsAtLastAdapt = framesDropped; return; }
    if (now - lastAdaptMs < 2000) return;            // evaluate every 2s
    int dropsSince = framesDropped - dropsAtLastAdapt;
    int nominal = profileFps();
    if (dropsSince > 3 && targetFps > 15) {
      targetFps = max(15, targetFps - 3);            // back off
    } else if (dropsSince == 0 && targetFps < nominal) {
      targetFps = min(nominal, targetFps + 2);       // ease back up
    }
    frameIntervalMs = 1000L / targetFps;
    lastAdaptMs = now;
    dropsAtLastAdapt = framesDropped;
  }

  // Toggle NORMAL <-> VENUE. Restarts the pipe if live (ffmpeg cmd is built at
  // start, so bitrate/scale/fps changes need a fresh ffmpeg).
  void cycleProfile() {
    profile = (profile == PROFILE_NORMAL) ? PROFILE_VENUE : PROFILE_NORMAL;
    println("[STREAM] profile -> " + profileName());
    if (running) { stop(); start(); }
  }

  void stop() {
    if (!running) return;
    running = false;
    println("[STREAM] stopping... pushed=" + framesPushed + " dropped=" + framesDropped);
    try { if (writer != null) writer.join(2000); } catch (InterruptedException ignored) {}
    try { if (ffmpeg != null) { ffmpeg.destroy(); ffmpeg.waitFor(); } } catch (InterruptedException ignored) {}
    stopMediaMTX();
    ffmpeg = null; pipe = null; writer = null; queue = null; framePool = null;
  }

  String statusLabel() {
    if (!running) {
      if (!lastError.isEmpty()) return "STREAM ERR: " + lastError;
      return "STREAM OFF";
    }
    long elapsed = (System.currentTimeMillis() - startMs) / 1000;
    return "STREAM " + nf((int)(elapsed / 60), 2) + ":" + nf((int)(elapsed % 60), 2)
         + " " + profileName() + "@" + targetFps
         + " [" + framesPushed + "f" + (framesDropped > 0 ? " -" + framesDropped : "") + "]";
  }
}
