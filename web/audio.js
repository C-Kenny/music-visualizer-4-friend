/**
 * audio.js — Web Audio API wrapper mirroring Minim/Audio.pde
 *
 * Exposes:
 *   audio.fft.getAvg(band)   → amplitude for log-average band
 *   audio.fft.avgSize()      → number of log bands
 *   audio.beat.isOnset()     → true once per beat
 *   audio.player.mix         → Float32Array waveform (current frame)
 *   audio.player.bufferSize()→ length of mix buffer
 *   audio.play() / pause() / stop() / skip(ms) / getGain() / setGain(db)
 *   audio.setSourceFile(file) / setSourceMic() / setSourceSystem()
 *   audio.sourceType         → "file" | "mic" | "system"
 */

class AudioSystem {
  constructor() {
    this._ctx = null;
    this._source = null;
    this._gainNode = null;
    this._analyser = null;
    this._timeDomain = null;
    this._freqData = null;
    this._logBands = [];       // pre-computed band objects {startBin, endBin}
    this._avgSize = 0;
    this._beatEnergy = 0;
    this._beatHistory = new Float32Array(43); // ~43 frames rolling average
    this._beatHistoryIdx = 0;
    this._beatOnset = false;
    this._fileName = "";
    this._duration = 0;        // seconds
    this._ready = false;
    this._paused = false;
    this._startTime = 0;       // ctx.currentTime when play() was last called
    this._pauseOffset = 0;     // accumulated playback offset in seconds
    this._audioBuffer = null;
    this._sampleRate = 44100;
    this._stream = null;       // active MediaStream (mic/system)
    this.sourceType = "file";  // "file" | "mic" | "system"

    // Public interface objects (mirroring Processing API surface)
    this.fft = {
      _sys: this,
      getAvg: (i) => this._logBands[i] ? this._logBands[i].avg : 0,
      avgSize: () => this._avgSize,
      timeSize: () => (this._analyser ? this._analyser.fftSize : 2048),
    };

    this.beat = {
      _sys: this,
      isOnset: () => {
        const onsetFiredThisFrame = this._beatOnset;
        this._beatOnset = false;   // consume: returns true exactly once per beat
        return onsetFiredThisFrame;
      },
    };

    this.player = {
      _sys: this,
      get mix() { return this._sys._timeDomain || new Float32Array(2048); },
      bufferSize: () => this._timeDomain ? this._timeDomain.length : 2048,
      position: () => {
        if (!this._ready) return 0;
        if (this._paused) return this._pauseOffset;
        return this._ctx.currentTime - this._startTime + this._pauseOffset;
      },
      length: () => this._duration,
    };

    // Bind player methods so they work as regular function calls
    this.player.position = () => {
      if (!this._ready) return 0;
      if (this._paused) return this._pauseOffset;
      return this._ctx.currentTime - this._startTime + this._pauseOffset;
    };
    this.player.length = () => this._duration;
  }

  // ── Shared analyser setup ────────────────────────────────────────────────

  _initAnalyser() {
    this._analyser = this._ctx.createAnalyser();
    this._analyser.fftSize = 2048;
    this._analyser.smoothingTimeConstant = 0.8;
    this._analyser.connect(this._ctx.destination);

    this._timeDomain = new Float32Array(this._analyser.fftSize);
    this._freqData = new Float32Array(this._analyser.frequencyBinCount);

    // Build log-average band table (mirrors Minim's logAverages(22, 4))
    this._buildLogBands(22, Config.bandsPerOctave);

    // Reset beat history
    this._beatHistory.fill(0);
    this._beatHistoryIdx = 0;
    this._beatOnset = false;
  }

  /** Stop and release any active MediaStream tracks. */
  _releaseStream() {
    if (this._stream) {
      this._stream.getTracks().forEach(track => track.stop());
      this._stream = null;
    }
  }

  /** Tear down existing audio context and state. */
  async _teardown() {
    this._releaseStream();
    if (this._source) {
      try { this._source.disconnect(); } catch (disconnectError) { /* already disconnected */ }
      try { this._source.stop(); } catch (stopError) { /* already stopped or not a BufferSource */ }
      this._source = null;
    }
    if (this._ctx) {
      await this._ctx.close();
      this._ctx = null;
    }
    this._ready = false;
    this._gainNode = null;
    this._analyser = null;
  }

  // ── Source: File ─────────────────────────────────────────────────────────

  /** Alias for loadFile — sets sourceType to "file". */
  async setSourceFile(file) {
    return this.loadFile(file);
  }

  /** Load an audio File object (from file input or drag-drop). */
  async loadFile(file) {
    await this._teardown();

    this.sourceType = "file";
    this._ctx = new AudioContext();
    this._sampleRate = this._ctx.sampleRate;

    const arrayBuffer = await file.arrayBuffer();
    this._audioBuffer = await this._ctx.decodeAudioData(arrayBuffer);
    this._duration = this._audioBuffer.duration;
    this._fileName = file.name;

    // Build node graph: BufferSource → Gain → Analyser → Destination
    this._gainNode = this._ctx.createGain();
    this._gainNode.connect(this._ctx.createGain()); // placeholder, replaced below

    // Re-wire: gain → analyser → destination
    this._gainNode = this._ctx.createGain();
    this._analyser = this._ctx.createAnalyser();
    this._analyser.fftSize = 2048;
    this._analyser.smoothingTimeConstant = 0.8;

    this._gainNode.connect(this._analyser);
    this._analyser.connect(this._ctx.destination);

    this._timeDomain = new Float32Array(this._analyser.fftSize);
    this._freqData = new Float32Array(this._analyser.frequencyBinCount);

    // Build log-average band table (mirrors Minim's logAverages(22, 4))
    this._buildLogBands(22, Config.bandsPerOctave);

    // Reset beat state
    this._beatHistory.fill(0);
    this._beatHistoryIdx = 0;
    this._beatOnset = false;

    this._ready = true;
    this._paused = false;
    this._pauseOffset = 0;

    Config.SONG_NAME = file.name.replace(/\.[^.]+$/, '');

    this._startPlayback(0);
    Config.SONG_PLAYING = true;
  }

  // ── Source: Microphone ───────────────────────────────────────────────────

  /**
   * Request microphone (or loopback monitor) access and connect it to the
   * analyser pipeline.
   *
   * @param {string|null} preferredDeviceId - deviceId from enumerateDevices(),
   *   or null to use the browser default. Passing a specific device lets users
   *   pick a PulseAudio monitor, VB-Cable output, or BlackHole for system audio
   *   capture in Firefox and other browsers that lack getDisplayMedia() audio.
   */
  async setSourceMic(preferredDeviceId = null) {
    await this._teardown();

    this.sourceType = "mic";
    this._ctx = new AudioContext();
    this._sampleRate = this._ctx.sampleRate;

    // Build the audio constraints — use exact deviceId when one was chosen,
    // otherwise fall back to the browser's default input.
    const audioConstraints = preferredDeviceId
      ? { deviceId: { exact: preferredDeviceId } }
      : true;

    const audioInputStream = await navigator.mediaDevices.getUserMedia({
      audio: audioConstraints,
      video: false,
    });
    this._stream = audioInputStream;

    this._initAnalyser();

    const mediaStreamSource = this._ctx.createMediaStreamSource(audioInputStream);
    mediaStreamSource.connect(this._analyser);
    this._source = mediaStreamSource;

    this._fileName = "🎤 Microphone";
    this._duration = Infinity;
    this._ready = true;
    this._paused = false;

    Config.SONG_NAME = "Microphone";
    Config.SONG_PLAYING = true;
  }

  // ── Source: System audio ─────────────────────────────────────────────────

  /**
   * Request screen/tab audio capture and connect to the analyser pipeline.
   * On Chrome/Windows this captures system audio natively.
   * On macOS, BlackHole virtual device must be set as the default output.
   * Throws if permission is denied or no audio track is available.
   */
  async setSourceSystem() {
    await this._teardown();

    this.sourceType = "system";
    this._ctx = new AudioContext();
    this._sampleRate = this._ctx.sampleRate;

    const displayMediaStream = await navigator.mediaDevices.getDisplayMedia({
      audio: true,
      video: false,
    });
    this._stream = displayMediaStream;

    const capturedAudioTracks = displayMediaStream.getAudioTracks();
    if (capturedAudioTracks.length === 0) {
      await this._teardown();
      throw new Error(
        "No audio track in display media stream. " +
        "Make sure to check 'Share audio' in the browser dialog."
      );
    }

    this._initAnalyser();

    const mediaStreamSource = this._ctx.createMediaStreamSource(displayMediaStream);
    mediaStreamSource.connect(this._analyser);
    this._source = mediaStreamSource;

    this._fileName = "🖥️ System Audio";
    this._duration = Infinity;
    this._ready = true;
    this._paused = false;

    Config.SONG_NAME = "System Audio";
    Config.SONG_PLAYING = true;
  }

  /**
   * Build log-spaced FFT bands matching Minim's logAverages(minFreq, bandsPerOctave).
   * minFreq = 22 Hz, bandsPerOctave = 4 → ~30 bands across audible range.
   */
  _buildLogBands(minFrequencyHz, bandsPerOctave) {
    this._logBands = [];
    const nyquistFrequency = this._sampleRate / 2;
    const hzPerBin = nyquistFrequency / (this._analyser.frequencyBinCount);

    let currentFrequency = minFrequencyHz;
    while (currentFrequency < nyquistFrequency) {
      const bandTopFrequency = currentFrequency * Math.pow(2, 1 / bandsPerOctave);
      const startBin = Math.round(currentFrequency / hzPerBin);
      const endBin   = Math.round(bandTopFrequency / hzPerBin);
      if (startBin < this._analyser.frequencyBinCount) {
        this._logBands.push({
          startBin,
          endBin: Math.min(endBin, this._analyser.frequencyBinCount - 1),
          avg: 0,
        });
      }
      currentFrequency = bandTopFrequency;
    }
    this._avgSize = this._logBands.length;
  }

  _startPlayback(playbackOffset) {
    if (this._source) {
      try { this._source.disconnect(); } catch (disconnectError) { /* already disconnected */ }
      try { this._source.stop(); } catch (stopError) { /* already stopped */ }
    }
    this._source = this._ctx.createBufferSource();
    this._source.buffer = this._audioBuffer;
    this._source.loop = true;
    this._source.connect(this._gainNode);
    this._source.start(0, playbackOffset % this._duration);
    this._startTime = this._ctx.currentTime;
    this._pauseOffset = playbackOffset;
    this._paused = false;
  }

  /**
   * Called once per frame — reads analyser data, computes band averages,
   * runs beat detection.  Mirrors audio.forward() + beat.detect().
   */
  forward() {
    if (!this._ready || !this._analyser) return;

    this._analyser.getFloatTimeDomainData(this._timeDomain);
    this._analyser.getFloatFrequencyData(this._freqData);

    // Convert dB frequency data to linear amplitude and compute band averages
    for (let bandIndex = 0; bandIndex < this._logBands.length; bandIndex++) {
      const band = this._logBands[bandIndex];
      let binSum = 0;
      let binCount = 0;
      for (let binIndex = band.startBin; binIndex <= band.endBin; binIndex++) {
        // _freqData values are in dBFS; convert to linear amplitude [0..1]
        const linearAmplitude = Math.pow(10, this._freqData[binIndex] / 20);
        binSum += linearAmplitude;
        binCount++;
      }
      band.avg = binCount > 0 ? binSum / binCount : 0;
    }

    // Beat detection: compare current RMS energy to rolling average
    // of the bass bands (bands 0-5 roughly cover sub-bass and bass)
    let bassEnergy = 0;
    const bassbandsToSample = Math.min(6, this._logBands.length);
    for (let bassIndex = 0; bassIndex < bassbandsToSample; bassIndex++) {
      bassEnergy += this._logBands[bassIndex].avg;
    }
    bassEnergy /= bassbandsToSample;

    // Rolling average of recent bass energy — used as the beat threshold baseline
    this._beatHistory[this._beatHistoryIdx] = bassEnergy;
    this._beatHistoryIdx = (this._beatHistoryIdx + 1) % this._beatHistory.length;

    let rollingAverageBassEnergy = 0;
    for (let histIndex = 0; histIndex < this._beatHistory.length; histIndex++) {
      rollingAverageBassEnergy += this._beatHistory[histIndex];
    }
    rollingAverageBassEnergy /= this._beatHistory.length;

    // Beat fires when current energy is significantly above the rolling average.
    // Threshold is ~1.5× rolling average, with a minimum floor to avoid false
    // positives during silence (when rolling average approaches zero).
    const beatThreshold = Math.max(0.001, rollingAverageBassEnergy * 1.5);
    if (bassEnergy > beatThreshold && !this._beatOnset) {
      this._beatOnset = true;
    }
  }

  // ── Playback controls ────────────────────────────────────────────────────────
  // For mic/system sources, play/pause/stop/skip are no-ops (live stream).

  play() {
    if (!this._ready) return;
    if (this.sourceType !== "file") return; // live stream — no-op
    if (this._paused) {
      this._startPlayback(this._pauseOffset);
    }
    Config.SONG_PLAYING = true;
  }

  pause() {
    if (!this._ready) return;
    if (this.sourceType !== "file") return; // live stream — no-op
    if (this._paused) return;
    const elapsedSeconds = this._ctx.currentTime - this._startTime;
    this._pauseOffset = (this._pauseOffset + elapsedSeconds) % this._duration;
    try { this._source.stop(); } catch (stopError) { /* already stopped */ }
    this._paused = true;
    Config.SONG_PLAYING = false;
  }

  stop() {
    if (!this._ready) return;
    if (this.sourceType !== "file") return; // live stream — no-op
    try { this._source.stop(); } catch (stopError) { /* already stopped */ }
    this._paused = true;
    this._pauseOffset = 0;
    Config.SONG_PLAYING = false;
  }

  /** Skip forward (positive) or backward (negative) by the given number of milliseconds. No-op for mic/system. */
  skip(skipMilliseconds) {
    if (!this._ready) return;
    if (this.sourceType !== "file") return; // live stream — no-op
    const currentPositionSeconds = this._pauseOffset +
      (this._paused ? 0 : this._ctx.currentTime - this._startTime);
    // Add duration * 2 before modulo to handle seeking before the start of the track
    const newPositionSeconds = (currentPositionSeconds + skipMilliseconds / 1000 + this._duration * 2) % this._duration;
    if (this._paused) {
      this._pauseOffset = newPositionSeconds;
    } else {
      this._startPlayback(newPositionSeconds);
    }
  }

  /** Returns gain in dB. Returns 0 for mic/system (no gain node). */
  getGain() {
    if (this.sourceType !== "file" || !this._gainNode) return 0;
    // Convert linear to dB
    return 20 * Math.log10(Math.max(0.0001, this._gainNode.gain.value));
  }

  /** Sets gain in dB. No-op for mic/system. */
  setGain(db) {
    if (this.sourceType !== "file" || !this._gainNode) return;
    this._gainNode.gain.value = Math.pow(10, db / 20);
  }

  get ready() { return this._ready; }
  get fileName() { return this._fileName; }
}

// Global singleton
const audio = new AudioSystem();
