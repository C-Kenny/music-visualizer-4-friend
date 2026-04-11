/**
 * ControllerLayout — structured controller guide system
 *
 * Each scene returns ControllerLayout[] from getControllerLayout() describing
 * its controls. drawControllerGuide() renders a dynamic diagram using real
 * Xbox controller SVG assets.
 *
 * Usage in a scene:
 *   ControllerLayout[] getControllerLayout() {
 *     return new ControllerLayout[] {
 *       new ControllerLayout("LStick ↕", "Rotation speed"),
 *       new ControllerLayout("A",         "Beat pulse"),
 *       new ControllerLayout("LT",        "Zoom in"),
 *     };
 *   }
 *
 * Button name tokens (used for position lookup):
 *   Front view : A  B  X  Y  LB  RB  LStick  RStick  D-pad  Back  Start
 *   Back view  : LT  RT
 */

class ControllerLayout {
  String button;
  String description;

  ControllerLayout(String button, String description) {
    this.button      = button;
    this.description = description;
  }
}

// ─── SVG viewBox dimensions ───────────────────────────────────────────────────
static final float FRONT_SVG_W = 580.032;
static final float FRONT_SVG_H = 580.032;
// Back view is drawn programmatically; no SVG constants needed.

// ─── Button positions in SVG coordinate space ─────────────────────────────────
// Front view (580 × 580). Face button centres are exact (read from SVG <circle>
// elements). LB/RB/D-pad are estimated from body path geometry.

PVector[] FRONT_BTN_KEYS_VEC;   // parallel arrays — Processing has no easy HashMap literal
String[]  FRONT_BTN_KEYS;

void initButtonPositions() {
  FRONT_BTN_KEYS = new String[]{
    "A",      "B",      "X",      "Y",
    "LStick", "RStick", "D-pad",
    "LB",     "RB",
    "Back",   "Start"
  };
  FRONT_BTN_KEYS_VEC = new PVector[]{
    new PVector(438.047, 252.192),   // A  (bottom of face cluster)
    new PVector(479.1,   212.094),   // B  (right)
    new PVector(399.932, 212.094),   // X  (left)
    new PVector(438.047, 173.997),   // Y  (top)
    new PVector(142.139, 211.103),   // Left  stick
    new PVector(365.299, 300.662),   // Right stick
    new PVector(203.0,   305.0),     // D-pad centre  (estimated)
    new PVector(168.0,   112.0),     // LB bumper     (estimated)
    new PVector(412.0,   112.0),     // RB bumper     (estimated)
    new PVector(249.019, 212.094),   // Back / Select
    new PVector(332.146, 212.094)    // Start
  };
}

// Back view is drawn programmatically — no SVG.
// Button screen positions are computed in getBackScreenPos().

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Convert a point in SVG space to screen space given the display rect.
PVector svgToScreen(float svgX, float svgY,
                    float cx,   float cy,
                    float svgW, float svgH,
                    float dispW, float dispH) {
  return new PVector(
    cx - dispW * 0.5 + svgX * (dispW / svgW),
    cy - dispH * 0.5 + svgY * (dispH / svgH)
  );
}

// Look up button SVG position, falling back to substring match for
// labels like "LStick ↕" or "D-pad ↔".
PVector getFrontPos(String btn) {
  if (FRONT_BTN_KEYS == null) initButtonPositions();
  for (int i = 0; i < FRONT_BTN_KEYS.length; i++) {
    if (btn.equals(FRONT_BTN_KEYS[i]) || btn.contains(FRONT_BTN_KEYS[i]))
      return FRONT_BTN_KEYS_VEC[i];
  }
  return null;
}

// Returns the screen-space centre of a back-view button given the back panel rect.
// Geometry matches the programmatic shapes drawn in drawXboxBack().
PVector getBackScreenPos(String btn, float cx, float cy, float dispW, float dispH) {
  float s = min(dispW, dispH) / 400.0;
  if (btn.equals("LT") || (btn.contains("LT") && !btn.contains("RT")))
    return new PVector(cx - 82*s, cy - 52*s);
  if (btn.equals("RT") || btn.contains("RT"))
    return new PVector(cx + 82*s, cy - 52*s);
  if (btn.equals("LB") || (btn.contains("LB") && !btn.contains("RB")))
    return new PVector(cx - 82*s, cy - 10*s);
  if (btn.contains("RB"))
    return new PVector(cx + 82*s, cy - 10*s);
  return null;
}

boolean isBackViewButton(String btn) {
  return btn.equals("LT") || btn.equals("RT")
      || btn.equals("LB") || btn.contains("RB");
}

// Xbox face button highlight colours.
color btnHighlightColor(String btn) {
  if (btn.equals("A"))                          return color(80,  200,  80);
  if (btn.equals("B"))                          return color(210,  70,  70);
  if (btn.equals("X"))                          return color(70,  130, 210);
  if (btn.equals("Y"))                          return color(210, 190,  50);
  if (btn.equals("LT") || btn.equals("RT"))     return color(80,  180, 220);
  if (btn.equals("LB") || btn.equals("RB"))     return color(160, 165, 185);
  return color(170, 175, 195);
}

// ─── Main entry point ─────────────────────────────────────────────────────────

void drawControllerGuide(ControllerLayout[] layouts) {
  if (layouts == null || layouts.length == 0) return;
  if (FRONT_BTN_KEYS == null) initButtonPositions();

  blendMode(BLEND);
  hint(DISABLE_DEPTH_TEST);
  pushStyle();

  // Show back view when the layout includes any shoulder / trigger button
  boolean dualLayout = false;
  for (ControllerLayout l : layouts) {
    if (isBackViewButton(l.button)) { dualLayout = true; break; }
  }

  float frontH = height * 0.50;
  float frontW = frontH;
  float backH  = height * 0.40;
  float backW  = backH;

  float frontCX, frontCY, backCX, backCY;

  if (dualLayout) {
    float gap    = 160 * uiScale();
    float totalW = frontW + gap + backW;
    float startX = width * 0.5 - totalW * 0.5;
    frontCX = startX + frontW * 0.5;
    frontCY = height * 0.5;
    backCX  = startX + frontW + gap + backW * 0.5;
    backCY  = height * 0.5;
  } else {
    frontCX = width * 0.5;
    frontCY = height * 0.5;
    backCX  = 0; backCY = 0;
  }

  // Full-screen dim — makes the overlay legible regardless of scene
  noStroke();
  fill(0, 0, 0, 150);
  rect(0, 0, width, height);

  // Dark backdrop behind controller(s) + label zone
  float labelZone = 200 * uiScale();
  float padY      = 60 * uiScale();
  float panelX    = (dualLayout ? frontCX : frontCX) - frontW * 0.5 - labelZone;
  float panelR    = dualLayout ? (backCX + backW * 0.5 + labelZone) : (frontCX + frontW * 0.5 + labelZone);
  float panelY    = (dualLayout ? min(frontCY - frontH * 0.5, backCY - backH * 0.5) : frontCY - frontH * 0.5) - padY;
  float panelH    = (dualLayout ? max(frontH, backH) : frontH) + padY * 2;
  fill(15, 15, 20, 220);
  rect(panelX, panelY, panelR - panelX, panelH, 16);

  drawXboxFront(frontCX, frontCY, frontW, frontH, layouts);
  if (dualLayout) {
    drawXboxBack(backCX, backCY, backW, backH, layouts);
    fill(120, 120, 130, 160);
    textFont(monoFont);
    textAlign(CENTER, BOTTOM);
    textSize(9 * uiScale());
    text("BACK VIEW", backCX, backCY - backH * 0.5 - 4 * uiScale());
  }

  drawFrontPointers(frontCX, frontCY, frontW, frontH, layouts, dualLayout);
  if (dualLayout) {
    drawBackPointers(backCX, backCY, backW, backH, layouts);
  }

  // Close hint
  fill(120, 120, 120, 160);
  textFont(monoFont);
  textAlign(CENTER, BOTTOM);
  textSize(10 * uiScale());
  text("(Press 'i' to close)", width * 0.5, height - 15 * uiScale());

  popStyle();
  hint(ENABLE_DEPTH_TEST);
}

// ─── Front controller rendering ───────────────────────────────────────────────

void drawXboxFront(float cx, float cy, float dispW, float dispH,
                   ControllerLayout[] layouts) {
  float svgX = cx - dispW * 0.5;
  float svgY = cy - dispH * 0.5;
  float s    = dispW / FRONT_SVG_W;   // SVG→screen scale

  if (xboxFrontSVG != null) {
    fill(172, 176, 186, 228);
    stroke(95, 100, 115, 160);
    strokeWeight(0.5);
    shape(xboxFrontSVG, svgX, svgY, dispW, dispH);
  }

  // Highlight each used button
  for (ControllerLayout layout : layouts) {
    if (isBackViewButton(layout.button)) continue;
    PVector svgPos = getFrontPos(layout.button);
    if (svgPos == null) continue;

    PVector sc  = svgToScreen(svgPos.x, svgPos.y, cx, cy, FRONT_SVG_W, FRONT_SVG_H, dispW, dispH);
    color   col = btnHighlightColor(layout.button);
    float   r   = 19 * s;  // base highlight radius (face button r=18.77 in SVG)

    noStroke();
    fill(red(col), green(col), blue(col), 80);
    circle(sc.x, sc.y, r * 3.2);
    fill(red(col), green(col), blue(col), 210);
    circle(sc.x, sc.y, r * 1.6);

    // Letter inside face buttons
    String btn = layout.button;
    if (btn.length() == 1 && "ABXY".indexOf(btn) >= 0) {
      fill(255, 255, 255, 230);
      textFont(monoFont);
      textAlign(CENTER, CENTER);
      textSize(r * 0.9);
      text(btn, sc.x, sc.y);
    }
  }
}

// ─── Back controller rendering ────────────────────────────────────────────────

void drawXboxBack(float cx, float cy, float dispW, float dispH,
                  ControllerLayout[] layouts) {
  float s = min(dispW, dispH) / 400.0;

  // ── Geometry (all in screen space) ─────────────────────────────────────────
  // Stack from top to bottom: trigger → bumper → body
  // Triggers
  float trigW  = 76 * s;
  float trigH  = 68 * s;
  float ltCX   = cx - 82 * s;
  float rtCX   = cx + 82 * s;
  float trigCY = cy - 52 * s;

  // Bumpers (sit flush below triggers)
  float bumpW  = 62 * s;
  float bumpH  = 20 * s;
  float bumpCY = cy - 10 * s;  // trigger bottom ≈ bumpCY - bumpH*0.5

  // Body
  float bodyW  = 230 * s;
  float bodyH  = 82 * s;
  float bodyCY = cy + 40 * s;  // body top = bumpCY + bumpH*0.5 (flush)

  // ── Draw controller shapes ──────────────────────────────────────────────────
  stroke(95, 100, 115, 170);
  strokeWeight(1.5);

  // Body (darkest layer — at the back)
  fill(148, 152, 162, 200);
  rect(cx - bodyW*0.5, bodyCY - bodyH*0.5, bodyW, bodyH, bodyH * 0.25);

  // Bumpers
  fill(165, 168, 178, 210);
  rect(ltCX - bumpW*0.5, bumpCY - bumpH*0.5, bumpW, bumpH, bumpH * 0.5);
  rect(rtCX - bumpW*0.5, bumpCY - bumpH*0.5, bumpW, bumpH, bumpH * 0.5);

  // Triggers (lightest — closest to viewer)
  fill(180, 184, 194, 220);
  rect(ltCX - trigW*0.5, trigCY - trigH*0.5, trigW, trigH, trigW * 0.35);
  rect(rtCX - trigW*0.5, trigCY - trigH*0.5, trigW, trigH, trigW * 0.35);

  // Button labels
  noStroke();
  fill(60, 65, 80, 200);
  textFont(monoFont);
  textSize(12 * uiScale());
  textAlign(CENTER, CENTER);
  text("LT", ltCX, trigCY);
  text("RT", rtCX, trigCY);
  text("LB", ltCX, bumpCY);
  text("RB", rtCX, bumpCY);

  // ── Active button highlights ────────────────────────────────────────────────
  for (ControllerLayout layout : layouts) {
    if (!isBackViewButton(layout.button)) continue;
    PVector sc = getBackScreenPos(layout.button, cx, cy, dispW, dispH);
    if (sc == null) continue;
    color col = btnHighlightColor(layout.button);
    boolean isTrigger = layout.button.contains("LT") || layout.button.contains("RT");
    float   r = (isTrigger ? 28 : 20) * s;
    noStroke();
    fill(red(col), green(col), blue(col), 50);
    circle(sc.x, sc.y, r * 2.8);
    fill(red(col), green(col), blue(col), 140);
    circle(sc.x, sc.y, r * 1.5);
  }
}

// ─── Pointer labels — front view ──────────────────────────────────────────────

void drawFrontPointers(float cx, float cy, float dispW, float dispH,
                       ControllerLayout[] layouts, boolean dualMode) {
  if (FRONT_BTN_KEYS == null) initButtonPositions();

  float marginX = 90 * uiScale();
  float marginY = 55 * uiScale();

  ArrayList<PointerLabel> bottomL = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> leftL   = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> rightL  = new ArrayList<PointerLabel>();

  // Edge exit positions — where lines leave the controller body horizontally
  float edgeL = cx - dispW * 0.47;
  float edgeR = cx + dispW * 0.47;
  float edgeB = cy + dispH * 0.43;

  for (ControllerLayout layout : layouts) {
    String btn = layout.button;
    if (isBackViewButton(btn)) continue;

    PVector svgPos = getFrontPos(btn);
    PVector from   = (svgPos != null)
      ? svgToScreen(svgPos.x, svgPos.y, cx, cy, FRONT_SVG_W, FRONT_SVG_H, dispW, dispH)
      : new PVector(cx, cy);

    // Route each button to the side it physically lives on.
    // All exits are horizontal so no line crosses the controller face.
    // Right side: B, Y, RB, RStick (right half of controller)
    // Bottom: A, Back, Start
    // Left side: everything else (X, LB, LStick, D-pad)
    if (btn.equals("A") || btn.equals("B") || btn.equals("X") || btn.equals("Y")
        || btn.contains("RB") || btn.contains("RStick")) {
      // All ABXY + right shoulder/stick → right side (ABXY cluster is right half of controller)
      rightL.add(new PointerLabel(btn, layout.description,
        cx + dispW * 0.5 + marginX, cy, from.x, from.y, edgeR, from.y));

    } else if (btn.equals("Back") || btn.equals("Start")) {
      bottomL.add(new PointerLabel(btn, layout.description,
        cx, cy + dispH * 0.5 + marginY, from.x, from.y, from.x, edgeB));

    } else {
      // LB, LStick, D-pad, anything else → left
      leftL.add(new PointerLabel(btn, layout.description,
        cx - dispW * 0.5 - marginX, cy, from.x, from.y, edgeL, from.y));
    }
  }

  // Sort each rail by button position before distributing so labels are assigned
  // in the same spatial order as their origins — prevents line crossings.
  sortByFromY(leftL);
  sortByFromY(rightL);
  sortByFromX(bottomL);

  distributeLabels(bottomL, cx,                         cy + dispH * 0.5 + marginY, marginX, true);
  distributeLabels(leftL,   cx - dispW * 0.5 - marginX, cy,                         marginY, false);
  distributeLabels(rightL,  cx + dispW * 0.5 + marginX, cy,                         marginY, false);

  for (PointerLabel pl : bottomL) drawPointerLabel(pl);
  for (PointerLabel pl : leftL)   drawPointerLabel(pl);
  for (PointerLabel pl : rightL)  drawPointerLabel(pl);
}

// ─── Pointer labels — back view ───────────────────────────────────────────────

void drawBackPointers(float cx, float cy, float dispW, float dispH,
                      ControllerLayout[] layouts) {
  float marginX = 80 * uiScale();
  float edgeL   = cx - dispW * 0.47;
  float edgeR   = cx + dispW * 0.47;

  ArrayList<PointerLabel> leftL  = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> rightL = new ArrayList<PointerLabel>();

  for (ControllerLayout layout : layouts) {
    String btn = layout.button;
    if (!isBackViewButton(btn)) continue;

    PVector from = getBackScreenPos(btn, cx, cy, dispW, dispH);
    if (from == null) from = new PVector(cx, cy);

    // LT / LB → left side; RT / RB → right side
    boolean goLeft = btn.equals("LT") || btn.equals("LB")
                  || (btn.contains("LT") && !btn.contains("RT"))
                  || (btn.contains("LB") && !btn.contains("RB"));
    if (goLeft) {
      leftL.add(new PointerLabel(btn, layout.description,
        cx - dispW * 0.5 - marginX, cy, from.x, from.y, edgeL, from.y));
    } else {
      rightL.add(new PointerLabel(btn, layout.description,
        cx + dispW * 0.5 + marginX, cy, from.x, from.y, edgeR, from.y));
    }
  }

  sortByFromY(leftL);
  sortByFromY(rightL);

  float marginY = 50 * uiScale();
  distributeLabels(leftL,  cx - dispW * 0.5 - marginX, cy, marginY, false);
  distributeLabels(rightL, cx + dispW * 0.5 + marginX, cy, marginY, false);

  for (PointerLabel pl : leftL)  drawPointerLabel(pl);
  for (PointerLabel pl : rightL) drawPointerLabel(pl);
}

// ─── Label distribution ───────────────────────────────────────────────────────
// spreadHorizontally=true  → top/bottom rails: labels spread left/right (x changes)
// spreadHorizontally=false → left/right rails: labels spread up/down   (y changes)

void distributeLabels(ArrayList<PointerLabel> labels, float railX, float railY,
                      float spacing, boolean spreadHorizontally) {
  if (labels.isEmpty()) return;
  int   n     = labels.size();
  float start = -(n - 1) * spacing * 0.5;

  for (int i = 0; i < n; i++) {
    if (spreadHorizontally) {
      labels.get(i).x = railX + start + i * spacing;
    } else {
      labels.get(i).y = railY + start + i * spacing;
    }
  }
}

// ─── Single pointer + label ───────────────────────────────────────────────────

void drawPointerLabel(PointerLabel pl) {
  pushStyle();

  // Annotation connector:
  //   For left/right exits: diagonal button → (exitX, label.y), then horizontal → label
  //   For bottom exits:     diagonal button → (label.x, exitY), then vertical   → label
  // This keeps the straight segment aligned with the label and avoids crossing the body.
  noFill();
  stroke(150, 200, 255, 110);
  strokeWeight(1.5);

  float segX, segY;
  if (abs(pl.exitX - pl.fromX) >= abs(pl.exitY - pl.fromY)) {
    segX = pl.exitX;  segY = pl.y;   // horizontal exit
  } else {
    segX = pl.x;      segY = pl.exitY; // vertical exit
  }
  line(pl.fromX, pl.fromY, segX, segY);  // diagonal: button to waypoint
  line(segX, segY, pl.x, pl.y);          // straight: waypoint to label

  // Dot at button end
  noStroke();
  fill(150, 200, 255, 170);
  circle(pl.fromX, pl.fromY, 4);

  // Label pill
  textFont(monoFont);
  textSize(11 * uiScale());
  textAlign(CENTER, CENTER);

  float tw  = textWidth(pl.description) + 10 * uiScale();
  float th  = 18 * uiScale();

  fill(0, 0, 0, 195);
  stroke(150, 200, 255, 170);
  strokeWeight(1);
  rect(pl.x - tw * 0.5, pl.y - th * 0.5, tw, th, 3);

  fill(150, 220, 255, 240);
  text(pl.description, pl.x, pl.y);

  popStyle();
}

// ─── Sort helpers (bubble sort — lists are tiny, simplicity wins) ─────────────

void sortByFromY(ArrayList<PointerLabel> labels) {
  for (int i = 0; i < labels.size() - 1; i++)
    for (int j = 0; j < labels.size() - 1 - i; j++)
      if (labels.get(j).fromY > labels.get(j+1).fromY) {
        PointerLabel t = labels.get(j);
        labels.set(j, labels.get(j+1));
        labels.set(j+1, t);
      }
}

void sortByFromX(ArrayList<PointerLabel> labels) {
  for (int i = 0; i < labels.size() - 1; i++)
    for (int j = 0; j < labels.size() - 1 - i; j++)
      if (labels.get(j).fromX > labels.get(j+1).fromX) {
        PointerLabel t = labels.get(j);
        labels.set(j, labels.get(j+1));
        labels.set(j+1, t);
      }
}

// ─── PointerLabel data class ──────────────────────────────────────────────────

class PointerLabel {
  String button, description;
  float  x, y;               // label centre (screen)
  float  fromX, fromY;       // button origin (screen)
  float  exitX, exitY;       // where the line exits the controller edge

  PointerLabel(String button, String description,
               float labelX, float labelY,
               float btnX,   float btnY,
               float exitX,  float exitY) {
    this.button      = button;
    this.description = description;
    this.x           = labelX;
    this.y           = labelY;
    this.fromX       = btnX;
    this.fromY       = btnY;
    this.exitX       = exitX;
    this.exitY       = exitY;
  }
}
