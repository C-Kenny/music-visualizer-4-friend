/*
 * tt3d_neon.glsl — Neon Bloom post-process for TableTennis3DScene
 *
 * Extracts bright areas, blurs them into a halo, and adds saturation boost.
 * Brights glow hard; darks stay dark — neon / arcade aesthetic.
 *
 * Uniforms:
 *   u_bass      — bass energy, 0..1  (expands bloom radius)
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

uniform float u_bass;
uniform float u_intensity;

void main() {
    vec2 uv  = vertTexCoord.st;
    vec4 src = texture2D(texture, uv);

    // ── Saturation boost ──────────────────────────────────────────────────────
    float grey    = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    float satMult = 1.5 + u_bass * 0.4;
    vec3  boosted = mix(vec3(grey), src.rgb, satMult);

    // ── 8-tap bloom ring ─────────────────────────────────────────────────────
    // Only samples that are above threshold contribute; keeps the bloom tight.
    float bloomR = (2.0 + u_bass * 3.5) * u_intensity;
    float thresh = 0.30;
    vec4  bloom  = vec4(0.0);
    float weight = 0.0;

    for (float a = 0.0; a < 6.28318; a += 0.78540) {   // 8 taps
        vec2  off = vec2(cos(a), sin(a)) * texOffset * bloomR;
        vec4  s   = texture2D(texture, uv + off);
        float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
        float w   = max(0.0, lum - thresh);
        bloom  += s * w;
        weight += w;
    }
    if (weight > 0.0) bloom /= weight;

    // ── Combine ───────────────────────────────────────────────────────────────
    vec3 finalRGB = boosted + bloom.rgb * 2.0 * u_intensity;

    // Additive hue tint toward hot colours on bright pixels
    float brightness = dot(finalRGB, vec3(0.333));
    vec3  neonHue    = vec3(1.0, 0.2 + u_bass * 0.6, 0.9 - u_bass * 0.3);
    finalRGB = mix(finalRGB, finalRGB * neonHue, brightness * 0.18 * u_intensity);

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 2.5), src.a) * vertColor;
}
