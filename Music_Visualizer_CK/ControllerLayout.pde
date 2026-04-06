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
// Main rendering function: draws large center controller with pointer annotations
// ─────────────────────────────────────────────────────────────────────────────

void drawControllerGuide(ControllerLayout[] layouts) {
  if (layouts == null || layouts.length == 0) return;

  blendMode(BLEND);
  pushStyle();

  float scale = 2.5 * uiScale();
  float cx = width * 0.5;
  float cy = height * 0.5;
  
  // Draw the large centered controller
  drawXboxControllerLarge(cx, cy, scale, layouts);
  
  // Draw pointer lines and labels around the controller
  drawControllerPointers(cx, cy, scale, layouts);

  // Draw hint at bottom
  fill(120, 120, 120, 160);
  textFont(monoFont);
  textAlign(CENTER, BOTTOM);
  textSize(10 * uiScale());
  text("(Press 'i' to close)", width * 0.5, height - 15 * uiScale());

  popStyle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw large Xbox controller in center of screen
// ─────────────────────────────────────────────────────────────────────────────

void drawXboxControllerLarge(float cx, float cy, float scale, ControllerLayout[] layouts) {
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

  // ─ BACK BUTTONS (shown as small indicators on top edge) ─────────────
  // Left Trigger (LT)
  fill(120, 120, 130, 200);
  stroke(160, 160, 170, 180);
  strokeWeight(1 * scale);
  rect(cx - cw*0.25, cy - ch/2 - 5*scale, 20*scale, 5*scale, 2*scale);
  fill(200, 200, 200, 160);
  textFont(monoFont);
  textAlign(CENTER, CENTER);
  textSize(6 * uiScale());
  text("LT", cx - cw*0.25, cy - ch/2 - 2.5*scale);

  // Right Trigger (RT)
  fill(120, 120, 130, 200);
  stroke(160, 160, 170, 180);
  strokeWeight(1 * scale);
  rect(cx + cw*0.25 - 20*scale, cy - ch/2 - 5*scale, 20*scale, 5*scale, 2*scale);
  fill(200, 200, 200, 160);
  textAlign(CENTER, CENTER);
  textSize(6 * uiScale());
  text("RT", cx + cw*0.25 - 10*scale, cy - ch/2 - 2.5*scale);

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
  
  // Label back buttons
  fill(140, 140, 150, 180);
  textFont(monoFont);
  textAlign(CENTER, CENTER);
  textSize(6 * uiScale());
  text("Back", cx - 17.5*scale, cy + ch*0.39);
  text("Start", cx + 17.5*scale, cy + ch*0.39);
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
// Draw pointer lines and labels arranged around the controller
// ─────────────────────────────────────────────────────────────────────────────

void drawControllerPointers(float cx, float cy, float scale, ControllerLayout[] layouts) {
  if (layouts == null || layouts.length == 0) return;

  float cw = 180 * scale;
  float ch = 110 * scale;
  float size = 18 * scale;  // Face button size
  
  // Map button names to their actual screen positions on the controller
  HashMap<String, PVector> buttonPositions = new HashMap<String, PVector>();
  
  // Face buttons (ABXY) positions
  float rightX = cx + cw * 0.28;
  float faceY = cy - ch * 0.25;
  buttonPositions.put("Y", new PVector(rightX, faceY - size*1.1));
  buttonPositions.put("X", new PVector(rightX - size*1.1, faceY));
  buttonPositions.put("A", new PVector(rightX, faceY + size*1.1));
  buttonPositions.put("B", new PVector(rightX + size*1.1, faceY));
  
  // D-Pad position
  float leftX = cx - cw * 0.28;
  float dpadY = cy - ch * 0.25;
  buttonPositions.put("D-pad", new PVector(leftX, dpadY));
  
  // Stick positions
  float lstickY = cy + ch * 0.15;
  float rstickY = cy + ch * 0.15;
  buttonPositions.put("LStick", new PVector(leftX, lstickY));
  buttonPositions.put("RStick", new PVector(rightX, rstickY));
  
  // Bumper positions
  buttonPositions.put("LB", new PVector(cx - cw*0.3, cy - ch*0.48));
  buttonPositions.put("RB", new PVector(cx + cw*0.3, cy - ch*0.48));
  
  // Back button positions (triggers and shoulder buttons)
  buttonPositions.put("LT", new PVector(cx - cw*0.25, cy - ch/2 - 2.5*uiScale()));
  buttonPositions.put("RT", new PVector(cx + cw*0.25 - 10*uiScale(), cy - ch/2 - 2.5*uiScale()));
  buttonPositions.put("Back", new PVector(cx - 17.5*scale, cy + ch*0.39));
  buttonPositions.put("Start", new PVector(cx + 17.5*scale, cy + ch*0.39));
  
  // Positions for labels (around the controller)
  ArrayList<PointerLabel> topLabels = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> bottomLabels = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> leftLabels = new ArrayList<PointerLabel>();
  ArrayList<PointerLabel> rightLabels = new ArrayList<PointerLabel>();

  float marginX = 80 * uiScale();
  float marginY = 60 * uiScale();

  // Categorize each button to its appropriate label position
  for (ControllerLayout layout : layouts) {
    String btn = layout.button;
    String desc = layout.description;
    
    // Get actual button position on controller
    PVector btnPos = buttonPositions.get(btn);
    if (btnPos == null && btn.contains("LStick")) {
      btnPos = buttonPositions.get("LStick");
    } else if (btnPos == null && btn.contains("RStick")) {
      btnPos = buttonPositions.get("RStick");
    } else if (btnPos == null && btn.contains("D-pad")) {
      btnPos = buttonPositions.get("D-pad");
    } else if (btnPos == null) {
      btnPos = new PVector(cx, cy);  // Default to controller center
    }

    // Determine which side this label should be positioned on
    if (btn.equals("Y") || btn.equals("LB") || btn.equals("RB") || btn.equals("LT") || btn.equals("RT")) {
      topLabels.add(new PointerLabel(btn, desc, cx, cy - ch/2 - marginY, btnPos.x, btnPos.y));
    } else if (btn.equals("A") || btn.equals("Back") || btn.equals("Start")) {
      bottomLabels.add(new PointerLabel(btn, desc, cx, cy + ch/2 + marginY, btnPos.x, btnPos.y));
    } else if (btn.equals("B")) {
      rightLabels.add(new PointerLabel(btn, desc, cx + cw/2 + marginX, cy, btnPos.x, btnPos.y));
    } else if (btn.equals("X") || btn.contains("LStick") || btn.contains("D-pad")) {
      leftLabels.add(new PointerLabel(btn, desc, cx - cw/2 - marginX, cy, btnPos.x, btnPos.y));
    } else if (btn.contains("RStick")) {
      rightLabels.add(new PointerLabel(btn, desc, cx + cw/2 + marginX, cy, btnPos.x, btnPos.y));
    } else {
      // Default: spread across available spaces
      if (topLabels.size() < bottomLabels.size()) {
        topLabels.add(new PointerLabel(btn, desc, cx + 100*uiScale(), cy - ch/2 - marginY, btnPos.x, btnPos.y));
      } else {
        bottomLabels.add(new PointerLabel(btn, desc, cx + 100*uiScale(), cy + ch/2 + marginY, btnPos.x, btnPos.y));
      }
    }
  }

  // Spread labels horizontally to avoid overlap
  distributeLabels(topLabels, cx, cy - ch/2 - marginY, -1, marginX);
  distributeLabels(bottomLabels, cx, cy + ch/2 + marginY, 1, marginX);
  distributeLabels(leftLabels, cx - cw/2 - marginX, cy, -1, marginY);
  distributeLabels(rightLabels, cx + cw/2 + marginX, cy, 1, marginY);

  // Draw all pointers and labels
  for (PointerLabel pl : topLabels) drawPointerLabel(pl);
  for (PointerLabel pl : bottomLabels) drawPointerLabel(pl);
  for (PointerLabel pl : leftLabels) drawPointerLabel(pl);
  for (PointerLabel pl : rightLabels) drawPointerLabel(pl);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: distribute labels to prevent overlap
// ─────────────────────────────────────────────────────────────────────────────

void distributeLabels(ArrayList<PointerLabel> labels, float centerX, float centerY, int direction, float spacing) {
  if (labels.isEmpty()) return;
  
  int n = labels.size();
  float startOffset = -(n - 1) * spacing / 2.0;
  
  // Use first label to determine distribution axis (avoid float comparison precision issues)
  float xDiff = abs(centerX - labels.get(0).x);
  boolean isHorizontal = xDiff > 5;  // X varies more than Y
  
  for (int i = 0; i < n; i++) {
    if (isHorizontal) {
      // Horizontal distribution (left/right)
      labels.get(i).x = centerX + startOffset + i * spacing;
    } else {
      // Vertical distribution (top/bottom)
      labels.get(i).y = centerY + startOffset + i * spacing;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draw a single pointer line + label with curved path
// ─────────────────────────────────────────────────────────────────────────────

void drawPointerLabel(PointerLabel pl) {
  pushStyle();
  
  // Curved pointer line using Bezier (routes around button clusters)
  noFill();
  stroke(150, 200, 255, 120);
  strokeWeight(1.5);
  
  // Calculate control point for smooth curve
  float midX = (pl.fromX + pl.x) / 2.0;
  float midY = (pl.fromY + pl.y) / 2.0;
  
  // Offset control points to create smooth arc away from center
  float offsetDist = dist(pl.fromX, pl.fromY, pl.x, pl.y) * 0.15;
  float angle = atan2(pl.y - pl.fromY, pl.x - pl.fromX) + HALF_PI;
  float cp1x = midX + cos(angle) * offsetDist;
  float cp1y = midY + sin(angle) * offsetDist;
  
  // Draw smooth curve from button to label
  bezier(pl.fromX, pl.fromY, cp1x, cp1y, cp1x, cp1y, pl.x, pl.y);
  
  // Small circle at button endpoint
  noStroke();
  fill(150, 200, 255, 180);
  circle(pl.fromX, pl.fromY, 4);

  // Label box background
  textFont(monoFont);
  textSize(11 * uiScale());
  textAlign(CENTER, CENTER);
  
  float textW = textWidth(pl.description) + 10 * uiScale();
  float textH = 18 * uiScale();
  
  fill(0, 0, 0, 200);
  stroke(150, 200, 255, 180);
  strokeWeight(1);
  rect(pl.x - textW/2, pl.y - textH/2, textW, textH, 3);

  // Label text
  fill(150, 220, 255, 240);
  text(pl.description, pl.x, pl.y);

  popStyle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper class for pointer labels
// ─────────────────────────────────────────────────────────────────────────────

class PointerLabel {
  String button;
  String description;
  float x, y;           // Label position
  float fromX, fromY;   // Button position (start of pointer line)

  PointerLabel(String button, String description, float labelX, float labelY, float btnX, float btnY) {
    this.button = button;
    this.description = description;
    this.x = labelX;
    this.y = labelY;
    this.fromX = btnX;
    this.fromY = btnY;
  }
}
