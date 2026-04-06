/**
 * ControllerLayout — structured controller guide system
 *
 * Each scene can define a list of {button, action} mappings that describe
 * what the controller does in that scene. This enables dynamic overlay rendering
 * of visual controller diagrams without static per-scene images.
 *
 * Usage in a scene:
 *   ControllerLayout[] getControllerLayout() {
 *     return new ControllerLayout[] {
 *       new ControllerLayout("LStick ↕", "Rotation speed"),
 *       new ControllerLayout("RStick ↔", "Scale (4–14)"),
 *       new ControllerLayout("A", "Beat pulse"),
 *     };
 *   }
 */

class ControllerLayout {
  String button;      // Xbox button label (e.g. "A", "RStick ↔", "LB")
  String description; // What it does in this scene

  ControllerLayout(String button, String description) {
    this.button = button;
    this.description = description;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main rendering function: draws controller diagram + annotation panel
// ─────────────────────────────────────────────────────────────────────────────

void drawControllerGuide(ControllerLayout[] layouts) {
  if (layouts == null || layouts.length == 0) return;

  blendMode(BLEND);
  pushStyle();

  // Draw the visual controller diagram on the left side
  drawXboxController(layouts);

  // Draw annotation list on the right side
  drawControllerAnnotations(layouts);

  // Draw hint at bottom
  fill(120, 120, 120, 160);
  textFont(monoFont);
  textAlign(LEFT, BOTTOM);
  textSize(10 * uiScale());
  text("(Press 'i' to close)", 20 * uiScale(), height - 15 * uiScale());

  popStyle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw Xbox controller diagram with proper proportions and 3D-ish appearance
// ─────────────────────────────────────────────────────────────────────────────

void drawXboxController(ControllerLayout[] layouts) {
  float scale = 2.0 * uiScale();
  float cx = width * 0.15;               // Controller center X
  float cy = height * 0.5;               // Controller center Y
  float cw = 180 * scale;                // Width
  float ch = 110 * scale;                // Height

  // Outer body shadow
  fill(20, 20, 30, 100);
  noStroke();
  rect(cx - cw/2 + 3*scale, cy - ch/2 + 3*scale, cw, ch, 25*scale);

  // Main controller body
  fill(80, 85, 95, 240);
  stroke(140, 145, 160, 200);
  strokeWeight(1.5 * scale);
  rect(cx - cw/2, cy - ch/2, cw, ch, 25*scale);

  // Grips (subtle side detail)
  fill(60, 65, 75, 200);
  noStroke();
  rect(cx - cw/2 - 2*scale, cy - ch/2 + ch*0.3, 3*scale, ch*0.4);
  rect(cx + cw/2 - 1*scale, cy - ch/2 + ch*0.3, 3*scale, ch*0.4);

  // ─ LEFT SIDE ─────────────────────────────────────
  float leftX = cx - cw * 0.28;

  // D-Pad
  float dpadY = cy - ch * 0.25;
  drawDPad(leftX, dpadY, 20*scale, layouts);

  // Left Stick
  float lstickY = cy + ch * 0.15;
  drawStick(leftX, lstickY, 22*scale, "LStick", layouts);

  // ─ RIGHT SIDE ────────────────────────────────────
  float rightX = cx + cw * 0.28;

  // Face buttons (ABXY)
  float faceY = cy - ch * 0.25;
  drawFaceButtons(rightX, faceY, 18*scale, layouts);

  // Right Stick
  float rstickY = cy + ch * 0.15;
  drawStick(rightX, rstickY, 22*scale, "RStick", layouts);

  // ─ CENTER & TOP ──────────────────────────────────
  // Center circle (Xbox button area - simplified)
  fill(100, 100, 110, 200);
  noStroke();
  circle(cx, cy - ch*0.3, 10*scale);

  // Bumpers (LB, RB)
  drawBumper(cx - cw*0.3, cy - ch*0.48, 35*scale, "LB", layouts);
  drawBumper(cx + cw*0.3, cy - ch*0.48, 35*scale, "RB", layouts);

  // Menu/Back buttons (small rectangles)
  fill(100, 100, 110, 180);
  stroke(140, 145, 160, 150);
  strokeWeight(1*scale);
  rect(cx - 25*scale, cy + ch*0.35, 15*scale, 8*scale, 2*scale);  // Back
  rect(cx + 10*scale, cy + ch*0.35, 15*scale, 8*scale, 2*scale);  // Start
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw D-Pad (cross shape with highlight for used buttons)
// ─────────────────────────────────────────────────────────────────────────────

void drawDPad(float x, float y, float size, ControllerLayout[] layouts) {
  float w = size * 0.5;
  float h = size * 0.8;

  boolean dpadUsed = false;
  for (ControllerLayout l : layouts) {
    if (l.button.contains("D-pad") || l.button.contains("↕") || l.button.contains("↔")) {
      dpadUsed = true;
      break;
    }
  }

  fill(dpadUsed ? 200 : 120, dpadUsed ? 140 : 100, dpadUsed ? 100 : 100, 200);
  stroke(dpadUsed ? 240 : 160, dpadUsed ? 180 : 140, dpadUsed ? 140 : 140, 180);
  strokeWeight(1.5);

  // Vertical bar
  rect(x - w/4, y - h/2, w/2, h, 2);
  // Horizontal bar
  rect(x - w/2, y - h/4, w, h/2, 2);
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw analog stick (circle with + indicator)
// ─────────────────────────────────────────────────────────────────────────────

void drawStick(float x, float y, float size, String label, ControllerLayout[] layouts) {
  boolean stickUsed = false;
  for (ControllerLayout l : layouts) {
    if (l.button.contains(label)) {
      stickUsed = true;
      break;
    }
  }

  // Outer ring
  fill(stickUsed ? 120 : 100, stickUsed ? 120 : 100, stickUsed ? 130 : 120, 200);
  stroke(stickUsed ? 200 : 160, stickUsed ? 200 : 160, stickUsed ? 220 : 200, 180);
  strokeWeight(1.5);
  circle(x, y, size * 1.2);

  // Inner stick
  fill(stickUsed ? 150 : 120, stickUsed ? 150 : 120, stickUsed ? 160 : 140, 220);
  noStroke();
  circle(x, y, size * 0.8);

  // Center dot
  fill(80, 80, 90, 200);
  circle(x, y, size * 0.3);
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw face buttons (A, B, X, Y)
// ─────────────────────────────────────────────────────────────────────────────

void drawFaceButtons(float cx, float cy, float size, ControllerLayout[] layouts) {
  String[] btnLabels = {"Y", "X", "A", "B"};
  float[] btnX = {cx, cx - size*1.1, cx, cx + size*1.1};
  float[] btnY = {cy - size*1.1, cy, cy + size*1.1, cy};
  color[] btnColors = {color(200, 200, 100), color(100, 150, 200), color(100, 200, 100), color(200, 100, 100)};

  for (int i = 0; i < 4; i++) {
    boolean btnUsed = false;
    for (ControllerLayout l : layouts) {
      if (l.button.equals(btnLabels[i])) {
        btnUsed = true;
        break;
      }
    }

    color baseColor = btnColors[i];
    if (btnUsed) {
      fill(red(baseColor), green(baseColor), blue(baseColor), 240);
      stroke(255, 255, 255, 200);
    } else {
      fill(red(baseColor) * 0.5, green(baseColor) * 0.5, blue(baseColor) * 0.5, 180);
      stroke(180, 180, 190, 150);
    }
    strokeWeight(1.5);
    circle(btnX[i], btnY[i], size * 0.9);

    // Button label
    fill(255, 255, 255, 240);
    textFont(monoFont);
    textAlign(CENTER, CENTER);
    textSize(12 * uiScale());
    text(btnLabels[i], btnX[i], btnY[i]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw bumper button (shoulder)
// ─────────────────────────────────────────────────────────────────────────────

void drawBumper(float x, float y, float w, String label, ControllerLayout[] layouts) {
  boolean btnUsed = false;
  for (ControllerLayout l : layouts) {
    if (l.button.contains(label)) {
      btnUsed = true;
      break;
    }
  }

  fill(btnUsed ? 180 : 130, btnUsed ? 180 : 130, btnUsed ? 190 : 145, 200);
  stroke(btnUsed ? 230 : 170, btnUsed ? 230 : 170, btnUsed ? 245 : 190, 180);
  strokeWeight(1.5);
  rect(x - w/2, y, w, 12 * uiScale(), 3 * uiScale());

  // Label
  fill(255, 255, 255, 180);
  textFont(monoFont);
  textAlign(CENTER, CENTER);
  textSize(9 * uiScale());
  text(label, x, y + 6 * uiScale());
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw annotation list showing what each button does
// ─────────────────────────────────────────────────────────────────────────────

void drawControllerAnnotations(ControllerLayout[] layouts) {
  pushStyle();
  textFont(monoFont);

  float boxX = width * 0.35;
  float boxY = height * 0.12;
  float boxW = width * 0.58;
  float boxH = height * 0.75;

  // Background panel
  fill(0, 0, 0, 180);
  stroke(100, 200, 255, 150);
  strokeWeight(1.5);
  rect(boxX, boxY, boxW, boxH, 6);

  // Title
  fill(100, 220, 255, 220);
  textAlign(LEFT, TOP);
  textSize(14 * uiScale());
  text("CONTROLS", boxX + 15 * uiScale(), boxY + 12 * uiScale());

  // Divider line
  stroke(100, 150, 200, 100);
  strokeWeight(1);
  line(boxX + 10*uiScale(), boxY + 28*uiScale(), boxX + boxW - 10*uiScale(), boxY + 28*uiScale());

  // List items
  float itemY = boxY + 40 * uiScale();
  float lineSpacing = 22 * uiScale();
  float maxItems = (boxH - 50*uiScale()) / lineSpacing;

  for (int i = 0; i < min(layouts.length, (int)maxItems); i++) {
    String btn = layouts[i].button;
    String desc = layouts[i].description;

    // Button name (cyan)
    fill(150, 220, 255, 220);
    textSize(12 * uiScale());
    textAlign(LEFT, TOP);
    text(btn, boxX + 20*uiScale(), itemY + i*lineSpacing);

    // Description (light green)
    fill(180, 255, 200, 200);
    textSize(11 * uiScale());
    text("→ " + desc, boxX + 80*uiScale(), itemY + i*lineSpacing);
  }

  popStyle();
}
