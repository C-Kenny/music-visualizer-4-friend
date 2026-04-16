/**
 * TunnelBackground — IBackground wrapper around Tunnel.
 * Audio: bass drives zoom, beat onset drives twist spike.
 *
 * Tunnel.pde already renders at 1/3 resolution internally (RENDER_SCALE=3)
 * and upscales itself — no additional buffer needed here.
 */
class TunnelBackground implements IBackground {
  Tunnel tunnel;
  float  zoomSpeed = 0;

  TunnelBackground() { tunnel = new Tunnel(); }

  void drawBackground(PGraphics pg) {
    if (audio.beat.isOnset()) zoomSpeed = 3;
    zoomSpeed = lerp(zoomSpeed, 0, 0.06);
    int zoom = (int)(zoomSpeed + analyzer.bass * 0.15);
    tunnel.draw(pg, zoom, 0, 0, pg.width);
  }

  String label() { return "Tunnel"; }
}
