import ddf.minim.*;
import ddf.minim.analysis.*;

class Audio {
  Minim minim;
  AudioPlayer player;
  BeatDetect beat;
  FFT fft;

  // Per-band rolling max for normalization (lazy-initialized after first forward())
  private float[] _bandMax;

  Audio(PApplet applet, String songToVisualize, int bandsPerOctave) {
    minim = new Minim(applet);
    try {
      player = minim.loadFile(songToVisualize);
    } catch (Throwable t) {
      // Minim can throw on corrupt headers (mark/reset, IOException) before
      // returning null. Catch broadly so a single bad file doesn't kill setup
      // and leave the P3D window unresponsive — caller will retry next song.
      System.err.println("[Audio] Minim threw loading " + songToVisualize + ": " + t.getMessage());
      player = null;
    }
    if (player == null) return;  // caller checks audio.player == null and skips
    player.play();
    beat = new BeatDetect();
    fft = new FFT(player.bufferSize(), player.sampleRate());
    fft.logAverages(22, bandsPerOctave);
  }

  void forward() {
    fft.forward(player.mix);
    if (_bandMax == null) _bandMax = new float[fft.avgSize()];
    for (int i = 0; i < fft.avgSize(); i++) {
      _bandMax[i] = max(_bandMax[i] * 0.997, fft.getAvg(i));
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
    player.play();
  }

  void pause() {
    player.pause();
  }

  void skip(int time) {
    player.skip(time);
  }

  float getGain() {
    return player.getGain();
  }

  void setGain(float gain) {
    player.setGain(gain);
  }

  void stop() {
    minim.stop();
  }
}