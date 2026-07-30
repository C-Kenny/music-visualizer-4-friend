/*
Music Visualizer ♫ ♪♪
*/
import org.gicentre.handy.*;
import java.util.Map;
import garciadelcastillo.dashedlines.*;
import peasy.*;
import java.util.ArrayList;
import java.util.HashSet;

Config config;
Audio audio;
Controller controller;
FeatureFlagServer featureFlagServer;
WebController webController;
ControllerWebSocket controllerWS;
ClientRegistry clientRegistry;
WebQueueManager webQueueManager;
PinManager pinManager;
IScene[] scenes;
SceneSwitcher sceneSwitcher;
AudioSourceSwitcher audioSwitcher;
AutoSwitcher   autoSwitcher;
ParamAutoPilot paramAutoPilot;
SceneGuard       sceneGuard;
FrameWatchdog    frameWatchdog;
KillSwitch       killSwitch;
StrobeSafety     strobeSafety;
TempoLock        tempoLock;
Setlist          setlist;
TextOverlay      textOverlay;
Recorder         recorder;
Streamer         streamer;
MidiBridge       midiBridge;
HelpOverlay      helpOverlay;
DisplayManager   displayManager;
DemoInputDriver  demoInput;
FrameBudget      frameBudget;
final int SCENE_COUNT = 58;
int previousState = -1;
boolean isProjecting = false; // Prevents HUD/text from rendering when a scene is projected off-screen

AudioAnalyser analyzer;
SpatialAudio spatial;     // 8D-audio pan/orbit tracker — scenes read spatial.pan/azimuth
DropPredictor dropPredictor;
PFont monoFont;
PGraphics sceneBuffer;
PostFXStack postFX;


// UI scale: 1.0 at 1080p, grows proportionally for higher resolutions.
// Use uiScale() for textSize, strokeWeight, and HUD rect sizes.
float uiScale() { return max(1.0, min(width, height) / 1080.0); }

PImage h3_emblem;
PImage newHaloEmblem;

PShape xboxFrontSVG;

HandyRenderer h, h1, h2;
HandyRenderer[] HANDY_RENDERERS;
HandyRenderer CURRENT_HANDY_RENDERER;

int[] modes;
String[]modeNames;

PeasyCam cam;

void loadSongToVisualize() {
  logToStdout("Loading audio source (mode: " + config.AUDIO_INPUT_MODE + ")");
  
  if (config.AUDIO_INPUT_MODE.equals("DEVICE")) {
    // DEVICE INPUT MODE — auto-pick `default` entry on first entry so user
    // doesn't have to F1/F2 cycle past suspended USB mics.
    if (config.SELECTED_AUDIO_DEVICE_INDEX == 0) pickPreferredAudioDevice();
    audio = new Audio(this, "", config.bandsPerOctave, true, config.SELECTED_AUDIO_DEVICE_INDEX);
    config.SONG_PLAYING = (audio.audioInput != null);
    config.SONG_NAME = "Live Audio: " + config.audioDeviceSelector.getSelectedDeviceName();
    
    if (audio.audioInput == null) {
      System.err.println("[Audio] Device init failed — falling back to FILE mode so the show keeps running.");
      config.AUDIO_INPUT_MODE = "FILE";
      audio = new Audio(this, config.SONG_TO_VISUALIZE, config.bandsPerOctave);
      config.SONG_PLAYING = (audio.player != null);
      if (config.SONG_TO_VISUALIZE != null) {
        config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      }
      return;
    }
    
    // Note: DropPredictor cannot scan live audio (it's real-time, not seekable)
    logToStdout("[Audio] Running in DEVICE mode — DropPredictor disabled (look-ahead not possible)");
    
  } else {
    // FILE INPUT MODE (original behavior)
    audio = new Audio(this, config.SONG_TO_VISUALIZE, config.bandsPerOctave);

    // If first pick failed (corrupt file etc.), walk through songList trying
    // each until one loads. Prevents a single bad WAV freezing the venue.
    if (audio.player == null && config.songList != null && config.songList.size() > 1) {
      int start = config.currentSongIndex;
      for (int step = 1; step < config.songList.size(); step++) {
        int idx = (start + step) % config.songList.size();
        String candidate = config.songList.get(idx);
        logToStdout("[Audio] Retrying with: " + candidate);
        audio = new Audio(this, candidate, config.bandsPerOctave);
        if (audio.player != null) {
          config.currentSongIndex = idx;
          config.SONG_TO_VISUALIZE = candidate;
          config.SONG_NAME = getSongNameFromFilePath(candidate, config.OS_TYPE);
          break;
        }
      }
    }

    config.SONG_PLAYING = (audio.player != null);
    
    // Only scan for drops in file mode (can't look ahead in live audio)
    if (dropPredictor != null && audio.player != null) {
      dropPredictor.scan(config.SONG_TO_VISUALIZE);
    }

    // Clean exit instead of letting downstream NPE-on-null-player freeze the
    // window. Better the venue sees the terminal error than a black hung screen.
    if (audio.player == null) {
      System.err.println("[FATAL] Could not load any playable audio file. Exiting.");
      exit();
    }
  }
}

void setupController() {
  controller = new Controller(this);
  if (controller.isConnected()) {
    config.USING_CONTROLLER = true;
    config.TITLE_BAR = "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (h)and-drawn, (p)lasma, (s)top, (w)ave, (>)toggle diamonds, (/)toggle fins";
    controller.debugPrintControls();
  }
  logToStdout("USING CONTROLLER? " + config.USING_CONTROLLER);
  
  // Initialize audio device selector
  healPulseDefaultSource();
  initializeAudioDeviceSelector();
}

// Heal Pulse routing if a previous crash left default-source on a monitor.
// That state can interfere with playback latency / focus on some systems.
void healPulseDefaultSource() {
  if (config.OS_TYPE == null || !config.OS_TYPE.toLowerCase().contains("linux")) return;
  try {
    Process get = new ProcessBuilder("sh", "-c", "pactl get-default-source").redirectErrorStream(true).start();
    java.io.BufferedReader r = new java.io.BufferedReader(new java.io.InputStreamReader(get.getInputStream()));
    String cur = r.readLine();
    get.waitFor();
    if (cur == null || !cur.endsWith(".monitor")) return;
    Process list = new ProcessBuilder("sh", "-c", "pactl list short sources").redirectErrorStream(true).start();
    java.io.BufferedReader rl = new java.io.BufferedReader(new java.io.InputStreamReader(list.getInputStream()));
    String line, fix = null;
    while ((line = rl.readLine()) != null) {
      String[] parts = line.split("\\s+");
      if (parts.length >= 2 && !parts[1].endsWith(".monitor")) { fix = parts[1]; break; }
    }
    list.waitFor();
    if (fix != null) {
      new ProcessBuilder("sh", "-c", "pactl set-default-source " + fix).start().waitFor();
      println("[Audio] Healed Pulse default source: " + cur + " -> " + fix);
    }
  } catch (Exception ignored) {}
}

void initializeAudioDeviceSelector() {
  config.audioDeviceSelector = new AudioDeviceSelector();
  config.audioDeviceSelector.refresh();

  if (config.audioDeviceSelector.getDeviceCount() > 0) {
    logToStdout("[Audio] Audio device selector initialized with " + config.audioDeviceSelector.getDeviceCount() + " devices");
  }
}

boolean hasDevAudioFlag() {
  String[] candidates = {
    sketchPath() + "/.devaudio",
    sketchPath() + "/../.devaudio",
    System.getProperty("user.dir") + "/.devaudio"
  };
  for (String path : candidates) {
    if (new java.io.File(path).exists()) return true;
  }
  return false;
}

// Snap selector to the first device whose name starts with "default" (Pulse/
// PipeWire-routable on Linux, "Primary Sound Capture Driver" on Windows).
// Falls through silently if no match — caller can still F1/F2.
void pickPreferredAudioDevice() {
  if (config.audioDeviceSelector == null) return;
  for (int i = 0; i < config.audioDeviceSelector.getDeviceCount(); i++) {
    String n = config.audioDeviceSelector.deviceNames.get(i);
    if (n != null && n.toLowerCase().startsWith("default")) {
      config.audioDeviceSelector.selectDevice(i);
      config.SELECTED_AUDIO_DEVICE_INDEX = i;
      return;
    }
  }
}

void initializeGlobals() {
  logToStdout("initializeGlobals");

  config = new Config();
  config.VERBOSE_LOG = isDevVerbose();
  dropPredictor = new DropPredictor();

  ellipseMode(CENTER);
  blendMode(BLEND);


  HANDY_RENDERERS = new HandyRenderer[3];
  config.HANDY_RENDERERS_COUNT = HANDY_RENDERERS.length;
  config.MAX_HANDY_RENDERER_POSITION = config.HANDY_RENDERERS_COUNT -1;

  h = HandyPresets.createWaterAndInk(this);
  h1 = HandyPresets.createMarker(this);
  h2 = new HandyRenderer(this);

  HANDY_RENDERERS[0] = h;
  HANDY_RENDERERS[1] = h1;
  HANDY_RENDERERS[2] = h2;

  CURRENT_HANDY_RENDERER = HANDY_RENDERERS[config.CURRENT_HANDY_RENDERER_POSITION];

  modes = new int[]{
    BLEND, ADD, SUBTRACT, EXCLUSION,
    DIFFERENCE, MULTIPLY, SCREEN,
    REPLACE
  };
  
  modeNames = new String[]{
    "BLEND", "ADD", "SUBTRACT", "EXCLUSION",
    "DIFFERENCE", "MULTIPLY", "SCREEN",
    "REPLACE"
  };
}

boolean isDevMode() {
  // Check several locations — sketchPath() can vary depending on how Processing CLI is invoked
  String[] candidates = {
    sketchPath() + "/.devmode",
    sketchPath() + "/../.devmode",
    System.getProperty("user.dir") + "/.devmode",
    System.getProperty("user.home") + "/.devmode"
  };
  for (String path : candidates) {
    if (new java.io.File(path).exists()) {
      logToStdout("devmode active: " + path);
      return true;
    }
  }
  return false;
}

// Verbose stdout heartbeat (SCENE/CONTROLLER/FPS once per second).
// Off by default — drop a `.devverbose` file in the sketch dir to re-enable
// for debugging. HUD + /operator already show this info live.
boolean isDevVerbose() {
  String[] candidates = {
    sketchPath() + "/.devverbose",
    sketchPath() + "/../.devverbose",
    System.getProperty("user.dir") + "/.devverbose"
  };
  for (String path : candidates) if (new java.io.File(path).exists()) return true;
  return false;
}

// Explicit opt-in for frame preview saves — separate from devmode so it never
// runs unless you specifically need Claude to see the visuals.
// Enable:  touch Music_Visualizer_CK/.devpreview
// Disable: rm Music_Visualizer_CK/.devpreview
boolean isDevPreview() {
  String[] candidates = {
    sketchPath() + "/.devpreview",
    sketchPath() + "/../.devpreview",
    System.getProperty("user.dir") + "/.devpreview"
  };
  for (String path : candidates) {
    if (new java.io.File(path).exists()) return true;
  }
  return false;
}

void saveDevPreview() {
  if (isDevPreview() && frameCount % 300 == 1) saveFrame("/tmp/vis_preview.png");
}

void setSongToVisualize() {
  logToStdout("Current song: " + config.SONG_TO_VISUALIZE);
  logToStdout("sketchPath() = " + sketchPath());
  logToStdout("user.dir     = " + System.getProperty("user.dir"));

  // Env-var or .devaudio override: skip dialog, start in DEVICE mode.
  String envMode = System.getenv("MV_AUDIO_MODE");
  if ("DEVICE".equalsIgnoreCase(envMode) || hasDevAudioFlag()) {
    config.AUDIO_INPUT_MODE = "DEVICE";
    config.STATE = SCENE_ORIGINAL;
    config.SONG_NAME = "Live Audio (pending device)";
    logToStdout("[Audio] Startup mode forced to DEVICE via env/flag");
    return;
  }

  // Dev / smoke-test shortcuts — skip the dialog
  if (isDevMode() || SMOKE_TEST_MODE) {
    try {
      java.io.File devSongFile = new java.io.File(sketchPath(".devsong"));
      if (devSongFile.exists()) {
        String devSongPath = join(loadStrings(devSongFile.getAbsolutePath()), "").trim();
        if (new java.io.File(devSongPath).exists()) {
          config.SONG_TO_VISUALIZE = devSongPath;
          config.SONG_NAME = getSongNameFromFilePath(devSongPath, config.OS_TYPE);
          config.STATE = SCENE_ORIGINAL;
          logToStdout("Dev song: " + config.SONG_TO_VISUALIZE);
          return;
        }
      }
    } catch (Exception e) { /* ignore */ }

    java.io.File musicDir = new java.io.File(System.getProperty("user.home"), "Music");
    if (config.songList.size() == 0) collectSongs(musicDir, config.songList);
    if (config.songList.size() > 0) {
      config.currentSongIndex = (int) random(config.songList.size());
      config.SONG_TO_VISUALIZE = config.songList.get(config.currentSongIndex);
      logToStdout("Random song selected: " + config.SONG_TO_VISUALIZE);
      config.STATE = SCENE_ORIGINAL;
      config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      return;
    }
    // Smoke-test fallback: bundled silent wav so headless CI never hits the
    // JOptionPane dialog (which would block forever with no display input).
    if (SMOKE_TEST_MODE) {
      String fallback = sketchPath("data/smoke-test.wav");
      if (new java.io.File(fallback).exists()) {
        config.SONG_TO_VISUALIZE = fallback;
        config.SONG_NAME = "smoke-test";
        config.STATE = SCENE_ORIGINAL;
        logToStdout("[SMOKE TEST] Using bundled silent wav: " + fallback);
        return;
      }
    }
    logToStdout("No songs found in ~/Music, falling back to file picker");
    // fall through to dialog
  }

  // Show a startup dialog: Random Song vs Browse vs Live Audio
  int choice = javax.swing.JOptionPane.showOptionDialog(
    null,
    "How would you like to source audio?",
    "Music Visualizer",
    javax.swing.JOptionPane.DEFAULT_OPTION,
    javax.swing.JOptionPane.QUESTION_MESSAGE,
    null,
    new String[]{ "Random Song", "Browse...", "Live Audio Device" },
    "Random Song"
  );

  if (choice == 2) {
    // Live audio device — no mp3 will be loaded.
    config.AUDIO_INPUT_MODE = "DEVICE";
    config.STATE = SCENE_ORIGINAL;
    config.SONG_NAME = "Live Audio (pending device)";
    logToStdout("[Audio] User selected DEVICE mode at startup");
    return;
  }

  if (choice == 0) {
    // Random song from ~/Music
    java.io.File musicDir = new java.io.File(System.getProperty("user.home"), "Music");
    if (config.songList.size() == 0) collectSongs(musicDir, config.songList);
    if (config.songList.size() > 0) {
      config.currentSongIndex = (int) random(config.songList.size());
      config.SONG_TO_VISUALIZE = config.songList.get(config.currentSongIndex);
      logToStdout("Random song selected: " + config.SONG_TO_VISUALIZE);
      config.STATE = SCENE_ORIGINAL;
      config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
      return;
    }
    logToStdout("No songs found in ~/Music, falling back to file picker");
  }

  // Browse (choice == 1, or random had no songs)
  selectInput("Select song to visualize", "fileSelected");
  while (config.SONG_TO_VISUALIZE == "") {
    delay(1);
  }
  config.STATE = SCENE_ORIGINAL;
  logToStdout("SONG TO VISUALIZE: " + config.SONG_TO_VISUALIZE);
  config.SONG_NAME = getSongNameFromFilePath(config.SONG_TO_VISUALIZE, config.OS_TYPE);
}

volatile boolean _loadingSong = false;
// Cross-thread song-load request. Set by any thread (AWT-EDT picker, network
// handler, etc); serviced on the draw thread via drainPendingSongLoad() so
// Minim teardown/init never collides with audio.forward().
volatile String _pendingSongPath = null;

void requestSongLoad(String path) {
  _pendingSongPath = path;
}

void drainPendingSongLoad() {
  String path = _pendingSongPath;
  if (path == null) return;
  _pendingSongPath = null;
  loadSongByPath(path);
}

void loadSongByPath(String path) {
  // Re-entrancy guard. With the pending-load queue this should only ever fire
  // if loadSongByPath itself recurses; keeping it as a belt-and-suspenders.
  if (_loadingSong) {
    logToStdout("[Audio] loadSongByPath ignored — load already in flight: " + path);
    return;
  }
  _loadingSong = true;
  try {
    if (audio != null) audio.stop();
    config.SONG_TO_VISUALIZE = path;
    config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
    loadSongToVisualize();
    logToStdout("Now playing: " + config.SONG_NAME);
    if (webQueueManager != null) webQueueManager.rotate();
  } finally {
    _loadingSong = false;
  }
}

void nextSong() {
  if (config.songList.size() == 0) return;
  config.currentSongIndex = (config.currentSongIndex + 1) % config.songList.size();
  loadSongByPath(config.songList.get(config.currentSongIndex));
}

void shuffleSong() {
  if (config.songList.size() == 0) return;
  int newIndex;
  do {
    newIndex = (int) random(config.songList.size());
  } while (config.songList.size() > 1 && newIndex == config.currentSongIndex);
  config.currentSongIndex = newIndex;
  loadSongByPath(config.songList.get(config.currentSongIndex));
}

void collectSongs(java.io.File dir, ArrayList<String> songs) {
  if (dir == null || !dir.exists()) return;
  java.io.File[] files = dir.listFiles();
  if (files == null) return;
  for (java.io.File f : files) {
    if (f.isDirectory()) {
      collectSongs(f, songs);
    } else {
      String name = f.getName().toLowerCase();
      if (name.endsWith(".mp3") || name.endsWith(".wav") || name.endsWith(".aiff")) {
        songs.add(f.getAbsolutePath());
      }
    }
  }
}

void folderSelected(File selection) {
  if (selection == null) {
    logToStdout("[FolderPicker] cancelled / null selection");
    return;
  }
  logToStdout("[FolderPicker] raw selection: " + selection.getAbsolutePath()
            + " isDir=" + selection.isDirectory() + " isFile=" + selection.isFile());

  // Linux GTK selectFolder sometimes returns the highlighted *file* inside the
  // folder rather than the folder itself. If that happens, fall back to its
  // parent directory so the picker still does the obvious thing.
  File dir = selection;
  if (!dir.isDirectory()) {
    File parent = dir.getParentFile();
    if (parent != null && parent.isDirectory()) {
      logToStdout("[FolderPicker] selection was a file — falling back to parent: " + parent.getAbsolutePath());
      dir = parent;
    } else {
      logToStdout("[FolderPicker] selection is not a folder and has no usable parent. Aborting.");
      return;
    }
  }

  config.songList.clear();
  collectSongs(dir, config.songList);
  logToStdout("[FolderPicker] scanned " + dir.getAbsolutePath() + " -> " + config.songList.size() + " song(s)");
  if (config.songList.size() == 0) {
    logToStdout("[FolderPicker] no playable .mp3 / .wav / .aiff under that folder.");
    return;
  }

  int idx = (int) random(config.songList.size());
  config.currentSongIndex = idx;
  String path = config.songList.get(idx);
  config.SONG_TO_VISUALIZE = path;
  config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
  logToStdout("[FolderPicker] enqueue first track: " + path);
  if (audio != null) requestSongLoad(path);
  else logToStdout("[FolderPicker] WARN: audio is null at request time");
}

void fileSelected(File selection) {
  if (selection == null) {
    logToStdout("No file selected. Window might have been closed/cancelled");
    return;
  }
  String path = selection.getAbsolutePath();
  logToStdout("File selected: " + path);
  config.SONG_TO_VISUALIZE = path;
  config.SONG_NAME = getSongNameFromFilePath(path, config.OS_TYPE);
  // Always rescan parent folder so n/N works with the new location
  config.songList.clear();
  collectSongs(selection.getParentFile(), config.songList);
  config.currentSongIndex = config.songList.indexOf(path);
  if (config.currentSongIndex < 0) config.currentSongIndex = 0;

  // At runtime (audio already exists) enqueue — the picker callback runs on
  // AWT-EDT, so doing the Minim teardown/init here would race the draw thread.
  // At startup the setSongToVisualize() while-loop picks up SONG_TO_VISUALIZE instead.
  if (audio != null) {
    requestSongLoad(path);
  }
}

String discoverOperatingSystem() {
  String os = System.getProperty("os.name");
  if (os.contains("Windows")) {
    return "win";
  } else if (os.contains("Mac")) {
    return "mac";
  } else if (os.contains("Linux")) {
    return "linux";
  } else {
    return "other";
  }
}

String getSongNameFromFilePath(String song_path, String osType) {
  logToStdout("Getting song name from file path, where osType is: " + osType);
  String[] file_name_parts;
  if (osType == "linux") {
    file_name_parts = split(song_path, "/");
  } else if (osType == "win") {
    file_name_parts = split(song_path, "\\");
  } else {
    file_name_parts = split(song_path, "\\");
  }
  config.SONG_NAME = file_name_parts[file_name_parts.length-1];
  logToStdout("SONG_NAME: " + config.SONG_NAME);
  return config.SONG_NAME;
}

void settings() {
  // Some sandboxed environments (e.g. Flatpak-packaged Processing blocking the
  // AWT/X11 portal call) can't query the display at settings()-time and report
  // 0x0 here. size() only works in settings() — if we let a 0 through, the OS
  // clamps it to a tiny sliver window for the whole run. Fall back to a sane
  // default so at least the window is usable; see documentation for the real
  // fix (running a non-sandboxed Processing install).
  int fallbackW = 1920, fallbackH = 1080;
  int w = (displayWidth  > 0) ? displayWidth  : fallbackW;
  int h = (displayHeight > 0) ? displayHeight : fallbackH;
  size(w, h - 80, P3D);
  boolean useFancy = false;
  if (args != null) {
    for (String arg : args) {
      if (arg.equals("--fancy")) useFancy = true;
    }
  }
  
  if (useFancy) {
    smooth(2);
  } else {
    noSmooth();
  }
}

void setup() {
  config = new Config();
  config.VERBOSE_LOG = isDevVerbose();
  pinManager = new PinManager();
  clientRegistry = new ClientRegistry();
  webQueueManager = new WebQueueManager();
  featureFlagServer = new FeatureFlagServer();
  featureFlagServer.start();
  webController = new WebController();
  // Pick a free WS port too (default 8081) and tell the FF server so it can
  // inject it into controller.html. Otherwise a stale JVM holding 8081 silently
  // breaks the phone connection.
  int wsPort = featureFlagServer.findFreePort(8081, 10);
  if (wsPort < 0) wsPort = 8081;  // fall back; .start() will log the bind failure
  controllerWS = new ControllerWebSocket(wsPort);
  controllerWS.start();
  featureFlagServer.wsPort = wsPort;
  println("[DIAG] displayWidth=" + displayWidth + " displayHeight=" + displayHeight + " width=" + width + " height=" + height);
  sceneBuffer = createGraphics(sceneBufferRenderWidth(), sceneBufferRenderHeight(), P3D);
  sceneBuffer.smooth(config.LOW_POWER_MODE ? 2 : 4);
  println("[DIAG] sceneBuffer=" + sceneBuffer.width + "x" + sceneBuffer.height);
  sceneBuffer.beginDraw(); sceneBuffer.background(0); sceneBuffer.endDraw();
  background(200);
  analyzer = new AudioAnalyser();
  spatial = new SpatialAudio();
  logToStdout("canvas spawned");
  initializeGlobals();
  // Detect smoke test early so setSongToVisualize() skips the file picker
  if (isSmokeTestMode()) {
    SMOKE_TEST_MODE = true;
    println("[SMOKE TEST] Detected — will exercise all " + SCENE_COUNT + " scenes");
  }
  setSongToVisualize();
  surface.setResizable(true);
  frameRate(999);
  surface.setTitle(config.TITLE_BAR);
  setupController();
  loadSongToVisualize();
  // ── PostFX stack ────────────────────────────────────────────────────────
  postFX = new PostFXStack();
  postFX.add(new BloomFX());               // G → cycle: index 0
  postFX.add(new ChromaticAberrationFX()); // G → cycle: index 1
  postFX.add(new ScanlinesFX());           // G → cycle: index 2
  postFX.add(new VignetteFX());            // G → cycle: index 3
  postFX.add(new PixelSortFX());           // G → cycle: index 4
  // Honour --fancy flag: start with bloom on
  if (config.BLOOM_ENABLED) postFX.setActive(0);

  // Initialize scene registry (0-18)
  scenes = new IScene[SCENE_COUNT];
  scenes[0]  = new RIPScene();
  scenes[1]  = new OriginalScene(this);
  scenes[2]  = new HeartGridScene();
  scenes[3]  = new Shapes3DScene();
  scenes[4]  = new CatsCradleScene();
  scenes[5]  = new OscilloscopeScene();
  scenes[6]  = new TableTennisScene();
  scenes[7]  = new PrismCodexScene();
  scenes[8]  = new ParticleFountainScene();
  scenes[9]  = new Halo2LogoScene();
  scenes[10] = new AuroraRibbonsScene();
  scenes[11] = new RadialFFTScene();
  scenes[12] = new SpirographScene();
  scenes[13] = new GravityStringsScene();
  scenes[14] = new NeuralWeaveScene();
  scenes[15] = new ShoalLuminaScene();
  scenes[16] = new AntigravityScene();
  scenes[17] = new FractalScene();
  scenes[18] = new ShaderScene();
  scenes[19] = new WormScene();
  scenes[20] = new FFTWormScene();
  scenes[21] = new DeepSpaceScene();
  scenes[22] = new CyberGridScene();
  scenes[23] = new RecursiveMandalaScene();
  scenes[24] = new KaleidoscopeScene();
  scenes[25] = new TableTennis3DScene();
  scenes[26] = new VoidBloomScene();
  scenes[27] = new CircuitMazeScene();
  scenes[28] = new MazePuzzleScene();
  scenes[29] = new LissajousKnotScene();
  scenes[30] = new FluidSimScene();
  scenes[31] = new HourglassScene();
  scenes[32] = new SacredGeometryScene();
  scenes[33] = new MathWaveScene();
  scenes[34] = new TorusKnotScene();
  scenes[35] = new RoseCurveScene();
  scenes[36] = new SriYantraScene();
  scenes[37] = new NetOfBeingScene();
  scenes[38] = new PsychedelicEyeScene();
  scenes[39] = new CosmicLatticeScene();
  scenes[40] = new Original3DScene();
  scenes[41] = new DotMandalaScene();
  scenes[42] = new MerkabaStarScene();
  scenes[43] = new PentagonalVortexScene();
  scenes[44] = new TunnelYantraScene();
  scenes[45] = new VisualizerExplainerScene();
  scenes[46] = new ChladniPlateScene();
  scenes[47] = new StrangeAttractorScene();
  scenes[48] = new SacredFractalsScene();
  scenes[49] = new TheyDontKnowScene();
  scenes[50] = new LiveCodeScene();
  scenes[51] = new SilhouettePaintingScene();
  scenes[52] = new HyperspaceBloomScene();
  scenes[53] = new TableTennisSimScene();
  scenes[54] = new SimCubeScene();
  scenes[55] = new FableMurmurationScene();
  scenes[56] = new SpatialOrbitScene();
  scenes[57] = new ParalyzedScene();

  // SceneSwitcher — must be created AFTER scenes[] is populated
  sceneSwitcher  = new SceneSwitcher(SCENE_ORDER);
  audioSwitcher  = new AudioSourceSwitcher();
  autoSwitcher   = new AutoSwitcher();
  paramAutoPilot = new ParamAutoPilot();
  featureFlagServer.loadFromDisk();  // after autoSwitcher so AUTO_SWITCH_MODE applies
  sceneGuard     = new SceneGuard();
  frameWatchdog  = new FrameWatchdog();
  if (!SMOKE_TEST_MODE) frameWatchdog.start();
  killSwitch     = new KillSwitch();
  strobeSafety   = new StrobeSafety();
  strobeSafety.loadPref();
  tempoLock      = new TempoLock();
  setlist        = new Setlist();
  setlist.load();
  textOverlay    = new TextOverlay();
  recorder       = new Recorder();
  streamer       = new Streamer();
  // .devstream = "venue" starts the stream in low-bandwidth profile (weak WiFi)
  try {
    java.io.File devStreamFile = new java.io.File(sketchPath(".devstream"));
    if (devStreamFile.exists()) {
      String raw = join(loadStrings(devStreamFile.getAbsolutePath()), "").trim();
      if (raw.equalsIgnoreCase("venue")) streamer.profile = Streamer.PROFILE_VENUE;
    }
  } catch (Exception e) { /* ignore — missing or malformed file */ }
  midiBridge     = new MidiBridge();
  helpOverlay    = new HelpOverlay();
  displayManager = new DisplayManager();
  demoInput      = new DemoInputDriver();
  frameBudget    = new FrameBudget();
  displayManager.initFromPrefs();

  // Initialise smoke test runner after all scenes exist
  if (SMOKE_TEST_MODE) {
    smokeTestRunner = new SmokeTestRunner();
    println("[SMOKE TEST] Runner initialised — starting on next draw()");
    runAudioModeTests(smokeTestRunner);
  }

  monoFont = createFont("Monospaced", 15, true);
  // Dev shortcut: if .devscene exists in the sketch dir, start on that scene.
  // Must be resolved BEFORE onEnter() so the correct scene receives the call.
  // The file may hold a number OR a scene name (whichever you can remember):
  //   echo 54        > Music_Visualizer_CK/.devscene
  //   echo SimCube   > Music_Visualizer_CK/.devscene
  //   echo sim_cube  > Music_Visualizer_CK/.devscene
  try {
    java.io.File devScene = new java.io.File(sketchPath(".devscene"));
    if (devScene.exists()) {
      String raw = join(loadStrings(devScene.getAbsolutePath()), "").trim();
      int sceneIndex = resolveDevScene(raw);
      if (sceneIndex >= 0 && sceneIndex < scenes.length && scenes[sceneIndex] != null) {
        config.STATE = sceneIndex;
        println("DEVSCENE: starting on " + sceneIndex + " = "
                + scenes[sceneIndex].getClass().getSimpleName());
      }
    }
  } catch (Exception e) { /* ignore — missing or malformed file */ }

  // Initial lifecycle trigger (skipped in smoke test — runner manages this)
  previousState = config.STATE;
  if (!SMOKE_TEST_MODE) scenes[config.STATE].onEnter();
  // load Halo 3 emblem used as reference for colors and texture
  h3_emblem = loadImage("../media/h3_emblem.jpg");

  xboxFrontSVG = loadShape("controller/front.svg");
  if (xboxFrontSVG != null) xboxFrontSVG.disableStyle();
}

// Resolve a .devscene value to a scene index. Accepts a plain number ("54") or
// a scene name in any casing/spacing ("SimCube", "sim_cube", "SimCubeScene",
// even "SCENE_SIM_CUBE"). Returns -1 if nothing matches, and lists the valid
// names to the console so the right spelling is one glance away.
int resolveDevScene(String raw) {
  if (raw == null) return -1;
  raw = raw.trim();
  if (raw.length() == 0) return -1;

  // A bare number is taken as the index directly.
  try { return Integer.parseInt(raw); } catch (NumberFormatException notANumber) { }

  // Otherwise match by name. Normalise both sides so punctuation and casing
  // don't matter; prefer an exact match, fall back to a partial one.
  String wanted = normalizeSceneName(raw);
  int exactMatch = -1, partialMatch = -1;
  for (int i = 0; i < scenes.length; i++) {
    if (scenes[i] == null) continue;
    String name = normalizeSceneName(scenes[i].getClass().getSimpleName());
    if (name.equals(wanted)) { exactMatch = i; break; }
    if (partialMatch < 0 && (name.contains(wanted) || wanted.contains(name))) partialMatch = i;
  }
  int found = (exactMatch >= 0) ? exactMatch : partialMatch;

  if (found < 0) {
    println("DEVSCENE: no scene matches \"" + raw + "\". Available scenes:");
    for (int i = 0; i < scenes.length; i++)
      if (scenes[i] != null) println("  " + i + " = " + scenes[i].getClass().getSimpleName());
  }
  return found;
}

// Lower-case, strip anything that isn't a letter or digit, and drop a trailing
// "scene" so "SimCubeScene", "sim_cube" and "Sim Cube" all become "simcube".
String normalizeSceneName(String name) {
  String cleaned = name.toLowerCase().replaceAll("[^a-z0-9]", "");
  String suffix = "scene";
  if (cleaned.endsWith(suffix)) cleaned = cleaned.substring(0, cleaned.length() - suffix.length());
  return cleaned;
}

void stop() {
  if (recorder != null && recorder.running) recorder.stop();
  if (streamer != null && streamer.running) streamer.stop();
  if (midiBridge != null && midiBridge.enabled) midiBridge.stop();
  if (frameWatchdog != null) frameWatchdog.stop();
  audio.stop();
  super.stop();
}

// Buffer-resize path disabled pending scene refactor — scenes draw in display
// coords (width/height globals), so a smaller buffer makes geometry centre at
// (display_w/2, display_h/2) which lands at the buffer's bottom-right corner.
// MSAA reduction + bloom-off still apply in LOW_POWER_MODE.
int sceneBufferRenderWidth()  { return width;  }
int sceneBufferRenderHeight() { return height; }

void toggleHandDrawn(){
  config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
  h.setIsHandy(config.APPEAR_HAND_DRAWN);
}

void toggleHandDrawn3(){
  config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
  h.setIsHandy(config.APPEAR_HAND_DRAWN);
}

void toggleSongPlaying(){
   if (config.SONG_PLAYING) {
    stopSong();
  } else {
    startSong();
  }
}

void stopSong(){
  audio.pause();
  config.SONG_PLAYING = false;
}

void startSong(){
  audio.play();
  config.SONG_PLAYING = true;
}

void toggleAudioInputMode() {
  if (config.AUDIO_INPUT_MODE.equals("FILE")) {
    config.AUDIO_INPUT_MODE = "DEVICE";
    pickPreferredAudioDevice();
    println("[Audio] Switched to DEVICE input mode. Use F1/F2 to select device.");
    if (config.OS_TYPE != null && config.OS_TYPE.toLowerCase().contains("linux")) {
      println("[Audio] LINUX TIP: to capture YT/Spotify, run `./loopback.sh on` then pick `default`. `./loopback.sh off` to restore mic.");
    }
  } else {
    config.AUDIO_INPUT_MODE = "FILE";
    println("[Audio] Switched to FILE input mode. Press 'o' to select a song file.");
  }
  
  // Stop current audio and reload with new mode
  if (audio != null) audio.stop();
  loadSongToVisualize();
  println("[Audio] Input mode: " + config.AUDIO_INPUT_MODE + " | Song: " + config.SONG_NAME);
}

void mousePressed() {
  if (paramAutoPilot != null) paramAutoPilot.noteActivity();
  scenes[config.STATE].handleKey(' '); // reuse handleKey for simple click-bursts if scene desires
}

void mouseWheel(MouseEvent event) {
  if (paramAutoPilot != null) paramAutoPilot.noteActivity();
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].handleMouseWheel(event.getCount());
  }
}

void keyPressed() {
  // Any keystroke means a human is at the desk — pause autopilot drift.
  if (paramAutoPilot != null) paramAutoPilot.noteActivity();

  // Tab always toggles scene switcher (checked before anything else)
  if (key == TAB) { sceneSwitcher.toggle(); return; }

  // +/- nudge DEVICE input gain manually; ` 0 ` (zero) re-enables AGC.
  if (audio != null && audio.isDeviceInput()) {
    if (key == '+' || key == '=') { audio.nudgeDeviceGain(1.5f); return; }
    if (key == '-' || key == '_') { audio.nudgeDeviceGain(1.0f / 1.5f); return; }
  }

  // ' (apostrophe) toggles audio source switcher. F-keys are unreliable —
  // many WMs (GNOME/KDE) grab F10/F11 for menu/fullscreen before the sketch.
  if (audioSwitcher != null && key == '\'') {
    audioSwitcher.toggle();
    return;
  }
  if (audioSwitcher != null && audioSwitcher.isOpen) {
    audioSwitcher.handleKey(key, keyCode);
    return;
  }

  // While switcher is open, route ALL keys to it and suppress everything else
  if (sceneSwitcher.isOpen) {
    sceneSwitcher.handleKey(key, keyCode);
    return;
  }

  // Esc fires the emergency kill switch (fade-to-black). Q quits.
  if (key == ESC) {
    key = 0; // suppress Processing's default ESC→exit behaviour
    killSwitch.toggle();
    return;
  }

  // F11 toggles "fill current display" mode (borderless-style fullscreen).
  // Auto-enables strobe safety on the way into fullscreen (venue assumption);
  // leaves it untouched when leaving fullscreen so manual overrides stick.
  if (keyCode == java.awt.event.KeyEvent.VK_F11) {
    boolean wasFullscreen = displayManager.fullscreen;
    displayManager.toggleFullscreen();
    if (!wasFullscreen && displayManager.fullscreen && strobeSafety != null && !strobeSafety.enabled) {
      strobeSafety.setEnabled(true);
      println("[STROBE] auto-enabled with fullscreen");
    }
    return;
  }

  // Ctrl+Enter: "showtime" macro — flip everything safety-relevant on at once.
  // Idempotent: re-pressing is safe. Pairs with Esc kill switch for emergencies.
  if (keyCode == java.awt.event.KeyEvent.VK_ENTER
      && keyEvent != null && keyEvent.isControlDown()) {
    if (displayManager != null && !displayManager.fullscreen) displayManager.toggleFullscreen();
    if (strobeSafety != null && !strobeSafety.enabled)        strobeSafety.setEnabled(true);
    println("[SHOWTIME] fullscreen + strobe safety enabled");
    return;
  }

  // F4 toggles MIDI bridge (auto-scans inputs on enable).
  if (keyCode == java.awt.event.KeyEvent.VK_F4) {
    if (midiBridge != null) midiBridge.toggle();
    return;
  }

  // F5 toggles mp4 recording (downscaled, ffmpeg-piped).
  if (keyCode == java.awt.event.KeyEvent.VK_F5) {
    if (recorder != null) recorder.toggle();
    return;
  }

  // Stream toggle: F6 OR F7 — F6 gets eaten by some WMs (GNOME).
  // If both fail, use the operator dashboard button (no auth needed on localhost).
  if (keyCode == java.awt.event.KeyEvent.VK_F6 || keyCode == java.awt.event.KeyEvent.VK_F7) {
    boolean shift = (keyEvent != null && keyEvent.isShiftDown());
    if (shift) {
      // Shift+F6/F7 — cycle stream bandwidth profile NORMAL <-> VENUE (weak WiFi)
      if (streamer != null) streamer.cycleProfile();
    } else {
      println("[STREAM] toggle hotkey pressed (key=" + key + " code=" + keyCode + ")");
      if (streamer != null) streamer.toggle();
      else                  println("[STREAM] streamer is null!");
    }
    return;
  }

  // F3 toggles live text overlay (DJ name / track title); Shift+F3 cycles layout.
  if (keyCode == java.awt.event.KeyEvent.VK_F3) {
    if (textOverlay != null) {
      boolean shift = (keyEvent != null && keyEvent.isShiftDown());
      if (shift) textOverlay.cycleLayout();
      else       textOverlay.toggle();
    }
    return;
  }

  // F8 toggles per-phase frame budget HUD (perf diagnostic).
  if (keyCode == java.awt.event.KeyEvent.VK_F8) {
    if (frameBudget != null) frameBudget.toggle();
    return;
  }

  // F12 toggles strobe safety cap (photosensitive-seizure protection).
  if (keyCode == java.awt.event.KeyEvent.VK_F12) {
    if (strobeSafety != null) {
      strobeSafety.toggle();
      println("[STROBE] " + (strobeSafety.enabled ? "ON" : "OFF"));
    }
    return;
  }

  // F9 toggle auto-switcher; Shift+F9 cycle mode
  if (keyCode == java.awt.event.KeyEvent.VK_F9) {
    boolean shift = (keyEvent != null && keyEvent.isShiftDown());
    if (shift) {
      autoSwitcher.cycleMode();
      println("AUTO: mode -> " + autoSwitcher.MODE_LABELS[autoSwitcher.mode]);
    } else {
      autoSwitcher.toggleEnabled();
      println("AUTO: " + (autoSwitcher.enabled ? "ON (" + autoSwitcher.MODE_LABELS[autoSwitcher.mode] + ")" : "OFF"));
    }
    return;
  }

  // `:` toggles knob autopilot (idle drift for sit-back, no-operator viewing)
  if (key == ':') {
    paramAutoPilot.toggleEnabled();
    println("PILOT: " + (paramAutoPilot.enabled ? "ON (drifts after "
            + (int) paramAutoPilot.IDLE_SECONDS_BEFORE_ENGAGE + "s idle)" : "OFF"));
    return;
  }

// Ctrl+1..9 moves window to that display (1-indexed in UI, 0-indexed internally).
  if (keyEvent != null && keyEvent.isControlDown() && key >= '1' && key <= '9') {
    displayManager.moveTo(key - '1');
    return;
  }

  // 1. Delegate to current scene first
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].handleKey(key);
  }

  // 2. Global Shortcuts
  if (key == 'h') cycleHandDrawn();
  if (key == 'H') {
    config.APPEAR_HAND_DRAWN = !config.APPEAR_HAND_DRAWN;
    CURRENT_HANDY_RENDERER.setIsHandy(config.APPEAR_HAND_DRAWN);
  }
  if (key == 's' || key == 'S') toggleSongPlaying();
  if (key == 'n') nextSong();
  if (key == 'N') shuffleSong();
  if (key == 'o') selectInput("Select song to visualize", "fileSelected");
  // selectInput uses the native GTK picker on Linux (has bookmarks); selectFolder
  // falls back to Swing (no bookmarks). So we use selectInput for both — the
  // folder version asks for any song *inside* the desired folder, and
  // folderSelected() walks up to the parent directory.
  if (key == 'O') selectInput("Pick any song in the folder to shuffle", "folderSelected");
  if (key == 'l' || key == 'L') config.LOGGING_ENABLED = !config.LOGGING_ENABLED;
  if (key == 'm' || key == 'M') config.SHOW_METADATA = !config.SHOW_METADATA;
  if (key == '`') config.SHOW_CODE = !config.SHOW_CODE;
  if (key == 'i' || key == 'I') config.SHOW_CONTROLLER_GUIDE = !config.SHOW_CONTROLLER_GUIDE;  // Toggle controller guide
  // G cycles PostFX stack (enable next effect); Shift+G disables all
  if (key == 'g') { if (postFX != null) postFX.cycleNext(); }
  if (key == 'G') { if (postFX != null) postFX.disableAll(); }
  if (key == 'c' || key == 'C') controller.calibrate();
  if (key == 'q' || key == 'Q') {
    audio.stop();
    exit();
  }

  // Scene Switching: 1-9 → SCENE_ORDER[0..8], 0 → SCENE_ORDER[9]
  if ((key >= '1' && key <= '9') || key == '0') {
    int pos = (key == '0') ? 9 : ((int) key - 49);
    if (pos >= 0 && pos < SCENE_ORDER.length) {
      switchScene(SCENE_ORDER[pos]);
    }
  }

  // Keyboard equivalent of controller LB/RB. Use '<' / '>' as primary —
  // ASCII keys can't be intercepted by the WM. PageUp/PageDown also work
  // when available; we accept multiple keyCode aliases because Processing's
  // NEWT backend uses 11/12 while AWT uses 33/34 (and X11 may map differently).
  if (key == '<') switchScene(prevActiveScene());
  if (key == '>') switchScene(nextActiveScene());
  if (key == CODED) {
    if (keyCode == 11 || keyCode == java.awt.event.KeyEvent.VK_PAGE_UP)
      switchScene(prevActiveScene());
    if (keyCode == 12 || keyCode == java.awt.event.KeyEvent.VK_PAGE_DOWN)
      switchScene(nextActiveScene());
  }

  // ? toggles stage hotkey help overlay
  if (key == '?') { if (helpOverlay != null) helpOverlay.toggle(); return; }

  // Setlist: ] advance, [ back, } toggle auto, { reload from disk
  if (key == ']') { if (setlist != null) setlist.advance(); return; }
  if (key == '[') { if (setlist != null) setlist.back();    return; }
  if (key == '}') { if (setlist != null) setlist.toggleAuto(); return; }
  if (key == '{') { if (setlist != null) setlist.load();      return; }

  // Tap tempo: `\` = tap (4 taps to lock), `|` (Shift+\) = clear lock
  if (key == '\\') {
    if (tempoLock != null) tempoLock.tap();
  }
  if (key == '|') {
    if (tempoLock != null) tempoLock.clear();
  }

  // Global background toggles
  if (key == 't' || key == 'T') {
    config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
    if (config.DRAW_TUNNEL) enableOneBackgroundAndDisableOthers("tunnel");
  }
  // Hotkey-only scenes (excluded from rotation order)
  if (key == 'w') { switchSceneDirect(SCENE_MATH_WAVE); return; }
  if (key == 'v') { switchSceneDirect(SCENE_EXPLAINER); return; }

  if (key == 'p') {
    config.DRAW_PLASMA = !config.DRAW_PLASMA;
    if (config.DRAW_PLASMA) enableOneBackgroundAndDisableOthers("plasma");
  }
  if (key == 'P') {
    config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
    if (config.DRAW_POLAR_PLASMA) enableOneBackgroundAndDisableOthers("polar_plasma");
  }

  if (key == CODED) {
    if (keyCode == LEFT)  audio.skip(-10000);
    if (keyCode == RIGHT) audio.skip(10000);
    if (keyCode == UP) {
      float current_gain = audio.getGain();
      audio.setGain(current_gain + 5);
    }
    if (keyCode == DOWN) {
      float current_gain = audio.getGain();
      audio.setGain(current_gain - 5);
    }
  }
}

void enableOneBackgroundAndDisableOthers(String backgroundToEnable) {
  config.DRAW_TUNNEL = false;
  config.DRAW_PLASMA = false;
  config.DRAW_POLAR_PLASMA = false;
  
  switch(backgroundToEnable) {
    case "tunnel":
      config.DRAW_TUNNEL = true;
      break;
    case "plasma":
      config.DRAW_PLASMA = true;
      break;
    case "polar_plasma":
      config.DRAW_POLAR_PLASMA = true;
      break;
  }
}

void cycleHandDrawn() {
  config.CURRENT_HANDY_RENDERER_POSITION += 1;
  config.CURRENT_HANDY_RENDERER_POSITION = config.CURRENT_HANDY_RENDERER_POSITION % config.HANDY_RENDERERS_COUNT;
}

void reset(){
  logToStdout("reset");
  audio.stop();
  config.SONG_TO_VISUALIZE = "";
  setSongToVisualize();
  loadSongToVisualize();
}

void logToStdout(String messageToLog) {
  if (config.LOGGING_ENABLED) {
    println(messageToLog);
  }
}



public void getUserInput() {
  // Always read (handles hot-plug retry inside Controller.read()).
  // Update the flag each frame so scenes react as soon as the device appears.
  controller.read();
  if (webController != null) webController.applyTo(controller);
  if (demoInput != null) demoInput.applyTo(controller);
  // USING_CONTROLLER counts physical OR web-driven OR demo-synthetic input as
  // "connected" so scenes that gate behind it still receive input.
  config.USING_CONTROLLER = controller.isConnected() || webController.isActive()
                            || (demoInput != null && demoInput.isActive());
  killSwitch.pollController(controller);
  if (!config.USING_CONTROLLER) return;

  // 1. Delegate to active scene
  if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    scenes[config.STATE].applyController(controller);
  }

  // 2. Global Controller Shortcuts
  // D-Pad Toggles (Backgrounds): Fired on Release to allow D-pad chords if needed.
  if (config.STATE != SCENE_TUNNEL_YANTRA) {
    if (controller.dpadUpJustReleased && !controller.dUpWasChorded) {
      config.DRAW_TUNNEL = !config.DRAW_TUNNEL;
      if (config.DRAW_TUNNEL) enableOneBackgroundAndDisableOthers("tunnel");
    }
    if (controller.dpadLeftJustReleased && !controller.dLeftWasChorded) {
      config.DRAW_PLASMA = !config.DRAW_PLASMA;
      if (config.DRAW_PLASMA) enableOneBackgroundAndDisableOthers("plasma");
    }
    if (controller.dpadRightJustReleased && !controller.dRightWasChorded) {
      config.DRAW_POLAR_PLASMA = !config.DRAW_POLAR_PLASMA;
      if (config.DRAW_POLAR_PLASMA) enableOneBackgroundAndDisableOthers("polar_plasma");
    }
    if (controller.dpadDownJustReleased && !controller.dDownWasChorded) {
      config.DRAW_TUNNEL = false;
      config.DRAW_POLAR_PLASMA = false;
      config.DRAW_PLASMA = false;
    }
  }

  // Scene Switching: Fired on RELEASE. If LB was used as a modifier (chorded),
  // then lbWasChorded will be true and no scene switch will occur.
  if (!controller.chord(controller.lbButton, controller.rbButton)) {
    if (controller.lbJustReleased && !controller.lbWasChorded) {
      if (config.VERBOSE_LOG) println("CONTROLLER: LB released -> switching prev");
      switchScene(prevActiveScene());
    }
    if (controller.rbJustReleased && !controller.rbWasChorded) {
      if (config.VERBOSE_LOG) println("CONTROLLER: RB released -> switching next");
      switchScene(nextActiveScene());
    }
  }
  
  // L3 toggle auto-switch, R3 cycle mode (on Release)
  if (controller.leftStickClickJustReleased && !controller.l3WasChorded) {
    autoSwitcher.toggleEnabled();
    println("AUTO: " + (autoSwitcher.enabled ? "ON (" + autoSwitcher.MODE_LABELS[autoSwitcher.mode] + ")" : "OFF"));
  }
  if (controller.rightStickClickJustReleased && !controller.r3WasChorded) {
    autoSwitcher.cycleMode();
    println("AUTO: mode -> " + autoSwitcher.MODE_LABELS[autoSwitcher.mode]);
  }

  // PostFX chords: LB held + Y = cycle, LB held + X = clear.
  // LB is the modifier. Pressing Y/X marks LB as 'chorded', preventing scene switch on release.
  if (postFX != null) {
    if (controller.lbButton) {
      if (controller.yJustPressed) {
        postFX.cycleNext();
        controller.lbWasChorded = true;
        println("PostFX: " + (postFX.anyEnabled() ? postFX.getActiveBadge() : "OFF"));
      }
      if (controller.xJustPressed) {
        postFX.disableAll();
        controller.lbWasChorded = true;
        println("PostFX: OFF");
      }
    }
  }

  if (controller.backJustReleased && !controller.backWasChorded) {
    if (config.VERBOSE_LOG) println("CONTROLLER: BACK released -> stopping");
    stopSong();
  }
  if (controller.startJustReleased && !controller.startWasChorded) {
    if (config.VERBOSE_LOG) println("CONTROLLER: START released -> starting");
    startSong();
  }
}
// ── Active scene list ─────────────────────────────────────────────────────────
// Fan-favourite scenes, in display order. Only these are reachable via
// LB/RB cycling or keyboard number keys. Add a SceneIds constant to re-enable.
// Scenes 3 (SHAPES_3D) and 9 (HALO2_LOGO) are kept in code but excluded for now.
final int[] SCENE_ORDER = {
  SCENE_ORIGINAL,
  SCENE_MAZE_PUZZLE,
  SCENE_LISSAJOUS_KNOT,
  // SCENE_TABLE_TENNIS,
  SCENE_TABLE_TENNIS_3D,
  SCENE_TT_SIM_LAB,
  SCENE_SIM_CUBE,
  SCENE_PRISM_CODEX,
  SCENE_GRAVITY_STRINGS,
  SCENE_NEURAL_WEAVE,
  SCENE_FRACTAL,
  SCENE_SHADER,
  SCENE_WORM,
  SCENE_RECURSIVE_MANDALA,
  SCENE_KALEIDOSCOPE,
  SCENE_VOID_BLOOM,
  // SCENE_CIRCUIT_MAZE,        // disabled — dynamic circuit maze, revisit later
  SCENE_HOURGLASS,
  SCENE_SACRED_GEOMETRY,
  // SCENE_MATH_WAVE — hotkey-only ('w'), excluded from rotation
  SCENE_TORUS_KNOT,
  SCENE_ROSE_CURVE,
  // SCENE_SRI_YANTRA,          // disabled, revisit later
  // SCENE_NET_OF_BEING,        // disabled, revisit later
  SCENE_PSYCHEDELIC_EYE,
  SCENE_COSMIC_LATTICE,
  // SCENE_DOT_MANDALA,         // disabled, revisit later
  SCENE_MERKABA_STAR,
  SCENE_PENTAGONAL_VORTEX,
  // SCENE_TUNNEL_YANTRA,       // disabled — combo layer scene, revisit later
  // SCENE_CHLADNI_PLATE,       // disabled — chladni skybox, revisit later
  SCENE_STRANGE_ATTRACTOR,
  SCENE_HYPERSPACE_BLOOM,
  SCENE_FABLE_MURMURATION,
  SCENE_SPATIAL_ORBIT,
  SCENE_PARALYZED,
  SCENE_SACRED_FRACTALS,
  // SCENE_EXPLAINER — hotkey-only ('v'), excluded from rotation
  // SCENE_THEY_DONT_KNOW,      // disabled, revisit later
  // SCENE_LIVE_CODE,           // disabled — live code console, revisit later
  // SCENE_SILHOUETTE_PAINTING  // disabled, revisit later
};

int _sceneOrderIndex(int state) {
  for (int i = 0; i < SCENE_ORDER.length; i++) {
    if (SCENE_ORDER[i] == state) return i;
  }
  return 0; // default to first if current scene not in list
}

int nextActiveScene() {
  int n = sceneSwitcher.activeOrder.size();
  int cur = config.STATE;
  for (int i = 0; i < n; i++) {
    cur = sceneSwitcher.nextScene(cur);
    if (sceneGuard == null || !sceneGuard.isBlacklisted(cur)) return cur;
  }
  return sceneSwitcher.nextScene(config.STATE);
}
int prevActiveScene() {
  int n = sceneSwitcher.activeOrder.size();
  int cur = config.STATE;
  for (int i = 0; i < n; i++) {
    cur = sceneSwitcher.prevScene(cur);
    if (sceneGuard == null || !sceneGuard.isBlacklisted(cur)) return cur;
  }
  return sceneSwitcher.prevScene(config.STATE);
}

// ── Scene crossfade ───────────────────────────────────────────────────────────
// When switchScene() is called, we capture the current frame as a frozen
// snapshot and draw it on top of the incoming scene with decreasing alpha.
// This gives a smooth dissolve without needing two live render buffers.

PImage crossfadeSnapshot  = null;
int    crossfadeFrame     = 0;
final int CROSSFADE_DURATION = 45; // frames  (~0.75 s at 60 fps)

// ── Beat-synced scene queue ───────────────────────────────────────────────────
// Scene changes requested via switchScene() are held here and executed on the
// next beat onset. If no beat fires within MAX_BEAT_WAIT logical frames (~1 s)
// the switch executes anyway so the UI never feels unresponsive.
int pendingScene     = -1;
int pendingFrameCount = 0;
final int MAX_BEAT_WAIT = 60; // logical frames before giving up on beat timing

void switchScene(int newState) {
  if (SMOKE_TEST_MODE) return; // runner manages scene state directly
  // Allow any scene in the switcher's active order (or direct calls from switcher itself)
  if (!sceneSwitcher.isInRotation(newState) && newState != config.STATE) {
    // Also allow direct jumps — just let it through if it's a valid scene index
    if (newState < 0 || newState >= SCENE_COUNT) return;
  }
  if (config.STATE == newState) return;
  // Queue for beat-timed execution
  pendingScene      = newState;
  pendingFrameCount = 0;
}

// Execute a queued scene switch — captures snapshot and updates state.
void commitPendingScene() {
  if (pendingScene < 0) return;
  // Snapshot the upscaled main canvas, not the raw sceneBuffer, so the
  // crossfade overlay matches window dimensions and doesn't leave an
  // undersized square pasted in the corner during transition.
  crossfadeSnapshot = get();
  crossfadeFrame    = 0;
  config.STATE      = pendingScene;
  pendingScene      = -1;
  pendingFrameCount = 0;
}

// Walks the active rotation forward from `from`, returning the first scene
// that isn't blacklisted by SceneGuard. Falls back to `from` when every scene
// in rotation is blacklisted (pathological — caller should render a card).
int nextNonBlacklistedScene(int from) {
  if (sceneSwitcher == null) return from;
  int n = sceneSwitcher.activeOrder.size();
  if (n == 0) return from;
  int cur = from;
  for (int i = 0; i < n; i++) {
    cur = sceneSwitcher.nextScene(cur);
    if (!sceneGuard.isBlacklisted(cur)) return cur;
  }
  return from;
}

// Direct switch called from SceneSwitcher — bypasses rotation guard
void switchSceneDirect(int newState) {
  if (SMOKE_TEST_MODE) return;
  if (newState < 0 || newState >= SCENE_COUNT) return;
  if (config.STATE == newState) return;
  crossfadeSnapshot = get();
  crossfadeFrame    = 0;
  scenes[config.STATE].onExit();
  config.STATE      = newState;
  scenes[config.STATE].onEnter();
}

long lastLogicalFrame = 0;
float accumulator = 0;

void draw() {
  if (frameBudget != null) frameBudget.frameStart();
  if (frameWatchdog != null) frameWatchdog.tick(config.STATE);
  // ── Smoke test fast-path ─────────────────────────────────────────────────
  if (SMOKE_TEST_MODE) {
    // Keep audio ticking so FFT data is valid (scenes read it in drawScene)
    audio.forward();
    audio.beat.detect(audio.player.mix);
    analyzer.update(audio);
    spatial.update(audio);
    smokeTestRunner.tick(sceneBuffer);
    blendMode(REPLACE);
    imageMode(CORNER);
  image(sceneBuffer, 0, 0, width, height);
    return;
  }
  // ────────────────────────────────────────────────────────────────────────
  // Per-second SCENE/CONTROLLER/FPS heartbeat removed — same info is in the HUD
  // and on /operator. Set .devverbose in the sketch dir to re-enable.
  if (config.VERBOSE_LOG && frameCount % 60 == 0) {
    println("SCENE: " + config.STATE + " | CONTROLLER: " + config.USING_CONTROLLER + " | FPS: " + int(frameRate));
  }
  saveDevPreview();
  if (webQueueManager != null) webQueueManager.tick();

  if (setlist != null) setlist.tick();
  if (midiBridge != null) midiBridge.drainPending();

  // ── Frame-stall recovery ─────────────────────────────────────────────────
  // Watchdog flagged a >2s render gap. Charge the failure to the scene that
  // was on screen when the stall began; SceneGuard will blacklist it after
  // repeated offenses. Force-switch to a non-blacklisted scene now.
  if (frameWatchdog != null && frameWatchdog.consumeStall()) {
    int suspect = frameWatchdog.stallSceneId;
    if (suspect >= 0 && suspect < SCENE_COUNT) {
      sceneGuard.recordFailure(suspect,
        new RuntimeException("frame stall " + frameWatchdog.stallDurationMs + "ms"));
      int safe = nextNonBlacklistedScene(suspect);
      if (safe != suspect) switchSceneDirect(safe);
    }
  }
  
  // 1. Scene Lifecycle Management
  if (config.STATE != previousState) {
    if (previousState >= 0 && previousState < SCENE_COUNT) {
      scenes[previousState].onExit();
    }
    previousState = config.STATE;
    if (config.STATE >= 0 && config.STATE < SCENE_COUNT) {
      scenes[config.STATE].onEnter();
    }
    // ── Clean render state on every scene switch ─────────────────────────
    sceneBuffer.beginDraw();
    sceneBuffer.blendMode(BLEND);
    sceneBuffer.background(0);
    sceneBuffer.endDraw();
    config.BACKGROUND_ENABLED = true;
    config.CURRENT_BLEND_MODE_INDEX = 0;
    blendMode(BLEND);
  }

  // Calculate Delta Time for Fixed Update Loop
  long now = millis();
  if (lastLogicalFrame == 0) lastLogicalFrame = now;
  float dtMs = now - lastLogicalFrame;
  lastLogicalFrame = now;
  if (dtMs > 100) dtMs = 16.666667; 
  accumulator += dtMs;
  
  boolean didRenderScene = false;

  // Fixed 60Hz Timestep for all Physics and Logic
  while (accumulator >= 16.666667) {
    accumulator -= 16.666667;
    config.logicalFrameCount++;

    // 2. Continuous Logic Updates
    if (frameCount % 480 == 0) logToStdout("Draw state=" + config.STATE);

    // Service any cross-thread song-load requests (file picker on AWT-EDT)
    // here on the draw thread so Minim teardown/setup doesn't race with
    // audio.forward() reading player.mix.
    drainPendingSongLoad();

    // Auto-advance to next track only in FILE mode. DEVICE input never "ends".
    // Uses isPlaybackComplete() not isPlaying() because Minim's isPlaying()
    // doesn't reliably flip at EOF.
    if (!audio.isDeviceInput() && config.songList.size() > 0) {
      // Periodic diagnostic (~every 4s at 60fps logical) so we can see why
      // auto-advance might not fire.
      if (frameCount % 240 == 0) {
        int pos = (audio.player != null) ? audio.player.position() : -1;
        int len = (audio.player != null) ? audio.player.length()   : -1;
        boolean playing = (audio.player != null) && audio.player.isPlaying();
        logToStdout("[AutoAdvance] pos=" + pos + "/" + len + " playing=" + playing
                  + " songPlaying=" + config.SONG_PLAYING
                  + " complete=" + audio.isPlaybackComplete());
      }
      if (audio.isPlaybackComplete()) {
        logToStdout("[AutoAdvance] track ended -> shuffleSong()");
        shuffleSong();
      }
    }

    if (frameBudget != null) frameBudget.begin(FrameBudget.P_AUDIO);
    audio.forward();
    audio.detectBeat();
    analyzer.update(audio);
    spatial.update(audio);
    if (frameBudget != null) frameBudget.end();

    if (frameBudget != null) frameBudget.begin(FrameBudget.P_INPUT);
    getUserInput();
    if (autoSwitcher != null) autoSwitcher.tick();
    if (paramAutoPilot != null) paramAutoPilot.tick(controller);
    if (frameBudget != null) frameBudget.end();

    didRenderScene = true;
  } // End Fixed Timestep

  // 3. Render Active Scene to Buffer — once per display frame (after all logic ticks)
  if (didRenderScene && config.STATE >= 0 && config.STATE < SCENE_COUNT) {
    int targetW = sceneBufferRenderWidth();
    int targetH = sceneBufferRenderHeight();
    if (sceneBuffer.width != targetW || sceneBuffer.height != targetH) {
      sceneBuffer = createGraphics(targetW, targetH, P3D);
      sceneBuffer.smooth(config.LOW_POWER_MODE ? 2 : 4);
      sceneBuffer.beginDraw(); sceneBuffer.background(0); sceneBuffer.endDraw();
    }

    sceneBuffer.beginDraw();
    sceneBuffer.colorMode(PConstants.RGB, 255);
    sceneBuffer.rectMode(PConstants.CORNER);
    sceneBuffer.ellipseMode(PConstants.CENTER);
    sceneBuffer.imageMode(PConstants.CORNER);
    sceneBuffer.hint(PConstants.ENABLE_DEPTH_TEST);

    if (monoFont != null) sceneBuffer.textFont(monoFont);

    boolean sceneThrew = false;
    int     skipTarget = -1;
    try {
      sceneBuffer.pushStyle();
      sceneBuffer.pushMatrix();
      try {
        if (sceneGuard.isRecovering()) {
          sceneGuard.drawRecoveryCard(sceneBuffer);
          if (sceneGuard.tickRecovery()) {
            if (sceneGuard.isBlacklisted(config.STATE)) {
              skipTarget = nextNonBlacklistedScene(config.STATE);
            }
            sceneGuard.clearRecovery();
          }
        } else if (sceneGuard.isBlacklisted(config.STATE)) {
          sceneBuffer.background(0);
          skipTarget = nextNonBlacklistedScene(config.STATE);
        } else {
          if (frameBudget != null) frameBudget.begin(FrameBudget.P_SCENE);
          scenes[config.STATE].drawScene(sceneBuffer);
          if (frameBudget != null) frameBudget.end();
        }
      } finally {
        try { sceneBuffer.popMatrix(); } catch (Throwable ignored) {}
        try { sceneBuffer.popStyle();  } catch (Throwable ignored) {}
      }
    } catch (Throwable t) {
      sceneThrew = true;
      sceneGuard.recordFailure(config.STATE, t);
    }
    try { sceneBuffer.endDraw(); } catch (Throwable ignored) {}

    if (sceneThrew) {
      // P3D renderer state may be corrupt mid-draw — recreate buffer fresh.
      sceneBuffer = createGraphics(sceneBufferRenderWidth(), sceneBufferRenderHeight(), P3D);
      sceneBuffer.smooth(config.LOW_POWER_MODE ? 2 : 4);
      sceneBuffer.beginDraw(); sceneBuffer.background(0); sceneBuffer.endDraw();
    }
    if (skipTarget >= 0 && skipTarget != config.STATE) {
      switchSceneDirect(skipTarget);
    }
  }

  // ── Beat-timed pending scene commit ─────────────────────────────────────
  // Fires once per rendered frame so pendingFrameCount tracks logical frames.
  if (pendingScene >= 0 && didRenderScene) {
    pendingFrameCount++;
    if (analyzer.isBeat || pendingFrameCount >= MAX_BEAT_WAIT) {
      commitPendingScene();
    }
  }

  // 4. Post-Processing & Final Output (Runs Unlocked at >144FPS)
  blendMode(REPLACE); // Massive Performance improvement for laptops
  imageMode(CORNER);
  // Run enabled PostFX (CPU in-place, then GLSL ping-pong). Returns the
  // final buffer to blit — may be sceneBuffer itself or a temp FX buffer.
  if (frameBudget != null) frameBudget.begin(FrameBudget.P_POSTFX);
  PGraphics toDisplay = postFX.process(sceneBuffer);
  if (frameBudget != null) frameBudget.end();
  if (frameBudget != null) frameBudget.begin(FrameBudget.P_COMPOSE);
  image(toDisplay, 0, 0, width, height);

  // Strobe safety cap — measures luma jumps + flash rate on the final
  // composite, blends prior frame back over to flatten unsafe spikes.
  if (strobeSafety != null) {
    strobeSafety.maybeDampen(toDisplay, width, height);
    strobeSafety.snapshot(toDisplay);
  }

  // mp4 capture — pipes the post-FX composite to ffmpeg via worker thread.
  // Excludes HUDs and text overlay (they sit on top of the window blit).
  if (recorder != null) recorder.tick(toDisplay);
  if (streamer != null) streamer.tick(toDisplay);

  // Headache-free wash: dim brightness + soft warm tint to round off harshness.
  // Applied in window space so it covers anything in the scene chain. HUD/overlays
  // draw on top unaffected so controls stay readable.
  if (config.HEADACHE_FREE_MODE) {
    blendMode(BLEND);
    noStroke();
    fill(20, 14, 30, 110);
    rect(0, 0, width, height);
    fill(255, 200, 160, 18);
    rect(0, 0, width, height);
  }
  if (frameBudget != null) frameBudget.end(); // close P_COMPOSE

  // 5. Global overlays (UI drawn at native res, over the buffer)
  blendMode(BLEND);
  if (frameBudget != null) frameBudget.begin(FrameBudget.P_HUD);

  // Live text overlay (DJ name / track title). Drawn before HUD so HUD reads
  // on top, hidden in demo capture and when no text file is present.
  if (textOverlay != null) textOverlay.draw(width, height, monoFont);

  // Demo capture mode hides every HUD/badge so the recorded gif is pure scene.
  boolean hideHuds = (demoInput != null && demoInput.isActive());

  // HUD Badges (Bottom-Right Stack)
  if (!hideHuds) {
    float nextHudY = height - 10 * uiScale();
    nextHudY = drawAudioSourceBadge(nextHudY);
    if (autoSwitcher != null) nextHudY = drawAutoSwitcherBadge(nextHudY);
    if (paramAutoPilot != null) nextHudY = drawAutoPilotBadge(nextHudY);
    if (postFX != null && postFX.anyEnabled()) nextHudY = drawPostFXBadge(nextHudY);
    if (strobeSafety != null && strobeSafety.enabled) nextHudY = drawStrobeSafetyBadge(nextHudY);
    if (tempoLock != null && (tempoLock.isLocked() || tempoLock.taps.size() > 0)) nextHudY = drawTempoLockBadge(nextHudY);
    if (setlist != null && setlist.isActive()) nextHudY = drawSetlistBadge(nextHudY);
    if (recorder != null && recorder.running)  nextHudY = drawRecorderBadge(nextHudY);
    if (streamer != null && streamer.running)  nextHudY = drawStreamerBadge(nextHudY);
    if (midiBridge != null && midiBridge.enabled) nextHudY = drawMidiBadge(nextHudY);
    if (sceneGuard != null) {
      ArrayList<String> bl = sceneGuard.blacklistedNames();
      if (!bl.isEmpty()) nextHudY = drawBlacklistBadge(nextHudY, bl);
    }

    drawWebControlBadge(); // Bottom-Left (doesn't stack)
  }

  if (!hideHuds && config.STATE >= 0 && config.STATE < SCENE_COUNT
      && !sceneGuard.isBlacklisted(config.STATE) && !sceneGuard.isRecovering()) {
    if (config.SHOW_CODE) {
      try { drawCodeOverlay(scenes[config.STATE].getCodeLines()); }
      catch (Throwable ignored) {}
    }
    if (config.SHOW_CONTROLLER_GUIDE) {
      try {
        ControllerLayout[] layout = scenes[config.STATE].getControllerLayout();
        if (layout != null) drawControllerGuide(layout);
      } catch (Throwable ignored) {}
    }
  }

  addFPSToTitleBar();

  // ── Crossfade overlay ───────────────────────────────────────────────────────
  if (crossfadeSnapshot != null) {
    if (didRenderScene) {
      crossfadeFrame++;
      if (!config.HEADACHE_FREE_MODE && audio.beat.isOnset() && crossfadeFrame > CROSSFADE_DURATION / 2) {
        crossfadeFrame = CROSSFADE_DURATION;
      }
    }

    if (crossfadeFrame >= CROSSFADE_DURATION) {
      crossfadeSnapshot = null;
    } else {
      float alpha = map(crossfadeFrame, 0, CROSSFADE_DURATION, 255, 0);
      blendMode(BLEND); 
      tint(255, alpha);
      // Draw at window size; snapshot may be from a resized buffer, so explicit
      // w/h prevents native-size pasting when dims don't match.
      image(crossfadeSnapshot, 0, 0, width, height);
      noTint();
    }
  }

  if (config.SHOW_METADATA && !hideHuds) {
    drawMetadataOverlay();
  }

  if (audioSwitcher != null && audioSwitcher.isOpen) {
    audioSwitcher.update();
    audioSwitcher.drawOverlay();
  }

  // Scene switcher overlay — drawn last so it always floats on top
  if (sceneSwitcher.isOpen) {
    sceneSwitcher.update();
    sceneSwitcher.drawOverlay();
  }

  // Stage hotkey help (?) — sits above HUDs but below kill switch fade.
  if (helpOverlay != null) helpOverlay.draw(width, height, monoFont);

  if (frameBudget != null) frameBudget.end(); // close P_HUD

  // KillSwitch composites a black quad over EVERYTHING — must be the very last draw.
  killSwitch.tick();
  killSwitch.draw();

  if (frameBudget != null) {
    frameBudget.frameEnd();
    frameBudget.draw();
  }
}

// ── Unified terminal-style HUD panel ──────────────────────────────────────────
// All on-screen HUDs route through this so they share the SYSTEM METADATA look:
// black 200-alpha bg, 2px bright-green border, 8px corners, bright-green mono text,
// auto-sized box. Pass anchor = "TL" | "TR" | "BL" | "BR" or specific x/y via
// drawTerminalPanelAt().
//
// All HUDs share the same width band so a Mandala HUD and an Audio HUD don't
// look like different products. HUD_MIN_W / HUD_MAX_W are *interior* widths
// (text region inside the padding). Lines longer than HUD_MAX_W are wrapped
// on spaces, or hard-broken if a single token is too long.
final float HUD_MIN_W = 360;
final float HUD_MAX_W = 460;

float[] hudWidthBounds() { return new float[] { HUD_MIN_W * uiScale(), HUD_MAX_W * uiScale() }; }

String[] wrapHUDLines(String[] lines, float maxTextW) {
  ArrayList<String> out = new ArrayList<String>();
  for (String raw : lines) {
    if (raw == null) { out.add(""); continue; }
    if (textWidth(raw) <= maxTextW) { out.add(raw); continue; }
    // Split on spaces, greedily pack onto current line.
    String[] words = raw.split(" ");
    String cur = "";
    for (String w : words) {
      String candidate = cur.length() == 0 ? w : (cur + " " + w);
      if (textWidth(candidate) <= maxTextW) {
        cur = candidate;
      } else if (cur.length() == 0) {
        // Single token wider than maxTextW — hard-break by characters.
        String chunk = "";
        for (int i = 0; i < w.length(); i++) {
          String next = chunk + w.charAt(i);
          if (textWidth(next) > maxTextW && chunk.length() > 0) {
            out.add(chunk);
            chunk = "" + w.charAt(i);
          } else chunk = next;
        }
        cur = chunk;
      } else {
        out.add(cur);
        cur = w;
      }
    }
    if (cur.length() > 0) out.add(cur);
  }
  return out.toArray(new String[0]);
}

void drawTerminalPanel(String[] rawLines, String anchor) {
  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  textAlign(LEFT, BASELINE);

  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float[] b   = hudWidthBounds();
  float minTextW = b[0], maxTextW = b[1];

  String[] lines = wrapHUDLines(rawLines, maxTextW);
  float maxW = 0;
  for (String l : lines) { float w = textWidth(l); if (w > maxW) maxW = w; }
  float textW = constrain(maxW, minTextW, maxTextW);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + lines.length * lineH;
  float margin = 12 * uiScale();
  float boxX, boxY;
  if (anchor.equals("TR"))      { boxX = width - boxW - margin; boxY = margin; }
  else if (anchor.equals("BL")) { boxX = margin;                 boxY = height - boxH - margin; }
  else if (anchor.equals("BR")) { boxX = width - boxW - margin; boxY = height - boxH - margin; }
  else                          { boxX = margin;                 boxY = margin; }
  drawTerminalPanelAt(lines, boxX, boxY, boxW, boxH, pad, lineH);
  popStyle();
}

void drawTerminalPanelAt(String[] lines, float boxX, float boxY,
                         float boxW, float boxH, float pad, float lineH) {
  fill(0, 200);
  stroke(0, 255, 0);
  strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 8);

  fill(0, 255, 0);
  noStroke();
  float ty = boxY + pad + lineH * 0.8;
  for (int i = 0; i < lines.length; i++) {
    text(lines[i], boxX + pad, ty);
    ty += lineH;
  }
}

void drawMetadataOverlay() {
  String[] lines = {
    "=== SYSTEM METADATA ===",
    "FPS (Render)    : " + int(frameRate),
    "Scene Index     : " + config.STATE,
    "Scene Name      : " + scenes[config.STATE].getClass().getSimpleName(),
    "Logical Frames  : " + config.logicalFrameCount,
    "",
    "=== AUDIO METADATA ===",
    "Song Name       : " + (config.SONG_NAME.length() > 20 ? config.SONG_NAME.substring(0, 20) + "\u2026" : config.SONG_NAME),
    "Playing         : " + config.SONG_PLAYING,
    "Controller Match: " + config.USING_CONTROLLER
  };

  drawTerminalPanel(lines, "TR");
}

// ── Standard top-left matrix-green HUD used by all scenes ──────────────────
// title : scene name (first row, bright green)
// lines : info/control rows (dim green)
void sceneHUD(PGraphics pg, String title, String[] lines) {
  if (isProjecting) return;
  if (demoInput != null && demoInput.isActive()) return;
  // Unified terminal style — matches SYSTEM METADATA / WEB CONTROL / AUDIO HUDs.
  // Title is "=== TITLE ===" centered as the first row of the lines block.
  String[] composed = new String[lines.length + 1];
  composed[0] = "=== " + title.toUpperCase() + " ===";
  for (int i = 0; i < lines.length; i++) composed[i + 1] = lines[i];

  pg.pushStyle();
  pg.textFont(monoFont);
  pg.textAlign(LEFT, BASELINE);

  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float minTextW = HUD_MIN_W * uiScale(), maxTextW = HUD_MAX_W * uiScale();
  // PGraphics textWidth uses pg's font metrics; wrapHUDLines uses the global
  // canvas font. They're the same monoFont so widths match — wrap then size.
  String[] wrapped = wrapHUDLines(composed, maxTextW);
  float maxW = 0;
  for (String l : wrapped) { float w = pg.textWidth(l); if (w > maxW) maxW = w; }
  float textW = constrain(maxW, minTextW, maxTextW);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + wrapped.length * lineH;
  float boxX = 12 * uiScale();
  float boxY = 12 * uiScale();

  pg.rectMode(CORNER);
  pg.fill(0, 200);
  pg.stroke(0, 255, 0);
  pg.strokeWeight(2);
  pg.rect(boxX, boxY, boxW, boxH, 8);

  pg.fill(0, 255, 0);
  pg.noStroke();
  float ty = boxY + pad + lineH * 0.8;
  for (int i = 0; i < wrapped.length; i++) {
    pg.text(wrapped[i], boxX + pad, ty);
    ty += lineH;
  }
  pg.popStyle();
}

// Generic right-side terminal HUD — used by worm scenes (and any future scene).
void drawSceneControlsHUD(String[] rawLines) {
  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  textAlign(LEFT, BASELINE);

  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float[] b = hudWidthBounds();
  String[] lines = wrapHUDLines(rawLines, b[1]);
  float maxW = 0;
  for (String l : lines) { float w = textWidth(l); if (w > maxW) maxW = w; }
  float textW = constrain(maxW, b[0], b[1]);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + lines.length * lineH;
  float boxX = width - boxW - 12 * uiScale();
  float boxY = (height - boxH) / 2.0;
  drawTerminalPanelAt(lines, boxX, boxY, boxW, boxH, pad, lineH);
  popStyle();
}

// Draws a terminal-style code overlay showing the formulas a scene uses.
// Each scene passes in plain-English lines explaining its maths.
// Controls HUD for scene 1 — shown on the right side when ` is pressed.
// Toggle with the backtick key (`).
void drawCodeOverlay(String[] lines) {
  // Unified terminal style — left-anchored, vertically centered.
  blendMode(BLEND);
  pushStyle();
  textFont(monoFont);
  textAlign(LEFT, BASELINE);
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float[] b = hudWidthBounds();
  String[] wrapped = wrapHUDLines(lines, b[1]);
  float maxW = 0;
  for (String l : wrapped) { float w = textWidth(l); if (w > maxW) maxW = w; }
  float textW = constrain(maxW, b[0], b[1]);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + wrapped.length * lineH;
  float boxX = 12 * uiScale();
  float boxY = (height - boxH) / 2.0;
  drawTerminalPanelAt(wrapped, boxX, boxY, boxW, boxH, pad, lineH);
  popStyle();
}

// Bottom-left HUD: shows LAN URLs and the venue PIN so the operator can read
// them out / let people scan instead of ssh'ing to check the terminal.
void drawWebControlBadge() {
  if (featureFlagServer == null) return;
  boolean haveUrls = featureFlagServer.lanUrls != null && featureFlagServer.lanUrls.size() > 0;
  boolean haveErr  = featureFlagServer.startError != null && featureFlagServer.startError.length() > 0;
  if (!haveUrls && !haveErr) return;
  // Unified terminal style — bottom-left anchored.
  pushStyle();
  textFont(monoFont);
  textAlign(LEFT, BASELINE);
  int urlCount = haveUrls ? featureFlagServer.lanUrls.size() : 0;
  String pinLine = pinManager == null ? "" : ("PIN  " + pinManager.masterPin);
  String errLine = haveErr ? ("SERVER FAIL: " + featureFlagServer.startError) : "";

  ArrayList<String> lineList = new ArrayList<String>();
  lineList.add("=== WEB CONTROL ===");
  for (int i = 0; i < urlCount; i++) lineList.add(featureFlagServer.lanUrls.get(i));
  if (pinLine.length() > 0) lineList.add(pinLine);
  if (haveErr) lineList.add(errLine);
  float lineH = 18 * uiScale();
  float pad   = 14 * uiScale();
  float[] b = hudWidthBounds();
  String[] lines = wrapHUDLines(lineList.toArray(new String[0]), b[1]);
  float maxW  = 0;
  for (String l : lines) { float w = textWidth(l); if (w > maxW) maxW = w; }
  // Reserve room for the LOCKDOWN pill next to the title if active.
  boolean lockdown = (clientRegistry != null && clientRegistry.lockdownMode);
  float pillW = lockdown ? textWidth("LOCKDOWN") + 10 + 8 : 0;
  float contentW = max(maxW, textWidth(lines[0]) + pillW);
  float textW = constrain(contentW, b[0], b[1]);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + lines.length * lineH;
  float margin = 12 * uiScale();
  float boxX = margin;
  float boxY = height - boxH - margin;

  // Body — bright-green border + bright-green text on black, like SYSTEM METADATA.
  fill(0, 200);
  stroke(0, 255, 0);
  strokeWeight(2);
  rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 8);

  noStroke();
  float ty = boxY + pad + lineH * 0.8;
  for (int i = 0; i < lines.length; i++) {
    if (i > 0 && errLine.length() > 0 && lines[i].equals(errLine)) fill(255, 80, 80);
    else fill(0, 255, 0);
    text(lines[i], boxX + pad, ty);
    ty += lineH;
  }

  // LOCKDOWN pill on the title row.
  if (lockdown) {
    String pill = "LOCKDOWN";
    float pillX = boxX + pad + textWidth(lines[0]) + 8;
    float pillY = boxY + pad - lineH * 0.2;
    float pillH = lineH * 0.95;
    fill(180, 30, 30);
    noStroke();
    rect(pillX, pillY, textWidth(pill) + 10, pillH, 3);
    fill(255);
    text(pill, pillX + 5, pillY + pillH * 0.78);
  }
  popStyle();
}

// Top-right HUD: current audio mode + source. RMS bar shows live signal so
// silence (black-screen scenes) can't be confused with a broken mic.
float drawAudioSourceBadge(float startY) {
  if (audio == null) return startY;
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String mode = audio.isDeviceInput() ? "DEVICE" : "FILE";
  String src;
  if (audio.isDeviceInput()) {
    src = config.audioDeviceSelector != null ? config.audioDeviceSelector.getSelectedDeviceName() : "default";
  } else {
    src = config.SONG_NAME != null ? config.SONG_NAME : "—";
  }
  String l1 = "AUDIO  " + mode;
  if (audio.isDeviceInput()) {
    l1 += "  ×" + nf(audio.deviceInputGain, 0, 1) + (audio.manualGainLock ? " (manual)" : " (auto)");
  }
  String l2 = src;
  String l3 = audio.isDeviceInput() ? "'  source    +/-  gain" : "'  open source picker";

  float pad   = 14 * uiScale();
  float lineH = 18 * uiScale();
  float[] b = hudWidthBounds();
  String title = audio.isDeviceInput() ? "=== AUDIO DEVICE ===" : "=== AUDIO FILE ===";
  String[] raw = { title, l1, l2, l3 };
  String[] lines = wrapHUDLines(raw, b[1]);
  float maxW = 0;
  for (String l : lines) { float w = textWidth(l); if (w > maxW) maxW = w; }
  float textW = constrain(maxW, b[0], b[1]);
  float boxW = textW + pad * 2;
  float boxH = pad * 2 + lines.length * lineH + 12; // +12 for RMS bar
  float boxX = width - boxW - 12 * uiScale();
  float boxY = startY - boxH;

  // Unified terminal style — bright green border + text, black bg.
  fill(0, 200);
  stroke(0, 255, 0);
  strokeWeight(2);
  rectMode(CORNER);
  rect(boxX, boxY, boxW, boxH, 8);

  fill(0, 255, 0);
  noStroke();
  textAlign(LEFT, BASELINE);
  float ty = boxY + pad + lineH * 0.8;
  for (int i = 0; i < lines.length; i++) {
    text(lines[i], boxX + pad, ty);
    ty += lineH;
  }

  // Live RMS bar — pulled from FFT band energies (no extra audio touch needed).
  float rms = 0;
  if (audio.fft != null) {
    int n = audio.fft.avgSize();
    for (int i = 0; i < n; i++) rms += audio.fft.getAvg(i);
    rms = n > 0 ? rms / n : 0;
  }
  float barW = boxW - pad * 2;
  float barH = 4 * uiScale();
  float barX = boxX + pad;
  float barY = boxY + boxH - barH - pad * 0.4;
  fill(40);
  rect(barX, barY, barW, barH, 2);
  float fill01 = constrain(rms / 5.0, 0, 1);
  fill(fill01 > 0.02 ? color(0, 255, 0) : color(120, 90, 90));
  rect(barX, barY, barW * fill01, barH, 2);

  popStyle();
  return boxY - 10 * uiScale(); // Return Y position for next badge above
}

float drawAutoSwitcherBadge(float startY) {
  String line = autoSwitcher.hudLine();
  if (line == null) return startY;
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);
  // Fixed width sized for longest possible line ("AUTO FAVS WEIGHTED cd 999s  ").
  float tw    = textWidth("AUTO FAVS WEIGHTED cd 999s  ");
  float boxH  = ts + 10;
  float boxW  = tw + 16;
  float pad   = 10 * uiScale();
  float boxX  = width - pad - boxW;
  float boxY  = startY - boxH;
  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);
  fill(0, 255, 120);
  text(line, boxX + 8, boxY + 5);
  popStyle();
  return boxY - 6 * uiScale();
}

// Knob autopilot badge — visible only while drift is actually moving knobs,
// so the operator can tell at a glance why params are changing on their own.
float drawAutoPilotBadge(float startY) {
  String line = paramAutoPilot.hudLine();
  if (line == null) return startY;
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);
  float tw    = textWidth("PILOT drifting 100%  ");
  float boxH  = ts + 10;
  float boxW  = tw + 16;
  float pad   = 10 * uiScale();
  float boxX  = width - pad - boxW;
  float boxY  = startY - boxH;
  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);
  fill(120, 200, 255);
  text(line, boxX + 8, boxY + 5);
  popStyle();
  return boxY - 6 * uiScale();
}

// ── PostFX HUD badge ─────────────────────────────────────────────────────────
// Bottom-right, stacked ABOVE the AutoSwitcher badge.
// Shows active FX names; hidden when no effects are enabled.
// Keyboard: g=cycle next, G=clear all. Controller: LB+RB+Y=cycle, LB+RB+X=clear.
float drawBlacklistBadge(float startY, ArrayList<String> names) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[GUARD] " + names.size() + " scene(s) disabled this session";
  String joined = "";
  for (int i = 0; i < names.size(); i++) {
    if (i > 0) joined += ", ";
    joined += names.get(i);
  }
  String line2 = joined;

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(255, 120, 100);
  text(line1, boxX + pad, boxY + pad);
  fill(255, 200, 200);
  text(line2, boxX + pad, boxY + pad + lineH);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawMidiBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[MIDI] F4=toggle";
  String line2 = midiBridge.openDevices.size() + " device(s) — pad note 36+ -> scene order";

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(160, 220, 255);
  text(line1, boxX + pad, boxY + pad);
  fill(200, 240, 255);
  text(line2, boxX + pad, boxY + pad + lineH);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawStreamerBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts  = 13 * uiScale();
  float tsBig = 18 * uiScale();
  textAlign(LEFT, TOP);

  String streamUrl = "http://?:8080/stream.html";
  if (featureFlagServer != null && featureFlagServer.lanUrls != null && featureFlagServer.lanUrls.size() > 0) {
    String base = featureFlagServer.lanUrls.get(0);
    if (base.endsWith("/")) streamUrl = base + "stream.html";
    else                    streamUrl = base + "/stream.html";
  }

  String line1 = "[STREAM]  F6=stop  +Shift=" + (streamer.profile == Streamer.PROFILE_VENUE ? "normal" : "venue");
  String line2 = streamer.statusLabel();
  String line3 = "TV / phone:";
  String line4 = streamUrl;

  float pad      = 10 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float bigH     = tsBig + 4;
  textSize(ts);
  float w1 = textWidth(line1), w2 = textWidth(line2), w3 = textWidth(line3);
  textSize(tsBig);
  float w4 = textWidth(line4);
  float boxW = max(max(w1, w2), max(w3, w4)) + pad * 2;
  float boxH = lineH * 3 + bigH + pad + 8;
  float boxX = width  - outerPad - boxW;
  float boxY = startY - boxH;

  noStroke();
  fill(0, 200);
  rect(boxX, boxY, boxW, boxH, 6);
  stroke(80, 220, 120);
  strokeWeight(1.5);
  noFill();
  rect(boxX, boxY, boxW, boxH, 6);

  // Pulsing green dot to signal "live"
  noStroke();
  float pulse = 0.6 + 0.4 * sin(millis() * 0.005);
  fill(50, 255 * pulse, 120);
  ellipse(boxX + pad + 5, boxY + pad + ts * 0.5, 8, 8);

  textSize(ts);
  fill(180, 255, 200);
  text(line1, boxX + pad + 16, boxY + pad);
  fill(220, 255, 230);
  text(line2, boxX + pad, boxY + pad + lineH);
  fill(140, 220, 160);
  text(line3, boxX + pad, boxY + pad + lineH * 2 + 4);
  textSize(tsBig);
  fill(120, 255, 180);
  text(line4, boxX + pad, boxY + pad + lineH * 3 + 4);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawRecorderBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[REC]  F5=stop";
  String line2 = recorder.statusLabel();

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  // Pulsing red dot
  float pulse = 0.6 + 0.4 * sin(millis() * 0.005);
  fill(255 * pulse, 50, 50);
  ellipse(boxX + pad + 5, boxY + pad + ts * 0.5, 8, 8);

  fill(255, 200, 200);
  text(line1, boxX + pad + 16, boxY + pad);
  fill(255, 240, 240);
  text(line2, boxX + pad, boxY + pad + lineH);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawSetlistBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[SETLIST " + (setlist.cursor + 1) + "/" + setlist.size()
               + (setlist.autoAdvance ? " AUTO" : "") + "]  ]=next [=back }=auto {=reload";
  String line2 = "now: "  + setlist.nowLabel();
  String line3 = "next: " + setlist.nextLabel();

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(max(textWidth(line1), textWidth(line2)), textWidth(line3)) + pad * 2;
  float boxH     = lineH * 3 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(255, 200, 120);
  text(line1, boxX + pad, boxY + pad);
  fill(220, 240, 200);
  text(line2, boxX + pad, boxY + pad + lineH);
  fill(160, 200, 160);
  text(line3, boxX + pad, boxY + pad + lineH * 2);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawTempoLockBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[TEMPO]  \\=tap  |=clear";
  String line2 = tempoLock.statusLabel();

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(140, 220, 255);
  text(line1, boxX + pad, boxY + pad);
  if (tempoLock.isLocked()) fill(120, 255, 160); else fill(255, 220, 120);
  text(line2, boxX + pad, boxY + pad + lineH);

  // Metronome pulse — visible verification that locked BPM matches the track.
  if (tempoLock.isLocked() && tempoLock.beatPeriodMs > 0) {
    long elapsed = System.currentTimeMillis() - tempoLock.lockEpochMs;
    float phase  = (elapsed % tempoLock.beatPeriodMs) / (float) tempoLock.beatPeriodMs;
    float pulse  = 1.0 - constrain(phase * 4, 0, 1);
    float r      = 6 * uiScale() * (1 + pulse);
    fill(120, 255, 160, 200);
    noStroke();
    ellipse(boxX + boxW - pad - 8 * uiScale(), boxY + pad + ts * 0.5, r, r);
  }

  popStyle();
  return boxY - 6 * uiScale();
}

float drawStrobeSafetyBadge(float startY) {
  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[STROBE-SAFE]  F12=toggle";
  String line2 = strobeSafety.lastDampAlpha > 0.02
                 ? "dampening: " + nf(strobeSafety.lastDampAlpha, 1, 2)
                 : "ok";

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(255, 180, 80);
  text(line1, boxX + pad, boxY + pad);
  if (strobeSafety.lastDampAlpha > 0.02) fill(255, 100, 100); else fill(120, 220, 140);
  text(line2, boxX + pad, boxY + pad + lineH);

  popStyle();
  return boxY - 6 * uiScale();
}

float drawPostFXBadge(float startY) {
  String badge = postFX.getActiveBadge();
  if (badge.length() == 0) return startY;

  pushStyle();
  textFont(monoFont);
  float ts = 12 * uiScale();
  textSize(ts);
  textAlign(LEFT, TOP);

  String line1 = "[FX]  g=next  G=clear  |  LB+RB+Y=next  LB+RB+X=clear";
  String line2 = badge;

  float pad      = 8 * uiScale();
  float outerPad = 10 * uiScale();
  float lineH    = ts + 4;
  float boxW     = max(textWidth(line1), textWidth(line2)) + pad * 2;
  float boxH     = lineH * 2 + pad;

  float boxX  = width  - outerPad - boxW;
  float boxY  = startY - boxH;

  noStroke();
  fill(0, 180);
  rect(boxX, boxY, boxW, boxH, 4);

  fill(180, 130, 255);   // purple label row
  text(line1, boxX + pad, boxY + pad);
  fill(230, 200, 255);   // lighter purple — active effects
  text(line2, boxX + pad, boxY + pad + lineH);

  popStyle();
  return boxY - 6 * uiScale();
}

void addFPSToTitleBar() {
  if (frameCount % 100 == 0) {
    surface.setTitle("Music Visualizer CK | fps: " + int(frameRate) + " | scene: " + config.STATE
      + " | " + config.SONG_TO_VISUALIZE);
  }
}

float pulseValBetweenRange(float currentVal, float minVal, float maxVal) {
  currentVal += config.PULSE_VALUE;
  if (currentVal > maxVal) {
    config.PULSE_VALUE = -40;
  } else if (currentVal <= minVal) {
    config.PULSE_VALUE = 40;
  }
  return currentVal;
}

void drawSongNameOnScreen(PGraphics pg, String song_name, float nameLocationX, float nameLocationY) {
  if (isProjecting) return;
  if (demoInput != null && demoInput.isActive()) return;
  pg.pushStyle();
  pg.textSize(24 * uiScale());
  pg.textAlign(CENTER);
  pg.fill(0);
  
  pg.text(song_name, nameLocationX + 2, nameLocationY + 2);
  
  pg.fill(255);
  pg.text(song_name, nameLocationX, nameLocationY);

  // Small path line below song name for easy debugging
  pg.textSize(11 * uiScale());
  pg.fill(0);
  pg.text(config.SONG_TO_VISUALIZE, nameLocationX + 1, nameLocationY + 18 * uiScale() + 1);
  pg.fill(180, 180, 180, 180);
  pg.text(config.SONG_TO_VISUALIZE, nameLocationX, nameLocationY + 18 * uiScale());
}

void mouseClicked() {
  config.ANIMATED = !config.ANIMATED;
}

void changeBlendMode() {
  if (config.CURRENT_BLEND_MODE_INDEX == modes.length - 1) {
    config.CURRENT_BLEND_MODE_INDEX = 0;
  } else {
    config.CURRENT_BLEND_MODE_INDEX += 1;
  }
  blendMode(config.CURRENT_BLEND_MODE_INDEX);
}

void changeFinRotation() {
  config.finRotationClockWise = !config.finRotationClockWise;
  config.canChangeFinDirection = false;
}


