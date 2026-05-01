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
            // Don't call play() — left/right buffers stay zero, position() = 0.
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

  // Active buffers — file player when in FILE mode, audioInput when capturing
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
  // Per-sample value — applies device gain so waveform scenes pop with quiet
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

  // True when audio is "playing" — file is mid-track, or device input is open
  // and listening. Lets callers skip the player.isPlaying() NPE in DEVICE mode.
  boolean isPlaying() {
    if (isUsingDeviceInput) return audioInput != null;
    return player != null && player.isPlaying();
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
    if (audioInput != null) {
      audioInput.close();
      audioInput = null;
    }
    minim.stop();
  }
}