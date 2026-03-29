/* 
   MILKDROP LESSON SHADER
   ======================
   Welcome! This shader runs entirely on your Graphics Card (GPU) instead of your CPU.
   Because the GPU has thousands of tiny cores, it can calculate the color of EVERY SINGLE PIXEL
   on your screen simultaneously, 60 times a second, without lagging.
   
   Unlike Java or Processing where you tell the computer "draw a line here", in a shader
   you write a single mathematical equation that says: "Given this pixel's coordinate, what color should it be?"
*/

#ifdef GL_ES
precision mediump float;
#endif

// UNIFORMS: These are variables passed from Processing (CPU) to this Shader (GPU) every frame.
// Think of them as the remote control for your shader.
uniform vec2 u_resolution; // The width and height of the screen
uniform float u_time;      // How many seconds the app has been running

// Our custom music interaction uniforms!
uniform float audio_bass;
uniform float audio_mid;
uniform float audio_high;

// Controller inputs we get from the Left and Right sticks
uniform vec2 controller_pan; // Moves the center point (-1 to 1)
uniform float controller_twist; // Twists the kaleidoscope

void main() {
    // -------------------------------------------------------------
    // 1. SETUP: WHERE ARE WE ON THE SCREEN?
    // -------------------------------------------------------------
    
    // gl_FragCoord gives us the (X, Y) pixel we are currently calculating.
    // Example: (1920, 1080) for the top right corner.
    vec2 absolute_pixel_coordinate = gl_FragCoord.xy;
    
    // We normalize the coordinate so it goes from -1.0 to 1.0, and put (0,0) exactly in the middle of the screen.
    // We divide by u_resolution.y to keep perfect circular math (no stretching on widescreen displays).
    vec2 centered_math_coordinate = (absolute_pixel_coordinate - 0.5 * u_resolution.xy) / u_resolution.y;

    // Apply the controller panning from the Left Stick
    centered_math_coordinate += controller_pan;

    // -------------------------------------------------------------
    // 2. THE KALEIDOSCOPE FRACTAL LOOP
    // -------------------------------------------------------------
    
    // We need a variable to store the final brightness of the pixel before coloring it.
    float final_brightness_accumulation = 0.0;
    
    // We make a copy of the coordinate that we can fold, mangle, and distort inside the loop
    vec2 working_coordinate = centered_math_coordinate;
    
    // The Magic Loop! We will repeat this math 4 times to fold space over itself recursively.
    for (float loop_index = 0.0; loop_index < 4.0; loop_index++) {
        
        // Let's create a symmetrical mirror! This forces all negative coordinates to be positive.
        // It's like folding a piece of paper into 4 corners!
        working_coordinate = abs(working_coordinate);
        
        // We push the coordinates away from the center.
        // The heavier the BASS drops in the music, the further everything pushes outward!
        float expansion_multiplier = 1.3 + (audio_bass * 0.5);
        working_coordinate = (working_coordinate * expansion_multiplier) - 0.5;
        
        // We twist the space around the origin point using a 2D Rotation Matrix
        // The rotation changes over time, and reacts to the Right Stick!
        float twist_angle = u_time * 0.2 + controller_twist;
        float s = sin(twist_angle);
        float c = cos(twist_angle);
        
        // This is standard algebra for spinning a 2D coordinate around (0,0)
        vec2 spun_coordinate;
        spun_coordinate.x = working_coordinate.x * c - working_coordinate.y * s;
        spun_coordinate.y = working_coordinate.x * s + working_coordinate.y * c;
        working_coordinate = spun_coordinate;

        // -------------------------------------------------------------
        // 3. DRAWING THE GLOWING RINGS
        // -------------------------------------------------------------
        
        // Now find out how far this newly-twisted pixel is from (0,0) using the Pythagorean theorem length()
        float distance_from_center = length(working_coordinate);
        
        // We use a Sine Wave to make concentric ripples based on distance!
        // We subtract u_time so the ripples move inward, and add audio_mid so they pulse to the vocals.
        float wave_ripple = sin(distance_from_center * 8.0 - (u_time * 2.0) + (audio_mid * 2.0));
        
        // The absolute function abs() takes alternating waves (-1 to 1) and bounces them (1 to 0 to 1).
        // This makes sharp, thin valleys at exactly 0.
        float sharp_valley = abs(wave_ripple);
        
        // Divide a very small thickness by the valley.
        // If the valley is 0.001, 0.02 / 0.001 = 20 (Huge brightness spike!)
        // The higher the Treble/Hats, the thicker the rings get!
        float ring_thickness = 0.01 + (audio_high * 0.05);
        float glowing_outline = ring_thickness / sharp_valley;
        
        // Add this loop's glowing outline to the total accumulation!
        final_brightness_accumulation += glowing_outline;
    }
    
    // -------------------------------------------------------------
    // 4. COLORING THE FRACTAL AND OUTPUTTING TO THE SCREEN
    // -------------------------------------------------------------
    
    // We create a base RGB color vector. Pink/Purple/Blue!
    vec3 base_color = vec3(0.5, 0.2, 0.9);
    
    // We add a shifting RGB vector so the colors crawl through the rainbow over time.
    vec3 time_shifting_color = vec3(
        sin(u_time * 1.1 + audio_bass), 
        cos(u_time * 1.3 + audio_mid), 
        sin(u_time * 0.7 + audio_high)
    );
    
    // Multiply the math together! We scale the color by 0.5 and add 0.5 so it stays bright.
    vec3 final_pixel_color = base_color * (time_shifting_color * 0.5 + 0.5);
    
    // Multiply the color by the glowing outlines we accumulated in the loop
    final_pixel_color *= final_brightness_accumulation;
    
    // The final keyword in GLSL! gl_FragColor is the ultimate exit door.
    // It requires a vec4 (Red, Green, Blue, Alpha boundary). The final 1.0 means fully opaque.
    gl_FragColor = vec4(final_pixel_color, 1.0);
}
