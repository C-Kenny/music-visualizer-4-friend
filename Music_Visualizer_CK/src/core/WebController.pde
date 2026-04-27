// WebController — phone/web input merged across many simultaneous clients.
//
// Each client (identified by its handshake clientId) writes into its own slot.
// applyTo() aggregates across all non-spectator, non-banned clients each frame:
//   sticks   → sum then clamp to unit circle (idle clients contribute 0)
//   triggers → max across clients (matches "any client pulls it = pulled")
//   buttons  → OR of held state across clients
//   edges    → fires once if ANY client tapped that frame
//
// Button vocabulary (case-insensitive):
//   A B X Y           — face buttons
//   LB RB             — shoulder bumpers
//   BACK START        — menu buttons
//   DUP DDOWN DLEFT DRIGHT — D-pad
//
// "down" both holds the button AND fires the rising edge once — matches
// physical-controller semantics so scenes that only check `*JustPressed`
// react to a phone tap.
//
// Scenes that want per-role input (e.g. one phone owns "fins", another owns
// "diamonds") can call getRoleSticks(role) instead of consuming the aggregate.

import java.util.concurrent.ConcurrentHashMap;

class PerClientInput {
  // Sticks (-1..1)
  volatile float lx = 0, ly = 0, rx = 0, ry = 0;
  volatile long lastStickMs = 0;

  // Triggers (0..1)
  volatile float lt = 0, rt = 0;

  // Buttons — parallel arrays indexed by BTN_NAMES.
  // held[i]  = currently down
  // edge[i]  = pending rising-edge event (consumed once on applyTo)
  volatile boolean[] held = new boolean[12];
  volatile boolean[] edge = new boolean[12];
}

class WebController {
  static final int STICK_TIMEOUT_MS = 500;

  // Order matters — applyButtons() depends on these indices.
  final String[] BTN_NAMES = {
    "A", "B", "X", "Y",
    "LB", "RB",
    "BACK", "START",
    "DUP", "DDOWN", "DLEFT", "DRIGHT"
  };

  ConcurrentHashMap<String, PerClientInput> inputs = new ConcurrentHashMap<String, PerClientInput>();

  PerClientInput slot(String clientId) {
    if (clientId == null) clientId = "_anon";
    PerClientInput p = inputs.get(clientId);
    if (p == null) {
      p = new PerClientInput();
      inputs.put(clientId, p);
    }
    return p;
  }

  int btnIndex(String name) {
    if (name == null) return -1;
    for (int i = 0; i < BTN_NAMES.length; i++) {
      if (BTN_NAMES[i].equalsIgnoreCase(name)) return i;
    }
    return -1;
  }

  void setSticks(String clientId, float lx, float ly, float rx, float ry) {
    PerClientInput p = slot(clientId);
    p.lx = lx; p.ly = ly; p.rx = rx; p.ry = ry;
    p.lastStickMs = System.currentTimeMillis();
  }

  void setTrigger(String clientId, String which, float value) {
    PerClientInput p = slot(clientId);
    if (value < 0) value = 0; if (value > 1) value = 1;
    if ("L".equalsIgnoreCase(which)) p.lt = value;
    else if ("R".equalsIgnoreCase(which)) p.rt = value;
  }

  void setButton(String clientId, String btn, String action) {
    int idx = btnIndex(btn);
    if (idx < 0) return;
    PerClientInput p = slot(clientId);
    if (action.equals("down"))      { p.held[idx] = true;  p.edge[idx] = true; }
    else if (action.equals("up"))   { p.held[idx] = false; }
    else if (action.equals("tap"))  { p.edge[idx] = true; }
  }

  void removeClient(String clientId) {
    if (clientId != null) inputs.remove(clientId);
  }

  // True if any client has fresh stick data, held button, or pulled trigger.
  boolean isActive() {
    long now = System.currentTimeMillis();
    for (java.util.Map.Entry<String, PerClientInput> e : inputs.entrySet()) {
      if (!isContributing(e.getKey())) continue;
      PerClientInput p = e.getValue();
      if ((now - p.lastStickMs) < STICK_TIMEOUT_MS) return true;
      if (p.lt > 0 || p.rt > 0) return true;
      for (int i = 0; i < p.held.length; i++) if (p.held[i]) return true;
    }
    return false;
  }

  // Skip spectators and banned clients.
  boolean isContributing(String clientId) {
    if (clientRegistry == null) return true;
    ClientInfo info = clientRegistry.byId.get(clientId);
    if (info == null) return true;
    if (clientRegistry.bannedIds.contains(clientId)) return false;
    return !"spectator".equals(info.role);
  }

  // Aggregate sticks across contributing clients with fresh stick data.
  float[] aggregateSticks() {
    float lx = 0, ly = 0, rx = 0, ry = 0;
    long now = System.currentTimeMillis();
    for (java.util.Map.Entry<String, PerClientInput> e : inputs.entrySet()) {
      if (!isContributing(e.getKey())) continue;
      PerClientInput p = e.getValue();
      if ((now - p.lastStickMs) >= STICK_TIMEOUT_MS) continue;
      lx += p.lx; ly += p.ly; rx += p.rx; ry += p.ry;
    }
    return new float[] { clamp1(lx), clamp1(ly), clamp1(rx), clamp1(ry) };
  }

  float clamp1(float v) { return v < -1 ? -1 : (v > 1 ? 1 : v); }

  // Per-role aggregate — for scenes that want partial control assignments.
  float[] getRoleSticks(String role) {
    float lx = 0, ly = 0, rx = 0, ry = 0;
    long now = System.currentTimeMillis();
    for (java.util.Map.Entry<String, PerClientInput> e : inputs.entrySet()) {
      String id = e.getKey();
      if (!isContributing(id)) continue;
      ClientInfo info = clientRegistry == null ? null : clientRegistry.byId.get(id);
      String r = info == null ? "primary" : info.role;
      if (!role.equals(r)) continue;
      PerClientInput p = e.getValue();
      if ((now - p.lastStickMs) >= STICK_TIMEOUT_MS) continue;
      lx += p.lx; ly += p.ly; rx += p.rx; ry += p.ry;
    }
    return new float[] { clamp1(lx), clamp1(ly), clamp1(rx), clamp1(ry) };
  }

  void applyTo(Controller c) {
    long now = System.currentTimeMillis();

    // Sticks
    boolean anyFreshStick = false;
    for (java.util.Map.Entry<String, PerClientInput> e : inputs.entrySet()) {
      if (!isContributing(e.getKey())) continue;
      if ((now - e.getValue().lastStickMs) < STICK_TIMEOUT_MS) { anyFreshStick = true; break; }
    }
    if (anyFreshStick) {
      float[] agg = aggregateSticks();
      c.lx = map(agg[0], -1, 1, 0, width);
      c.ly = map(agg[1], -1, 1, 0, height);
      c.rx = map(agg[2], -1, 1, 0, width);
      c.ry = map(agg[3], -1, 1, 0, height);
    }

    // Triggers + buttons in one pass
    float lt = 0, rt = 0;
    boolean[] orHeld = new boolean[BTN_NAMES.length];
    boolean[] orEdge = new boolean[BTN_NAMES.length];
    for (java.util.Map.Entry<String, PerClientInput> e : inputs.entrySet()) {
      if (!isContributing(e.getKey())) continue;
      PerClientInput p = e.getValue();
      if (p.lt > lt) lt = p.lt;
      if (p.rt > rt) rt = p.rt;
      for (int i = 0; i < orHeld.length; i++) {
        if (p.held[i]) orHeld[i] = true;
        if (p.edge[i]) { orEdge[i] = true; p.edge[i] = false; }
      }
    }
    if (lt > c.lt) c.lt = lt;
    if (rt > c.rt) c.rt = rt;
    applyButtons(c, orHeld, orEdge);
  }

  // Map indexed bool[] back to Controller's named fields.
  // Index order: A B X Y LB RB BACK START DUP DDOWN DLEFT DRIGHT
  void applyButtons(Controller c, boolean[] h, boolean[] e) {
    if (h[0])  c.aButton = true;
    if (h[1])  c.bButton = true;
    if (h[2])  c.xButton = true;
    if (h[3])  c.yButton = true;
    if (h[4])  c.lbButton = true;
    if (h[5])  c.rbButton = true;
    if (h[6])  c.backButton = true;
    if (h[7])  c.startButton = true;
    if (h[8])  c.dpadUpHeld = true;
    if (h[9])  c.dpadDownHeld = true;
    if (h[10]) c.dpadLeftHeld = true;
    if (h[11]) c.dpadRightHeld = true;

    if (e[0])  c.aJustPressed = true;
    if (e[1])  c.bJustPressed = true;
    if (e[2])  c.xJustPressed = true;
    if (e[3])  c.yJustPressed = true;
    if (e[4])  c.lbJustPressed = true;
    if (e[5])  c.rbJustPressed = true;
    if (e[6])  c.backJustPressed = true;
    if (e[7])  c.startJustPressed = true;
    if (e[8])  c.dpadUpJustPressed = true;
    if (e[9])  c.dpadDownJustPressed = true;
    if (e[10]) c.dpadLeftJustPressed = true;
    if (e[11]) c.dpadRightJustPressed = true;
  }
}
