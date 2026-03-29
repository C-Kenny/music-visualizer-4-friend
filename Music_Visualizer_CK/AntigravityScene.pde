class AntigravityScene {
  float gravity = -1.5;
  float wind = 0.0;
  float baseSpawningSpeed = 1.0;
  int paletteIndex = 0;
  float hueOffset = 0;
  float pulseRippleRadius = 0;
  float pulseRippleIntensity = 0;
  
  ArrayList<AntigravParticle> particles;

  String[] paletteNames = {"Neon Vapor", "Cyber Punk", "Ethereal", "Crimson"};
  float[] paletteBaseHue = {200, 280, 160, 350};

  AntigravityScene() {
    particles = new ArrayList<AntigravParticle>();
  }

  void applyController(Controller c) {
    float lx = map(c.lx, 0, width, -1, 1);
    wind = lx * 5.0; 

    float ry = map(c.ry, 0, height, -1, 1);
    gravity = ry * 2.5 - 1.5;

    if (c.a_just_pressed) triggerPulse();
    if (c.y_just_pressed) cyclePalette();
  }

  void triggerPulse() {
    pulseRippleRadius = 1;
    pulseRippleIntensity = 1.0;
  }

  void cyclePalette() {
    paletteIndex = (paletteIndex + 1) % paletteNames.length;
  }

  void adjustGravity(float delta) {
    gravity += delta;
  }
  
  void adjustWind(float delta) {
    wind += delta;
  }

  void drawScene() {
    // Solid background prevents bleed from previous scenes
    background(10, 12, 18);
    
    // Audio processing
    float basRaw = audio.normalisedAvg(2); // Low freq (bass)
    float midRaw = audio.normalisedAvg(8); // Mid freq
    float higRaw = audio.normalisedAvg(18); // High freq

    // Draw the frequency meters on the side
    drawEnergyMeters(basRaw, midRaw, higRaw);

    // Switch to additive blending for glowing effect without ghosting
    blendMode(ADD);

    // On beat, trigger a visual pulse effect spanning outward
    if (audio.beat.isOnset()) {
      triggerPulse();
      // Increase spawn rate slightly on beat for Bass
      for (int i=0; i<3; i++) spawnParticle("BASS");
    }

    // Expanding pulse ripple effect
    if (pulseRippleIntensity > 0) {
      noFill();
      strokeWeight(map(pulseRippleIntensity, 1, 0, 5, 0));
      float hue = (paletteBaseHue[paletteIndex] + hueOffset + midRaw * 50) % 360;
      colorMode(HSB, 360, 255, 255);
      stroke(hue, 200, 255, pulseRippleIntensity * 255);
      ellipse(width/2, height/2, pulseRippleRadius, pulseRippleRadius);
      colorMode(RGB, 255);
      
      pulseRippleRadius += 25 + higRaw * 20;
      pulseRippleIntensity -= 0.02;
    }

    // Spawn new particles continuously based on frequency spikes
    if (basRaw > 0.6 && random(1) < 0.3) {
      spawnParticle("BASS");
    }
    if (midRaw > 0.4 && random(1) < 0.4) {
      spawnParticle("MID");
    }
    if (higRaw > 0.3 && random(1) < 0.6) {
      spawnParticle("HIGH");
    }

    // Handle existing particles
    colorMode(HSB, 360, 255, 255);
    for (int i = particles.size() - 1; i >= 0; i--) {
      AntigravParticle p = particles.get(i);
      
      // Affect particle physics based on dynamic gravity
      // Bass explicitly boosts upward momentum
      float dynamicGravity = gravity + (basRaw * -2.0);
      p.applyForce(new PVector(wind, dynamicGravity));
      
      // Jitter horizontally based on high hats for high-freq particles
      if (higRaw > 0.4 && p.type.equals("HIGH")) {
        p.loc.x += random(-higRaw*8, higRaw*8);
      } else if (higRaw > 0.5) {
        p.loc.x += random(-higRaw*2, higRaw*2);
      }
      
      // When a pulse hits the particle, give it an outward shove
      if (pulseRippleIntensity > 0) {
        float distToCenter = dist(p.loc.x, p.loc.y, width/2, height/2);
        if (abs(distToCenter - (pulseRippleRadius/2)) < 50) {
           PVector dir = PVector.sub(p.loc, new PVector(width/2, height/2));
           dir.normalize();
           dir.mult(pulseRippleIntensity * 5.0);
           p.applyForce(dir);
        }
      }

      p.update();
      p.display(paletteBaseHue[paletteIndex], midRaw);

      if (p.isDead()) {
        particles.remove(i);
      }
    }
    
    blendMode(BLEND); // Set back to normal for HUD
    colorMode(RGB, 255);

    drawSongNameOnScreen(config.SONG_NAME, width / 2.0, height - 5);
    drawHud(basRaw, midRaw, higRaw);
  }

  void drawEnergyMeters(float basRaw, float midRaw, float higRaw) {
    noStroke();
    colorMode(HSB, 360, 255, 255);
    float hue = paletteBaseHue[paletteIndex];
    int meterWidth = 10;
    int meterMaxHeight = height / 3;
    int margin = 20;
    
    // Draw on left side
    fill(hue, 200, 255, 150);
    rect(margin, height - margin - (basRaw * meterMaxHeight), meterWidth, basRaw * meterMaxHeight);
    fill((hue + 40) % 360, 200, 255, 150);
    rect(margin + 15, height - margin - (midRaw * meterMaxHeight), meterWidth, midRaw * meterMaxHeight);
    fill((hue + 80) % 360, 200, 255, 150);
    rect(margin + 30, height - margin - (higRaw * meterMaxHeight), meterWidth, higRaw * meterMaxHeight);
    
    // Mirror on right side
    fill(hue, 200, 255, 150);
    rect(width - margin - meterWidth, height - margin - (basRaw * meterMaxHeight), meterWidth, basRaw * meterMaxHeight);
    fill((hue + 40) % 360, 200, 255, 150);
    rect(width - margin - meterWidth - 15, height - margin - (midRaw * meterMaxHeight), meterWidth, midRaw * meterMaxHeight);
    fill((hue + 80) % 360, 200, 255, 150);
    rect(width - margin - meterWidth - 30, height - margin - (higRaw * meterMaxHeight), meterWidth, higRaw * meterMaxHeight);
    colorMode(RGB, 255);
  }

  void spawnParticle(String type) {
    float x = random(width);
    float y = height + random(50);
    PVector vel = new PVector(random(-1, 1), random(-1, 0));
    particles.add(new AntigravParticle(x, y, vel, type));
  }

  void drawHud(float low, float mid, float high) {
    pushStyle();
      float ts = 11 * uiScale();
      float lh = ts * 1.3;
      fill(0, 125);
      noStroke();
      rectMode(CORNER);
      rect(8, 8, 380 * uiScale(), 8 + lh * 6);
      fill(255);
      textSize(ts);
      textAlign(LEFT, TOP);
      text("Scene: Antigravity", 12, 12);
      text("low / mid / high (norm): " + nf(low, 1, 2) + " / " + nf(mid, 1, 2) + " / " + nf(high, 1, 2), 12, 12 + lh);
      text("gravity: " + nf(gravity, 1, 2) + "  wind: " + nf(wind, 1, 2), 12, 12 + lh * 2);
      text("particles: " + particles.size(), 12, 12 + lh * 3);
      text("palette: " + paletteNames[paletteIndex], 12, 12 + lh * 4);
      text("A pulse  Y palette  [ ] gravity  -/= wind", 12, 12 + lh * 5);
    popStyle();
  }

  class AntigravParticle {
    PVector loc;
    PVector vel;
    PVector acc;
    float lifespan;
    float maxLifespan;
    float size;
    String type;
    float hueShift;

    AntigravParticle(float x, float y, PVector velocity, String pType) {
      loc = new PVector(x, y);
      vel = velocity.copy();
      acc = new PVector(0, 0);
      type = pType;
      
      if (type.equals("BASS")) {
        maxLifespan = random(300, 500);
        size = random(20, 35);
        hueShift = 0; // Pure palette color
        vel.mult(0.5); // Starts slower
      } else if (type.equals("MID")) {
        maxLifespan = random(200, 350);
        size = random(12, 20);
        hueShift = 40; // Shifted hue 
        vel.mult(1.0);
      } else { // HIGH
        maxLifespan = random(80, 150);
        size = random(4, 10);
        hueShift = -40;
        vel.mult(2.5); // Starts much faster
      }
      lifespan = maxLifespan;
    }

    void applyForce(PVector force) {
      PVector f = force.copy();
      if (type.equals("HIGH")) f.mult(1.5); // High particles affected easily
      else if (type.equals("BASS")) f.mult(0.6); // Bass particles are heavy
      f.div(size * 0.1); 
      acc.add(f);
    }

    void update() {
      vel.add(acc);
      if (type.equals("HIGH")) vel.limit(15);
      else vel.limit(8);
      
      loc.add(vel);
      acc.mult(0); // Clear acceleration
      lifespan -= 1.0;
    }

    void display(float baseHue, float midIntensity) {
      noStroke();
      float lifeRatio = lifespan / maxLifespan;
      float alpha = lifeRatio * 200;
      
      float h = (baseHue + hueShift + (1.0 - lifeRatio) * 60 + midIntensity * 30) % 360;
      if (h < 0) h += 360;
      
      // High frequency spark jitter visually brightens
      if (type.equals("HIGH")) {
        fill(h, 100, 255, alpha);
        ellipse(loc.x, loc.y, size * 1.5, size * 1.5);
      } 
      // Mid and Bass particles get halos
      else {
        // Draw glow
        fill(h, 200, 255, alpha * 0.4);
        ellipse(loc.x, loc.y, size * 2.5 + midIntensity * 10, size * 2.5 + midIntensity * 10);
        
        // Draw core
        fill(h, 150, 255, alpha);
        ellipse(loc.x, loc.y, size, size);
      }
    }

    boolean isDead() {
      return (lifespan < 0 || loc.y < -100 || loc.y > height + 200 || loc.x < -100 || loc.x > width + 100);
    }
  }
}
