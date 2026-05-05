/*
 * fx_chromatic.glsl — Global chromatic aberration + glitch band post-FX.
 *
 * Uniforms:
 *   u_bass      — bass energy 0..1  (drives split amount)
 *   u_intensity — overall effect strength 0..1
 *   u_time      — elapsed seconds (drives glitch band animation)
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
uniform float u_time;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = vertTexCoord.st;

    // Chromatic aberration: R right, B left, G center
    float shift = 0.006 * u_intensity * (1.0 + u_bass * 1.2);
    float r = texture2D(texture, uv + vec2( shift,  shift * 0.25)).r;
    float g = texture2D(texture, uv).g;
    float b = texture2D(texture, uv + vec2(-shift, -shift * 0.25)).b;

    // Glitch band: thin horizontal tear that slides down periodically
    float bandY    = mod(u_time * 0.3, 1.0);
    float bandDist = abs(uv.y - bandY);
    if (bandDist < 0.015 * u_intensity) {
        float jitter = (rand(vec2(floor(uv.y * 180.0), u_time)) - 0.5) * 0.02 * u_intensity;
        r = texture2D(texture, uv + vec2(shift  + jitter, 0.0)).r;
        b = texture2D(texture, uv + vec2(-shift - jitter * 0.5, 0.0)).b;
        r *= 1.1; g *= 1.05; b *= 1.15;
    }

    gl_FragColor = vec4(r, g, b, 1.0) * vertColor;
}
