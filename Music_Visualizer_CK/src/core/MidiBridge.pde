import javax.sound.midi.MidiDevice;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Sequencer;
import javax.sound.midi.Synthesizer;

/**
 * MidiBridge — note-driven scene select from any MIDI input device.
 *
 * Uses javax.sound.midi (JVM built-in) so no extra contributed library is
 * required. On start(), scans every MidiDevice that supports input, opens
 * those that have a Transmitter, and installs a Receiver that routes
 * note-on events to scene selection.
 *
 * Mapping: note 36..(36 + SCENE_ORDER.length - 1) → SCENE_ORDER[note - 36].
 * Note 36 is the bottom-left pad on a Novation Launchpad / Mk2 / Mini and
 * the C in MPK pad banks A/B. Channel is ignored — any channel triggers.
 *
 * Velocity 0 (note-on with vel=0 is the canonical note-off) is treated as
 * note-off and ignored, so a pad release doesn't double-fire.
 *
 * Hotkey (wired in main keyPressed):
 *   F4   toggle MIDI bridge — re-scan devices on enable
 *
 * The receiver runs on the JVM MIDI thread; it forwards work to the main
 * thread via a flag the draw loop polls, so scene switches still go through
 * the regular pendingScene / beat-aligned commit path.
 */
class MidiBridge {
  static final int   PAD_BASE_NOTE        = 36;
  static final int   PENDING_NOOP         = -1;

  boolean enabled = false;
  ArrayList<MidiDevice> openDevices = new ArrayList<MidiDevice>();

  // Set by the MIDI thread; read + cleared by the main thread each frame.
  volatile int pendingSceneId = PENDING_NOOP;

  void toggle() {
    if (enabled) stop();
    else         start();
  }

  void start() {
    if (enabled) return;

    int opened = 0;
    try {
      MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
      for (MidiDevice.Info info : infos) {
        try {
          MidiDevice dev = MidiSystem.getMidiDevice(info);
          // Skip outputs / sequencers — we want devices that source events.
          if (dev.getMaxTransmitters() == 0) continue;
          if (dev instanceof Sequencer)   continue;
          if (dev instanceof Synthesizer) continue;
          // Processing's preprocessor mangles `dev.open()` (collides with the
          // global open() builtin). Reflection sidesteps the rewrite.
          if (!dev.isOpen()) {
            dev.getClass().getMethod("open").invoke(dev);
          }
          dev.getTransmitter().setReceiver(new MidiReceiver());
          openDevices.add(dev);
          opened++;
          println("[MIDI] opened: " + info.getName() + " — " + info.getDescription());
        } catch (Throwable t) {
          // One bad device shouldn't stop the rest
        }
      }
    } catch (Throwable t) {
      println("[MIDI] start error: " + t);
    }

    if (opened == 0) {
      println("[MIDI] no input devices found");
      return;
    }
    enabled = true;
    println("[MIDI] bridge ON — " + opened + " device(s)");
  }

  void stop() {
    for (MidiDevice dev : openDevices) {
      try { if (dev.isOpen()) dev.close(); } catch (Throwable ignored) {}
    }
    openDevices.clear();
    enabled = false;
    pendingSceneId = PENDING_NOOP;
    println("[MIDI] bridge OFF");
  }

  // Polled by main draw() — applies any queued scene jump on the render thread.
  void drainPending() {
    if (!enabled) return;
    int target = pendingSceneId;
    if (target == PENDING_NOOP) return;
    pendingSceneId = PENDING_NOOP;
    if (target >= 0 && target < SCENE_COUNT && scenes[target] != null) {
      switchScene(target);
    }
  }

  void onNoteOn(int note, int velocity) {
    if (velocity <= 0) return; // note-off encoded as vel=0
    int idx = note - PAD_BASE_NOTE;
    if (idx < 0 || idx >= SCENE_ORDER.length) return;
    pendingSceneId = SCENE_ORDER[idx];
  }

  // ── Inner Receiver ─────────────────────────────────────────────────────────
  // Non-static inner class — outer MidiBridge instance is implicit.
  class MidiReceiver implements javax.sound.midi.Receiver {
    public void send(MidiMessage msg, long timestamp) {
      if (!(msg instanceof ShortMessage)) return;
      ShortMessage sm = (ShortMessage) msg;
      if (sm.getCommand() == ShortMessage.NOTE_ON) {
        onNoteOn(sm.getData1(), sm.getData2());
      }
    }
    public void close() {}
  }
}
