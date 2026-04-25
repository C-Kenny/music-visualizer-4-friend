// Scene groups for the web UI scene picker. Groups render as folders;
// scenes inside are buttons that POST /scene to switch live.
//
// To re-classify a scene: move its ID between groups below.
// Display names are derived from SceneIds constants but overridable here.

class SceneEntry {
  int id;
  String name;
  SceneEntry(int id, String name) { this.id = id; this.name = name; }
}

class SceneGroup {
  String name;
  ArrayList<SceneEntry> scenes;
  SceneGroup(String name) { this.name = name; this.scenes = new ArrayList<SceneEntry>(); }
  SceneGroup add(int id, String label) { scenes.add(new SceneEntry(id, label)); return this; }
}

ArrayList<SceneGroup> buildSceneGroups() {
  ArrayList<SceneGroup> g = new ArrayList<SceneGroup>();

  SceneGroup demos = new SceneGroup("Demos (client-facing)");
  demos.add(SCENE_EXPLAINER, "Visualizer Explainer");
  demos.add(SCENE_MATH_WAVE, "Math Wave");
  g.add(demos);

  SceneGroup production = new SceneGroup("Production (concert)");
  production.add(SCENE_ORIGINAL,          "Original");
  production.add(SCENE_HEART_GRID,        "Heart Grid");
  production.add(SCENE_SHAPES_3D,         "Shapes 3D");
  production.add(SCENE_CATS_CRADLE,       "Cat's Cradle");
  production.add(SCENE_OSCILLOSCOPE,      "Oscilloscope");
  production.add(SCENE_TABLE_TENNIS,      "Table Tennis");
  production.add(SCENE_PRISM_CODEX,       "Prism Codex");
  production.add(SCENE_PARTICLE_FOUNTAIN, "Particle Fountain");
  production.add(SCENE_HALO2_LOGO,        "Halo 2 Logo");
  production.add(SCENE_AURORA_RIBBONS,    "Aurora Ribbons");
  production.add(SCENE_RADIAL_FFT,        "Radial FFT");
  production.add(SCENE_SPIROGRAPH,        "Spirograph");
  production.add(SCENE_GRAVITY_STRINGS,   "Gravity Strings");
  production.add(SCENE_NEURAL_WEAVE,      "Neural Weave");
  production.add(SCENE_SHOAL_LUMINA,      "Shoal Lumina");
  production.add(SCENE_ANTIGRAVITY,       "Antigravity");
  production.add(SCENE_FRACTAL,           "Fractal");
  production.add(SCENE_SHADER,            "Shader");
  production.add(SCENE_WORM,              "Worm");
  production.add(SCENE_FFT_WORM,          "FFT Worm");
  production.add(SCENE_DEEP_SPACE,        "Deep Space");
  production.add(SCENE_CYBER_GRID,        "Cyber Grid");
  production.add(SCENE_RECURSIVE_MANDALA, "Recursive Mandala");
  production.add(SCENE_KALEIDOSCOPE,      "Kaleidoscope");
  production.add(SCENE_TABLE_TENNIS_3D,   "Table Tennis 3D");
  production.add(SCENE_VOID_BLOOM,        "Void Bloom");
  production.add(SCENE_CIRCUIT_MAZE,      "Circuit Maze");
  production.add(SCENE_MAZE_PUZZLE,       "Maze Puzzle");
  production.add(SCENE_LISSAJOUS_KNOT,    "Lissajous Knot");
  production.add(SCENE_FLUID_SIM,         "Fluid Sim");
  production.add(SCENE_HOURGLASS,         "Hourglass");
  production.add(SCENE_SACRED_GEOMETRY,   "Sacred Geometry");
  production.add(SCENE_TORUS_KNOT,        "Torus Knot");
  production.add(SCENE_ROSE_CURVE,        "Rose Curve");
  production.add(SCENE_SRI_YANTRA,        "Sri Yantra");
  production.add(SCENE_NET_OF_BEING,      "Net of Being");
  production.add(SCENE_PSYCHEDELIC_EYE,   "Psychedelic Eye");
  production.add(SCENE_COSMIC_LATTICE,    "Cosmic Lattice");
  production.add(SCENE_ORIGINAL_3D,       "Original 3D");
  production.add(SCENE_DOT_MANDALA,       "Dot Mandala");
  production.add(SCENE_MERKABA_STAR,      "Merkaba Star");
  production.add(SCENE_PENTAGONAL_VORTEX, "Pentagonal Vortex");
  production.add(SCENE_TUNNEL_YANTRA,     "Tunnel Yantra");
  production.add(SCENE_CHLADNI_PLATE,     "Chladni Plate");
  production.add(SCENE_STRANGE_ATTRACTOR, "Strange Attractor");
  production.add(SCENE_RIP,               "RIP");
  g.add(production);

  return g;
}
