/**
 * TunnelBackground — IBackground wrapper around Tunnel.
 *
 * Audio reactivity:
 *   Sustained bass (above 0.55 for ~1s) → zoomSustain ramps up and accelerates
 *   tunnel zoom. Every beat onset fires a short twist spike. If a beat hits
 *   while sustain is already loaded, a larger "drop twist" fires — the tunnel
 *   wrings sharply, then eases back. This matches how live drops feel.
 *
 * Tunnel.pde renders at 1/3 resolution internally (RENDER_SCALE=3) and
 * upscales itself — no additional buffer needed here.
 */
class TunnelBackground implements IBackground {
  Tunnel tunnel;
  TriggerEngine zoomSustain = new TriggerEngine(0.55, 0.04, 0.025);
  float twistValue = 0;   // small per-beat twist spike (fast decay)
  float dropTwist  = 0;   // large twist fired on beat-after-buildup (slow decay)
  float zoomSpeed  = 0;   // per-beat zoom kick

  TunnelBackground() { tunnel = new Tunnel(); }

  void drawBackground(PGraphics pg) {
    zoomSustain.update(analyzer.bass);
    float sustain = zoomSustain.getValue();

    if (audio.beat.isOnset()) {
      zoomSpeed  = 3;
      twistValue = 1.0;
      if (sustain > 0.5) dropTwist = 1.0;   // drop: buildup + beat
    }
    zoomSpeed  = lerp(zoomSpeed,  0, 0.06);
    twistValue = lerp(twistValue, 0, 0.10);
    dropTwist  = lerp(dropTwist,  0, 0.035);

    int zoom  = (int)(zoomSpeed + analyzer.bass * 0.15 + sustain * 10);
    int twist = (int)(twistValue * 18 + dropTwist * 60);

    tunnel.draw(pg, zoom, twist, 0, pg.width);
  }

  String label() { return "Tunnel"; }
}
