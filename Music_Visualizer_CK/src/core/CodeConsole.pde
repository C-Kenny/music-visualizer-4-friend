/**
 * CodeConsole — hot-reload Java snippet engine (Janino-backed).
 *
 * Watches a .java file (mtime poll). On change, compiles via Janino's
 * SimpleCompiler and finds a class named `LiveCode` with method:
 *
 *   public void draw(PGraphics pg, float t, float bass, float mid, float high)
 *
 * Compile or runtime exceptions are captured and exposed for HUD display.
 * The previous good instance keeps drawing — never blanks the screen.
 *
 * Sandboxing: Janino runs user code with full JVM permissions (no SecurityManager
 * wrapper here). The watchdog (>2s frame stall) still applies, so an infinite
 * loop in user code crashes back to a safe scene rather than hanging the show.
 *
 * Caveat: Janino 3.1 supports up to ~Java 11 syntax. Lambdas/method refs OK,
 * records/switch-expressions are NOT.
 */
class CodeConsole {
  final String userFileName;
  final String seedResource;

  String   path;
  Object   lastGoodInstance;
  java.lang.reflect.Method lastGoodDraw;
  String   lastError = "";
  long     lastMtimeMs = -1;
  long     lastReloadMs = 0;
  int      reloadCount = 0;
  String   lastClassName = "?";

  CodeConsole(String userFileName, String seedResource) {
    this.userFileName = userFileName;
    this.seedResource = seedResource;
    this.path = userDataPath(userFileName);
    seedIfMissing();
  }

  void seedIfMissing() {
    java.io.File f = new java.io.File(path);
    if (f.exists()) return;
    try {
      String src = resourcePath(seedResource);
      java.io.File s = new java.io.File(src);
      if (!s.exists()) { writeBuiltinSeed(); return; }
      java.io.File parent = f.getParentFile();
      if (parent != null && !parent.exists()) parent.mkdirs();
      java.nio.file.Files.copy(s.toPath(), f.toPath());
      println("[CodeConsole] seeded " + path + " from " + seedResource);
    } catch (Exception e) {
      println("[CodeConsole] seed copy failed: " + e.getMessage());
      writeBuiltinSeed();
    }
  }

  void writeBuiltinSeed() {
    String seed =
      "import processing.core.PGraphics;\n" +
      "\n" +
      "public class LiveCode {\n" +
      "  float phase = 0;\n" +
      "\n" +
      "  public void draw(PGraphics pg, float t, float bass, float mid, float high) {\n" +
      "    pg.background(0);\n" +
      "    int w = pg.width, h = pg.height;\n" +
      "    phase += 0.02f + bass * 0.2f;\n" +
      "    pg.noStroke();\n" +
      "    int rings = 24;\n" +
      "    for (int i = 0; i < rings; i++) {\n" +
      "      float r = (float) Math.min(w, h) * 0.45f * (i + 1) / rings;\n" +
      "      float a = phase + i * 0.3f;\n" +
      "      float x = w * 0.5f + (float) Math.cos(a) * r * mid;\n" +
      "      float y = h * 0.5f + (float) Math.sin(a) * r * mid;\n" +
      "      float sz = 8 + bass * 80 + high * 40;\n" +
      "      pg.fill(\n" +
      "        128 + 127 * (float) Math.sin(a + bass * 4),\n" +
      "        128 + 127 * (float) Math.sin(a * 1.3f + mid * 3),\n" +
      "        128 + 127 * (float) Math.sin(a * 0.7f + high * 5),\n" +
      "        200);\n" +
      "      pg.ellipse(x, y, sz, sz);\n" +
      "    }\n" +
      "  }\n" +
      "}\n";
    try {
      java.io.File f = new java.io.File(path);
      java.io.File parent = f.getParentFile();
      if (parent != null && !parent.exists()) parent.mkdirs();
      java.nio.file.Files.write(f.toPath(), seed.getBytes(java.nio.charset.StandardCharsets.UTF_8));
      println("[CodeConsole] wrote built-in seed to " + path);
    } catch (Exception e) {
      println("[CodeConsole] could not write seed: " + e.getMessage());
    }
  }

  boolean reloadIfChanged() {
    java.io.File f = new java.io.File(path);
    if (!f.exists()) { lastError = "missing: " + path; return false; }
    long mtime = f.lastModified();
    if (mtime == lastMtimeMs) return false;
    lastMtimeMs = mtime;
    forceReload();
    return true;
  }

  void forceReload() {
    java.io.File f = new java.io.File(path);
    if (f.exists()) lastMtimeMs = f.lastModified();
    try {
      String src = new String(java.nio.file.Files.readAllBytes(f.toPath()),
                              java.nio.charset.StandardCharsets.UTF_8);
      String className = extractPublicClassName(src);
      if (className == null) { lastError = "no `public class X` declaration found"; return; }

      org.codehaus.janino.SimpleCompiler sc = new org.codehaus.janino.SimpleCompiler();
      sc.cook(src);
      Class<?> cls = sc.getClassLoader().loadClass(className);
      Object instance = cls.getDeclaredConstructor().newInstance();

      // Find draw(PGraphics, float, float, float, float, float)
      java.lang.reflect.Method m = null;
      for (java.lang.reflect.Method cand : cls.getMethods()) {
        if (!cand.getName().equals("draw")) continue;
        Class<?>[] p = cand.getParameterTypes();
        if (p.length != 5) continue;
        if (!processing.core.PGraphics.class.isAssignableFrom(p[0])) continue;
        if (p[1] != float.class || p[2] != float.class || p[3] != float.class || p[4] != float.class) continue;
        m = cand; break;
      }
      if (m == null) {
        lastError = "class " + className + " missing required method:\n" +
                    "  public void draw(PGraphics pg, float t, float bass, float mid, float high)";
        return;
      }

      lastGoodInstance = instance;
      lastGoodDraw     = m;
      lastClassName    = className;
      lastError        = "";
      reloadCount++;
      lastReloadMs     = millis();
      println("[CodeConsole] reloaded " + userFileName + " -> " + className + " (#" + reloadCount + ")");
    } catch (Throwable t) {
      lastError = formatError(t);
      println("[CodeConsole] compile error:\n" + lastError);
    }
  }

  // Invoke draw on last-good instance. Caller passes its own try/catch so a
  // runtime crash in user code can be reported back here without nuking the
  // surrounding scene.
  void invokeDraw(processing.core.PGraphics pg, float t, float bass, float mid, float high) throws Throwable {
    if (lastGoodInstance == null || lastGoodDraw == null) return;
    try {
      lastGoodDraw.invoke(lastGoodInstance, pg, t, bass, mid, high);
    } catch (java.lang.reflect.InvocationTargetException ite) {
      throw ite.getCause() == null ? ite : ite.getCause();
    }
  }

  void markRuntimeError(Throwable t) {
    lastError = "runtime: " + formatError(t);
    println("[CodeConsole] runtime error:\n" + lastError);
  }

  boolean hasError()      { return lastError.length() > 0; }
  boolean hasInstance()   { return lastGoodInstance != null && lastGoodDraw != null; }
  String  errorMessage()  { return lastError; }
  String  filePath()      { return path; }
  String  className()     { return lastClassName; }

  String extractPublicClassName(String src) {
    java.util.regex.Matcher m = java.util.regex.Pattern
      .compile("public\\s+class\\s+([A-Za-z_][A-Za-z0-9_]*)")
      .matcher(src);
    return m.find() ? m.group(1) : null;
  }

  String formatError(Throwable t) {
    String m = t.getMessage();
    if (m == null) m = t.getClass().getSimpleName();
    int idx = m.indexOf("Location:");
    if (idx > 0 && idx < m.length() - 1) m = m.substring(0, idx).trim() + "\n" + m.substring(idx);
    return m;
  }
}
