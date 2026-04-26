/**
 * MandelbrotRenderer — escape-time fractal rendered to a low-res PGraphics
 * buffer, then upscaled. Owns its own pan/zoom state since those are not
 * driven by audio (interactive). Caller wires controller input via the
 * pan()/zoom()/setView() helpers.
 *
 * Bass adds iteration headroom (more detail at the boundary).
 * Mid breathes the zoom slightly for organic motion.
 */
class MandelbrotRenderer implements FractalRenderer {
  PGraphics buf;
  int bw = 240, bh = 180;
  float cx = -0.5, cy = 0.0, zoom = 1.0;

  String name() { return "Mandelbrot"; }

  void pan(float dx, float dy) { cx += dx / zoom; cy += dy / zoom; }
  void zoomBy(float factor)    { zoom = constrain(zoom * factor, 0.3, 5000.0); }
  void setView(float cx, float cy, float zoom) { this.cx = cx; this.cy = cy; this.zoom = zoom; }

  void draw(PGraphics pg, FractalParams p) {
    if (buf == null) buf = createGraphics(bw, bh);
    int maxIter = 60 + (int)(p.bass * 120);
    float z = zoom * (1.0 + p.mid * 0.3);

    buf.beginDraw();
    buf.loadPixels();
    buf.colorMode(HSB, 360, 255, 255);
    for (int py = 0; py < bh; py++) {
      for (int px = 0; px < bw; px++) {
        float x0 = cx + (px - bw * 0.5) * (3.0 / bw) / z;
        float y0 = cy + (py - bh * 0.5) * (3.0 / bw) / z;
        float zx = 0, zy = 0;
        int it = 0;
        while (zx * zx + zy * zy < 4 && it < maxIter) {
          float t = zx * zx - zy * zy + x0;
          zy = 2 * zx * zy + y0;
          zx = t;
          it++;
        }
        int c = (it == maxIter) ? buf.color(0, 0, 0)
                                 : buf.color((p.hueShift + it * 6) % 360, 220, 255);
        buf.pixels[py * bw + px] = c;
      }
    }
    buf.updatePixels();
    buf.endDraw();

    float drawW = min(pg.width, pg.height) * 0.75;
    float drawH = drawW * (float)bh / bw;
    pg.imageMode(CENTER);
    pg.image(buf, 0, 0, drawW, drawH);
    pg.imageMode(CORNER);
  }
}
