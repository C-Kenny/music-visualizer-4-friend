/**
 * IForeground
 *
 * Interface for swappable foreground layers in combo scenes.
 * drawForeground() must:
 *   - NOT call pg.background(), beginDraw(), or endDraw()
 *   - wrap any pg.translate/rotate in pushMatrix/popMatrix
 *   - restore colorMode to RGB,255 if it changed it
 *   - restore hint(ENABLE_DEPTH_TEST) if it disabled it
 *   - leave blendMode as BLEND when done
 */
interface IForeground {
  void drawForeground(PGraphics pg);
  String fgLabel();
}
