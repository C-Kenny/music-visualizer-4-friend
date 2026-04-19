/**
 * SkyboxBackground — IBackground wrapping the Skybox cubemap renderer.
 * Slowly pans the camera around the skybox; bass nudges speed.
 * Requires sceneBuffer to be P3D (it is).
 */
class SkyboxBackground implements IBackground {
  Skybox skybox;
  String dirName;
  String displayName;
  float  camRotY = 0;
  float  camRotX = 0.15;  // gentle upward tilt

  SkyboxBackground(String skyboxDirName) {
    skybox      = new Skybox();
    dirName     = skyboxDirName;
    displayName = skyboxDirName;
    // Lazy-load: don't call skybox.load() here — deferred to first drawBackground()
  }

  void drawBackground(PGraphics pg) {
    // Load on first use so setup() doesn't block loading 150 PNGs at once
    if (!skybox.loaded) {
      skybox.load(sketchPath("../../media/skyboxes/" + dirName));
    }

    pg.background(0);
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2);

    // Slow auto-pan; bass adds a subtle extra drift
    camRotY += 0.0008 + analyzer.bass * 0.002;
    camRotX  = lerp(camRotX, 0.15 + sin(camRotY * 0.4) * 0.08, 0.02);

    pg.rotateX(camRotX);
    pg.rotateY(camRotY);
    skybox.draw(pg);
    pg.popMatrix();
    pg.blendMode(BLEND);
  }

  String label() { return displayName; }
}
