/**
 * ShaderConsole — hot-reload GLSL editor backend.
 *
 * Watches a user-editable .glsl file (mtime poll). On change, recompiles via
 * loadShader(). Compile errors are captured (parse-time and first-use) and
 * exposed for HUD display while the previous good shader keeps rendering.
 *
 * Compile cost: GLSL is sandboxed by the driver — a syntax error never crashes
 * the JVM, just throws RuntimeException out of loadShader() / pg.shader().
 *
 *   ShaderConsole sc = new ShaderConsole("live_shader.glsl", "milkdrop_lesson.glsl");
 *   sc.reloadIfChanged();
 *   PShader sh = sc.activeShader();   // last-good, never null after first success
 *   if (sh != null) {
 *     try { pg.shader(sh); ... } catch (RuntimeException e) { sc.markRuntimeError(e); }
 *   }
 */
class ShaderConsole {
  final String userFileName;
  final String seedResource;          // bundled fallback copied on first run
  String   path;
  PShader  lastGood;
  String   lastError = "";            // empty == no error
  long     lastMtimeMs = -1;
  long     lastReloadMs = 0;
  int      reloadCount = 0;

  ShaderConsole(String userFileName, String seedResource) {
    this.userFileName = userFileName;
    this.seedResource = seedResource;
    this.path         = userDataPath(userFileName);
    seedIfMissing();
  }

  void seedIfMissing() {
    java.io.File f = new java.io.File(path);
    if (f.exists()) return;
    try {
      String src = resourcePath(seedResource);
      java.io.File s = new java.io.File(src);
      if (!s.exists()) return;
      java.io.File parent = f.getParentFile();
      if (parent != null && !parent.exists()) parent.mkdirs();
      java.nio.file.Files.copy(s.toPath(), f.toPath());
      println("[ShaderConsole] seeded " + path + " from " + seedResource);
    } catch (Exception e) {
      println("[ShaderConsole] seed failed: " + e.getMessage());
    }
  }

  // Returns true if a reload was attempted (success or failure) this call.
  boolean reloadIfChanged() {
    java.io.File f = new java.io.File(path);
    if (!f.exists()) {
      lastError = "missing: " + path;
      return false;
    }
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
      PShader sh = loadShader(path);
      if (sh == null) { lastError = "loadShader returned null"; return; }
      lastGood    = sh;
      lastError   = "";
      reloadCount++;
      lastReloadMs = millis();
      println("[ShaderConsole] reloaded " + userFileName + " (#" + reloadCount + ")");
    } catch (Throwable t) {
      lastError = formatError(t);
      println("[ShaderConsole] compile error:\n" + lastError);
    }
  }

  // Caller wraps pg.shader(sh) in try/catch and reports runtime compile errors
  // (some drivers defer compile until first bind).
  void markRuntimeError(Throwable t) {
    lastError = formatError(t);
    println("[ShaderConsole] runtime shader error:\n" + lastError);
  }

  PShader activeShader() { return lastGood; }
  boolean hasError()     { return lastError.length() > 0; }
  String  errorMessage() { return lastError; }
  String  filePath()     { return path; }

  private String formatError(Throwable t) {
    String m = t.getMessage();
    if (m == null) m = t.getClass().getSimpleName();
    // Trim noisy "(in /full/path/X.glsl)" suffix Processing adds
    int idx = m.indexOf("(in ");
    if (idx > 0) m = m.substring(0, idx).trim();
    return m;
  }
}
