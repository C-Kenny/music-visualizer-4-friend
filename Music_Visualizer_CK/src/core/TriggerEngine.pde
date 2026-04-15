/**
 * TriggerEngine
 *
 * Smooths a float 0→1 when an input signal crosses a threshold, then eases
 * back to 0. Scenes poll getValue() each frame to drive large-scale effects.
 *
 * Two usage patterns:
 *   Level follower — call update(signal) every frame; value tracks when signal
 *                    exceeds threshold, decays when it drops below.
 *   One-shot pulse — call fire() directly (e.g. on a beat onset); value snaps
 *                    to 1 and decays at decayRate.
 *
 * Example:
 *   TriggerEngine zoom = new TriggerEngine(0.7, 0.06, 0.03);
 *   zoom.update(analyzer.bass);            // each frame
 *   tunnelSpeed += zoom.getValue() * 6;    // use result
 */
class TriggerEngine {
  float threshold;
  float riseRate;   // lerp rate toward 1 when input >= threshold  (0..1)
  float decayRate;  // lerp rate toward 0 when input < threshold   (0..1)
  float value = 0;

  TriggerEngine(float threshold, float riseRate, float decayRate) {
    this.threshold = threshold;
    this.riseRate  = riseRate;
    this.decayRate = decayRate;
  }

  // Call once per frame with the driving signal (expected range 0..1).
  void update(float input) {
    float target = (input >= threshold) ? 1.0 : 0.0;
    float rate   = (target > value) ? riseRate : decayRate;
    value = lerp(value, target, rate);
  }

  // Snap value to 1.0 immediately — will decay each subsequent frame.
  void fire() { value = 1.0; }

  float getValue() { return value; }
  void  reset()    { value = 0; }
}
