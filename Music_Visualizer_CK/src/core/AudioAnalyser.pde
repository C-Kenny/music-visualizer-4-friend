/**
 * AudioAnalyser
 *
 * A centralized audio analysis service that runs once per frame.
 * Scenes should read from this instead of performing their own FFT calls.
 */
class AudioAnalyser {
  float bass;      // Normalised 0..1 (low frequency energy)
  float mid;       // Normalised 0..1
  float high;      // Normalised 0..1
  float master;    // Overall RMS level / amplitude
  boolean isBeat;  // True on the frame a beat onset fires

  // Full spectrum of normalized averages for complex scenes
  float[] spectrum;

  AudioAnalyser() {
    bass = 0;
    mid = 0;
    high = 0;
    master = 0;
    isBeat = false;
    spectrum = new float[48];
  }

  void update(Audio audio) {
    if (audio == null || audio.fft == null) return;

    // The main sketch should have called audio.forward() and 
    // audio.beat.detect() before calling this.

    isBeat = audio.beat.isOnset();

    // Accumulate normalised averages from the Audio class.
    // Audio.normalisedAvg() already handles peak tracking for us.
    float bSum = 0, mSum = 0, hSum = 0;
    int bCount = 0, mCount = 0, hCount = 0;

    int totalBands = audio.fft.avgSize();
    
    // Divide the first 42 bands into 3 logical sectors
    for (int i = 0; i < totalBands; i++) {
      float val = audio.normalisedAvg(i);
      if (i < spectrum.length) spectrum[i] = val;

      if (i >= 0 && i <= 5) {
        bSum += val;
        bCount++;
      } else if (i >= 6 && i <= 15) {
        mSum += val;
        mCount++;
      } else if (i >= 16 && i <= 41) {
        hSum += val;
        hCount++;
      }
    }

    bass = bCount > 0 ? bSum / bCount : 0;
    mid  = mCount > 0 ? mSum / mCount : 0;
    high = hCount > 0 ? hSum / hCount : 0;

    // Master amplitude
    master = (audio.player.left.level() + audio.player.right.level()) / 2.0;
  }
}
