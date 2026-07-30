/**
 * SceneParam - one named, bounded, live-tweakable knob a scene exposes.
 *
 * The param IS the source of truth: a scene holds SceneParam fields and reads
 * `param.value` in drawScene(). Controller, keyboard, and the web UI all drive
 * the SAME object through one router (see applyParamNorm / paramNudge in the
 * main sketch), so adding a knob once makes it reachable from every input.
 *
 * A scene opts in by overriding IScene.getParams() (a default method, so
 * existing scenes need no changes). See ParamRouter.pde for the input plumbing.
 *
 * Conventions:
 *   id - stable lowercase key, used over the wire + for keyboard cycling
 *   label - short human text for HUD / web slider
 *   value - current, always within [min,max]
 *   norm - value expressed as 0..1 (what sliders and stick axes speak)
 */
class SceneParam {
  String id;
  String label;
  float  min, max;
  float  value;
  float  deflt;

  SceneParam(String id, String label, float min, float max, float value) {
    this.id = id;
    this.label = label;
    this.min = min;
    this.max = max;
    this.deflt = value;
    this.value = constrain(value, min, max);
  }

  // Absolute set, clamped to range.
  void set(float v) { value = constrain(v, min, max); }

  // Set from a 0..1 normalized position (sliders, stick axes).
  void setNorm(float t) { value = lerp(min, max, constrain(t, 0, 1)); }

  // Current value as 0..1 within [min,max] (for slider position / readout).
  float norm() { return (max == min) ? 0 : (value - min) / (max - min); }

  // Relative nudge by a fraction of the full range (keyboard / d-pad steps).
  void nudgeNorm(float dt) { setNorm(norm() + dt); }

  void reset() { value = deflt; }
}
