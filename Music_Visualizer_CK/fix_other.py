import glob
for f in ["AntigravityScene.pde", "CatsCradleScene.pde"]:
    try:
        content = open(f).read()
    except FileNotFoundError:
        continue
        
    if f == "AntigravityScene.pde":
        content = content.replace('gravity += delta;', 'gravity += delta * config.TIME_SCALE;')
        content = content.replace('wind += delta;', 'wind += delta * config.TIME_SCALE;')
        content = content.replace('p.loc.x += random(-higRaw*8, higRaw*8);', 'p.loc.x += random(-higRaw*8, higRaw*8) * config.TIME_SCALE;')
        content = content.replace('p.loc.x += random(-higRaw*2, higRaw*2);', 'p.loc.x += random(-higRaw*2, higRaw*2) * config.TIME_SCALE;')
        content = content.replace('p.loc.add(p.velocity);', 'p.loc.add(PVector.mult(p.velocity, config.TIME_SCALE));')
        content = content.replace('p.velocity.add(p.acceleration);', 'p.velocity.add(PVector.mult(p.acceleration, config.TIME_SCALE));')
        content = content.replace('p.lifespan -= 2.0;', 'p.lifespan -= 2.0 * config.TIME_SCALE;')

    if f == "CatsCradleScene.pde":
        content = content.replace('rotation += 0.08;', 'rotation += 0.08 * config.TIME_SCALE;')
        content = content.replace('phase    += 0.04;', 'phase += 0.04 * config.TIME_SCALE;')
        content = content.replace('rotation += rotationSpeed;', 'rotation += rotationSpeed * config.TIME_SCALE;')

    open(f, 'w').write(content)
