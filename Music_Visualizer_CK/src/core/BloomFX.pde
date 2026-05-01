/**
 * BloomFX — Wraps the existing bloom.glsl as an IPostFX GLSL effect.
 *
 * Migrated from the hardcoded bloom pass in Music_Visualizer_CK.pde.
 * Behavior is identical; it just lives in the PostFX stack now.
 */
class BloomFX implements IPostFX {
  private PShader shader;
  private boolean enabled;

  BloomFX() {
    enabled = false;
    shader  = loadShader("bloom.glsl");
  }

  String  label()            { return "Bloom"; }
  boolean isEnabled()        { return enabled; }
  void    setEnabled(boolean v) { enabled = v; }
  boolean isCPUEffect()      { return false; }
  void    onUpdate()         {} // bloom has no audio-reactive uniforms currently
  void    applyCPU(PGraphics pg) {}

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
