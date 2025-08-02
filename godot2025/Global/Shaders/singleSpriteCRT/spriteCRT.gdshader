shader_type canvas_item;

uniform vec2 resolution = vec2(320.0, 180.0);
uniform float scan_line_amount : hint_range(0.0, 1.0) = 0.3;
uniform float scan_line_speed : hint_range(0.0, 5.0) = 1.0;
uniform float warp_amount : hint_range(0.0, 1.0) = 0.1;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float grille_amount : hint_range(0.0, 1.0) = 0.05;
uniform float brightness_boost : hint_range(1.0, 2.0) = 1.2;
uniform vec3 blue_tint_color : source_color = vec3(0.8, 0.9, 1.0);

void fragment() {
    vec2 uv = UV; // Changed from SCREEN_UV to UV
    
    // --- Screen Warp/Curvature ---
    vec2 delta = uv - 0.5;
    float warp_factor = dot(delta, delta) * warp_amount;
    uv += delta * warp_factor;
    
    // Check if warped UV is outside texture bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent outside bounds
    }
    
    // --- Scanlines ---
    float scanline = sin((uv.y * resolution.y + TIME * scan_line_speed) * PI) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, scan_line_amount * 0.5);
    
    // --- RGB Grille / Pixel Mask ---
    float grille = mod(uv.x * resolution.x, 3.0) < 1.5 ? 0.95 : 1.05;
    grille = mix(1.0, grille, grille_amount * 0.5);
    
    // Sample the sprite's texture instead of SCREEN_TEXTURE
    vec4 tex_color = texture(TEXTURE, uv);
    vec3 color = tex_color.rgb * scanline * grille;
    
    // --- Apply Blue Tint ---
    color *= blue_tint_color;
    
    // --- Vignette ---
    vec2 v_uv = uv * (1.0 - uv.xy);
    float vignette = v_uv.x * v_uv.y * 15.0;
    vignette = mix(1.0, vignette, vignette_amount * 0.7);
    
    // Apply vignette and brightness boost
    color *= vignette * brightness_boost;
    
    COLOR.rgb = color;
    COLOR.a = tex_color.a; // Preserve original alpha
}