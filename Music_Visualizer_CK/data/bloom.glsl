#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2 texOffset;

varying vec4 vertColor;
varying vec4 vertTexCoord;

// Bloom parameters
uniform float threshold = 0.85;
uniform float intensity = 1.2;

void main() {
    vec4 color = texture2D(texture, vertTexCoord.st);
    
    // Extract brightness
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec4 highlight = vec4(0.0);
    if (brightness > threshold) {
        highlight = color;
    }

    // Simple 9-tap blur for the highlight
    vec4 blur = vec4(0.0);
    float samples = 0.0;
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec4 s = texture2D(texture, vertTexCoord.st + vec2(x, y) * texOffset * 2.0);
            float b = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
            if (b > threshold) {
                blur += s;
            }
            samples += 1.0;
        }
    }
    blur /= samples;

    gl_FragColor = color + blur * intensity;
}
