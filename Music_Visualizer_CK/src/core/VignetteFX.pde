/**
 * VignetteFX — Cinematic dark-edge vignette.
 *
 * Uses fx_vignette.glsl. Near-zero GPU cost.
 * Bass slightly pulses the vignette radius inward on drops.
 */
class VignetteFX implements IPostFX {
  private PShader shader;
  private boolean enabled;
  private float   intensity = 0.8;

  VignetteFX() {
    enabled = false;
    shader  = loadShader("fx_vignette.glsl");
  }

  String  label()               { return "Vignette"; }
  boolean isEnabled()           { return enabled; }
  void    setEnabled(boolean v) { enabled = v; }
  boolean isCPUEffect()         { return false; }
  void    applyCPU(PGraphics pg) {}

  void onUpdate() {
    shader.set("u_intensity", intensity);
    shader.set("u_bass",      analyzer.bass);
  }

  void applyGLSL(PGraphics src, PGraphics dst) {
    dst.beginDraw();
    dst.background(0);
    dst.shader(shader);
    dst.imageMode(CORNER);
    dst.image(src, 0, 0, dst.width, dst.height);
    dst.resetShader();
    dst.endDraw();
  }
}
