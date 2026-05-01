// AudioModeTest.pde — assertions for audio init paths.
//
// Runs once at smoke-test startup (before scene loop). Verifies:
//   - FILE mode (the existing global `audio` instance) is fully initialised
//     and its accessors don't crash. Backwards-compat guard for the recent
//     DEVICE-mode refactor.
//   - AudioDeviceSelector enumerates without throwing and its cycle methods
//     are safe even when device list is empty.
//   - DEVICE mode constructor doesn't crash. We don't assert that audioInput
//     opens (the JVM may have no usable input device in CI), only that init
//     fails gracefully and forward()/stop() are safe regardless.
//
// Failures are appended to the SmokeTestRunner.failures list so the final
// report includes them and smoketest.sh exits non-zero.

void runAudioModeTests(SmokeTestRunner runner) {
  println("[AUDIOTEST] starting audio-mode assertions");
  int startFails = runner.failures.size();

  testFileModeInitialised(runner);
  testDeviceSelector(runner);
  testDeviceModeConstructor(runner);

  int newFails = runner.failures.size() - startFails;
  if (newFails == 0) {
    println("[AUDIOTEST] PASS — all audio-mode assertions held");
  } else {
    println("[AUDIOTEST] FAIL — " + newFails + " audio-mode assertion(s) failed");
  }
}

void testFileModeInitialised(SmokeTestRunner runner) {
  String section = "FileMode";
  try {
    if (audio == null) throw new RuntimeException("global audio is null");
    if (audio.fft == null) throw new RuntimeException("audio.fft is null");
    if (audio.beat == null) throw new RuntimeException("audio.beat is null");
    if (audio.player == null) throw new RuntimeException("audio.player is null (file mode expected)");
    if (audio.isDeviceInput()) throw new RuntimeException("isDeviceInput() true in file mode");
    if (!"FILE".equals(audio.getInputMode())) throw new RuntimeException("getInputMode() != FILE: " + audio.getInputMode());

    audio.forward();
    if (audio.fft.avgSize() <= 0) throw new RuntimeException("fft.avgSize() <= 0 after forward()");

    float g = audio.getGain();
    audio.setGain(g);

    if (audio.getLength() <= 0) throw new RuntimeException("getLength() <= 0 in file mode");

    println("[AUDIOTEST] " + section + " ok (bands=" + audio.fft.avgSize() + ", len=" + audio.getLength() + "ms)");
  } catch (Throwable t) {
    runner.logFailure(section, "init checks", new RuntimeException(t));
  }
}

void testDeviceSelector(SmokeTestRunner runner) {
  String section = "DeviceSelector";
  try {
    if (config.audioDeviceSelector == null) throw new RuntimeException("config.audioDeviceSelector is null after setup");

    AudioDeviceSelector sel = config.audioDeviceSelector;
    int count = sel.getDeviceCount();
    if (count < 0) throw new RuntimeException("getDeviceCount() negative: " + count);

    String name = sel.getSelectedDeviceName();
    if (name == null) throw new RuntimeException("getSelectedDeviceName() returned null");

    sel.refresh();
    if (sel.getDeviceCount() != count) {
      println("[AUDIOTEST] " + section + " note: refresh changed device count " + count + " -> " + sel.getDeviceCount());
    }

    sel.selectNext();
    sel.selectPrevious();

    if (count > 0) {
      sel.selectDevice(0);
      if (sel.getSelectedIndex() != 0) throw new RuntimeException("selectDevice(0) didn't take");
      sel.selectDevice(-1);
      if (sel.getSelectedIndex() != 0) throw new RuntimeException("selectDevice(-1) corrupted index");
      sel.selectDevice(9999);
      if (sel.getSelectedIndex() != 0) throw new RuntimeException("selectDevice(9999) corrupted index");
    }

    println("[AUDIOTEST] " + section + " ok (devices=" + count + ", selected=\"" + name + "\")");
  } catch (Throwable t) {
    runner.logFailure(section, "selector checks", new RuntimeException(t));
  }
}

void testDeviceModeConstructor(SmokeTestRunner runner) {
  String section = "DeviceMode";
  Audio probe = null;
  int openedIdx = -1;
  try {
    // First: bare constructor must not crash with index 0 (API contract).
    probe = new Audio(this, "", config.bandsPerOctave, true, 0);
    if (probe == null) throw new RuntimeException("constructor returned null");
    if (!"DEVICE".equals(probe.getInputMode())) throw new RuntimeException("getInputMode() != DEVICE: " + probe.getInputMode());
    if (!probe.isDeviceInput()) throw new RuntimeException("isDeviceInput() false in device mode");
    if (probe.player != null) throw new RuntimeException("player non-null in device mode");

    probe.forward();
    probe.play();
    probe.pause();
    probe.skip(100);
    float g = probe.getGain();
    probe.setGain(g);
    if (probe.getPosition() != 0) throw new RuntimeException("getPosition() non-zero in device mode");
    if (probe.getLength()   != 0) throw new RuntimeException("getLength() non-zero in device mode");

    // If first device didn't open, walk the list to find one that does — so
    // the signal-level probe below has a real input to sample. Idle mics
    // (e.g. suspended USB) often fail to open; system "default" usually works.
    if (probe.audioInput == null && config.audioDeviceSelector != null) {
      int n = config.audioDeviceSelector.getDeviceCount();
      for (int i = 1; i < n; i++) {
        try { probe.stop(); } catch (Throwable ignored) {}
        config.audioDeviceSelector.selectDevice(i);
        probe = new Audio(this, "", config.bandsPerOctave, true, i);
        if (probe.audioInput != null) { openedIdx = i; break; }
      }
    } else if (probe.audioInput != null) {
      openedIdx = 0;
    }

    boolean opened = probe.audioInput != null;
    if (opened) {
      println("[AUDIOTEST] " + section + " opened device idx=" + openedIdx + " name=\"" + config.audioDeviceSelector.getSelectedDeviceName() + "\"");
    }
    if (opened) {
      // Sample ~1s of incoming audio so the user can confirm signal is flowing
      // (e.g. after `./loopback.sh on` + playing music). Idle/no-source =>
      // RMS near 0; live signal => clearly non-zero.
      float sumSq = 0;
      int samples = 0;
      float peak = 0;
      long endNs = System.nanoTime() + 1_000_000_000L;
      while (System.nanoTime() < endNs) {
        for (int i = 0; i < probe.audioInput.bufferSize(); i++) {
          float v = probe.audioInput.mix.get(i);
          sumSq += v * v;
          peak = max(peak, abs(v));
          samples++;
        }
        try { Thread.sleep(20); } catch (InterruptedException ignored) {}
      }
      float rms = samples > 0 ? (float)Math.sqrt(sumSq / samples) : 0;
      String verdict = rms > 0.001 ? "SIGNAL" : "silent";
      println("[AUDIOTEST] " + section + " ok (audioInput opened=true, rms=" + nf(rms, 0, 5) + ", peak=" + nf(peak, 0, 5) + " -> " + verdict + ")");
    } else {
      println("[AUDIOTEST] " + section + " ok (audioInput opened=false — JVM has no usable input on this platform)");
    }
  } catch (Throwable t) {
    runner.logFailure(section, "device-mode init", new RuntimeException(t));
  } finally {
    if (probe != null) {
      try { probe.stop(); } catch (Throwable ignored) {}
    }
  }
}
