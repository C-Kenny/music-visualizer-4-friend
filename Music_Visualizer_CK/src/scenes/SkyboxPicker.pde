/**
 * SkyboxPicker — lightweight skybox-cycling helper for individual scenes.
 *
 * Holds one active Skybox at a time (loaded on cycle).
 * Index 0 = none.  Indices 1..N = discovered cubemap directories.
 *
 * Discovery: scans media/skyboxes/ at construction time and includes any
 * subdirectory that contains px.png (all 6 faces assumed present).
 *
 * Pattern A (3D buf with camera): call draw3D(buf) after buf.camera+perspective, before geometry.
 * Pattern B (2D/direct pg):       call drawBg2D(pg) to replace pg.background().
 *
 * Key binding convention: s = next sky, S = prev sky
 * Controller: dpad right = next, dpad left = prev
 */

// ── Top-level helper — scan media/skyboxes/ for valid cubemap directories ────
// Returns sorted array of directory names that contain px.png.
String[] discoverSkyboxNames() {
  String root = sketchPath("../../media/skyboxes/");
  java.io.File dir = new java.io.File(root);
  java.io.File[] entries = dir.listFiles();
  if (entries == null) {
    println("discoverSkyboxNames: skyboxes dir not found at " + root);
    return new String[0];
  }
  java.util.ArrayList<String> names = new java.util.ArrayList<String>();
  for (java.io.File f : entries) {
    if (f.isDirectory() && new java.io.File(f, "px.png").exists()) {
      names.add(f.getName());
    }
  }
  java.util.Collections.sort(names);
  println("discoverSkyboxNames: found " + names.size() + " skyboxes in " + root);
  return names.toArray(new String[0]);
}

// ─────────────────────────────────────────────────────────────────────────────

class SkyboxPicker {
  final String[] NAMES;

  Skybox box = null;
  int    idx = 0;    // 0 = none
  float  rotX = 0.15, rotY = 0;  // animated drift for 2D mode

  SkyboxPicker() {
    String[] dirs = discoverSkyboxNames();
    NAMES = new String[dirs.length + 1];
    NAMES[0] = "none";
    for (int i = 0; i < dirs.length; i++) NAMES[i + 1] = dirs[i];
  }

  void next() { _setIdx(idx + 1); }
  void prev() { _setIdx(idx - 1); }
  boolean active() { return idx > 0; }
  String  label()  { return NAMES[idx]; }

  // Pattern A: draw directly into 3D buf. Call after camera+perspective, before geometry.
  // Skybox.draw uses DISABLE_DEPTH_TEST so it is always rendered behind everything.
  void draw3D(PGraphics buf) {
    if (box == null || !box.loaded) return;
    box.draw(buf);
  }

  // Pattern B: draw as animated 2D-style background onto pg.
  // Replaces pg.background(). Returns true if drawn (caller skips own bg call).
  boolean drawBg2D(PGraphics pg) {
    if (box == null || !box.loaded) return false;
    rotY += 0.0008 + analyzer.bass * 0.002;
    rotX  = lerp(rotX, 0.15 + sin(rotY * 0.4) * 0.08, 0.02);
    pg.background(0);
    pg.pushMatrix();
    pg.translate(pg.width / 2, pg.height / 2);
    pg.rotateX(rotX);
    pg.rotateY(rotY);
    box.draw(pg);
    pg.popMatrix();
    pg.blendMode(BLEND);
    return true;
  }

  private void _setIdx(int newIdx) {
    int total = NAMES.length;
    newIdx = ((newIdx % total) + total) % total;
    if (newIdx == idx) return;
    idx = newIdx;
    if (idx == 0) { box = null; return; }
    box = new Skybox();
    box.load(sketchPath("../../media/skyboxes/" + NAMES[idx]));
  }
}
