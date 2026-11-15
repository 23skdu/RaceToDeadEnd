shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(100.0, 1200.0) = 420.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.32;
uniform float vignette_radius : hint_range(0.3, 1.2) = 0.78;
uniform float chromatic_aberration : hint_range(0.0, 0.006) = 0.0018;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.68;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.22;
uniform float film_grain : hint_range(0.0, 0.15) = 0.04;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - 0.5;

    // Chromatic aberration (radial, stronger at edges)
    float ca = chromatic_aberration * (1.0 + length(center) * 1.6);
    vec3 col;
    col.r = texture(screen_texture, uv + vec2(ca, 0.0)).r;
    col.g = texture(screen_texture, uv).g;
    col.b = texture(screen_texture, uv - vec2(ca, 0.0)).b;

    // Simple bloom: boost bright pixels
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    if (lum > bloom_threshold) {
        float boost = (lum - bloom_threshold) * bloom_intensity;
        col += col * boost;
    }

    // Scanlines
    float scan = sin(uv.y * scanline_count * 3.14159265) * 0.5 + 0.5;
    col *= 1.0 - scanline_intensity * (1.0 - scan);

    // Film grain
    float grain = hash(uv * 1000.0 + vec2(TIME * 7.0, TIME * 13.0)) - 0.5;
    col += grain * film_grain;

    // Vignette
    float dist = length(center);
    float vign = smoothstep(vignette_radius, vignette_radius - 0.32, dist);
    col *= mix(1.0, vign, vignette_intensity);

    COLOR = vec4(col, 1.0);
}
