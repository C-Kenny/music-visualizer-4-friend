import java.net.InetSocketAddress;
import java.io.OutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

// Lightweight feature-flag server. GET/POST /featureflags. Persists to featureflags.json.
// Add a flag: append a FeatureFlagSpec in buildSchema(), wire read/write in
// applyFlag() + snapshot(). UI renders automatically from the schema.
class FeatureFlagServer {
  com.sun.net.httpserver.HttpServer server;
  String jsonPath;
  int port = 8080;

  // Schema entry. type: "bool" | "float" | "enum"
  class FeatureFlagSpec {
    String key, type, label;
    float min, max;
    String[] options;
    FeatureFlagSpec(String k, String t, String l) { key=k; type=t; label=l; }
  }

  ArrayList<FeatureFlagSpec> schema;
  ArrayList<String> lanUrls = new ArrayList<String>();  // populated at start; used by HUD

  FeatureFlagServer() {
    jsonPath = sketchPath("featureflags.json");
    schema = buildSchema();
  }

  ArrayList<FeatureFlagSpec> buildSchema() {
    ArrayList<FeatureFlagSpec> s = new ArrayList<FeatureFlagSpec>();
    s.add(new FeatureFlagSpec("BLOOM_ENABLED",         "bool", "Bloom (post-FX glow)"));
    s.add(new FeatureFlagSpec("SHOW_METADATA",         "bool", "Show song metadata"));
    s.add(new FeatureFlagSpec("EPILEPSY_MODE_ON",      "bool", "Epilepsy mode (intense flash)"));
    s.add(new FeatureFlagSpec("RAINBOW_FINS",          "bool", "Rainbow fins"));
    s.add(new FeatureFlagSpec("APPEAR_HAND_DRAWN",     "bool", "Hand-drawn aesthetic"));
    s.add(new FeatureFlagSpec("BACKGROUND_ENABLED",    "bool", "Scene background"));
    s.add(new FeatureFlagSpec("SHOW_CONTROLLER_GUIDE", "bool", "Controller guide overlay"));

    FeatureFlagSpec wm = new FeatureFlagSpec("WAVE_MULTIPLIER", "float", "Waveform amplitude");
    wm.min = 0; wm.max = 200;
    s.add(wm);

    FeatureFlagSpec mode = new FeatureFlagSpec("AUTO_SWITCH_MODE", "enum", "Auto scene switch");
    mode.options = new String[]{"OFF", "FAVS_ONLY", "FAVS_WEIGHTED", "SEQUENTIAL", "RANDOM"};
    s.add(mode);
    return s;
  }

  // ------- persistence -------

  void loadFromDisk() {
    java.io.File f = new java.io.File(jsonPath);
    if (!f.exists()) { println("[FEATUREFLAGS] no featureflags.json, using Config defaults"); return; }
    try {
      JSONObject o = loadJSONObject(jsonPath);
      applyFromJSON(o);
      println("[FEATUREFLAGS] loaded " + jsonPath);
    } catch (Exception e) {
      println("[FEATUREFLAGS] load failed: " + e.getMessage());
    }
  }

  void applyFromJSON(JSONObject o) {
    for (FeatureFlagSpec sp : schema) {
      if (!o.hasKey(sp.key)) continue;
      if (sp.type.equals("bool"))  applyBool(sp.key,  o.getBoolean(sp.key));
      if (sp.type.equals("float")) applyFloat(sp.key, o.getFloat(sp.key));
      if (sp.type.equals("enum"))  applyString(sp.key, o.getString(sp.key));
    }
  }

  void saveToDisk() {
    JSONObject o = snapshotValues();
    saveJSONObject(o, jsonPath);
  }

  // ------- read/write Config -------

  JSONObject snapshotValues() {
    JSONObject o = new JSONObject();
    o.setBoolean("BLOOM_ENABLED",         config.BLOOM_ENABLED);
    o.setBoolean("SHOW_METADATA",         config.SHOW_METADATA);
    o.setBoolean("EPILEPSY_MODE_ON",      config.EPILEPSY_MODE_ON);
    o.setBoolean("RAINBOW_FINS",          config.RAINBOW_FINS);
    o.setBoolean("APPEAR_HAND_DRAWN",     config.APPEAR_HAND_DRAWN);
    o.setBoolean("BACKGROUND_ENABLED",    config.BACKGROUND_ENABLED);
    o.setBoolean("SHOW_CONTROLLER_GUIDE", config.SHOW_CONTROLLER_GUIDE);
    o.setFloat  ("WAVE_MULTIPLIER",       config.WAVE_MULTIPLIER);
    o.setString ("AUTO_SWITCH_MODE",      autoSwitchModeString());
    return o;
  }

  // Map AutoSwitcher.enabled+mode → enum string for UI.
  String autoSwitchModeString() {
    if (autoSwitcher == null || !autoSwitcher.enabled) return "OFF";
    int m = autoSwitcher.mode;
    if (m == autoSwitcher.MODE_FAVS_ONLY)     return "FAVS_ONLY";
    if (m == autoSwitcher.MODE_FAVS_WEIGHTED) return "FAVS_WEIGHTED";
    if (m == autoSwitcher.MODE_SEQUENTIAL)    return "SEQUENTIAL";
    if (m == autoSwitcher.MODE_RANDOM_ALL)    return "RANDOM";
    return "OFF";
  }

  void applyBool(String key, boolean v) {
    if (key.equals("BLOOM_ENABLED"))              config.BLOOM_ENABLED         = v;
    else if (key.equals("SHOW_METADATA"))         config.SHOW_METADATA         = v;
    else if (key.equals("EPILEPSY_MODE_ON"))      config.EPILEPSY_MODE_ON      = v;
    else if (key.equals("RAINBOW_FINS"))          config.RAINBOW_FINS          = v;
    else if (key.equals("APPEAR_HAND_DRAWN"))     config.APPEAR_HAND_DRAWN     = v;
    else if (key.equals("BACKGROUND_ENABLED"))    config.BACKGROUND_ENABLED    = v;
    else if (key.equals("SHOW_CONTROLLER_GUIDE")) config.SHOW_CONTROLLER_GUIDE = v;
  }
  void applyFloat(String key, float v) {
    if (key.equals("WAVE_MULTIPLIER")) config.WAVE_MULTIPLIER = v;
  }
  void applyString(String key, String v) {
    if (key.equals("AUTO_SWITCH_MODE")) applyAutoSwitchMode(v);
  }

  void applyAutoSwitchMode(String v) {
    if (autoSwitcher == null) return;
    if (v.equals("OFF"))           { autoSwitcher.enabled = false; return; }
    autoSwitcher.enabled = true;
    if (v.equals("FAVS_ONLY"))     autoSwitcher.mode = autoSwitcher.MODE_FAVS_ONLY;
    if (v.equals("FAVS_WEIGHTED")) autoSwitcher.mode = autoSwitcher.MODE_FAVS_WEIGHTED;
    if (v.equals("SEQUENTIAL"))    autoSwitcher.mode = autoSwitcher.MODE_SEQUENTIAL;
    if (v.equals("RANDOM"))        autoSwitcher.mode = autoSwitcher.MODE_RANDOM_ALL;
  }

  // ------- HTTP -------

  void start() {
    try {
      // Bind 0.0.0.0 so phones/tablets on the same LAN can reach the panel.
      server = com.sun.net.httpserver.HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);
      server.createContext("/featureflags", new FeatureFlagHandler());
      server.createContext("/scene", new SceneHandler());
      server.createContext("/input/sticks", new SticksHandler());
      server.createContext("/input/button", new ButtonHandler());
      server.createContext("/", new UiHandler());
      server.setExecutor(null);
      server.start();
      println("[FEATUREFLAGS] server listening on port " + port + " (all interfaces)");
      printLanAddresses();
    } catch (IOException e) {
      println("[FEATUREFLAGS] server start failed: " + e.getMessage());
    }
  }

  void stop() {
    if (server != null) server.stop(0);
  }

  String buildPayload() {
    JSONObject root = new JSONObject();
    JSONArray sch = new JSONArray();
    for (int i = 0; i < schema.size(); i++) {
      FeatureFlagSpec sp = schema.get(i);
      JSONObject e = new JSONObject();
      e.setString("key", sp.key);
      e.setString("type", sp.type);
      e.setString("label", sp.label);
      if (sp.type.equals("float")) {
        e.setFloat("min", sp.min);
        e.setFloat("max", sp.max);
      }
      if (sp.type.equals("enum") && sp.options != null) {
        JSONArray opts = new JSONArray();
        for (int k = 0; k < sp.options.length; k++) opts.setString(k, sp.options[k]);
        e.setJSONArray("options", opts);
      }
      sch.setJSONObject(i, e);
    }
    root.setJSONArray("schema", sch);
    root.setJSONObject("values", snapshotValues());
    return root.toString();
  }

  class FeatureFlagHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");
      ex.getResponseHeaders().set("Content-Type", "application/json");

      String method = ex.getRequestMethod();
      if (method.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }

      try {
        if (method.equals("GET")) {
          byte[] body = buildPayload().getBytes(StandardCharsets.UTF_8);
          ex.sendResponseHeaders(200, body.length);
          OutputStream os = ex.getResponseBody(); os.write(body); os.close();
          return;
        }
        if (method.equals("POST")) {
          byte[] in = readAll(ex.getRequestBody());
          String bodyStr = new String(in, StandardCharsets.UTF_8);
          JSONObject patch = parseJSONObject(bodyStr);
          if (patch == null) throw new RuntimeException("invalid JSON");
          applyFromJSON(patch);
          saveToDisk();
          byte[] body = buildPayload().getBytes(StandardCharsets.UTF_8);
          ex.sendResponseHeaders(200, body.length);
          OutputStream os = ex.getResponseBody(); os.write(body); os.close();
          return;
        }
        ex.sendResponseHeaders(405, -1); ex.close();
      } catch (Exception e) {
        println("[FEATUREFLAGS] handler error: " + e.getMessage());
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(500, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }

    byte[] readAll(java.io.InputStream is) throws IOException {
      java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
      byte[] chunk = new byte[1024];
      int n;
      while ((n = is.read(chunk)) > 0) buf.write(chunk, 0, n);
      return buf.toByteArray();
    }
  }

  // GET /scene → list groups + current. POST /scene {"id":N} → switch.
  class SceneHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");
      ex.getResponseHeaders().set("Content-Type", "application/json");

      String method = ex.getRequestMethod();
      if (method.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }

      try {
        if (method.equals("POST")) {
          byte[] in = readSceneBody(ex.getRequestBody());
          JSONObject patch = parseJSONObject(new String(in, StandardCharsets.UTF_8));
          if (patch == null || !patch.hasKey("id")) throw new RuntimeException("missing id");
          int id = patch.getInt("id");
          if (id < 0 || id >= SCENE_COUNT) throw new RuntimeException("scene id out of range: " + id);
          switchScene(id);
        }
        byte[] body = buildScenePayload().getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(200, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      } catch (Exception e) {
        println("[FEATUREFLAGS] /scene error: " + e.getMessage());
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(400, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }

    byte[] readSceneBody(java.io.InputStream is) throws IOException {
      java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
      byte[] chunk = new byte[1024];
      int n;
      while ((n = is.read(chunk)) > 0) buf.write(chunk, 0, n);
      return buf.toByteArray();
    }
  }

  String buildScenePayload() {
    JSONObject root = new JSONObject();
    root.setInt("currentScene", config.STATE);
    JSONArray gs = new JSONArray();
    ArrayList<SceneGroup> groups = buildSceneGroups();
    for (int i = 0; i < groups.size(); i++) {
      SceneGroup g = groups.get(i);
      JSONObject go = new JSONObject();
      go.setString("name", g.name);
      JSONArray ss = new JSONArray();
      for (int j = 0; j < g.scenes.size(); j++) {
        SceneEntry s = g.scenes.get(j);
        JSONObject so = new JSONObject();
        so.setInt("id", s.id);
        so.setString("name", s.name);
        ss.setJSONObject(j, so);
      }
      go.setJSONArray("scenes", ss);
      gs.setJSONObject(i, go);
    }
    root.setJSONArray("groups", gs);
    return root.toString();
  }

  // HTTP fallback for the controller UI when WebSocket is blocked (corp wifi etc).
  // Same shape as ControllerWebSocket: forwards to webController.
  abstract class InputHandlerBase implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!m.equals("POST"))   { ex.sendResponseHeaders(405, -1); ex.close(); return; }
      try {
        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[1024]; int n;
        while ((n = ex.getRequestBody().read(chunk)) > 0) buf.write(chunk, 0, n);
        JSONObject o = parseJSONObject(new String(buf.toByteArray(), StandardCharsets.UTF_8));
        if (o == null) throw new RuntimeException("invalid JSON");
        process(o);
        ex.sendResponseHeaders(204, -1); ex.close();
      } catch (Exception e) {
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(400, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }
    abstract void process(JSONObject o);
  }

  class SticksHandler extends InputHandlerBase {
    void process(JSONObject o) {
      webController.setSticks(
        o.getFloat("lx", 0), o.getFloat("ly", 0),
        o.getFloat("rx", 0), o.getFloat("ry", 0));
    }
  }
  class ButtonHandler extends InputHandlerBase {
    void process(JSONObject o) {
      webController.setButton(o.getString("btn", ""), o.getString("action", ""));
    }
  }

  // Serves the static UI from ../../featureflags-ui/index.html so phones can hit
  // http://<pc-lan-ip>:8080/ without copying files.
  class UiHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      String path = ex.getRequestURI().getPath();
      if (path.equals("/")) path = "/index.html";
      java.io.File root = new java.io.File(sketchPath("../../featureflags-ui")).getCanonicalFile();
      java.io.File f = new java.io.File(root, path).getCanonicalFile();
      if (!f.getPath().startsWith(root.getPath()) || !f.exists() || f.isDirectory()) {
        ex.sendResponseHeaders(404, -1); ex.close(); return;
      }
      String ct = "text/plain";
      String p = f.getName().toLowerCase();
      if (p.endsWith(".html")) ct = "text/html; charset=utf-8";
      else if (p.endsWith(".css")) ct = "text/css";
      else if (p.endsWith(".js"))  ct = "application/javascript";
      ex.getResponseHeaders().set("Content-Type", ct);
      byte[] body = java.nio.file.Files.readAllBytes(f.toPath());
      ex.sendResponseHeaders(200, body.length);
      OutputStream os = ex.getResponseBody(); os.write(body); os.close();
    }
  }

  void printLanAddresses() {
    try {
      java.util.Enumeration<java.net.NetworkInterface> ifs = java.net.NetworkInterface.getNetworkInterfaces();
      while (ifs.hasMoreElements()) {
        java.net.NetworkInterface ni = ifs.nextElement();
        if (!ni.isUp() || ni.isLoopback()) continue;
        java.util.Enumeration<java.net.InetAddress> addrs = ni.getInetAddresses();
        while (addrs.hasMoreElements()) {
          java.net.InetAddress a = addrs.nextElement();
          if (a instanceof java.net.Inet4Address) {
            String url = "http://" + a.getHostAddress() + ":" + port + "/";
            lanUrls.add(url);
            println("[FEATUREFLAGS] open on phone: " + url);
          }
        }
      }
    } catch (Exception e) {
      println("[FEATUREFLAGS] could not enumerate IPs: " + e.getMessage());
    }
  }
}
