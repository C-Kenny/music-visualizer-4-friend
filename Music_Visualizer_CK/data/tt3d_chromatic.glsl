/*
 * tt3d_chromatic.glsl — Chromatic Glitch post-process for TableTennis3DScene
 *
 * RGB channel separation + scanlines + occasional glitch band.
 * Gives a cyberpunk / broken-CRT aesthetic.
 *
 * Uniforms:
 *   u_time      — accumulated time in seconds
 *   u_bass      — bass energy, 0..1
 *   u_intensity — overall effect blend, 0..1
 */

#ifdef GL_ES
precision mediump float;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2      texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float u_time;
uniform float u_bass;
uniform float u_intensity;

// Cheap pseudo-random from UV position
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = vertTexCoord.st;

    // ── Chromatic aberration ──────────────────────────────────────────────────
    // R shifted right, G center, B shifted left — exaggerated by bass
    float shift = 0.007 * u_intensity * (1.0 + u_bass * 0.8);
    float r = texture2D(texture, uv + vec2( shift,  shift * 0.3)).r;
    float g = texture2D(texture, uv).g;
    float b = texture2D(texture, uv + vec2(-shift, -shift * 0.3)).b;

    // ── Glitch band (horizontal tear) ────────────────────────────────────────
    // A thin scanline slides down the screen periodically
    float bandY   = mod(u_time * 0.35, 1.0);
    float bandDist = abs(uv.y - bandY);
    if (bandDist < 0.018) {
        // Inside the glitch band: add horizontal jitter + colour bleed
        float jitter = (rand(vec2(floor(uv.y * 200.0), u_time)) - 0.5) * 0.025 * u_intensity;
        r = texture2D(texture, uv + vec2(shift + jitter, 0.0)).r;
        b = texture2D(texture, uv + vec2(-shift - jitter * 0.5, 0.0)).b;
        // Slight brightness spike in the band
        r *= 1.15; g *= 1.1; b *= 1.2;
    }

    // ── Scanlines ─────────────────────────────────────────────────────────────
    // Faint horizontal lines like a CRT
    float scanline = sin(uv.y * 720.0 * 3.14159);
    float scanAmt  = mix(0.0, 0.09, u_intensity);
    float scanFactor = 1.0 - (scanline * 0.5 + 0.5) * scanAmt;

    vec4 col = vec4(r, g, b, 1.0);
    col.rgb  *= scanFactor;

    // ── Cool tint (cyan shadows, warm highlights) ────────────────────────────
    float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tint = mix(vec3(0.4, 0.7, 1.0), vec3(1.0, 0.9, 0.8), lum);
    col.rgb = mix(col.rgb, col.rgb * tint, 0.18 * u_intensity);

    gl_FragColor = col * vertColor;
}
