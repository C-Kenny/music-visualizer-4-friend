/**
 * PostFXStack — Global post-processing pipeline manager.
 *
 * Usage in draw():
 *   PGraphics toDisplay = postFX.process(sceneBuffer);
 *   image(toDisplay, 0, 0, width, height);
 *
 * Architecture:
 *   1. CPU effects run first, modifying sceneBuffer pixels in-place.
 *   2. GLSL effects are applied in order via ping-pong between two temp buffers.
 *   3. Returns the final buffer (sceneBuffer if no GLSL effects were active,
 *      otherwise the last temp buffer written by the GLSL chain).
 *
 * Temp buffers are lazily created and resized to match sceneBuffer dimensions.
 */
class PostFXStack {
  ArrayList<IPostFX> effects = new ArrayList<IPostFX>();

  // Ping-pong buffers for GLSL effect chaining.
  // Only allocated when a GLSL effect is actually enabled.
  private PGraphics pingBuf;
  private PGraphics pongBuf;

  // -1 = OFF, otherwise index of single active effect.
  private int activeIndex = -1;

  // ── Public API ─────────────────────────────────────────────────────────────

  void add(IPostFX fx) {
    effects.add(fx);
  }

  IPostFX get(int i) {
    return effects.get(i);
  }

  int size() {
    return effects.size();
  }

  /**
   * Cycle: solo the next effect. Order: OFF → fx0 → fx1 → ... → fxN → OFF.
   * Only one effect active at a time.
   */
  void cycleNext() {
    activeIndex++;
    if (activeIndex >= effects.size()) activeIndex = -1;
    syncEnabled();
  }

  void disableAll() {
    activeIndex = -1;
    syncEnabled();
  }

  void setActive(int idx) {
    activeIndex = (idx < 0 || idx >= effects.size()) ? -1 : idx;
    syncEnabled();
  }

  private void syncEnabled() {
    for (int i = 0; i < effects.size(); i++) {
      effects.get(i).setEnabled(i == activeIndex);
    }
  }

  /** Comma-separated list of enabled effect labels for the HUD badge. */
  String getActiveBadge() {
    StringBuilder sb = new StringBuilder();
    for (IPostFX fx : effects) {
      if (fx.isEnabled()) {
        if (sb.length() > 0) sb.append(", ");
        sb.append(fx.label());
      }
    }
    return sb.toString();
  }

  boolean anyEnabled() {
    for (IPostFX fx : effects) {
      if (fx.isEnabled()) return true;
    }
    return false;
  }

  // ── Core processing ────────────────────────────────────────────────────────

  /**
   * Apply all enabled effects and return the buffer to blit to the screen.
   * May return src itself (CPU-only or no effects) or a temp GLSL buffer.
   */
  PGraphics process(PGraphics src) {
    boolean calm = config.HEADACHE_FREE_MODE;

    // Update all enabled effects' audio-reactive state this frame
    for (IPostFX fx : effects) {
      if (fx.isEnabled() && !suppressedInCalm(fx, calm)) fx.onUpdate();
    }

    // 1. CPU pass — modifies src pixels in-place
    for (IPostFX fx : effects) {
      if (fx.isEnabled() && fx.isCPUEffect() && !suppressedInCalm(fx, calm)) {
        fx.applyCPU(src);
      }
    }

    // 2. GLSL pass — ping-pong between temp buffers
    ensureBuffers(src.width, src.height);

    PGraphics current = src;
    boolean usingPing = true; // next write target

    for (IPostFX fx : effects) {
      if (!fx.isEnabled() || fx.isCPUEffect()) continue;
      if (suppressedInCalm(fx, calm)) continue;

      PGraphics dst = usingPing ? pingBuf : pongBuf;
      fx.applyGLSL(current, dst);
      current  = dst;
      usingPing = !usingPing;
    }

    return current;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  // Glitch / VHS / chromatic aberration spike visual intensity — skip when
  // the user wants a calm session. Bloom and Vignette are softening and stay on.
  private boolean suppressedInCalm(IPostFX fx, boolean calm) {
    if (!calm) return false;
    String l = fx.label();
    return l.equals("Glitch") || l.equals("VHS") || l.equals("ChromAb");
  }

  private void ensureBuffers(int w, int h) {
    if (pingBuf == null || pingBuf.width != w || pingBuf.height != h) {
      pingBuf = createGraphics(w, h, P3D);
      pingBuf.smooth(4);
    }
    if (pongBuf == null || pongBuf.width != w || pongBuf.height != h) {
      pongBuf = createGraphics(w, h, P3D);
      pongBuf.smooth(4);
    }
  }
}
