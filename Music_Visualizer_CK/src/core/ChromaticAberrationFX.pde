/**
 * ChromaticAberrationFX — RGB channel split + animated glitch band.
 *
 * Uses fx_chromatic.glsl. Intensity is audio-reactive:
 *   - Base split scales with bass energy
 *   - On beat, intensity spikes then decays
 */
class ChromaticAberrationFX implements IPostFX {
  private PShader shader;
  private boolean enabled;
  private float   intensity = 0.0;
  private float   targetIntensity = 0.5;

  ChromaticAberrationFX() {
    enabled = false;
    shader  = loadShader("fx_chromatic.glsl");
  }

  String  label()               { return "ChromAb"; }
  boolean isEnabled()           { return enabled; }
  void    setEnabled(boolean v) { enabled = v; }
  boolean isCPUEffect()         { return false; }
  void    applyCPU(PGraphics pg) {}

  void onUpdate() {
    // Spike on beat, decay otherwise
    if (analyzer.isBeat) {
      targetIntensity = min(1.0, 0.6 + analyzer.bass * 0.5);
    } else {
      targetIntensity = max(0.35, targetIntensity * 0.95);
    }
    intensity = lerp(intensity, targetIntensity, 0.15);

    shader.set("u_bass",      analyzer.bass);
    shader.set("u_intensity", intensity);
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
