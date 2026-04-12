/**
 * DropPredictor
 * 
 * Scans the audio file in a background thread to identify high-energy "drops".
 * Allows scenes to anticipate major rhythmic shifts.
 */
class DropPredictor implements Runnable {
  ArrayList<Float> dropTimes;      // Strong peaks (top 18% energy)
  ArrayList<Float> majorDropTimes; // Massive drops (top 5% energy) — flip candidates
  boolean isScanning = false;
  boolean isReady = false;
  String songPath;
  float threshold = 0.85;

  DropPredictor() {
    dropTimes      = new ArrayList<Float>();
    majorDropTimes = new ArrayList<Float>();
  }

  void scan(String path) {
    this.songPath = path;
    this.isReady = false;
    this.dropTimes.clear();
    this.majorDropTimes.clear();
    Thread t = new Thread(this);
    t.start();
  }

  public void run() {
    isScanning = true;
    try {
      // Load sample separately to avoid interfering with playback
      AudioSample sample = audio.minim.loadSample(songPath, 1024);
      if (sample == null) return;

      float[] left = sample.getChannel(AudioSample.LEFT);
      float[] right = sample.getChannel(AudioSample.RIGHT);
      float rate = sample.sampleRate();
      int totalSamples = left.length;

      // Scan in 200ms windows
      int windowSize = (int)(rate * 0.2); 
      float maxFound = 0;
      float[] energies = new float[totalSamples / windowSize];

      for (int i = 0; i < energies.length; i++) {
        float windowMax = 0;
        for (int j = 0; j < windowSize; j++) {
          int idx = i * windowSize + j;
          if (idx >= totalSamples) break;
          float val = (abs(left[idx]) + abs(right[idx])) / 2.0;
          if (val > windowMax) windowMax = val;
        }
        energies[i] = windowMax;
        if (windowMax > maxFound) maxFound = windowMax;
      }

      // Tier 1: strong peaks (top 18% energy)
      float worldThreshold = maxFound * 0.82;
      ArrayList<float[]> candidates = new ArrayList<float[]>(); // [timeMs, energy]
      for (int i = 1; i < energies.length - 1; i++) {
        if (energies[i] > worldThreshold && energies[i] > energies[i-1] && energies[i] > energies[i+1]) {
          float timeMs = (i * windowSize / rate) * 1000.0;
          dropTimes.add(timeMs);
          candidates.add(new float[]{ timeMs, energies[i] });
          i += (int)(rate * 2.0 / windowSize);
        }
      }

      // Tier 2: adaptive — always pick the top 10 strongest peaks as major drop targets.
      // This ensures flip candidates exist for any song regardless of dynamic range.
      candidates.sort(new java.util.Comparator<float[]>() {
        public int compare(float[] a, float[] b) { return Float.compare(b[1], a[1]); }
      });
      int majorCount = min(20, candidates.size());
      for (int i = 0; i < majorCount; i++) majorDropTimes.add(candidates.get(i)[0]);
      // Re-sort by time for timeline display
      majorDropTimes.sort(new java.util.Comparator<Float>() {
        public int compare(Float a, Float b) { return Float.compare(a, b); }
      });

      sample.close();
      isReady = true;
    } catch (Exception e) {
      System.err.println("DropPredictor failed: " + e.getMessage());
    } finally {
      isScanning = false;
    }
  }

  /**
   * Returns a value from 0..1 indicating how close we are to a predicted drop.
   * 1.0 means the drop is NOW.
   */
  float imminentDropFactor(float currentTimeMs, float windowSeconds) {
    if (!isReady || dropTimes.isEmpty()) return 0;
    float windowMs = windowSeconds * 1000.0;
    float best = 0;
    for (float drop : dropTimes) {
      float diff = drop - currentTimeMs;
      if (diff > 0 && diff < windowMs) {
        float f = 1.0 - (diff / windowMs);
        if (f > best) best = f;
      }
    }
    return best;
  }

  /**
   * Same as imminentDropFactor but for the top-10 MAJOR drop targets only.
   * Use this for flip triggers — guaranteed candidates for any song.
   */
  float majorImminentDropFactor(float currentTimeMs, float windowSeconds) {
    if (!isReady || majorDropTimes.isEmpty()) return 0;
    float windowMs = windowSeconds * 1000.0;
    float best = 0;
    for (float drop : majorDropTimes) {
      float diff = drop - currentTimeMs;
      if (diff > 0 && diff < windowMs) {
        float f = 1.0 - (diff / windowMs);
        if (f > best) best = f;
      }
    }
    return best;
  }
}
