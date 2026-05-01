// AudioSourceSwitcher — matrix terminal overlay for picking the audio source.
//
// Toggle with F11. Lists:
//   • [FILE]   Random song / Browse / current song
//   • [DEVICE] each Java AudioSystem input mixer (ALSA/CoreAudio/WASAPI)
//   • [DEVICE] each PulseAudio/PipeWire source on Linux (monitors included)
//
// Picking a Pulse source on Linux: we shell to `pactl set-default-source`
// before opening Java's `default` mixer. Prior source is saved and restored
// on mode change / shutdown so the user's mic isn't permanently rebound.
//
// Same matrix-green theme as SceneSwitcher (Tab).

class AudioSourceSwitcher {

  static final int KIND_FILE_RANDOM = 0;
  static final int KIND_FILE_BROWSE = 1;
  static final int KIND_DEVICE_JAVA = 2;  // payload = Java mixer index
  static final int KIND_DEVICE_PULSE = 3; // payload = Pulse source name

  class Entry {
    int kind;
    String label;
    String detail;       // sub-line / hint
    int javaIdx = -1;
    String pulseName;
    boolean isMonitor;
    boolean isRecommended;
  }

  ArrayList<Entry> entries = new ArrayList<Entry>();
  boolean isOpen = false;
  int cursor = 0;

  // Repeat throttle (mirrors SceneSwitcher)
  long lastRepeatTime = 0;
  int repeatDelay = 300, repeatInterval = 60;
  boolean isRepeating = false;

  // Palette (same as SceneSwitcher)
  int BG_COLOR, BORDER_COLOR, ROW_LIVE, ROW_CURSOR;
  int TEXT_HEADER, TEXT_DIM, TEXT_HINT, TEXT_WARN;

  // Pulse default-source backup so we can restore on exit/mode switch.
  String savedPulseDefault = null;

  AudioSourceSwitcher() {
    BG_COLOR     = color(0, 210);
    BORDER_COLOR = color(0, 255, 0);
    ROW_LIVE     = color(0, 255, 0, 60);
    ROW_CURSOR   = color(0, 255, 0, 100);
    TEXT_HEADER  = color(0, 255, 0);
    TEXT_DIM     = color(150, 255, 150);
    TEXT_HINT    = color(100, 200, 100);
    TEXT_WARN    = color(255, 200, 80);

    // Restore default source if the JVM dies mid-session.
    Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
      public void run() { restorePulseDefault(); }
    }));
  }

  void toggle() {
    isOpen = !isOpen;
    if (isOpen) {
      rebuildEntries();
      snapCursorToCurrent();
      resetRepeat();
    }
  }

  void rebuildEntries() {
    entries.clear();

    // ── 1. Recommended: monitor of current default sink (Linux only) ────────
    String recommendedMonitor = null;
    if (isLinux()) {
      String defaultSink = runShell("pactl get-default-sink");
      if (defaultSink != null) recommendedMonitor = defaultSink.trim() + ".monitor";
    }

    ArrayList<String[]> pulse = isLinux() ? listPulseSources() : new ArrayList<String[]>();

    // Recommended row first.
    if (recommendedMonitor != null) {
      for (String[] row : pulse) {
        if (row[0].equals(recommendedMonitor)) {
          Entry e = new Entry();
          e.kind = KIND_DEVICE_PULSE;
          e.pulseName = row[0];
          e.isMonitor = true;
          e.isRecommended = true;
          e.label = "★ " + row[0];
          e.detail = "RECOMMENDED  ·  hears whatever your speakers play";
          entries.add(e);
          break;
        }
      }
    }

    // ── 2. FILE options ─────────────────────────────────────────────────────
    Entry random = new Entry();
    random.kind = KIND_FILE_RANDOM;
    random.label = "Random song from ~/Music";
    random.detail = "FILE  ·  picks a random track";
    entries.add(random);

    Entry browse = new Entry();
    browse.kind = KIND_FILE_BROWSE;
    browse.label = "Browse for a song...";
    browse.detail = "FILE  ·  opens file picker";
    entries.add(browse);

    // ── 3. Other Pulse monitors (other sinks/loopback) ──────────────────────
    for (String[] row : pulse) {
      if (row[0].endsWith(".monitor") && !row[0].equals(recommendedMonitor)) {
        Entry e = new Entry();
        e.kind = KIND_DEVICE_PULSE;
        e.pulseName = row[0];
        e.isMonitor = true;
        e.label = "[MONITOR] " + row[0];
        e.detail = "DEVICE  ·  Pulse output capture";
        entries.add(e);
      }
    }

    // ── 4. Real microphone inputs ───────────────────────────────────────────
    for (String[] row : pulse) {
      if (!row[0].endsWith(".monitor")) {
        Entry e = new Entry();
        e.kind = KIND_DEVICE_PULSE;
        e.pulseName = row[0];
        e.isMonitor = false;
        e.label = "[INPUT]   " + row[0];
        e.detail = "DEVICE  ·  Pulse mic / line-in";
        entries.add(e);
      }
    }

    // ── 5. Raw Java mixers (advanced, often duplicates) ─────────────────────
    if (config.audioDeviceSelector != null) {
      for (int i = 0; i < config.audioDeviceSelector.getDeviceCount(); i++) {
        Entry e = new Entry();
        e.kind = KIND_DEVICE_JAVA;
        e.javaIdx = i;
        e.label = config.audioDeviceSelector.deviceNames.get(i);
        e.detail = "ADVANCED  ·  raw Java mixer";
        entries.add(e);
      }
    }
  }

  void snapCursorToCurrent() {
    cursor = 0;
    // First-time / not-yet-on-device: land on the recommended row if it
    // exists, otherwise the first FILE row. So Enter is the right default.
    if (audio == null || !audio.isDeviceInput()) {
      for (int i = 0; i < entries.size(); i++) {
        if (entries.get(i).isRecommended) { cursor = i; return; }
      }
      return;
    }
    // Already in DEVICE mode — try to find the active row.
    String active = pactlGetDefaultSource();
    for (int i = 0; i < entries.size(); i++) {
      Entry e = entries.get(i);
      if (e.kind == KIND_DEVICE_PULSE && e.pulseName != null && e.pulseName.equals(active)) {
        cursor = i; return;
      }
    }
    if (config.audioDeviceSelector != null) {
      int sel = config.audioDeviceSelector.getSelectedIndex();
      for (int i = 0; i < entries.size(); i++) {
        Entry e = entries.get(i);
        if (e.kind == KIND_DEVICE_JAVA && e.javaIdx == sel) { cursor = i; return; }
      }
    }
  }

  void resetRepeat() {
    lastRepeatTime = 0;
    isRepeating = false;
  }

  void update() {
    if (!isOpen) return;
    if (controller != null && controller.isConnected()) {
      if (controller.bJustPressed || controller.backJustPressed) { isOpen = false; return; }
      if (controller.aJustPressed) { commit(); return; }
      if (controller.dpadUpHeld) handleRepeatMove(-1);
      else if (controller.dpadDownHeld) handleRepeatMove(1);
    }
    if (keyPressed) {
      if (key == 'j' || keyCode == DOWN) handleRepeatMove(1);
      else if (key == 'k' || keyCode == UP) handleRepeatMove(-1);
      else resetRepeat();
    } else if (controller == null || (!controller.dpadUpHeld && !controller.dpadDownHeld)) {
      resetRepeat();
    }
  }

  void handleRepeatMove(int dir) {
    long now = millis();
    if (lastRepeatTime == 0) {
      moveCursor(dir);
      lastRepeatTime = now;
      isRepeating = false;
    } else {
      long wait = isRepeating ? repeatInterval : repeatDelay;
      if (now - lastRepeatTime > wait) {
        moveCursor(dir);
        lastRepeatTime = now;
        isRepeating = true;
      }
    }
  }

  void moveCursor(int dir) {
    if (entries.isEmpty()) return;
    int n = entries.size();
    cursor = (cursor + dir + n) % n;
  }

  // ' / Esc / Enter routing — returns true if consumed.
  boolean handleKey(char k, int kc) {
    if (!isOpen) {
      if (k == '\'') { toggle(); return true; }
      return false;
    }
    if (k == '\'' || k == ESC || kc == ESC) { isOpen = false; return true; }
    if (k == '\n' || k == '\r' || k == ' ') { commit(); return true; }
    return true;
  }

  void commit() {
    if (entries.isEmpty()) { isOpen = false; return; }
    Entry e = entries.get(cursor);
    isOpen = false;

    switch (e.kind) {
      case KIND_FILE_RANDOM:
        restorePulseDefault();
        config.AUDIO_INPUT_MODE = "FILE";
        nextSong();
        break;
      case KIND_FILE_BROWSE:
        restorePulseDefault();
        config.AUDIO_INPUT_MODE = "FILE";
        selectInput("Select song to visualize", "fileSelected");
        break;
      case KIND_DEVICE_JAVA:
        restorePulseDefault();
        config.AUDIO_INPUT_MODE = "DEVICE";
        if (config.audioDeviceSelector != null) {
          config.audioDeviceSelector.selectDevice(e.javaIdx);
          config.SELECTED_AUDIO_DEVICE_INDEX = e.javaIdx;
        }
        if (audio != null) audio.stop();
        loadSongToVisualize();
        break;
      case KIND_DEVICE_PULSE:
        applyPulseSource(e.pulseName);
        config.AUDIO_INPUT_MODE = "DEVICE";
        // Open Java's `default` mixer (which Pulse now routes from chosen source).
        if (config.audioDeviceSelector != null) {
          for (int i = 0; i < config.audioDeviceSelector.getDeviceCount(); i++) {
            String n = config.audioDeviceSelector.deviceNames.get(i);
            if (n != null && n.toLowerCase().startsWith("default")) {
              config.audioDeviceSelector.selectDevice(i);
              config.SELECTED_AUDIO_DEVICE_INDEX = i;
              break;
            }
          }
        }
        if (audio != null) audio.stop();
        loadSongToVisualize();
        break;
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────
  void drawOverlay() {
    if (!isOpen) return;
    blendMode(BLEND);
    pushStyle();
    textFont(monoFont);

    float lineH = 19 * uiScale();
    float pad = 14 * uiScale();
    int rows = entries.size();

    float boxW = min(820 * uiScale(), width * 0.7);
    float boxH = pad * 2 + (rows + 4) * lineH;
    float boxX = 20 * uiScale();
    float boxY = (height - boxH) / 2.0;

    fill(BG_COLOR);
    stroke(BORDER_COLOR);
    strokeWeight(2);
    rect(boxX, boxY, boxW, boxH, 10);

    noStroke();
    float ty = boxY + pad;
    fill(TEXT_HEADER);
    textAlign(CENTER, TOP);
    textSize(13 * uiScale());
    text("♪  AUDIO SOURCE  ♪", boxX + boxW / 2.0, ty);
    ty += lineH;

    fill(TEXT_HINT);
    textSize(10 * uiScale());
    String mode = (audio != null && audio.isDeviceInput()) ? "DEVICE" : "FILE";
    text("current mode: " + mode + "    '  close    ⏎ select", boxX + boxW / 2.0, ty);
    ty += lineH * 1.2;

    textAlign(LEFT, TOP);
    textSize(12 * uiScale());
    for (int i = 0; i < entries.size(); i++) {
      Entry e = entries.get(i);
      boolean isCursor = (i == cursor);
      boolean isLive = isEntryLive(e);

      if (isCursor) { fill(ROW_CURSOR); rect(boxX + 4, ty - 2, boxW - 8, lineH + 1, 4); }
      else if (isLive) { fill(ROW_LIVE); rect(boxX + 4, ty - 2, boxW - 8, lineH + 1, 4); }

      int labelColor = isLive ? TEXT_HEADER
                       : e.isRecommended ? TEXT_WARN
                       : isCursor ? color(200, 255, 200)
                       : TEXT_DIM;

      // Reserve right column for detail; truncate label to avoid overlap.
      float detailW = e.detail != null ? textWidth(e.detail) + 12 : 0;
      float labelMax = boxW - pad * 2 - detailW - 8;
      String prefix = isLive ? "◄ " : "  ";
      String drawLabel = prefix + e.label;
      drawLabel = truncateToWidth(drawLabel, labelMax);

      fill(labelColor);
      text(drawLabel, boxX + pad, ty);

      if (e.detail != null) {
        fill(e.isRecommended ? TEXT_WARN
             : (e.kind == KIND_DEVICE_PULSE && e.isMonitor) ? TEXT_WARN
             : TEXT_HINT);
        textAlign(RIGHT, TOP);
        text(e.detail, boxX + boxW - pad, ty);
        textAlign(LEFT, TOP);
      }
      ty += lineH;
    }

    popStyle();
  }

  boolean isEntryLive(Entry e) {
    if (audio == null) return false;
    if (e.kind == KIND_FILE_RANDOM || e.kind == KIND_FILE_BROWSE) {
      return !audio.isDeviceInput();
    }
    if (!audio.isDeviceInput()) return false;
    if (e.kind == KIND_DEVICE_JAVA && config.audioDeviceSelector != null) {
      return config.audioDeviceSelector.getSelectedIndex() == e.javaIdx;
    }
    if (e.kind == KIND_DEVICE_PULSE) {
      return e.pulseName != null && e.pulseName.equals(savedPulseActiveName());
    }
    return false;
  }

  String savedPulseActiveName() {
    return savedPulseDefault == null ? null : pactlGetDefaultSource();
  }

  // ── Pulse helpers ─────────────────────────────────────────────────────────

  boolean isLinux() {
    String os = System.getProperty("os.name", "").toLowerCase();
    return os.contains("linux");
  }

  ArrayList<String[]> listPulseSources() {
    ArrayList<String[]> out = new ArrayList<String[]>();
    String stdout = runShell("pactl list short sources");
    if (stdout == null) return out;
    for (String line : stdout.split("\n")) {
      String[] parts = line.split("\\s+");
      // pactl format: ID  NAME  DRIVER  FORMAT  STATE
      if (parts.length >= 2) {
        String name = parts[1];
        String state = parts.length >= 5 ? parts[4] : "";
        out.add(new String[]{ name, state });
      }
    }
    return out;
  }

  String pactlGetDefaultSource() {
    String s = runShell("pactl get-default-source");
    return s == null ? null : s.trim();
  }

  void applyPulseSource(String name) {
    if (savedPulseDefault == null) {
      String prior = pactlGetDefaultSource();
      // Don't preserve a `.monitor` as the "real" default — it usually means
      // a previous run died before restoring. Pick the first plain input
      // instead so we land back on a real mic on exit.
      if (prior == null || prior.endsWith(".monitor")) {
        for (String[] row : listPulseSources()) {
          if (!row[0].endsWith(".monitor")) { prior = row[0]; break; }
        }
      }
      savedPulseDefault = prior;
    }
    runShell("pactl set-default-source " + shellQuote(name));
    println("[Audio] Pulse default source -> " + name + " (saved prior: " + savedPulseDefault + ")");
  }

  void restorePulseDefault() {
    if (savedPulseDefault == null) return;
    runShell("pactl set-default-source " + shellQuote(savedPulseDefault));
    println("[Audio] Pulse default source restored: " + savedPulseDefault);
    savedPulseDefault = null;
  }

  String shellQuote(String s) {
    return "'" + s.replace("'", "'\\''") + "'";
  }

  String truncateToWidth(String s, float maxW) {
    if (textWidth(s) <= maxW) return s;
    String suffix = "…";
    while (s.length() > 1 && textWidth(s + suffix) > maxW) {
      s = s.substring(0, s.length() - 1);
    }
    return s + suffix;
  }

  String runShell(String cmd) {
    try {
      Process p = new ProcessBuilder("sh", "-c", cmd).redirectErrorStream(true).start();
      java.io.BufferedReader r = new java.io.BufferedReader(new java.io.InputStreamReader(p.getInputStream()));
      StringBuilder sb = new StringBuilder();
      String line;
      while ((line = r.readLine()) != null) sb.append(line).append('\n');
      p.waitFor();
      return sb.toString();
    } catch (Exception e) {
      return null;
    }
  }
}
