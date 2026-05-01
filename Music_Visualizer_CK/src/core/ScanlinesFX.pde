/**
 * ScanlinesFX — CRT scanlines + film grain post-FX.
 *
 * Uses fx_scanlines.glsl. Very cheap (single texture sample + math per pixel).
 * Intensity is mostly static; bass slightly thickens the scanlines on drops.
 */
class ScanlinesFX implements IPostFX {
  private PShader shader;
  private boolean enabled;
  private float   intensity = 0.7; // fixed strength — visible but not distracting

  ScanlinesFX() {
    enabled = false;
    shader  = loadShader("fx_scanlines.glsl");
  }

  String  label()               { return "VHS"; }
  boolean isEnabled()           { return enabled; }
  void    setEnabled(boolean v) { enabled = v; }
  boolean isCPUEffect()         { return false; }
  void    applyCPU(PGraphics pg) {}

  void onUpdate() {
    shader.set("u_intensity", intensity);
    shader.set("u_bass",      analyzer.bass);
    shader.set("u_time",      millis() / 1000.0);
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
