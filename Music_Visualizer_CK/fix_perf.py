import os

for f in ["Tunnel.pde", "Plasma.pde", "PolarPlasma.pde"]:
    try:
        content = open(f).read()
    except Exception:
        continue
        
    if "PImage buffer;" not in content:
        # Add buffer declaration and init
        if "Tunnel" in f:
            content = content.replace("class Tunnel {", "class Tunnel {\n  PImage buffer;\n")
            content = content.replace("lookUpTable = new int[width*height];", "lookUpTable = new int[width*height];\n    buffer = createImage(width, height, ARGB);")
            # Replace pg pixel ops
            content = content.replace("pg.loadPixels();", "buffer.loadPixels();")
            content = content.replace("pg.updatePixels();", "buffer.updatePixels();\n    pg.image(buffer, 0, 0);")
            content = content.replace("pg.pixels[pgIdx]", "buffer.pixels[pgIdx]")
            
        elif "Plasma" in f and "PolarPlasma" not in f:
            content = content.replace("class Plasma {", "class Plasma {\n  PImage buffer;\n")
            content = content.replace("pal = new int[config.PLASMA_SIZE];", "pal = new int[config.PLASMA_SIZE];\n    buffer = createImage(width, height, RGB);")
            content = content.replace("pg.loadPixels();", "buffer.loadPixels();\n    if (buffer.pixels.length != cls.length) return;")
            content = content.replace("pg.updatePixels();", "buffer.updatePixels();\n    pg.image(buffer, 0, 0);")
            content = content.replace("pixelCount >= pg.pixels.length", "pixelCount >= buffer.pixels.length")
            content = content.replace("pg.pixels[pixelCount]", "buffer.pixels[pixelCount]")
            
        elif "PolarPlasma" in f:
            content = content.replace("class PolarPlasma {", "class PolarPlasma {\n  PImage buffer;\n")
            content = content.replace("radius = new int[screenSize];", "radius = new int[screenSize];\n    buffer = createImage(width, height, RGB);")
            content = content.replace("pg.loadPixels();", "buffer.loadPixels();")
            content = content.replace("pg.updatePixels();", "buffer.updatePixels();\n    pg.image(buffer, 0, 0);")
            content = content.replace("i >= pg.pixels.length", "i >= buffer.pixels.length")
            content = content.replace("pg.pixels.length", "buffer.pixels.length")
            content = content.replace("pg.pixels[i]", "buffer.pixels[i]")
            
        open(f, 'w').write(content)

