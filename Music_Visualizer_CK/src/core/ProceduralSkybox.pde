/**
 * ProceduralSkybox - copyright-free cubemaps generated at runtime, plus the
 * path routing that lets venues drop in their own licensed skybox packs.
 *
 * Why: the bundled media/skyboxes/ assets have unclear licensing, so they are
 * gitignored and must NOT ship in releases (.deb etc). Instead:
 *
 *   1. User-supplied packs - <userDataDir>/skyboxes/<name>/px.png..nz.png.
 *      The venue provides assets THEY have rights to. User dir shadows any
 *      same-named bundled pack.
 *   2. Generated fallbacks - three "auto_*" skyboxes below are pure code, so
 *      skybox scenes always have something to show on a fresh install.
 *
 * Seamlessness: every pixel is colored purely as a function of its view
 * DIRECTION on the unit sphere. Face corner tables are copied verbatim from
 * Skybox.draw()'s cube geometry, so adjacent faces sample identical directions
 * along shared edges - no visible seams, and orientation matches loaded packs.
 *
 * Cost: each style renders once per run (~0.9M px), then is cached. Palettes
 * are seeded from the first song's name, so every show gets its own tint.
 */

final String[] AUTO_SKYBOX_NAMES = { "auto_stars", "auto_nebula", "auto_horizon" };
final int      AUTO_SKYBOX_FACE_SIZE = 384;

java.util.HashMap<String, PImage[]> _autoSkyboxCache = new java.util.HashMap<String, PImage[]>();

boolean isAutoSkybox(String name) {
  return name != null && name.startsWith("auto_");
}

// Root for venue/user-provided packs: <userDataDir>/skyboxes/<name>/px.png …
String userSkyboxRoot() {
  String dir = userDataDir() + java.io.File.separator + "skyboxes";
  java.io.File d = new java.io.File(dir);
  if (!d.exists()) d.mkdirs(); // visible target for the user to drop packs into
  return dir;
}

// Resolve a skybox name to a directory: user packs win over bundled media.
String skyboxPath(String name) {
  java.io.File user = new java.io.File(userSkyboxRoot(), name);
  if (new java.io.File(user, "px.png").exists()) return user.getAbsolutePath();
  return resourcePath("media/skyboxes/" + name);
}

// The one loader every call site should use: routes auto_* names to the
// generator, everything else to disk (user dir first, then bundled).
void loadSkyboxByName(Skybox box, String name) {
  if (isAutoSkybox(name)) {
    box.faces  = autoSkyboxFaces(name);
    box.loaded = true;
    return;
  }
  box.load(skyboxPath(name));
}

// ── Generation ───────────────────────────────────────────────────────────────

PImage[] autoSkyboxFaces(String name) {
  PImage[] cached = _autoSkyboxCache.get(name);
  if (cached != null) return cached;

  long t0 = millis();
  // Palette hue seeded by the current song so each show gets its own cast.
  // floorMod: hashCode() may be negative (abs(MIN_VALUE) is too).
  int songHash = (config.SONG_NAME == null ? "x" : config.SONG_NAME).hashCode();
  float seedHue = Math.floorMod(songHash, 360) / 360.0;

  PImage[] faces = new PImage[6];
  for (int f = 0; f < 6; f++) {
    faces[f] = renderAutoFace(name, f, seedHue);
  }
  _autoSkyboxCache.put(name, faces);
  println("[ProceduralSkybox] generated " + name + " in " + (millis() - t0) + "ms");
  return faces;
}

// Face corner tables - same order Skybox stores faces (px,nx,py,ny,pz,nz) and
// the same cube corners Skybox.draw() textures them onto (TL,TR,BR,BL).
final float[][][] AUTO_FACE_CORNERS = {
  { {-1,-1,-1}, { 1,-1,-1}, { 1, 1,-1}, {-1, 1,-1} },  // px → front  (-Z)
  { { 1,-1, 1}, {-1,-1, 1}, {-1, 1, 1}, { 1, 1, 1} },  // nx → back   (+Z)
  { {-1,-1, 1}, { 1,-1, 1}, { 1,-1,-1}, {-1,-1,-1} },  // py → ceiling(-Y)
  { {-1, 1,-1}, { 1, 1,-1}, { 1, 1, 1}, {-1, 1, 1} },  // ny → floor  (+Y)
  { { 1,-1,-1}, { 1,-1, 1}, { 1, 1, 1}, { 1, 1,-1} },  // pz → right  (+X)
  { {-1,-1, 1}, {-1,-1,-1}, {-1, 1,-1}, {-1, 1, 1} },  // nz → left   (-X)
};

PImage renderAutoFace(String style, int faceIndex, float seedHue) {
  int n = AUTO_SKYBOX_FACE_SIZE;
  PImage img = createImage(n, n, RGB);
  img.loadPixels();

  float[] tl = AUTO_FACE_CORNERS[faceIndex][0];
  float[] tr = AUTO_FACE_CORNERS[faceIndex][1];
  float[] br = AUTO_FACE_CORNERS[faceIndex][2];
  float[] bl = AUTO_FACE_CORNERS[faceIndex][3];

  for (int j = 0; j < n; j++) {
    float v = j / (float) (n - 1);
    for (int i = 0; i < n; i++) {
      float u = i / (float) (n - 1);
      // Bilinear corner blend → direction on the cube, then normalize.
      float dx = lerp(lerp(tl[0], tr[0], u), lerp(bl[0], br[0], u), v);
      float dy = lerp(lerp(tl[1], tr[1], u), lerp(bl[1], br[1], u), v);
      float dz = lerp(lerp(tl[2], tr[2], u), lerp(bl[2], br[2], u), v);
      float len = sqrt(dx*dx + dy*dy + dz*dz);
      dx /= len; dy /= len; dz /= len;

      int rgb;
      if      (style.equals("auto_stars"))  rgb = autoStarsPixel (dx, dy, dz, seedHue);
      else if (style.equals("auto_nebula")) rgb = autoNebulaPixel(dx, dy, dz, seedHue);
      else                                  rgb = autoHorizonPixel(dx, dy, dz, seedHue);
      img.pixels[j * n + i] = rgb;
    }
  }
  img.updatePixels();
  return img;
}

// Cheap deterministic 3D-cell hash → 0..1. Stars must NOT use noise(): they
// need hard points, and we must not disturb the sketch's global noise field.
float autoCellHash(int x, int y, int z) {
  int h = x * 374761393 + y * 668265263 + z * 1274126177;
  h = (h ^ (h >> 13)) * 1103515245;
  return ((h ^ (h >> 16)) & 0x7fffffff) / (float) 0x7fffffff;
}

// STARS - two layers of hashed point stars + a whisper of milky tint.
int autoStarsPixel(float dx, float dy, float dz, float seedHue) {
  float bright = 0;

  // layer: (cellScale, starRadius, density)
  for (int layer = 0; layer < 2; layer++) {
    float cells  = (layer == 0) ? 44 : 16;
    float radius = (layer == 0) ? 0.10 : 0.16;  // in cell units
    float chance = (layer == 0) ? 0.18 : 0.10;
    int cx = floor(dx * cells), cy = floor(dy * cells), cz = floor(dz * cells);
    float gate = autoCellHash(cx + layer * 911, cy, cz);
    if (gate < chance) {
      // star sits at a hashed offset inside the cell
      float sx = cx + autoCellHash(cx, cy + 7, cz);
      float sy = cy + autoCellHash(cx + 3, cy, cz + 5);
      float sz = cz + autoCellHash(cx + 9, cy + 1, cz);
      float ex = dx * cells - sx, ey = dy * cells - sy, ez = dz * cells - sz;
      float d2 = ex*ex + ey*ey + ez*ez;
      float core = max(0, 1 - sqrt(d2) / radius);
      bright = max(bright, core * core * (0.5 + 0.5 * autoCellHash(cx, cy, cz + 13)));
    }
  }

  // faint band of galaxy haze (continuous over the sphere ⇒ seamless)
  float haze = noise(dx * 1.6 + 31.7, dy * 1.6 + 47.2, dz * 1.6 + 11.9);
  haze = max(0, haze - 0.52) * 0.55;

  float r = bright * 255 + haze * 70  * (0.6 + seedHue * 0.4);
  float g = bright * 245 + haze * 60;
  float b = bright * 235 + haze * 110 * (1.2 - seedHue * 0.4);
  return 0xff000000 | (min(255, (int) r) << 16) | (min(255, (int) g) << 8) | min(255, (int) b);
}

// NEBULA - 4-octave fbm over the sphere mapped through a 3-stop palette.
int autoNebulaPixel(float dx, float dy, float dz, float seedHue) {
  float amp = 0.5, freq = 1.3, sum = 0;
  for (int o = 0; o < 4; o++) {
    sum  += noise(dx * freq + 91.3, dy * freq + 12.7, dz * freq + 55.1) * amp;
    freq *= 2.1;
    amp  *= 0.5;
  }
  float t = constrain(map(sum, 0.25, 0.75, 0, 1), 0, 1);

  // Palette: near-black → deep seeded hue → hot core. HSB done by hand so we
  // don't depend on the caller's colorMode.
  float hue = (seedHue + 0.55 * t) % 1.0;
  float briL = t * t * 200;                  // dark sky stays dark
  float r = briL * (0.6 + 0.4 * cos(TWO_PI * hue));
  float g = briL * (0.45 + 0.4 * cos(TWO_PI * (hue + 0.33)));
  float b = briL * (0.7 + 0.3 * cos(TWO_PI * (hue + 0.66)));

  // sprinkle stars on top so it reads as space, not smoke
  int sRGB = autoStarsPixel(dx, dy, dz, seedHue);
  r = min(255, r + (sRGB >> 16 & 0xff) * 0.8);
  g = min(255, g + (sRGB >> 8  & 0xff) * 0.8);
  b = min(255, b + (sRGB       & 0xff) * 0.8);
  return 0xff000000 | ((int) r << 16) | ((int) g << 8) | (int) b;
}

// HORIZON - synthwave: gradient sky, sun disk with scanlines, neon floor grid.
// Processing Y points DOWN, so dy<0 is sky and dy>0 is ground.
int autoHorizonPixel(float dx, float dy, float dz, float seedHue) {
  float r, g, b;
  if (dy <= 0) {
    float up = -dy;                                  // 0 horizon → 1 zenith
    r = lerp(70, 8,  up); g = lerp(20, 4, up); b = lerp(90, 30, up); // dusk purple

    // sun: fixed direction just above the horizon toward -Z
    float sunDot = dx * 0 + dy * 0.20 + dz * -0.98;  // dot(d, sunDir)
    if (sunDot > 0.965) {
      float core = map(sunDot, 0.965, 1.0, 0, 1);
      boolean scanline = (dy > -0.06) && (((int) (dy * 220) & 1) == 0);
      if (!scanline) {
        r = lerp(r, 255, core);
        g = lerp(g, 120 + 100 * (1 - core), core);
        b = lerp(b, 40, core * 0.9);
      }
    }
  } else {
    // ground: project direction onto the floor plane, draw grid lines
    float gx = dx / dy * 1.4, gz = dz / dy * 1.4;
    float fade  = constrain(dy * 2.2, 0, 1);          // dim toward the horizon
    float lineX = abs(gx - round(gx)), lineZ = abs(gz - round(gz));
    boolean line = min(lineX, lineZ) < 0.035 * (0.4 + dy); // thinner when far
    if (line) {
      float hue = (seedHue + 0.5) % 1.0;              // grid contrasts the sky
      r = (120 + 135 * hue) * fade; g = 40 * fade; b = (255 - 100 * hue) * fade;
    } else {
      r = 10 * fade; g = 4 * fade; b = 18 * fade;
    }
  }
  return 0xff000000 | ((int) constrain(r, 0, 255) << 16)
                    | ((int) constrain(g, 0, 255) << 8)
                    |  (int) constrain(b, 0, 255);
}
