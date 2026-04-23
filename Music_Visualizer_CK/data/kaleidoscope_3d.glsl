#ifdef GL_ES
precision highp float;
#endif

#define PROCESSING_COLOR_SHADER

uniform vec2  resolution;
uniform float time;
uniform float bass;
uniform float mid;
uniform float high;
uniform float segments;
uniform float rotation;
uniform float zoom;
uniform vec3  paletteCol;

#define MAX_STEPS 80
#define SURF_DIST 0.005
#define MAX_DIST 25.0

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// Global variable to capture glow accumulation
float glow = 0.0;

// Fold space kaleidoscopically
vec2 fold(vec2 p, float n) {
    float w = 3.14159265359 / n;
    float a = atan(p.y, p.x);
    float r = length(p);
    
    // fold angle
    a = mod(a + w, 2.0 * w) - w;
    a = abs(a);
    
    return vec2(cos(a), sin(a)) * r;
}

float map(vec3 p) {
    vec3 q = p;
    
    // Travel forward in the dimension
    q.z -= time * (1.5 + mid * 0.5);
    
    // Twist the entire space based on Z and rotation
    q.xy *= rot(rotation + q.z * 0.05);
    
    // Apply global kaleidoscope fold to XY
    q.xy = fold(q.xy, segments);

    // Repeat space infinitely along Z axis so we never fly past it
    q.z = mod(q.z, 4.0) - 2.0;
    
    // Define a straight hollow tunnel around the camera path
    // We use the original p.xy (before twist/fold/travel) so the tunnel perfectly follows the camera!
    float tunnel = length(p.xy) - (0.5 + bass * 0.2);

    // KIFS (Kaleidoscopic Iterated Function System) Fractal
    float scale = 1.0;
    for (int i = 0; i < 4; i++) {
        // Fold space
        q.xyz = abs(q.xyz) - vec3(0.8 + bass * 0.2, 0.4, 0.5);
        
        // Rotate
        q.xy *= rot(0.2 + time * 0.1);
        q.xz *= rot(0.3);
        
        // Scale
        q *= 1.2;
        scale *= 1.2;
    }
    
    // Distance to a hollow box or framework
    float d = length(max(abs(q) - vec3(0.5, 0.5, 2.0), 0.0)) - 0.1;
    
    // Convert back to true distance
    d /= scale;
    
    // CRITICAL FIX: Carve out the center tunnel so the camera never intersects solid geometry!
    d = max(d, -tunnel);
    
    // Accumulate glow based on proximity to the fractal
    // Drastically reduced accumulation to prevent blowing out to white
    glow += 0.002 / (0.002 + d * d);
    
    return d;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.005, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

void main() {
    // Normalize coordinates (-1 to 1)
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    
    // Camera setup
    vec3 ro = vec3(0.0, 0.0, -2.0);
    vec3 rd = normalize(vec3(uv * (1.0 / zoom), 1.0));
    
    float t = 0.0;
    float d = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * t;
        d = map(p);
        if (d < SURF_DIST || t > MAX_DIST) break;
        t += d;
    }
    
    vec3 col = vec3(0.0);
    
    if (t < MAX_DIST) {
        vec3 p = ro + rd * t;
        vec3 n = getNormal(p);
        
        // Dynamic rich colors based on normals and depth
        vec3 matCol = paletteCol;
        // Faster, more dramatic color shift
        matCol = mix(matCol, matCol.gbr, sin(t * 0.8 - time * 2.0) * 0.5 + 0.5);
        matCol = mix(matCol, matCol.brg, n.y * 0.5 + 0.5);
        
        // Lighting
        vec3 lightDir = normalize(vec3(1.0, 1.0, -2.0)); // Adjusted angle
        float diff = max(dot(n, lightDir), 0.0);
        float ambient = 0.05; // Darker ambient for richer shadows
        
        // Base geometry color - keeping it grounded
        col = matCol * (diff + ambient);
        
        // Add fresnel rim light for deep glass reflections, but tighter and darker
        float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 5.0);
        col += matCol * fresnel * (0.5 + high);
    }
    
    // Add volumetric fractal glow (accumulated during raymarch)
    // Use pure vivid color for the glow, avoid mixing with white
    vec3 glowCol = paletteCol;
    glowCol = mix(glowCol, glowCol.zxy, 0.5); // Shift hue slightly
    
    // Scaled way down to prevent washing out
    col += glowCol * glow * 0.015 * (1.0 + bass);
    
    // Distance fog - Use black fog to create dramatic depth and hide the clipping plane
    float fog = exp(-t * 0.15); // Thicker fog
    col *= fog;
    
    // Subtle high energy flash
    col += paletteCol * high * 0.05;
    
    // Cinematic ACES Tone mapping for extremely rich, vibrant colors
    col = (col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14);
    
    // Gamma correction
    col = pow(col, vec3(1.0 / 2.2));
    
    gl_FragColor = vec4(col, 1.0);
}
