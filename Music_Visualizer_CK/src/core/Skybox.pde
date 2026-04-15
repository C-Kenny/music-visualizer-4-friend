/**
 * Skybox
 *
 * Reusable 6-face cubemap skybox for any 3D scene.
 *
 * Usage:
 *   Skybox skybox = new Skybox();
 *   skybox.load("absolute/path/to/cubemap/dir");  // px/nx/py/ny/pz/nz .png
 *   // inside drawScene, after camera rotations, before geometry:
 *   skybox.draw(canvas);
 *
 * Pass an absolute path — relative paths won't resolve from inside a class.
 * Processing builds to .build/Music_Visualizer_CK/ so use sketchPath("../../media/...")
 * to reach the project media folder.
 */
class Skybox {
  PImage[] faces = new PImage[6]; // order: px, nx, py, ny, pz, nz
  float size     = 2000;          // cube half-extent — stays within far-clip for all resolutions
  boolean loaded = false;

  void load(String dirPath) {
    String base = dirPath.endsWith("/") ? dirPath : dirPath + "/";
    String[] names = { "px.png", "nx.png", "py.png", "ny.png", "pz.png", "nz.png" };
    loaded = true;
    for (int i = 0; i < 6; i++) {
      faces[i] = loadImage(base + names[i]);
      if (faces[i] == null) {
        println("Skybox: MISSING " + base + names[i]);
        loaded = false;
      }
    }
    println(loaded ? "Skybox: loaded OK  " + base : "Skybox: FAILED  " + base);
  }

  /**
   * Draw the skybox. Renders before all other geometry using DISABLE_DEPTH_TEST
   * so it always appears as the background regardless of cube size or clip planes.
   * Full ambient light (255) ensures textures appear at correct brightness.
   */
  void draw(PGraphics canvas) {
    if (!loaded) return;
    canvas.pushStyle();
    canvas.noStroke();
    canvas.textureMode(IMAGE);

    // Full ambient so textures render at true color — noLights() would make them black
    canvas.ambientLight(255, 255, 255);
    canvas.fill(255);

    // Render before scene geometry; depth-test off so skybox is always behind everything
    canvas.hint(DISABLE_DEPTH_TEST);

    // Face file convention for this skybox pack: PX=FRONT, NX=BACK, PZ=RIGHT, NZ=LEFT, PY=UP, NY=DOWN
    // Processing default camera looks in -Z direction, so:
    //   -Z cube face = FRONT = px  |  +Z cube face = BACK  = nx
    //   +X cube face = RIGHT = pz  |  -X cube face = LEFT  = nz
    //   -Y cube face = UP   = py   |  +Y cube face = DOWN  = ny  (Processing Y is flipped)
    float s = size;
    // Vertex winding: v0=TL, v1=TR, v2=BR, v3=BL  →  UV (0,0)(w,0)(w,h)(0,h)
    // Verified empirically with sign-encoded equirectangular via py360convert:
    //   px F: TL=(-X+Y-Z) TR=(+X+Y-Z) BL=(-X-Y-Z) BR=(+X-Y-Z)
    //   pz R: TL=(+X+Y-Z) TR=(+X+Y+Z) BL=(+X-Y-Z) BR=(+X-Y+Z)
    //   nx B: TL=(+X+Y+Z) TR=(-X+Y+Z) BL=(+X-Y+Z) BR=(-X-Y+Z)
    //   nz L: TL=(-X+Y+Z) TR=(-X+Y-Z) BL=(-X-Y+Z) BR=(-X-Y-Z)
    //   py U: TL=(-X+Y+Z) TR=(+X+Y+Z) BL=(-X+Y-Z) BR=(+X+Y-Z)  [+Y=up in py360=-Y in Processing=ceiling]
    //   ny D: TL=(-X-Y-Z) TR=(+X-Y-Z) BL=(-X-Y+Z) BR=(+X-Y+Z)  [-Y=down in py360=+Y in Processing=floor]
    _face(canvas, faces[4],  s,-s,-s,   s,-s, s,   s, s, s,   s, s,-s);  // +X right  → pz (RIGHT)
    _face(canvas, faces[5], -s,-s, s,  -s,-s,-s,  -s, s,-s,  -s, s, s);  // -X left   → nz (LEFT)
    _face(canvas, faces[3], -s, s,-s,   s, s,-s,   s, s, s,  -s, s, s);  // +Y floor  → ny (DOWN)
    _face(canvas, faces[2], -s,-s, s,   s,-s, s,   s,-s,-s,  -s,-s,-s);  // -Y ceiling → py (UP)
    _face(canvas, faces[1],  s,-s, s,  -s,-s, s,  -s, s, s,   s, s, s);  // +Z back   → nx (BACK)
    _face(canvas, faces[0], -s,-s,-s,   s,-s,-s,   s, s,-s,  -s, s,-s);  // -Z front  → px (FRONT)

    canvas.hint(ENABLE_DEPTH_TEST);
    canvas.popStyle();
  }

  private void _face(PGraphics canvas, PImage img,
                     float x0, float y0, float z0,
                     float x1, float y1, float z1,
                     float x2, float y2, float z2,
                     float x3, float y3, float z3) {
    float w = img.width, h = img.height;
    canvas.beginShape(QUADS);
    canvas.texture(img);
    canvas.vertex(x0, y0, z0,  0, 0);
    canvas.vertex(x1, y1, z1,  w, 0);
    canvas.vertex(x2, y2, z2,  w, h);
    canvas.vertex(x3, y3, z3,  0, h);
    canvas.endShape();
  }
}
