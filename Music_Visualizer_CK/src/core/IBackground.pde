/**
 * IBackground
 *
 * Interface for swappable background layers in combo scenes.
 * Implementations draw a full-screen background to the given PGraphics.
 * Blend mode is BLEND on entry; implementation may use ADD/etc. internally
 * but must restore to BLEND before returning.
 */
interface IBackground {
  void drawBackground(PGraphics pg);
  String label();
}
