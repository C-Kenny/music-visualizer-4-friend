/**
 * IScene
 *
 * The standard interface for all visualizer scenes.
 * This allows the main sketch to manage scenes uniformly via a registry.
 */
interface IScene {
  /**
   * Main render method called every frame when this scene is active.
   */
  void drawScene();

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
   * Returns an array of strings to display in the code overlay.
   * Return an empty array if no overlay is needed.
   */
  String[] getCodeLines();
}
