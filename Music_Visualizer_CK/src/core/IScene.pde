/**
 * IScene
 *
 * The standard interface for all visualizer scenes.
 * This allows the main sketch to manage scenes uniformly via a registry.
 */
interface IScene {
  /**
   * Main render method called every frame when this scene is active.
   * Renders its visuals to the provided PGraphics buffer.
   */
  void drawScene(PGraphics pg);

  /**
   * Called once when the application switches TO this scene.
   * Use for resetting state or initializing transients.
   */
  void onEnter();

  /**
   * Called once when the application switches AWAY from this scene.
   * Use for cleanup.
   */
  void onExit();

  /**
   * Handles gamepad/controller input for the active scene.
   */
  void applyController(Controller c);

  /**
   * Handles scene-specific keyboard input.
   */
  void handleKey(char k);

  /**
   * Called when the mouse wheel is scrolled. delta is -1 (up/zoom-in) or +1 (down/zoom-out).
   * Default: no-op. Override in scenes that support scroll-zoom.
   */
  default void handleMouseWheel(int delta) {}

  /**
   * Optional: live-tweakable knobs this scene exposes (see SceneParam).
   * Returned objects are the source of truth - the scene reads param.value in
   * drawScene(). Controller, keyboard, and the web UI all drive these same
   * objects through ParamRouter, so declaring a knob here makes it reachable
   * from every input at once. Default: none.
   */
  default SceneParam[] getParams() { return null; }

  /**
   * Returns an array of strings to display in the code overlay.
   * Return an empty array if no overlay is needed.
   */
  String[] getCodeLines();

  /**
   * Returns an array of controller mappings describing this scene's controls.
   * Used to dynamically render a "Controller Guide" overlay.
   * Return an empty array or null if no guide is needed.
   *
   * Example:
   *   new ControllerLayout("LStick ↕", "Rotate faster"),
   *   new ControllerLayout("A Button", "Inject beat"),
   */
  ControllerLayout[] getControllerLayout();
}
