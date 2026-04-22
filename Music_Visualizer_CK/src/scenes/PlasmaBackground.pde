/**
 * PlasmaBackground — IBackground wrapper around Plasma.
 * config.PLASMA_SEED drives palette animation (same as OriginalScene).
 */
class PlasmaBackground implements IBackground {
  Plasma plasma;

  PlasmaBackground() { plasma = new Plasma(); }

  void drawBackground(PGraphics pg) {
    plasma.draw(pg, config.PLASMA_SEED);
  }

  String label() { return "Plasma"; }
}
