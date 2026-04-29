// PinManager — venue master PIN + per-person named PINs + brute-force lockout.
//
// Master PIN: regenerated each launch, displayed on screen + admin panel + QR.
//   Anyone with it connects as role="guest". Rotates every restart.
//
// Named PIN: minted by admin, e.g. "alice-3F7K29" (label=alice, secret=3F7K29).
//   First successful use binds it to a clientId; reuse from a different client
//   is rejected (forces admin to revoke + re-mint if a friend swaps phones).
//   Carries a role (primary/co1/co2/admin), persisted to pins.json.
//
// Lockout: per-IP. 5 wrong attempts → 60s. Each subsequent failure during
// lockout extends. Crude but enough — the alphabet is ~32^6 = 1B combos.
//
// Alphabet: 32 chars, no 0/O/1/I/l/B/8 ambiguity, easy on phone keyboards.

import java.util.concurrent.ConcurrentHashMap;

class NamedPin {
  String label;          // human label e.g. "alice"
  String secret;         // 6-char random part
  String role;           // role this PIN grants
  String boundClientId;  // null until first use
  long mintedMs;
  long lastUsedMs;

  String fullPin() { return label + "-" + secret; }
}

class IpAttemptState {
  int wrong = 0;
  long lockUntilMs = 0;
}

class PinManager {
  static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 chars
  static final int  PIN_LEN = 6;
  static final int  MAX_WRONG_BEFORE_LOCK = 5;
  static final long LOCKOUT_MS = 60_000;

  String masterPin;
  ConcurrentHashMap<String, NamedPin> namedByFull = new ConcurrentHashMap<String, NamedPin>();
  ConcurrentHashMap<String, IpAttemptState> attempts = new ConcurrentHashMap<String, IpAttemptState>();
  String pinsPath;
  java.security.SecureRandom rng = new java.security.SecureRandom();

  PinManager() {
    pinsPath = userDataPath("pins.json");
    masterPin = randomPin();
    println("[PIN] master PIN this session: " + masterPin);
    loadNamed();
  }

  // --- Generation ---

  String randomPin() {
    StringBuilder sb = new StringBuilder(PIN_LEN);
    for (int i = 0; i < PIN_LEN; i++) sb.append(ALPHABET.charAt(rng.nextInt(ALPHABET.length())));
    return sb.toString();
  }

  // Sanitise label: lowercase, alphanum + dashes, max 16 chars.
  String sanitiseLabel(String s) {
    if (s == null) return "guest";
    StringBuilder out = new StringBuilder();
    for (char c : s.toLowerCase().toCharArray()) {
      if (out.length() >= 16) break;
      if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-') out.append(c);
    }
    if (out.length() == 0) out.append("guest");
    return out.toString();
  }

  // --- Validation ---

  // Result codes: "ok-master", "ok-named:<role>", "locked", "wrong", "rebound"
  String validate(String pin, String ip, String clientId) {
    if (pin == null) pin = "";
    pin = pin.trim();
    long now = System.currentTimeMillis();

    IpAttemptState st = attempts.get(ip);
    if (st == null) { st = new IpAttemptState(); attempts.put(ip, st); }
    synchronized (st) {
      if (st.lockUntilMs > now) return "locked";
    }

    if (pin.length() == 0) {
      bumpWrong(st, now); return "wrong";
    }

    if (pin.equalsIgnoreCase(masterPin)) {
      resetAttempts(st);
      return "ok-master";
    }

    NamedPin np = lookupNamed(pin);
    if (np != null) {
      synchronized (np) {
        if (np.boundClientId == null || np.boundClientId.equals(clientId)) {
          np.boundClientId = clientId;
          np.lastUsedMs = now;
          saveNamed();
          resetAttempts(st);
          return "ok-named:" + np.role;
        } else {
          // PIN stolen / used from a different client.
          bumpWrong(st, now);
          return "rebound";
        }
      }
    }

    bumpWrong(st, now);
    return "wrong";
  }

  NamedPin lookupNamed(String pin) {
    NamedPin np = namedByFull.get(pin);
    if (np != null) return np;
    // case-insensitive fallback (label is lowercase, secret is uppercase but be lenient)
    for (NamedPin n : namedByFull.values()) if (n.fullPin().equalsIgnoreCase(pin)) return n;
    return null;
  }

  void bumpWrong(IpAttemptState st, long now) {
    synchronized (st) {
      st.wrong++;
      if (st.wrong >= MAX_WRONG_BEFORE_LOCK) {
        st.lockUntilMs = now + LOCKOUT_MS;
        println("[PIN] IP locked out");
      }
    }
  }

  void resetAttempts(IpAttemptState st) {
    synchronized (st) { st.wrong = 0; st.lockUntilMs = 0; }
  }

  // --- Admin: mint / revoke ---

  NamedPin mint(String label, String role) {
    NamedPin np = new NamedPin();
    np.label = sanitiseLabel(label);
    np.secret = randomPin();
    np.role = role == null ? "primary" : role;
    np.mintedMs = System.currentTimeMillis();
    namedByFull.put(np.fullPin(), np);
    saveNamed();
    println("[PIN] minted " + np.fullPin() + " role=" + np.role);
    return np;
  }

  void revoke(String fullPin) {
    NamedPin np = lookupNamed(fullPin);
    if (np != null) {
      namedByFull.remove(np.fullPin());
      saveNamed();
      println("[PIN] revoked " + fullPin);
    }
  }

  // --- Snapshot for admin UI ---

  JSONObject snapshot() {
    JSONObject root = new JSONObject();
    root.setString("master", masterPin);
    JSONArray arr = new JSONArray();
    int i = 0;
    for (NamedPin np : namedByFull.values()) {
      JSONObject o = new JSONObject();
      o.setString("pin", np.fullPin());
      o.setString("label", np.label);
      o.setString("role", np.role);
      o.setString("boundClientId", np.boundClientId == null ? "" : np.boundClientId);
      o.setLong("mintedMs", np.mintedMs);
      o.setLong("lastUsedMs", np.lastUsedMs);
      arr.setJSONObject(i++, o);
    }
    root.setJSONArray("named", arr);
    return root;
  }

  // --- Persistence ---

  void loadNamed() {
    java.io.File f = new java.io.File(pinsPath);
    if (!f.exists()) return;
    try {
      JSONObject o = loadJSONObject(pinsPath);
      JSONArray arr = o.getJSONArray("named");
      if (arr == null) return;
      for (int i = 0; i < arr.size(); i++) {
        JSONObject e = arr.getJSONObject(i);
        NamedPin np = new NamedPin();
        np.label = e.getString("label", "guest");
        np.secret = e.getString("secret", "");
        np.role = e.getString("role", "primary");
        np.boundClientId = e.getString("boundClientId", null);
        if ("".equals(np.boundClientId)) np.boundClientId = null;
        np.mintedMs = e.getLong("mintedMs", 0);
        np.lastUsedMs = e.getLong("lastUsedMs", 0);
        if (np.secret.length() > 0) namedByFull.put(np.fullPin(), np);
      }
      println("[PIN] loaded " + namedByFull.size() + " named PINs");
    } catch (Exception e) {
      println("[PIN] load failed: " + e.getMessage());
    }
  }

  void saveNamed() {
    JSONObject o = new JSONObject();
    JSONArray arr = new JSONArray();
    int i = 0;
    for (NamedPin np : namedByFull.values()) {
      JSONObject e = new JSONObject();
      e.setString("label", np.label);
      e.setString("secret", np.secret);
      e.setString("role", np.role);
      e.setString("boundClientId", np.boundClientId == null ? "" : np.boundClientId);
      e.setLong("mintedMs", np.mintedMs);
      e.setLong("lastUsedMs", np.lastUsedMs);
      arr.setJSONObject(i++, e);
    }
    o.setJSONArray("named", arr);
    saveJSONObject(o, pinsPath);
  }
}
