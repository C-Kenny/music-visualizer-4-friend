/**
 * IPostFX — Interface for all post-processing effects in the PostFX stack.
 *
 * Two effect types:
 *   CPU effects  (isCPUEffect() == true):  call applyCPU(pg) — modifies pg pixels in-place.
 *   GLSL effects (isCPUEffect() == false): call applyGLSL(src, dst) — blits src → dst via shader.
 *
 * CPU effects run first (directly on sceneBuffer), then GLSL effects are
 * ping-ponged through temp buffers. The stack returns the final buffer to blit.
 *
 * All effects receive an onUpdate() call every frame while enabled so they can
 * track audio-reactive state (e.g. beat counters, lerped intensities).
 */
interface IPostFX {
  /** Short display name shown in the HUD badge, e.g. "Bloom", "Glitch". */
  String label();

  boolean isEnabled();
  void setEnabled(boolean v);

  /** Called every logical frame. Update audio-reactive uniforms / state here. */
  void onUpdate();

  /**
   * true  → CPU effect: implement applyCPU(), stack ignores applyGLSL().
   * false → GLSL effect: implement applyGLSL(), stack ignores applyCPU().
   */
  boolean isCPUEffect();

  /** CPU path: modify pg.pixels[] in-place. Must call pg.loadPixels() / pg.updatePixels(). */
  void applyCPU(PGraphics pg);

  /**
   * GLSL path: blit src → dst using a shader.
   * Must call dst.beginDraw(), dst.endDraw(), and dst.resetShader() internally.
   */
  void applyGLSL(PGraphics src, PGraphics dst);
}
