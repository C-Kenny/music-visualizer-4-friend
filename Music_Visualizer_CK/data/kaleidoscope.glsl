/*
 * kaleidoscope.glsl  —  glass/mirror kaleidoscope
 *
 * Folds UV space into N mirror-symmetric wedges with optical glass effects:
 *   • Chromatic aberration  — R/G/B channels sample at different radii (prism dispersion)
 *   • Mirror seam shadow    — darkening where adjacent mirrors meet
 *   • Seam specular glint   — bright reflection line exactly on the mirror edge
 *   • Thin-film iridescence — rainbow shimmer on the mirror edge (like real glass)
 *   • Radial vignette       — soft falloff at outer rim only (keeps most of screen lit)
 *
 * All effects are tunable from the sketch via uniforms.
 */

#ifdef GL_ES
precision mediump float;
#endif

#define PROCESSING_TEXTURE_SHADER

#define PI  3.14159265358979323846

uniform sampler2D texture;
uniform vec2      texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

uniform float segments;    // number of mirror wedges
uniform float rotation;    // global angular offset in radians
uniform float zoom;        // source zoom (0.65 fills screen, >1 zooms in)
uniform float chromaAmt;   // chromatic aberration delta (0.0–0.05)
uniform float seamWidth;   // seam shadow width as fraction of wedge (0.05–0.25)
uniform float seamDark;    // seam shadow strength (0.0–0.8)

// Fold a radius+angle pair back to source UV space.
vec2 toSourceUV(float fa, float r) {
    return clamp(vec2(cos(fa), -sin(fa)) * r + 0.5, 0.001, 0.999);
}

void main() {
    vec2 uv = vertTexCoord.st - 0.5;
    uv.y = -uv.y;

    float r = length(uv);
    float a = atan(uv.y, uv.x) + rotation;

    float wedge = PI / segments;
    float fa    = mod(a, 2.0 * wedge);
    if (fa > wedge) fa = 2.0 * wedge - fa;

    // ── Chromatic aberration ─────────────────────────────────────────────────
    // Each colour channel samples at a slightly different radius — prism effect.
    vec4 col;
    col.r = texture2D(texture, toSourceUV(fa, r * (zoom + chromaAmt))).r;
    col.g = texture2D(texture, toSourceUV(fa, r *  zoom             )).g;
    col.b = texture2D(texture, toSourceUV(fa, r * (zoom - chromaAmt))).b;
    col.a = 1.0;

    // ── Mirror seam shadow ───────────────────────────────────────────────────
    // 'edge' = 0 at the mirror edge, 1 at wedge centre.
    float edge       = min(fa, wedge - fa) / (wedge * 0.5);
    float seamFactor = smoothstep(0.0, seamWidth, edge);
    col.rgb *= mix(1.0 - seamDark, 1.0, seamFactor);

    // ── Seam specular glint ───────────────────────────────────────────────────
    // Tight gaussian peak exactly on the mirror edge.
    float glint = exp(-edge * edge / (seamWidth * seamWidth * 0.03)) * 0.45;
    col.rgb += glint * vec3(0.88, 0.94, 1.00);

    // ── Thin-film iridescence on mirror edge ─────────────────────────────────
    // Real glass/crystal shows rainbow colours where two surfaces meet.
    // We add a small additive colour that cycles through hues along the edge.
    float iriMask  = exp(-edge * edge / (seamWidth * seamWidth * 0.10)) * 0.30;
    float iriAngle = fa / wedge * PI * 6.0 + r * 12.0;
    vec3  iriCol   = vec3(
        sin(iriAngle        ) * 0.5 + 0.5,
        sin(iriAngle + 2.094) * 0.5 + 0.5,
        sin(iriAngle + 4.189) * 0.5 + 0.5
    );
    col.rgb += iriCol * iriMask;

    // ── Radial vignette ─────────────────────────────────────────────────────
    // Only darkens the outermost 20% of the radius — most of the screen stays lit.
    float normR    = r * zoom;
    float vignette = 1.0 - smoothstep(0.52, 0.76, normR) * 0.50;
    col.rgb       *= vignette;

    gl_FragColor = col * vertColor;
}
