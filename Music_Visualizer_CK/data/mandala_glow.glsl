/*
 * mandala_glow.glsl
 *
 * Soft additive glow post-process for the Recursive Mandala scene.
 * Samples 8 neighbours in a ring and adds a weighted halo on top of the
 * source pixel. Both radius and strength are driven per-frame by audio.
 *
 * Uniforms:
 *   glowStrength  — how much to add (0 = off, 3 = heavy bloom)
 *   glowRadius    — sample offset in pixels (1 = tight, 8 = wide halo)
 */

#ifdef GL_ES
precision mediump float;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2      texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float glowStrength;
uniform float glowRadius;

void main() {
    vec2 uv  = vertTexCoord.st;
    vec4 src = texture2D(texture, uv);

    vec2 off = texOffset * glowRadius;

    // 8-tap ring (cardinal + diagonal, diagonal weight ≈ 0.707)
    vec4 ring = vec4(0.0);
    ring += texture2D(texture, uv + vec2( off.x,      0.0     ));
    ring += texture2D(texture, uv + vec2(-off.x,      0.0     ));
    ring += texture2D(texture, uv + vec2(    0.0,  off.y      ));
    ring += texture2D(texture, uv + vec2(    0.0, -off.y      ));
    ring += texture2D(texture, uv + vec2( off.x * 0.707,  off.y * 0.707));
    ring += texture2D(texture, uv + vec2(-off.x * 0.707,  off.y * 0.707));
    ring += texture2D(texture, uv + vec2( off.x * 0.707, -off.y * 0.707));
    ring += texture2D(texture, uv + vec2(-off.x * 0.707, -off.y * 0.707));
    ring *= 0.125;   // normalise to 1.0 total weight

    // Additive blend: halo on top of sharp source
    gl_FragColor = src + ring * glowStrength;
}
