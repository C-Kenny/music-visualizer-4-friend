/**
 * ParamRouter — the single spine connecting every input source (controller,
 * keyboard, web UI) to the active scene's SceneParam knobs.
 *
 * Scenes opt in by overriding IScene.getParams(). Everything here no-ops
 * gracefully for scenes that don't, so it's safe to call unconditionally.
 *
 *   activeParams()                 — knobs of the current scene (or empty)
 *   setParamNorm(id, t)            — web slider / absolute 0..1 set
 *   paramsToJson()                 — discovery payload for the web UI
 *   routeParamsToSticks(c, p)      — reusable default controller mapping
 *   handleParamKey(k)              — keyboard select + nudge HELPER (a scene's
 *                                    own handleKey may call it; not global, so
 *                                    it never steals reserved global keys)
 */

int selectedParamIndex = 0;   // which knob keyboard nudging points at

SceneParam[] activeParams() {
  if (scenes == null) return new SceneParam[0];
  SceneParam[] p = scenes[config.STATE].getParams();
  return (p == null) ? new SceneParam[0] : p;
}

// Set a knob by id from a normalized 0..1 position. Returns true if it existed.
boolean setParamNorm(String id, float t) {
  if (paramAutoPilot != null) paramAutoPilot.noteActivity(); // web slider = human driving
  for (SceneParam p : activeParams()) {
    if (p.id.equals(id)) { p.setNorm(t); return true; }
  }
  return false;
}

// Set a knob by id to an absolute value. Returns true if it existed.
boolean setParamValue(String id, float v) {
  if (paramAutoPilot != null) paramAutoPilot.noteActivity();
  for (SceneParam p : activeParams()) {
    if (p.id.equals(id)) { p.set(v); return true; }
  }
  return false;
}

// JSON for the web UI: scene id + name + the live knob list.
String paramsToJson() {
  SceneParam[] ps = activeParams();
  String name = (scenes == null) ? "" : scenes[config.STATE].getClass().getSimpleName();
  StringBuilder sb = new StringBuilder();
  sb.append("{\"scene\":").append(config.STATE)
    .append(",\"name\":\"").append(paramJsonEsc(name))
    .append("\",\"params\":[");
  for (int i = 0; i < ps.length; i++) {
    SceneParam p = ps[i];
    if (i > 0) sb.append(",");
    sb.append("{\"id\":\"").append(paramJsonEsc(p.id))
      .append("\",\"label\":\"").append(paramJsonEsc(p.label))
      .append("\",\"min\":").append(p.min)
      .append(",\"max\":").append(p.max)
      .append(",\"value\":").append(p.value)
      .append(",\"norm\":").append(p.norm())
      .append("}");
  }
  sb.append("]}");
  return sb.toString();
}

String paramJsonEsc(String s) {
  if (s == null) return "";
  return s.replace("\\", "\\\\").replace("\"", "\\\"");
}

/**
 * Reusable default controller mapping a scene can call from applyController():
 * left stick X/Y + right stick X/Y drive the first four knobs; triggers nudge
 * the 5th; A resets all. Gives a scene full generic control with one line.
 * Deadzoned so a centred stick doesn't drift the knobs.
 */
void routeParamsToSticks(Controller c, SceneParam[] p) {
  if (p == null || p.length == 0) return;
  float lx = (c.lx - width  * 0.5) / (width  * 0.5);
  float ly = (c.ly - height * 0.5) / (height * 0.5);
  float rx = (c.rx - width  * 0.5) / (width  * 0.5);
  float ry = (c.ry - height * 0.5) / (height * 0.5);
  float dz = 0.12;
  if (p.length > 0 && abs(lx) > dz) p[0].nudgeNorm(lx * 0.02);
  if (p.length > 1 && abs(ly) > dz) p[1].nudgeNorm(-ly * 0.02);
  if (p.length > 2 && abs(rx) > dz) p[2].nudgeNorm(rx * 0.02);
  if (p.length > 3 && abs(ry) > dz) p[3].nudgeNorm(-ry * 0.02);
  if (p.length > 4) {
    if (c.lt > 0.15) p[4].nudgeNorm(-0.02 * c.lt);
    if (c.rt > 0.15) p[4].nudgeNorm( 0.02 * c.rt);
  }
  if (c.aJustPressed) for (SceneParam q : p) q.reset();
}

/**
 * Keyboard knob helper for scenes that want it — call from the scene's own
 * handleKey(char). NOT wired globally (the obvious keys [ ] - = \ are already
 * taken by setlist / gain / line-break). Returns true if the key was consumed.
 *   < >  select previous / next knob      (any of , . too)
 *   - +  nudge selected knob down / up    (5% of range)
 */
boolean handleParamKey(char k) {
  SceneParam[] ps = activeParams();
  if (ps.length == 0) return false;
  selectedParamIndex = constrain(selectedParamIndex, 0, ps.length - 1);
  switch (k) {
    case '<': case ',': selectedParamIndex = (selectedParamIndex + ps.length - 1) % ps.length; return true;
    case '>': case '.': selectedParamIndex = (selectedParamIndex + 1) % ps.length; return true;
    case '-': ps[selectedParamIndex].nudgeNorm(-0.05); return true;
    case '+': ps[selectedParamIndex].nudgeNorm( 0.05); return true;
  }
  return false;
}
