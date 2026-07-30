import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Mixer;

class Audio {
  Minim minim;
  AudioPlayer player;     // null if using device input
  AudioInput audioInput;  // null if using file input
  BeatDetect beat;
  FFT fft;

  // Input mode flags
  boolean isUsingDeviceInput = false;
  String inputMode = "FILE"; // "FILE" or "DEVICE"

  // Per-band rolling max for normalization (lazy-initialized after first forward())
  private float[] _bandMax;

  // DEVICE-mode input gain. PulseAudio monitor / Stereo Mix / BlackHole
  // capture is typically ~10-20× quieter than a decoded mp3, so FFT bands
  // and beat onsets stay flat without amplification. Auto-tuned each frame
  // toward a target peak; scenes can read `audio.deviceInputGain` to display.
  float deviceInputGain = 8.0f;
  boolean manualGainLock = false;  // true after +/- override; AGC stops moving
  private float _recentPeak = 0;
  private float[] _scaled; // reused per-frame scratch buffer

  // Master playback volume, linear 0..2.0 (1.0 = 100%, unchanged). Backed by
  // a persistent DevVolumeEffect in the player's effect chain rather than
  // player.setGain() - setGain() only works if the underlying JavaSound line
  // exposes a MASTER_GAIN FloatControl, which PulseAudio's JavaSound bridge
  // commonly doesn't expose, so setGain() silently no-ops on many Linux
  // machines. The effect chain (AudioSource.stream.setAudioEffect) is wired
  // completely separately from the SignalSplitter that feeds FFT/BeatDetect
  // (AudioSource.stream.setAudioListener), so scenes stay just as
  // audio-reactive at any volume. Read by the VOLUME HUD badge (toggle: V).
  float volume = 1.0;
  DevVolumeEffect volumeEffect;

  void setVolume(float v) {
    volume = constrain(v, 0.0, 2.0);
    if (volumeEffect != null) volumeEffect.gain = volume;
  }

  // Steps by a flat percentage-point amount (e.g. +5/-5), snapped to the
  // nearest whole percent so repeated presses land on clean numbers (5%,
  // 10%, 15%...) instead of drifting into decimals.
  void nudgeVolume(float deltaPercent) {
    float pct = round(volume * 100 + deltaPercent);
    setVolume(pct / 100.0);
    println("[Audio] volume -> " + nf(volume * 100, 0, 0) + "%");
  }

  // Dev shortcut: if .devvolume exists in the sketch dir, start playback at
  // that listening volume (0-100%) instead of full blast - handy for
  // running locally at ~5% while you keep working.
  //   echo 5 > Music_Visualizer_CK/.devvolume
  void applyDevVolume() {
    try {
      java.io.File devVol = new java.io.File(sketchPath(".devvolume"));
      if (!devVol.exists()) return;
      String raw = join(loadStrings(devVol.getAbsolutePath()), "").trim();
      float pct = Float.parseFloat(raw);
      setVolume(pct / 100.0);
      println("[Audio] DEVVOLUME: " + nf(pct, 0, 1) + "%");
    } catch (Exception e) { /* ignore - missing or malformed file */ }
  }

  void nudgeDeviceGain(float factor) {
    deviceInputGain = constrain(deviceInputGain * factor, 1.0f, 200.0f);
    manualGainLock = true;
    System.out.println("[Audio] manual gain -> ×" + nf(deviceInputGain, 0, 1));
  }
  void unlockDeviceGain() {
    manualGainLock = false;
    System.out.println("[Audio] AGC re-enabled");
  }

  // Constructor for FILE INPUT (original behavior)
  Audio(PApplet applet, String songToVisualize, int bandsPerOctave) {
    this(applet, songToVisualize, bandsPerOctave, false, -1);
  }

  // Constructor for DEVICE INPUT
  Audio(PApplet applet, String songToVisualize, int bandsPerOctave, boolean useDeviceInput, int deviceIndex) {
    minim = new Minim(applet);
    this.isUsingDeviceInput = useDeviceInput;
    this.audioInput = null;
    this.player = null;

    if (!useDeviceInput) {
      // FILE INPUT MODE
      inputMode = "FILE";
      try {
        player = minim.loadFile(songToVisualize);
      } catch (Throwable t) {
        System.err.println("[Audio] Minim threw loading " + songToVisualize + ": " + t.getMessage());
        player = null;
      }
      if (player == null) return;
      player.play();
      volumeEffect = new DevVolumeEffect(volume);
      player.addEffect(volumeEffect);
      applyDevVolume();
      beat = new BeatDetect();
      fft = new FFT(player.bufferSize(), player.sampleRate());
      fft.logAverages(22, bandsPerOctave);
    } else {
      // DEVICE INPUT MODE
      inputMode = "DEVICE";
      try {
        // Route Minim through chosen Mixer if selector has a pick; else fall
        // back to JVM default. Cross-platform: Linux=PulseAudio monitors,
        // Windows=Stereo Mix / VB-Cable, macOS=BlackHole.
        String chosenName = "system default";
        if (config != null && config.audioDeviceSelector != null) {
          Mixer.Info info = config.audioDeviceSelector.getSelectedMixerInfo();
          if (info != null) {
            try {
              minim.setInputMixer(AudioSystem.getMixer(info));
              chosenName = info.getName();
            } catch (Throwable t) {
              System.err.println("[Audio] setInputMixer failed for " + info.getName() + ": " + t.getMessage());
            }
          }
        }

        audioInput = minim.getLineIn(Minim.STEREO, 2048, 44100);

        if (audioInput == null) {
          System.err.println("[Audio] Failed to open audio input device: " + chosenName);
          return;
        }

        System.out.println("[Audio] Opened device input: " + chosenName);
        beat = new BeatDetect();
        fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
        fft.logAverages(22, bandsPerOctave);

        // Scene code reads `audio.player.left/right/mix/bufferSize/position`
        // directly. Load a silent stub so those calls return zero buffers
        // instead of NPE'ing in DEVICE mode. Stub stays paused + muted, so
        // no audible output and no FFT contention with device input.
        try {
          String stub = sketchPath("data/smoke-test.wav");
          player = minim.loadFile(stub);
          if (player != null) {
            player.mute();
            // Don't call play() - left/right buffers stay zero, position() = 0.
          }
        } catch (Throwable t) {
          System.err.println("[Audio] Could not load silent stub player: " + t.getMessage());
        }
      } catch (Throwable t) {
        System.err.println("[Audio] Error initializing device input: " + t.getMessage());
        t.printStackTrace();
      }
    }
  }

  /**
   * Get the appropriate audio buffer for FFT analysis.
   * Returns player.mix for file input, audioInput.mix for device input.
   */
  private AudioBuffer getAudioBuffer() {
    if (!isUsingDeviceInput && player != null) {
      return player.mix;
    } else if (isUsingDeviceInput && audioInput != null) {
      return audioInput.mix;
    }
    return null;
  }

  // Public so callers can run beat detection on whichever buffer is active.
  AudioBuffer getActiveBuffer() {
    return getAudioBuffer();
  }

  // Active buffers - file player when in FILE mode, audioInput when capturing
  // from a device. Use these in scenes instead of `audio.player.left` so
  // oscilloscope/waveform scenes work in both modes.
  AudioBuffer left() {
    if (isUsingDeviceInput && audioInput != null) return audioInput.left;
    return player != null ? player.left : null;
  }
  AudioBuffer right() {
    if (isUsingDeviceInput && audioInput != null) return audioInput.right;
    return player != null ? player.right : null;
  }
  AudioBuffer mix() {
    return getAudioBuffer();
  }
  int bufferSize() {
    if (isUsingDeviceInput && audioInput != null) return audioInput.bufferSize();
    return player != null ? player.bufferSize() : 0;
  }
  // Per-sample value - applies device gain so waveform scenes pop with quiet
  // monitor sources too.
  float leftSample(int i) {
    AudioBuffer b = left();
    if (b == null) return 0;
    float v = b.get(i);
    return isUsingDeviceInput ? v * deviceInputGain : v;
  }
  float rightSample(int i) {
    AudioBuffer b = right();
    if (b == null) return 0;
    float v = b.get(i);
    return isUsingDeviceInput ? v * deviceInputGain : v;
  }

  void detectBeat() {
    AudioBuffer buffer = getAudioBuffer();
    if (buffer == null || beat == null) return;
    if (isUsingDeviceInput && _scaled != null) {
      beat.detect(_scaled);
    } else {
      beat.detect(buffer);
    }
  }

  // True when audio is "playing" - file is mid-track, or device input is open
  // and listening. Lets callers skip the player.isPlaying() NPE in DEVICE mode.
  boolean isPlaying() {
    if (isUsingDeviceInput) return audioInput != null;
    return player != null && player.isPlaying();
  }

  // Minim's AudioPlayer.isPlaying() is unreliable at EOF - has been observed to
  // keep returning true after the last sample drained. Auto-advance polling
  // isPlaying() alone misses the end-of-track and the show goes silent.
  // This combines both signals: true when track ran out OR was paused at end.
  boolean isPlaybackComplete() {
    if (isUsingDeviceInput) return false;       // device input never ends
    if (player == null) return true;            // closed/torn-down counts as done
    int len = player.length();
    int pos = player.position();
    if (len <= 0) return false;                 // unknown length - can't tell
    // 250ms tolerance for Minim's per-buffer position jitter at EOF.
    if (pos >= len - 250) return true;
    return !player.isPlaying();
  }

  void forward() {
    AudioBuffer buffer = getAudioBuffer();
    if (buffer == null) return;

    if (isUsingDeviceInput) {
      int n = buffer.size();
      if (_scaled == null || _scaled.length != n) _scaled = new float[n];
      float framePeak = 0;
      for (int i = 0; i < n; i++) {
        float v = buffer.get(i);
        if (v < 0) v = -v;
        if (v > framePeak) framePeak = v;
      }
      // AGC: track recent peak (slow attack/release), aim its scaled value
      // at ~0.6. Clamp gain so silence doesn't blow up to noise-amp.
      _recentPeak = max(framePeak, _recentPeak * 0.995f);
      if (_recentPeak > 0.0005f && !manualGainLock) {
        float target = 0.85f / _recentPeak;
        deviceInputGain += (target - deviceInputGain) * 0.2f;
      }
      deviceInputGain = constrain(deviceInputGain, 1.0f, 200.0f);
      for (int i = 0; i < n; i++) _scaled[i] = buffer.get(i) * deviceInputGain;
      fft.forward(_scaled);
    } else {
      fft.forward(buffer);
    }
    if (_bandMax == null) _bandMax = new float[fft.avgSize()];
    // Faster decay (0.99 ≈ 1.1s halflife) lets quiet sources reach 1.0
    // normalized within a couple seconds instead of staying flat.
    float decay = isUsingDeviceInput ? 0.99f : 0.997f;
    for (int i = 0; i < fft.avgSize(); i++) {
      _bandMax[i] = max(_bandMax[i] * decay, fft.getAvg(i));
    }
  }

  // Returns FFT band value normalised to ~0..1 relative to that band's recent peak.
  // Use this instead of fft.getAvg(band) to make scenes song-loudness-agnostic.
  float normalisedAvg(int band) {
    float raw = fft.getAvg(band);
    if (_bandMax == null || _bandMax[band] < 0.0001) return 0;
    return constrain(raw / _bandMax[band], 0, 1);
  }

  void play() {
    if (!isUsingDeviceInput && player != null) {
      player.play();
    }
    // Device input is always "playing" (listening)
  }

  void pause() {
    if (!isUsingDeviceInput && player != null) {
      player.pause();
    }
    // Cannot pause device input
  }

  void skip(int time) {
    if (!isUsingDeviceInput && player != null) {
      player.skip(time);
    }
    // Cannot skip device input
  }

  // NOTE: getPosition() only works for file input
  int getPosition() {
    if (!isUsingDeviceInput && player != null) {
      return player.position();
    }
    return 0; // Return 0 for device input (real-time, no position concept)
  }

  // NOTE: getLength() only works for file input
  int getLength() {
    if (!isUsingDeviceInput && player != null) {
      return player.length();
    }
    return 0; // Return 0 for device input (infinite/unknown length)
  }

  float getGain() {
    if (!isUsingDeviceInput && player != null) {
      return player.getGain();
    }
    return 1.0;
  }

  void setGain(float gain) {
    if (!isUsingDeviceInput && player != null) {
      player.setGain(gain);
    }
  }

  /**
   * Returns true if currently using device input instead of file input.
   */
  boolean isDeviceInput() {
    return isUsingDeviceInput;
  }

  /**
   * Returns the input mode string ("FILE" or "DEVICE")
   */
  String getInputMode() {
    return inputMode;
  }

  void stop() {
    // Explicit per-resource teardown before minim.stop(). minim.stop() alone
    // has been observed to leave file-mode AudioPlayer streams alive long
    // enough that a follow-up new Audio() overlaps two songs on output.
    if (player != null) {
      try { player.pause(); } catch (Throwable ignored) {}
      try { player.close(); } catch (Throwable ignored) {}
      player = null;
    }
    if (audioInput != null) {
      try { audioInput.close(); } catch (Throwable ignored) {}
      audioInput = null;
    }
    try { minim.stop(); } catch (Throwable ignored) {}
  }
}

// Linear sample-scale gain effect backing Audio.volume. Plugs into
// AudioSource's effect chain (which feeds the actual output line) rather
// than player.setGain() (which requires JavaSound MASTER_GAIN line support
// that PulseAudio's JavaSound bridge commonly doesn't expose). `gain` is
// mutated live by Audio.setVolume() - one instance lives for the player's
// whole lifetime.
class DevVolumeEffect implements AudioEffect {
  float gain;
  DevVolumeEffect(float gain) { this.gain = gain; }

  void process(float[] signal) {
    for (int i = 0; i < signal.length; i++) signal[i] *= gain;
  }

  void process(float[] signalLeft, float[] signalRight) {
    for (int i = 0; i < signalLeft.length; i++) {
      signalLeft[i]  *= gain;
      signalRight[i] *= gain;
    }
  }
}