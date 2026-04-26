/**
 * SacredFractalsScene
 *
 * Gallery scene that composes reusable FractalRenderer objects from
 * src/fractals/. Cycles through the renderers; wraps each in a Flower of
 * Life halo (also reusable).
 *
 * The renderers are decoupled — any other scene can pull one in standalone.
 *
 * Audio mapping (interpreted per-renderer):
 *   bass  -> recursion depth / iteration / point count
 *   mid   -> branch angle / rotation / brightness
 *   high  -> stroke jitter / weight / hue speed
 *   beat  -> bumps RNG seed (regenerates stochastic fractals)
 */
class SacredFractalsScene implements IScene {

  FractalRenderer[] renderers;
  MandelbrotRenderer mandel;   // kept typed for pan/zoom controller wiring
  FlowerOfLifeHalo halo = new FlowerOfLifeHalo();
  FractalParams params = new FractalParams();

  int mode = 0;
  float sBass, sMid, sHigh;
  float rotation = 0;
  float hueShift = 0;
  long  rngSeed  = 1;
  boolean showHalo   = true;
  boolean autoRotate = true;

  SacredFractalsScene() {
    mandel = new MandelbrotRenderer();
    renderers = new FractalRenderer[] {
      new BarnsleyFernRenderer(),
      new RomanescoRenderer(),
      new LightningRenderer(),
      new KochSnowflakeRenderer(),
      new TreeBarkRenderer(),
      new SierpinskiRenderer(),
      new KochCurveRenderer(),
      mandel,
      new BifurcationRenderer(),
      new RecursiveTreeRenderer()
    };
  }

  void onEnter() {
    rotation = 0; hueShift = 0;
    sBass = sMid = sHigh = 0;
    rngSeed = millis();
  }
  void onExit() {}

  void drawScene(PGraphics pg) {
    sBass = lerp(sBass, analyzer.bass, 0.18);
    sMid  = lerp(sMid,  analyzer.mid,  0.18);
    sHigh = lerp(sHigh, analyzer.high, 0.22);
    if (autoRotate) rotation += analyzer.rotDir * (0.0025 + sMid * 0.012);
    hueShift = (hueShift + 0.3 + sHigh * 4.0) % 360;
    if (analyzer.isBeat) rngSeed++;

    params.set(sBass, sMid, sHigh, hueShift, analyzer.isBeat, rngSeed);

    pg.background(4, 3, 10);

    if (showHalo) {
      pg.pushMatrix();
      pg.translate(pg.width * 0.5, pg.height * 0.5);
      pg.rotate(-rotation * 0.5);
      halo.draw(pg, params);
      pg.popMatrix();
    }

    pg.pushMatrix();
    pg.translate(pg.width * 0.5, pg.height * 0.5);
    pg.rotate(rotation);
    renderers[mode].draw(pg, params);
    pg.popMatrix();

    pg.colorMode(RGB, 255);
    drawHUD(pg);
  }

  void drawHUD(PGraphics pg) {
    pg.resetMatrix();
    sceneHUD(pg, "Sacred Fractals", new String[]{
      "Mode: " + renderers[mode].name() + "  (" + (mode + 1) + "/" + renderers.length + ")",
      "A / SPACE  cycle    D-pad ←/→  prev/next    0-9  jump",
      "B / R      regenerate    Y / H  toggle halo    X / O  auto-rotate",
      "LStick     pan Mandelbrot   RT/LT   zoom in/out",
      "Bass " + nf(sBass, 0, 2) + "  Mid " + nf(sMid, 0, 2) + "  High " + nf(sHigh, 0, 2)
    });
  }

  void applyController(Controller c) {
    if (c.aJustPressed) mode = (mode + 1) % renderers.length;
    if (c.bJustPressed) rngSeed++;
    if (c.yJustPressed) showHalo   = !showHalo;
    if (c.xJustPressed) autoRotate = !autoRotate;
    if (c.dpadRightJustPressed) mode = (mode + 1) % renderers.length;
    if (c.dpadLeftJustPressed)  mode = (mode + renderers.length - 1) % renderers.length;

    if (renderers[mode] == mandel) {
      mandel.pan(c.lx * 0.01, c.ly * 0.01);
      mandel.zoomBy(1.0 + (c.rt - c.lt) * 0.04);
    }
  }

  void handleKey(char k) {
    if (k == ' ') mode = (mode + 1) % renderers.length;
    else if (k == 'r' || k == 'R') rngSeed++;
    else if (k == 'h' || k == 'H') showHalo   = !showHalo;
    else if (k == 'o' || k == 'O') autoRotate = !autoRotate;
    else if (k >= '0' && k <= '9') {
      int idx = k - '0';
      if (idx < renderers.length) mode = idx;
    }
  }

  String[] getCodeLines() {
    return new String[]{
      "// Sacred Fractals (gallery)",
      "Renderers composed from src/fractals/",
      "z = z^2 + c        (Mandelbrot)",
      "x = r·x·(1-x)      (logistic map)",
      "Koch / Sierpinski / IFS / L-system"
    };
  }

  ControllerLayout[] getControllerLayout() {
    return new ControllerLayout[]{
      new ControllerLayout("A",        "Cycle fractal"),
      new ControllerLayout("B",        "Regenerate (random fractals)"),
      new ControllerLayout("X",        "Toggle auto-rotate"),
      new ControllerLayout("Y",        "Toggle Flower-of-Life halo"),
      new ControllerLayout("DPad ←/→", "Prev / next fractal"),
      new ControllerLayout("LStick",   "Pan (Mandelbrot)"),
      new ControllerLayout("RT / LT",  "Zoom in / out (Mandelbrot)")
    };
  }
}
