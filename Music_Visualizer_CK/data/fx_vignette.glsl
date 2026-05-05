/*
 * fx_vignette.glsl — Cinematic vignette (dark edges) post-FX.
 *
 * Uniforms:
 *   u_intensity — vignette strength 0..1
 *   u_bass      — bass energy 0..1 (pulses vignette on beats)
 */

#ifdef GL_ES
precision mediump float;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2      texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float u_intensity;
uniform float u_bass;

void main() {
    vec2 uv  = vertTexCoord.st;
    vec4 col = texture2D(texture, uv);

    // Distance from center (0..~0.71 at corners)
    vec2  d       = uv - 0.5;
    float dist    = length(d);

    // Vignette curve: soft falloff, slightly pulsed by bass
    float strength = mix(0.0, 1.0, u_intensity);
    float pulse    = 1.0 + u_bass * 0.25 * u_intensity;
    float vignette = 1.0 - smoothstep(0.35, 0.75, dist * pulse) * strength;

    col.rgb *= vignette;

    gl_FragColor = col * vertColor;
}
