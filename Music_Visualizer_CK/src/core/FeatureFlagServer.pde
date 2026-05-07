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
  int port   = 8080;   // chosen at start() — may walk forward if 8080 taken
  int wsPort = 8081;   // set by main after ControllerWebSocket binds; injected into controller.html

  // Schema entry. type: "bool" | "float" | "enum"
  class FeatureFlagSpec {
    String key, type, label;
    float min, max;
    String[] options;
    FeatureFlagSpec(String k, String t, String l) { key=k; type=t; label=l; }
  }

  ArrayList<FeatureFlagSpec> schema;
  ArrayList<String> lanUrls = new ArrayList<String>();  // populated at start; used by HUD
  String startError = "";  // non-empty if HTTP bind failed; surfaced on the HUD

  FeatureFlagServer() {
    jsonPath = userDataPath("featureflags.json");
    schema = buildSchema();
  }

  ArrayList<FeatureFlagSpec> buildSchema() {
    ArrayList<FeatureFlagSpec> s = new ArrayList<FeatureFlagSpec>();
    s.add(new FeatureFlagSpec("BLOOM_ENABLED",         "bool", "Bloom (post-FX glow)"));
    s.add(new FeatureFlagSpec("SHOW_METADATA",         "bool", "Show song metadata"));
    s.add(new FeatureFlagSpec("EPILEPSY_MODE_ON",      "bool", "Epilepsy mode (intense flash)"));
    s.add(new FeatureFlagSpec("HEADACHE_FREE_MODE",    "bool", "Headache-free mode (calm/soothing)"));
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
    o.setBoolean("HEADACHE_FREE_MODE",    config.HEADACHE_FREE_MODE);
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
    else if (key.equals("HEADACHE_FREE_MODE"))    config.HEADACHE_FREE_MODE    = v;
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

  // Walks forward from `start` until it finds a free TCP port (or returns -1 after `span` tries).
  // Used for both the HTTP panel and the WS controller so a leftover JVM doesn't lock us out.
  int findFreePort(int startPort, int span) {
    for (int i = 0; i < span; i++) {
      int p = startPort + i;
      java.net.ServerSocket s = null;
      try {
        s = new java.net.ServerSocket();
        s.setReuseAddress(true);
        s.bind(new InetSocketAddress("0.0.0.0", p));
        return p;
      } catch (IOException e) {
        // try next
      } finally {
        if (s != null) try { s.close(); } catch (IOException e) {}
      }
    }
    return -1;
  }

  void start() {
    // Pick a free HTTP port up-front so a stale instance on 8080 doesn't blank the panel.
    int chosen = findFreePort(port, 10);
    if (chosen < 0) {
      startError = "no free port in " + port + ".." + (port + 9);
      println("[FEATUREFLAGS] " + startError);
      printLanAddresses();
      return;
    }
    if (chosen != port) println("[FEATUREFLAGS] port " + port + " busy → using " + chosen);
    port = chosen;
    // Enumerate IPs (uses chosen port) so the HUD shows the correct URLs.
    printLanAddresses();
    try {
      // Bind 0.0.0.0 so phones/tablets on the same LAN can reach the panel.
      server = com.sun.net.httpserver.HttpServer.create(new InetSocketAddress("0.0.0.0", port), 0);
      server.createContext("/featureflags", new FeatureFlagHandler());
      server.createContext("/scene", new SceneHandler());
      server.createContext("/input/sticks", new SticksHandler());
      server.createContext("/input/button", new ButtonHandler());
      server.createContext("/input/trigger",new TriggerHandler());
      server.createContext("/input/hello",  new HelloHandler());
      server.createContext("/admin/clients", new AdminClientsHandler());
      server.createContext("/admin/kick",    new AdminKickHandler());
      server.createContext("/admin/ban",     new AdminBanHandler());
      server.createContext("/admin/unban",   new AdminUnbanHandler());
      server.createContext("/admin/role",    new AdminRoleHandler());
      server.createContext("/admin/lockdown",new AdminLockdownHandler());
      server.createContext("/admin/auth",    new AdminAuthHandler());
      server.createContext("/admin/logout",  new AdminLogoutHandler());
      server.createContext("/admin/pins",        new AdminPinsListHandler());
      server.createContext("/admin/pins/mint",   new AdminPinsMintHandler());
      server.createContext("/admin/pins/revoke", new AdminPinsRevokeHandler());
      server.createContext("/admin/pins/rotate-master", new AdminPinsRotateMasterHandler());
      server.createContext("/operator.json", new OperatorHandler());
      server.createContext("/admin/stream/toggle", new AdminStreamToggleHandler());
      server.createContext("/", new UiHandler());
      server.setExecutor(null);
      server.start();
      getAdminToken();   // surface or generate token at start
      println("[FEATUREFLAGS] server listening on port " + port + " (all interfaces)");
    } catch (IOException e) {
      startError = e.getMessage();
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
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type,X-Admin-Token");
      ex.getResponseHeaders().set("Access-Control-Allow-Credentials", "true");
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
          if (!adminAuthed(ex)) {
            byte[] body = "{\"error\":\"admin auth required\"}".getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(401, body.length);
            OutputStream os = ex.getResponseBody(); os.write(body); os.close();
            return;
          }
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

  // GET /scene → list groups + current. POST /scene {"id":N} → switch (admin only).
  class SceneHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type,X-Admin-Token");
      ex.getResponseHeaders().set("Access-Control-Allow-Credentials", "true");
      ex.getResponseHeaders().set("Content-Type", "application/json");

      String method = ex.getRequestMethod();
      if (method.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }

      try {
        if (method.equals("POST")) {
          if (!adminAuthed(ex)) {
            byte[] body = "{\"error\":\"admin auth required\"}".getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(401, body.length);
            OutputStream os = ex.getResponseBody(); os.write(body); os.close();
            return;
          }
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
  // Client identity comes from the X-Client-Id header (browser-generated UUID).
  // /input/hello captures handshake metadata up-front.
  abstract class InputHandlerBase implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type,X-Client-Id");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!m.equals("POST"))   { ex.sendResponseHeaders(405, -1); ex.close(); return; }
      try {
        String cid = ex.getRequestHeaders().getFirst("X-Client-Id");
        String ip = ex.getRemoteAddress().getAddress().getHostAddress();
        ClientInfo info = clientRegistry.touchHttp(cid, ip);
        if (info == null) { ex.sendResponseHeaders(403, -1); ex.close(); return; }
        if (!info.pinVerified) { ex.sendResponseHeaders(401, -1); ex.close(); return; }
        if (!clientRegistry.allow(info)) { ex.sendResponseHeaders(429, -1); ex.close(); return; }
        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[1024]; int n;
        while ((n = ex.getRequestBody().read(chunk)) > 0) buf.write(chunk, 0, n);
        JSONObject o = parseJSONObject(new String(buf.toByteArray(), StandardCharsets.UTF_8));
        if (o == null) throw new RuntimeException("invalid JSON");
        process(info, o);
        ex.sendResponseHeaders(204, -1); ex.close();
      } catch (Exception e) {
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(400, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }
    abstract void process(ClientInfo info, JSONObject o);
  }

  class SticksHandler extends InputHandlerBase {
    void process(ClientInfo info, JSONObject o) {
      webController.setSticks(info.clientId,
        o.getFloat("lx", 0), o.getFloat("ly", 0),
        o.getFloat("rx", 0), o.getFloat("ry", 0));
    }
  }
  class ButtonHandler extends InputHandlerBase {
    void process(ClientInfo info, JSONObject o) {
      webController.setButton(info.clientId, o.getString("btn", ""), o.getString("action", ""));
    }
  }
  class TriggerHandler extends InputHandlerBase {
    void process(ClientInfo info, JSONObject o) {
      webController.setTrigger(info.clientId, o.getString("which", ""), o.getFloat("value", 0));
    }
  }
  // HelloHandler differs from sticks/button: PIN must be validated BEFORE we
  // accept the client's metadata, so we don't share InputHandlerBase here.
  class HelloHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type,X-Client-Id");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!m.equals("POST"))   { ex.sendResponseHeaders(405, -1); ex.close(); return; }
      try {
        String cid = ex.getRequestHeaders().getFirst("X-Client-Id");
        String ip = ex.getRemoteAddress().getAddress().getHostAddress();
        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[1024]; int n;
        while ((n = ex.getRequestBody().read(chunk)) > 0) buf.write(chunk, 0, n);
        JSONObject o = parseJSONObject(new String(buf.toByteArray(), StandardCharsets.UTF_8));
        if (o == null) throw new RuntimeException("invalid JSON");
        String pinResult = pinManager.validate(o.getString("pin", ""), ip, cid);
        if (!pinResult.startsWith("ok-")) {
          byte[] body = ("{\"error\":\"" + pinResult + "\"}").getBytes(StandardCharsets.UTF_8);
          ex.sendResponseHeaders(403, body.length);
          OutputStream os = ex.getResponseBody(); os.write(body); os.close();
          return;
        }
        String role = pinResult.startsWith("ok-named:") ? pinResult.substring("ok-named:".length()) : "guest";
        ClientInfo info = clientRegistry.touchHttp(cid, ip);
        if (info == null) { ex.sendResponseHeaders(403, -1); ex.close(); return; }
        info.pinVerified = true;
        info.role = role;
        info.nickname = o.getString("nickname", info.nickname);
        info.ua       = o.getString("ua",       info.ua);
        info.platform = o.getString("platform", info.platform);
        info.model    = o.getString("model",    info.model);
        info.dpr      = o.getFloat("dpr",       info.dpr);
        JSONArray scr = o.getJSONArray("screen");
        if (scr != null && scr.size() == 2) { info.screenW = scr.getInt(0); info.screenH = scr.getInt(1); }
        ex.sendResponseHeaders(204, -1); ex.close();
      } catch (Exception e) {
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(400, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }
  }

  // ---------- Operator dashboard ----------

  // GET /operator → JSON snapshot of stage state for live-show monitoring.
  // Read-only; no auth required (LAN-bound). Powers operator.html and a future
  // in-app secondary-display HUD.
  class OperatorHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET,OPTIONS");
      ex.getResponseHeaders().set("Content-Type", "application/json");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!m.equals("GET"))    { ex.sendResponseHeaders(405, -1); ex.close(); return; }
      try {
        byte[] body = buildOperatorPayload().getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(200, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      } catch (Exception e) {
        println("[FEATUREFLAGS] /operator error: " + e.getMessage());
        byte[] body = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(500, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      }
    }
  }

  String sceneNameOrFallback(int id) {
    if (id < 0 || id >= SCENE_COUNT) return "Scene " + id;
    if (sceneSwitcher != null && sceneSwitcher.SCENE_NAMES != null) {
      String nm = sceneSwitcher.SCENE_NAMES[id];
      if (nm != null && nm.length() > 0) return nm;
    }
    return "Scene " + id;
  }

  String buildOperatorPayload() {
    JSONObject root = new JSONObject();
    root.setLong("nowMs", System.currentTimeMillis());
    root.setFloat("fps", frameRate);

    // Scene
    JSONObject scene = new JSONObject();
    int curId = config.STATE;
    scene.setInt("id", curId);
    scene.setString("name", sceneNameOrFallback(curId));
    scene.setInt("orderIndex", _sceneOrderIndex(curId));
    scene.setInt("orderCount", SCENE_ORDER.length);
    scene.setString("song", config.SONG_NAME == null ? "" : config.SONG_NAME);
    root.setJSONObject("scene", scene);

    // Tempo
    JSONObject tempo = new JSONObject();
    tempo.setBoolean("locked", tempoLock != null && tempoLock.isLocked());
    tempo.setFloat("bpm", tempoLock != null ? tempoLock.bpm : 0);
    root.setJSONObject("tempo", tempo);

    // Strobe
    JSONObject strobe = new JSONObject();
    strobe.setBoolean("safety", strobeSafety != null && strobeSafety.enabled);
    root.setJSONObject("strobe", strobe);

    // Recorder
    JSONObject rec = new JSONObject();
    if (recorder != null) {
      rec.setBoolean("running", recorder.running);
      rec.setInt("framesWritten", recorder.framesWritten);
      rec.setInt("framesDropped", recorder.framesDropped);
      rec.setLong("startMs", recorder.startMs);
      rec.setString("path", recorder.outPath == null ? "" : recorder.outPath);
    } else {
      rec.setBoolean("running", false);
    }
    root.setJSONObject("recorder", rec);

    // Setlist
    JSONObject sl = new JSONObject();
    if (setlist != null && setlist.entries != null && setlist.entries.size() > 0) {
      sl.setInt("cursor", setlist.cursor);
      sl.setInt("size", setlist.entries.size());
      sl.setBoolean("autoAdvance", setlist.autoAdvance);
      sl.setString("now", setlist.nowLabel());
      sl.setString("next", setlist.nextLabel());
    } else {
      sl.setInt("size", 0);
    }
    root.setJSONObject("setlist", sl);

    // Blacklist (from SceneGuard)
    JSONArray bl = new JSONArray();
    if (sceneGuard != null) {
      for (int i = 0; i < SCENE_COUNT; i++) {
        if (sceneGuard.isBlacklisted(i)) {
          JSONObject e = new JSONObject();
          e.setInt("id", i);
          e.setString("name", sceneNameOrFallback(i));
          bl.append(e);
        }
      }
    }
    root.setJSONArray("blacklist", bl);

    // Audio source
    JSONObject au = new JSONObject();
    if (audio != null) {
      String mode = audio.isDeviceInput() ? "DEVICE" : "FILE";
      au.setString("mode", mode);
      String src = "";
      if (audio.isDeviceInput()) {
        if (config != null && config.audioDeviceSelector != null) {
          src = config.audioDeviceSelector.getSelectedDeviceName();
        }
      } else {
        src = config != null && config.SONG_NAME != null ? config.SONG_NAME : "";
      }
      au.setString("source", src);
      au.setBoolean("playing", config != null && config.SONG_PLAYING);
      // Cheap level meter from current FFT mix buffer (RMS of left channel)
      float level = 0;
      try {
        if (audio.player != null && audio.player.left != null) {
          int n = audio.player.left.size();
          if (n > 0) {
            float sum = 0;
            for (int i = 0; i < n; i++) { float v = audio.player.left.get(i); sum += v * v; }
            level = (float) Math.sqrt(sum / n);
          }
        } else if (audio.audioInput != null && audio.audioInput.left != null) {
          int n = audio.audioInput.left.size();
          if (n > 0) {
            float sum = 0;
            for (int i = 0; i < n; i++) { float v = audio.audioInput.left.get(i); sum += v * v; }
            level = (float) Math.sqrt(sum / n);
          }
        }
      } catch (Throwable t) { /* best-effort */ }
      au.setFloat("levelRms", level);
    } else {
      au.setString("mode", "?");
      au.setString("source", "");
      au.setBoolean("playing", false);
      au.setFloat("levelRms", 0);
    }
    root.setJSONObject("audio", au);

    // Streamer (LAN streaming via MediaMTX)
    JSONObject st = new JSONObject();
    if (streamer != null) {
      st.setBoolean("running", streamer.running);
      st.setInt("framesPushed", streamer.framesPushed);
      st.setInt("framesDropped", streamer.framesDropped);
      st.setLong("startMs", streamer.startMs);
      st.setString("audioSource", streamer.audioSource == null ? "" : streamer.audioSource);
      st.setString("error", streamer.lastError == null ? "" : streamer.lastError);
    } else {
      st.setBoolean("running", false);
    }
    root.setJSONObject("stream", st);

    // Phone clients (count only — admin dashboard has full list)
    JSONObject clients = new JSONObject();
    if (clientRegistry != null) {
      clients.setInt("total", clientRegistry.byId.size());
      clients.setBoolean("lockdown", clientRegistry.lockdownMode);
      long remain = lockdownExpiresAtMs > 0 ? Math.max(0, lockdownExpiresAtMs - System.currentTimeMillis()) : 0;
      clients.setLong("lockdownRemainMs", remain);
    } else {
      clients.setInt("total", 0);
      clients.setBoolean("lockdown", false);
      clients.setLong("lockdownRemainMs", 0);
    }
    root.setJSONObject("clients", clients);

    return root.toString();
  }

  // ---------- Admin ----------

  // Token: read .devadmintoken from sketch dir; create with random value if missing.
  String adminToken;
  String getAdminToken() {
    if (adminToken != null) return adminToken;
    java.io.File f = new java.io.File(userDataPath(".devadmintoken"));
    try {
      if (f.exists()) {
        adminToken = new String(java.nio.file.Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8).trim();
      } else {
        adminToken = java.util.UUID.randomUUID().toString().replace("-", "");
        java.nio.file.Files.write(f.toPath(), adminToken.getBytes(StandardCharsets.UTF_8));
        println("[ADMIN] generated new token at " + f.getPath());
      }
      println("[ADMIN] token: " + adminToken);
    } catch (Exception e) {
      println("[ADMIN] token init failed: " + e.getMessage());
      adminToken = "";
    }
    return adminToken;
  }

  boolean isLocalhost(com.sun.net.httpserver.HttpExchange ex) {
    String h = ex.getRemoteAddress().getAddress().getHostAddress();
    return h.equals("127.0.0.1") || h.equals("0:0:0:0:0:0:0:1") || h.equals("::1");
  }

  // Per-IP brute-force lockout for /admin/auth. Mirrors PinManager.
  // 5 wrong tokens → 60s lockout. Localhost (laptop operator) is exempt.
  class AdminAttemptState { int wrong = 0; long lockUntilMs = 0; }
  final int  ADMIN_MAX_WRONG  = 5;
  final long ADMIN_LOCKOUT_MS = 60_000L;
  ConcurrentHashMap<String, AdminAttemptState> adminAttempts =
    new ConcurrentHashMap<String, AdminAttemptState>();

  AdminAttemptState adminAttemptState(String ip) {
    AdminAttemptState st = adminAttempts.get(ip);
    if (st == null) { st = new AdminAttemptState(); adminAttempts.put(ip, st); }
    return st;
  }
  boolean adminLockedOut(String ip) {
    AdminAttemptState st = adminAttempts.get(ip);
    if (st == null) return false;
    synchronized (st) { return st.lockUntilMs > System.currentTimeMillis(); }
  }
  void bumpAdminWrong(String ip) {
    AdminAttemptState st = adminAttemptState(ip);
    long now = System.currentTimeMillis();
    synchronized (st) {
      st.wrong++;
      if (st.wrong >= ADMIN_MAX_WRONG) {
        st.lockUntilMs = now + ADMIN_LOCKOUT_MS;
        println("[ADMIN] IP " + ip + " locked out for " + (ADMIN_LOCKOUT_MS/1000) + "s");
      }
    }
  }
  void resetAdminAttempts(String ip) {
    AdminAttemptState st = adminAttempts.get(ip);
    if (st != null) synchronized (st) { st.wrong = 0; st.lockUntilMs = 0; }
  }

  boolean adminAuthed(com.sun.net.httpserver.HttpExchange ex) {
    if (isLocalhost(ex)) return true;
    String hdr = ex.getRequestHeaders().getFirst("X-Admin-Token");
    if (hdr != null && hdr.equals(getAdminToken())) return true;
    String cookie = ex.getRequestHeaders().getFirst("Cookie");
    return cookie != null && cookie.contains("vis_admin=" + getAdminToken());
  }

  abstract class AdminHandlerBase implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type,X-Admin-Token");
      ex.getResponseHeaders().set("Content-Type", "application/json");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!adminAuthed(ex))     { ex.sendResponseHeaders(401, -1); ex.close(); return; }
      try {
        String body = handleAdmin(ex);
        byte[] out = body.getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(200, out.length);
        OutputStream os = ex.getResponseBody(); os.write(out); os.close();
      } catch (Exception e) {
        byte[] out = ("{\"error\":\"" + e.getMessage() + "\"}").getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(400, out.length);
        OutputStream os = ex.getResponseBody(); os.write(out); os.close();
      }
    }
    abstract String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception;

    JSONObject readJsonBody(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
      byte[] chunk = new byte[1024]; int n;
      while ((n = ex.getRequestBody().read(chunk)) > 0) buf.write(chunk, 0, n);
      return parseJSONObject(new String(buf.toByteArray(), StandardCharsets.UTF_8));
    }
  }

  // POST /admin/stream/toggle → admin-only. Cookie auth (vis_admin) or
  // X-Admin-Token header. Localhost bypasses auth (operator at the laptop).
  class AdminStreamToggleHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      if (!"POST".equals(ex.getRequestMethod())) throw new RuntimeException("POST required");
      if (streamer == null) throw new RuntimeException("streamer not initialized");
      streamer.toggle();
      return "{\"running\":" + streamer.running
           + ",\"error\":\"" + (streamer.lastError == null ? "" : streamer.lastError.replace("\"", "\\\"")) + "\"}";
    }
  }

  class AdminClientsHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) {
      return clientRegistry.snapshot().toString();
    }
  }
  class AdminKickHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      clientRegistry.kick(o.getString("clientId", ""));
      return "{\"ok\":true}";
    }
  }
  class AdminBanHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      clientRegistry.ban(o.getString("clientId", ""));
      return "{\"ok\":true}";
    }
  }
  class AdminUnbanHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      clientRegistry.unban(o.getString("clientId", null), o.getString("ip", null));
      return "{\"ok\":true}";
    }
  }
  // Optional auto-release timer. Set when admin posts {enabled:true, ttlMs:N}.
  // Cancelled on any subsequent /admin/lockdown POST.
  java.util.concurrent.ScheduledExecutorService lockdownTimer;
  java.util.concurrent.ScheduledFuture lockdownTimerFuture;
  volatile long lockdownExpiresAtMs = 0;

  class AdminLockdownHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      String m = ex.getRequestMethod();
      if (m.equals("GET")) {
        long remain = lockdownExpiresAtMs > 0 ? Math.max(0, lockdownExpiresAtMs - System.currentTimeMillis()) : 0;
        return "{\"enabled\":" + clientRegistry.lockdownMode + ",\"remainMs\":" + remain + "}";
      }
      JSONObject o = readJsonBody(ex);
      boolean enable = o.getBoolean("enabled", false);
      long ttlMs = 0;
      try { ttlMs = o.getLong("ttlMs", 0L); } catch (Exception ignore) {}
      // Always cancel any pending auto-release first.
      if (lockdownTimerFuture != null) { lockdownTimerFuture.cancel(false); lockdownTimerFuture = null; }
      lockdownExpiresAtMs = 0;
      clientRegistry.lockdownMode = enable;
      if (enable && ttlMs > 0) {
        if (lockdownTimer == null) {
          lockdownTimer = java.util.concurrent.Executors.newSingleThreadScheduledExecutor(new java.util.concurrent.ThreadFactory() {
            public Thread newThread(Runnable r) { Thread t = new Thread(r, "lockdown-timer"); t.setDaemon(true); return t; }
          });
        }
        lockdownExpiresAtMs = System.currentTimeMillis() + ttlMs;
        final long ttl = ttlMs;
        lockdownTimerFuture = lockdownTimer.schedule(new Runnable() {
          public void run() {
            clientRegistry.lockdownMode = false;
            lockdownExpiresAtMs = 0;
            println("[REG] lockdown auto-released after " + (ttl/1000) + "s");
          }
        }, ttlMs, java.util.concurrent.TimeUnit.MILLISECONDS);
      }
      println("[REG] lockdown " + (clientRegistry.lockdownMode ? "ON" : "OFF") + (ttlMs > 0 ? (" (ttl " + (ttlMs/1000) + "s)") : ""));
      long remain = lockdownExpiresAtMs > 0 ? Math.max(0, lockdownExpiresAtMs - System.currentTimeMillis()) : 0;
      return "{\"enabled\":" + clientRegistry.lockdownMode + ",\"remainMs\":" + remain + "}";
    }
  }
  class AdminRoleHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      clientRegistry.setRole(o.getString("clientId", ""), o.getString("role", "primary"));
      return "{\"ok\":true}";
    }
  }
  class AdminPinsListHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) {
      return pinManager.snapshot().toString();
    }
  }
  class AdminPinsMintHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      NamedPin np = pinManager.mint(o.getString("label", "guest"), o.getString("role", "primary"));
      JSONObject r = new JSONObject();
      r.setString("pin", np.fullPin());
      r.setString("role", np.role);
      return r.toString();
    }
  }
  class AdminPinsRevokeHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      JSONObject o = readJsonBody(ex);
      pinManager.revoke(o.getString("pin", ""));
      return "{\"ok\":true}";
    }
  }
  class AdminPinsRotateMasterHandler extends AdminHandlerBase {
    String handleAdmin(com.sun.net.httpserver.HttpExchange ex) throws Exception {
      String fresh = pinManager.rotateMaster();
      return "{\"masterPin\":\"" + fresh + "\"}";
    }
  }

  // Gate /admin.html: only localhost OR a valid auth cookie gets through.
  // The cookie is planted by POST /admin/auth — we deliberately do NOT accept
  // ?token=XXX in the URL, since query strings leak via screenshots, browser
  // history, referrer headers, and shoulder-surfing.
  boolean adminPageAllowed(com.sun.net.httpserver.HttpExchange ex) {
    if (isLocalhost(ex)) return true;
    String cookie = ex.getRequestHeaders().getFirst("Cookie");
    if (cookie != null && cookie.contains("vis_admin=" + getAdminToken())) return true;
    return false;
  }

  // POST /admin/logout — clears the auth cookie. HttpOnly means JS can't drop it,
  // so the server has to overwrite with Max-Age=0.
  class AdminLogoutHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().add("Set-Cookie", "vis_admin=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0");
      ex.getResponseHeaders().set("Content-Type", "application/json");
      byte[] body = "{\"ok\":true}".getBytes(StandardCharsets.UTF_8);
      ex.sendResponseHeaders(200, body.length);
      OutputStream os = ex.getResponseBody(); os.write(body); os.close();
    }
  }

  // POST /admin/auth { token: "..." } — validates and plants the cookie.
  // No GET (cookie via URL would defeat the point). Constant-time compare
  // so a quick brute-force loop can't easily distinguish prefix matches.
  class AdminAuthHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
      ex.getResponseHeaders().set("Access-Control-Allow-Methods", "POST,OPTIONS");
      ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");
      ex.getResponseHeaders().set("Content-Type", "application/json");
      String m = ex.getRequestMethod();
      if (m.equals("OPTIONS")) { ex.sendResponseHeaders(204, -1); ex.close(); return; }
      if (!m.equals("POST"))   { ex.sendResponseHeaders(405, -1); ex.close(); return; }
      String ip = ex.getRemoteAddress().getAddress().getHostAddress();
      boolean local = isLocalhost(ex);
      if (!local && adminLockedOut(ip)) {
        ex.sendResponseHeaders(429, -1); ex.close(); return;
      }
      try {
        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[1024]; int n;
        while ((n = ex.getRequestBody().read(chunk)) > 0) buf.write(chunk, 0, n);
        JSONObject o = parseJSONObject(new String(buf.toByteArray(), StandardCharsets.UTF_8));
        String submitted = (o == null) ? "" : o.getString("token", "");
        String expected  = getAdminToken();
        boolean ok = submitted != null && expected != null && submitted.length() == expected.length()
                  && java.security.MessageDigest.isEqual(submitted.getBytes(StandardCharsets.UTF_8), expected.getBytes(StandardCharsets.UTF_8));
        if (!ok) {
          if (!local) bumpAdminWrong(ip);
          ex.sendResponseHeaders(401, -1); ex.close(); return;
        }
        if (!local) resetAdminAttempts(ip);
        ex.getResponseHeaders().add("Set-Cookie",
          "vis_admin=" + expected + "; Path=/; HttpOnly; SameSite=Strict; Max-Age=86400");
        byte[] body = "{\"ok\":true}".getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(200, body.length);
        OutputStream os = ex.getResponseBody(); os.write(body); os.close();
      } catch (Exception e) {
        ex.sendResponseHeaders(400, -1); ex.close();
      }
    }
  }

  // Serves the static UI from ../../featureflags-ui/index.html so phones can hit
  // http://<pc-lan-ip>:8080/ without copying files.
  class UiHandler implements com.sun.net.httpserver.HttpHandler {
    public void handle(com.sun.net.httpserver.HttpExchange ex) throws IOException {
      String path = ex.getRequestURI().getPath();
      if (path.equals("/")) path = "/index.html";
      if (path.equals("/admin.html") && !adminPageAllowed(ex)) {
        // Redirect to a login form. Trade-off: this advertises that an admin page
        // exists, but the previous 404 forced operators to paste the token into
        // the URL — which leaks via screenshots / browser history. The login form
        // POSTs the token so it never appears in any URL.
        ex.getResponseHeaders().set("Location", "/admin-login.html");
        ex.sendResponseHeaders(302, -1); ex.close(); return;
      }
      // For an authorised admin pageview, plant the token cookie so admin/* fetches succeed.
      if (path.equals("/admin.html") && adminPageAllowed(ex)) {
        ex.getResponseHeaders().add("Set-Cookie",
          "vis_admin=" + getAdminToken() + "; Path=/; HttpOnly; SameSite=Strict; Max-Age=86400");
      }
      java.io.File root = new java.io.File(resourcePath("featureflags-ui")).getCanonicalFile();
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
      // Substitute the live WS port into HTML so the page reaches the right socket
      // even if 8081 was busy at startup and we walked forward.
      if (ct.startsWith("text/html")) {
        String s = new String(body, StandardCharsets.UTF_8).replace("__WS_PORT__", String.valueOf(wsPort));
        body = s.getBytes(StandardCharsets.UTF_8);
      }
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
