/**
 * TempoLock — tap tempo + locked metronome grid.
 *
 * Minim's onset detector is good at finding kicks but drifts on
 * four-on-the-floor house/techno (every kick is a "beat" so the running
 * mean wanders). For beat-synced visual moves (TriggerEngine drops,
 * crossfades, scene snaps) we want a stable timing grid.
 *
 * Workflow:
 *   T          register a tap
 *   T x4       lock — average gap of last 4 taps becomes the BPM
 *   Shift+T    clear lock, return to onset following
 *
 * Locked grid uses millis() so it survives FPS variance — a frame stutter
 * doesn't shift the downbeat.
 *
 * Read state:
 *   tempoLock.isLocked()         — true if grid is authoritative
 *   tempoLock.gridBeatThisFrame()— true once per metronome tick (locked only)
 *   tempoLock.bpm                — current locked BPM (0 if unlocked)
 */
class TempoLock {
  static final int   MAX_TAPS         = 8;
  static final int   LOCK_AFTER_TAPS  = 4;
  static final long  TAP_WINDOW_MS    = 2500;  // taps older than this evicted
  static final float MIN_BPM          = 60;
  static final float MAX_BPM          = 200;

  ArrayList<Long> taps = new ArrayList<Long>();
  boolean locked   = false;
  float   bpm      = 0;
  long    lockEpochMs = 0;
  long    beatPeriodMs = 0;

  // Internal: which logical metronome tick we last reported as a beat.
  long lastReportedTick = -1;

  void tap() {
    long now = System.currentTimeMillis();
    // Evict stale
    while (!taps.isEmpty() && now - taps.get(0) > TAP_WINDOW_MS * 2) {
      taps.remove(0);
    }
    taps.add(now);
    while (taps.size() > MAX_TAPS) taps.remove(0);

    if (taps.size() >= LOCK_AFTER_TAPS) {
      // Average gap across last LOCK_AFTER_TAPS taps
      int n = min(taps.size(), LOCK_AFTER_TAPS);
      long sumGap = 0;
      int  gaps   = 0;
      for (int i = taps.size() - n + 1; i < taps.size(); i++) {
        sumGap += taps.get(i) - taps.get(i - 1);
        gaps++;
      }
      if (gaps > 0) {
        float avgGap = sumGap / (float) gaps;
        float candidate = 60000.0 / avgGap;
        if (candidate >= MIN_BPM && candidate <= MAX_BPM) {
          bpm           = candidate;
          beatPeriodMs  = (long)(60000.0 / bpm);
          lockEpochMs   = taps.get(taps.size() - 1); // latest tap = downbeat
          locked        = true;
          lastReportedTick = -1;
          println("[TEMPO] locked at " + nf(bpm, 1, 2) + " BPM (period " + beatPeriodMs + "ms)");
        }
      }
    } else {
      println("[TEMPO] tap " + taps.size() + "/" + LOCK_AFTER_TAPS);
    }
  }

  void clear() {
    taps.clear();
    locked = false;
    bpm = 0;
    beatPeriodMs = 0;
    lastReportedTick = -1;
    println("[TEMPO] cleared");
  }

  boolean isLocked() { return locked; }

  // True exactly once per metronome tick. Caller invokes once per frame.
  boolean gridBeatThisFrame() {
    if (!locked || beatPeriodMs <= 0) return false;
    long now  = System.currentTimeMillis();
    long tick = (now - lockEpochMs) / beatPeriodMs;
    if (tick != lastReportedTick && tick >= 0) {
      lastReportedTick = tick;
      return true;
    }
    return false;
  }

  String statusLabel() {
    if (locked) return "LOCK " + nf(bpm, 1, 1) + " BPM";
    if (taps.size() > 0) return "TAP " + taps.size() + "/" + LOCK_AFTER_TAPS;
    return "FOLLOW";
  }
}
