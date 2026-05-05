/*
 * fx_scanlines.glsl — CRT scanlines + film grain post-FX.
 *
 * Uniforms:
 *   u_intensity — overall effect strength 0..1
 *   u_time      — elapsed seconds (animates grain)
 *   u_bass      — bass energy 0..1 (thickens lines on drops)
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
uniform float u_time;
uniform float u_bass;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv  = vertTexCoord.st;
    vec4 col = texture2D(texture, uv);

    // Scanlines: horizontal sine pattern — slightly thicker with bass
    float lineFreq   = 480.0 + u_bass * 120.0;
    float scanline   = sin(uv.y * lineFreq * 3.14159);
    float scanAmt    = mix(0.0, 0.12, u_intensity);
    float scanFactor = 1.0 - (scanline * 0.5 + 0.5) * scanAmt;
    col.rgb *= scanFactor;

    // Film grain: per-pixel random noise
    float grain    = rand(uv + vec2(u_time * 0.01, 0.0)) - 0.5;
    float grainAmt = mix(0.0, 0.06, u_intensity);
    col.rgb += grain * grainAmt;

    gl_FragColor = col * vertColor;
}
