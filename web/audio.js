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
        const v = this._beatOnset;
        this._beatOnset = false;   // consume: returns true exactly once per beat
        return v;
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

  /** Load an audio File object (from file input or drag-drop). */
  async loadFile(file) {
    // Tear down any previous context
    if (this._ctx) {
      await this._ctx.close();
    }

    this._ctx = new AudioContext();
    this._sampleRate = this._ctx.sampleRate;

    const arrayBuffer = await file.arrayBuffer();
    this._audioBuffer = await this._ctx.decodeAudioData(arrayBuffer);
    this._duration = this._audioBuffer.duration;
    this._fileName = file.name;

    // Build node graph
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

    this._ready = true;
    this._paused = false;
    this._pauseOffset = 0;

    Config.SONG_NAME = file.name.replace(/\.[^.]+$/, '');

    this._startPlayback(0);
    Config.SONG_PLAYING = true;
  }

  /**
   * Build log-spaced FFT bands matching Minim's logAverages(minFreq, bandsPerOctave).
   * minFreq = 22 Hz, bandsPerOctave = 4 → ~30 bands across audible range.
   */
  _buildLogBands(minFreq, bandsPerOctave) {
    this._logBands = [];
    const nyquist = this._sampleRate / 2;
    const binWidth = nyquist / (this._analyser.frequencyBinCount);

    let freq = minFreq;
    while (freq < nyquist) {
      const bandTop = freq * Math.pow(2, 1 / bandsPerOctave);
      const startBin = Math.round(freq / binWidth);
      const endBin   = Math.round(bandTop / binWidth);
      if (startBin < this._analyser.frequencyBinCount) {
        this._logBands.push({ startBin, endBin: Math.min(endBin, this._analyser.frequencyBinCount - 1), avg: 0 });
      }
      freq = bandTop;
    }
    this._avgSize = this._logBands.length;
  }

  _startPlayback(offset) {
    if (this._source) {
      try { this._source.disconnect(); } catch(e) {}
      try { this._source.stop(); } catch(e) {}
    }
    this._source = this._ctx.createBufferSource();
    this._source.buffer = this._audioBuffer;
    this._source.loop = true;
    this._source.connect(this._gainNode);
    this._source.start(0, offset % this._duration);
    this._startTime = this._ctx.currentTime;
    this._pauseOffset = offset;
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
    for (let b = 0; b < this._logBands.length; b++) {
      const band = this._logBands[b];
      let sum = 0, count = 0;
      for (let bin = band.startBin; bin <= band.endBin; bin++) {
        // _freqData is in dBFS; convert to linear [0..1]
        const lin = Math.pow(10, this._freqData[bin] / 20);
        sum += lin;
        count++;
      }
      band.avg = count > 0 ? sum / count : 0;
    }

    // Beat detection: compare current RMS energy to rolling average
    // of the bass band (bands 0-5 roughly cover sub-bass/bass)
    let energy = 0;
    for (let i = 0; i < Math.min(6, this._logBands.length); i++) {
      energy += this._logBands[i].avg;
    }
    energy /= Math.min(6, this._logBands.length);

    // Rolling average
    this._beatHistory[this._beatHistoryIdx] = energy;
    this._beatHistoryIdx = (this._beatHistoryIdx + 1) % this._beatHistory.length;

    let histAvg = 0;
    for (let i = 0; i < this._beatHistory.length; i++) histAvg += this._beatHistory[i];
    histAvg /= this._beatHistory.length;

    // Beat fires when current energy is significantly above average
    // Threshold ~1.5× history average, with a minimum level to avoid false positives in silence
    const threshold = Math.max(0.001, histAvg * 1.5);
    if (energy > threshold && !this._beatOnset) {
      this._beatOnset = true;
    }
  }

  // ── Playback controls ────────────────────────────────────────────────────────

  play() {
    if (!this._ready) return;
    if (this._paused) {
      this._startPlayback(this._pauseOffset);
    }
    Config.SONG_PLAYING = true;
  }

  pause() {
    if (!this._ready || this._paused) return;
    const elapsed = this._ctx.currentTime - this._startTime;
    this._pauseOffset = (this._pauseOffset + elapsed) % this._duration;
    try { this._source.stop(); } catch(e) {}
    this._paused = true;
    Config.SONG_PLAYING = false;
  }

  stop() {
    if (!this._ready) return;
    try { this._source.stop(); } catch(e) {}
    this._paused = true;
    this._pauseOffset = 0;
    Config.SONG_PLAYING = false;
  }

  /** Skip forward (positive) or backward (negative) by ms milliseconds. */
  skip(ms) {
    if (!this._ready) return;
    const offset = (this._pauseOffset + (this._paused ? 0 : this._ctx.currentTime - this._startTime) + ms / 1000 + this._duration * 2) % this._duration;
    if (this._paused) {
      this._pauseOffset = offset;
    } else {
      this._startPlayback(offset);
    }
  }

  /** Returns gain in dB. */
  getGain() {
    if (!this._gainNode) return 0;
    // Convert linear to dB
    return 20 * Math.log10(Math.max(0.0001, this._gainNode.gain.value));
  }

  /** Sets gain in dB. */
  setGain(db) {
    if (!this._gainNode) return;
    this._gainNode.gain.value = Math.pow(10, db / 20);
  }

  get ready() { return this._ready; }
  get fileName() { return this._fileName; }
}

// Global singleton
const audio = new AudioSystem();
