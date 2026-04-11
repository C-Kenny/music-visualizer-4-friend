import os

# fix Tunnel ARGB to RGB
tunnel_content = open("Tunnel.pde").read()
tunnel_content = tunnel_content.replace("createImage(w, h, ARGB)", "createImage(w, h, RGB)")
open("Tunnel.pde", "w").write(tunnel_content)

# fix Plasma
plasma_content = open("Plasma.pde").read()
plasma_content = plasma_content.replace("pg.pushMatrix();\n    pg.resetMatrix();", "pg.pushMatrix();")
open("Plasma.pde", "w").write(plasma_content)

# fix PolarPlasma
polar_content = open("PolarPlasma.pde").read()
polar_content = polar_content.replace("pg.pushMatrix();\n    pg.resetMatrix();", "pg.pushMatrix();")
open("PolarPlasma.pde", "w").write(polar_content)
