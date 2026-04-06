/*
 * tt3d_acid.glsl — Acid Warp post-process for TableTennis3DScene
 *
 * UV warping with nested sine waves + hue rotation cycling.
 * Bass expands the warp amplitude; time drives the rotation speed.
 *
 * Uniforms (set each frame from Processing):
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

// Rodrigues rotation around the achromatic (1,1,1) axis — rotates hue.
vec3 hueRotate(vec3 col, float angle) {
    vec3 k = vec3(0.57735);   // normalize(vec3(1))
    float c = cos(angle);
    float s = sin(angle);
    return col * c + cross(k, col) * s + k * dot(k, col) * (1.0 - c);
}

void main() {
    vec2 uv = vertTexCoord.st;

    // Two-layer sinusoidal warp — different frequencies & speeds
    float wAmt = 0.014 * u_intensity * (1.0 + u_bass * 1.4);
    float wx = sin(uv.y * 11.0 + u_time * 1.3) * wAmt
             + sin(uv.y *  5.7 + u_time * 0.7) * wAmt * 0.5;
    float wy = cos(uv.x *  9.5 + u_time * 1.1) * wAmt
             + cos(uv.x *  4.3 + u_time * 0.9) * wAmt * 0.5;

    vec2 warpedUV = clamp(uv + vec2(wx, wy), 0.001, 0.999);
    vec4 col = texture2D(texture, warpedUV);

    // Hue cycling driven by time + bass pulse
    float hueAngle = u_time * 0.5 + u_bass * 0.8;
    col.rgb = hueRotate(col.rgb, hueAngle * u_intensity);

    // Subtle brightness pulse on beats
    col.rgb *= 1.0 + u_bass * 0.25 * u_intensity;

    gl_FragColor = col * vertColor;
}
