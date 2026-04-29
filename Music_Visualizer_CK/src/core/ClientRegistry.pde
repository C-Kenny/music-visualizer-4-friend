// ClientRegistry — per-client identity, metadata, bans, rate limiting.
//
// Identity comes from the browser (UUID in localStorage) sent via the "hello"
// handshake. We trust that as a stable handle for kick/ban; IP is the secondary
// anchor so a banned user can't just clear localStorage and reconnect.
//
// Persistence: bans.json next to the sketch. Loaded on start, written on every
// ban/unban. Rate-limit and live client maps are in-memory only.

import org.java_websocket.WebSocket;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

class ClientInfo {
  String clientId;
  String nickname = "";
  String ua = "";
  String platform = "";
  String model = "";        // navigator.userAgentData.model when available
  int screenW = 0, screenH = 0;
  float dpr = 1;
  String ip = "";
  long connectMs;
  volatile long lastMsgMs;
  AtomicLong msgCount = new AtomicLong(0);
  volatile String role = "primary";   // primary | co1 | co2 | spectator | admin | guest
  volatile boolean pinVerified = false;
  volatile WebSocket conn;            // null = HTTP-fallback client

  // rate limit: timestamps ring buffer (last RATE_WINDOW ms)
  long[] tsRing = new long[256];
  int tsHead = 0;
}

class ClientRegistry {
  static final int RATE_WINDOW_MS  = 1000;
  static final int RATE_LIMIT_MSGS = 120;          // per RATE_WINDOW_MS
  static final long IDLE_PRUNE_MS  = 60_000;       // HTTP clients with no msgs

  ConcurrentHashMap<String, ClientInfo> byId = new ConcurrentHashMap<String, ClientInfo>();
  // Bans
  java.util.Set<String> bannedIds = java.util.Collections.synchronizedSet(new java.util.HashSet<String>());
  java.util.Set<String> bannedIps = java.util.Collections.synchronizedSet(new java.util.HashSet<String>());
  // Soft bans applied by KICK — block reconnect for a window without polluting persistent bans.
  ConcurrentHashMap<String, Long> tempBanIds = new ConcurrentHashMap<String, Long>();
  ConcurrentHashMap<String, Long> tempBanIps = new ConcurrentHashMap<String, Long>();
  static final long KICK_COOLDOWN_MS = 5 * 60_000L;
  // Admin panic-button: when true, all new external connections are refused
  // (admin/localhost still allowed via the localhost bypass in routes that need it).
  volatile boolean lockdownMode = false;
  String bansPath;

  ClientRegistry() {
    bansPath = userDataPath("bans.json");
    loadBans();
  }

  // --- Connection / handshake ---

  // Register from WS onOpen. Returns false if banned (caller should close).
  boolean registerWs(WebSocket conn, String ip) {
    if (lockdownMode) { println("[REG] reject — lockdown active, ip=" + ip); return false; }
    if (bannedIps.contains(ip)) {
      println("[REG] reject banned IP " + ip);
      return false;
    }
    if (isTempBanned(null, ip)) { println("[REG] reject temp-banned IP " + ip); return false; }
    return true;   // actual ClientInfo created on hello (we don't have id yet)
  }

  // Temp-ban check: true while either the clientId or IP is within its kick window.
  boolean isTempBanned(String clientId, String ip) {
    long now = System.currentTimeMillis();
    if (clientId != null) {
      Long t = tempBanIds.get(clientId);
      if (t != null) { if (t > now) return true; tempBanIds.remove(clientId); }
    }
    if (ip != null) {
      Long t = tempBanIps.get(ip);
      if (t != null) { if (t > now) return true; tempBanIps.remove(ip); }
    }
    return false;
  }

  void tempBan(String clientId, String ip, long ttlMs) {
    long until = System.currentTimeMillis() + ttlMs;
    if (clientId != null && clientId.length() > 0) tempBanIds.put(clientId, until);
    if (ip != null && ip.length() > 0)             tempBanIps.put(ip, until);
  }

  // Apply hello payload: validate PIN, create-or-update info. Returns null on
  // success or a short error string ("banned", "locked", "wrong-pin", "rebound").
  String applyHello(WebSocket conn, String ip, JSONObject hello) {
    String id = hello.getString("clientId", "");
    if (id == null || id.length() == 0) {
      id = "anon-" + java.util.UUID.randomUUID().toString().substring(0, 8);
    }
    if (lockdownMode) { println("[REG] reject — lockdown active, id=" + id); return "lockdown"; }
    if (bannedIds.contains(id) || bannedIps.contains(ip)) {
      println("[REG] reject banned id=" + id + " ip=" + ip);
      return "banned";
    }
    if (isTempBanned(id, ip)) { println("[REG] reject temp-banned id=" + id); return "kicked"; }
    String pin = hello.getString("pin", "");
    String pinResult = pinManager.validate(pin, ip, id);
    if (pinResult.equals("locked"))   return "locked";
    if (pinResult.equals("wrong"))    return "wrong-pin";
    if (pinResult.equals("rebound"))  return "rebound";
    String roleFromPin = "guest";
    if (pinResult.startsWith("ok-named:")) roleFromPin = pinResult.substring("ok-named:".length());

    ClientInfo info = byId.get(id);
    if (info == null) {
      info = new ClientInfo();
      info.clientId = id;
      info.connectMs = System.currentTimeMillis();
      info.role = roleFromPin;
      byId.put(id, info);
    } else {
      info.role = roleFromPin;
    }
    info.conn = conn;
    info.ip = ip;
    info.nickname = hello.getString("nickname", info.nickname);
    info.ua       = hello.getString("ua",       info.ua);
    info.platform = hello.getString("platform", info.platform);
    info.model    = hello.getString("model",    info.model);
    info.dpr      = hello.getFloat("dpr",       info.dpr);
    JSONArray scr = hello.getJSONArray("screen");
    if (scr != null && scr.size() == 2) {
      info.screenW = scr.getInt(0);
      info.screenH = scr.getInt(1);
    }
    info.lastMsgMs = System.currentTimeMillis();
    info.pinVerified = true;
    println("[REG] hello id=" + id + " nick=" + info.nickname + " ip=" + ip + " role=" + info.role + " model=" + info.model);
    return null;
  }

  // HTTP fallback: minimal registration when we only have headers.
  ClientInfo touchHttp(String clientId, String ip) {
    if (clientId == null || clientId.length() == 0) clientId = "http-" + ip;
    if (lockdownMode) return null;
    if (bannedIds.contains(clientId) || bannedIps.contains(ip)) return null;
    if (isTempBanned(clientId, ip)) return null;
    ClientInfo info = byId.get(clientId);
    if (info == null) {
      info = new ClientInfo();
      info.clientId = clientId;
      info.connectMs = System.currentTimeMillis();
      info.ip = ip;
      info.platform = "http";
      byId.put(clientId, info);
    }
    info.lastMsgMs = System.currentTimeMillis();
    return info;
  }

  ClientInfo byConn(WebSocket conn) {
    for (ClientInfo i : byId.values()) if (i.conn == conn) return i;
    return null;
  }

  void onClose(WebSocket conn) {
    ClientInfo i = byConn(conn);
    if (i != null) i.conn = null;   // keep entry briefly so admin sees disconnect; pruned later
  }

  // --- Rate limiting ---

  // True = allowed. False = drop (over limit).
  boolean allow(ClientInfo info) {
    if (info == null) return false;
    long now = System.currentTimeMillis();
    info.lastMsgMs = now;
    info.msgCount.incrementAndGet();
    synchronized (info) {
      info.tsRing[info.tsHead] = now;
      info.tsHead = (info.tsHead + 1) % info.tsRing.length;
      // Count entries within window
      int hits = 0;
      long cutoff = now - RATE_WINDOW_MS;
      for (int k = 0; k < info.tsRing.length; k++) {
        if (info.tsRing[k] > cutoff) hits++;
      }
      return hits <= RATE_LIMIT_MSGS;
    }
  }

  // --- Admin actions ---

  void kick(String clientId) {
    ClientInfo i = byId.get(clientId);
    String ip = (i != null) ? i.ip : null;
    if (i != null && i.conn != null) {
      try { i.conn.close(1000, "kicked"); } catch (Exception e) {}
    }
    byId.remove(clientId);
    // Without a cooldown the kicked phone just reconnects with the same PIN.
    // 5-minute soft ban on (id, ip) keeps them out without a permanent ban.
    tempBan(clientId, ip, KICK_COOLDOWN_MS);
    println("[REG] kicked " + clientId + " (cooldown " + (KICK_COOLDOWN_MS/1000) + "s)");
  }

  void ban(String clientId) {
    ClientInfo i = byId.get(clientId);
    if (i != null) {
      bannedIds.add(clientId);
      if (i.ip != null && i.ip.length() > 0) bannedIps.add(i.ip);
    } else {
      bannedIds.add(clientId);   // ban by id even if not currently connected
    }
    saveBans();
    kick(clientId);
    println("[REG] banned " + clientId);
  }

  void unban(String clientId, String ip) {
    if (clientId != null) bannedIds.remove(clientId);
    if (ip != null) bannedIps.remove(ip);
    saveBans();
  }

  void setRole(String clientId, String role) {
    ClientInfo i = byId.get(clientId);
    if (i != null) i.role = role;
  }

  // --- Snapshot for admin UI ---

  JSONObject snapshot() {
    pruneIdleHttp();
    JSONObject root = new JSONObject();
    JSONArray arr = new JSONArray();
    int idx = 0;
    long now = System.currentTimeMillis();
    for (ClientInfo i : byId.values()) {
      JSONObject o = new JSONObject();
      o.setString("clientId", i.clientId);
      o.setString("nickname", i.nickname);
      o.setString("ip", i.ip);
      o.setString("ua", i.ua);
      o.setString("platform", i.platform);
      o.setString("model", i.model);
      o.setInt("screenW", i.screenW);
      o.setInt("screenH", i.screenH);
      o.setFloat("dpr", i.dpr);
      o.setString("role", i.role);
      o.setLong("connectMs", i.connectMs);
      o.setLong("ageMs", now - i.connectMs);
      o.setLong("idleMs", now - i.lastMsgMs);
      o.setLong("msgCount", i.msgCount.get());
      o.setBoolean("connected", i.conn != null && i.conn.isOpen());
      arr.setJSONObject(idx++, o);
    }
    root.setJSONArray("clients", arr);
    JSONArray bIds = new JSONArray();
    int k = 0; for (String s : bannedIds) bIds.setString(k++, s);
    JSONArray bIps = new JSONArray();
    k = 0; for (String s : bannedIps) bIps.setString(k++, s);
    root.setJSONArray("bannedIds", bIds);
    root.setJSONArray("bannedIps", bIps);
    return root;
  }

  void pruneIdleHttp() {
    long now = System.currentTimeMillis();
    java.util.Iterator<java.util.Map.Entry<String,ClientInfo>> it = byId.entrySet().iterator();
    while (it.hasNext()) {
      ClientInfo i = it.next().getValue();
      if (i.conn == null && (now - i.lastMsgMs) > IDLE_PRUNE_MS) it.remove();
    }
  }

  // --- Persistence ---

  void loadBans() {
    java.io.File f = new java.io.File(bansPath);
    if (!f.exists()) return;
    try {
      JSONObject o = loadJSONObject(bansPath);
      JSONArray ids = o.getJSONArray("ids");
      if (ids != null) for (int k = 0; k < ids.size(); k++) bannedIds.add(ids.getString(k));
      JSONArray ips = o.getJSONArray("ips");
      if (ips != null) for (int k = 0; k < ips.size(); k++) bannedIps.add(ips.getString(k));
      println("[REG] loaded " + bannedIds.size() + " banned ids, " + bannedIps.size() + " banned ips");
    } catch (Exception e) {
      println("[REG] bans load failed: " + e.getMessage());
    }
  }

  void saveBans() {
    JSONObject o = new JSONObject();
    JSONArray ids = new JSONArray();
    int k = 0; for (String s : bannedIds) ids.setString(k++, s);
    JSONArray ips = new JSONArray();
    k = 0; for (String s : bannedIps) ips.setString(k++, s);
    o.setJSONArray("ids", ids);
    o.setJSONArray("ips", ips);
    saveJSONObject(o, bansPath);
  }
}
