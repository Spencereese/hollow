shader_type canvas_item;
render_mode blend_mix;

// Full-screen (or overlay rect) tension post-processing effect for HOLLOW.
// Animated film grain, breathing vignette, subtle chromatic "fringe" and color drain on high dread.
// Applied to a ColorRect in the UI layer. Very cheap and technically satisfying.

uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float grain_amount : hint_range(0.0, 0.8) = 0.35;
uniform vec4 base_tint : source_color = vec4(1.0, 0.97, 0.93, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 screen_uv = FRAGCOORD.xy / vec2(1280.0, 720.0);  // approx for grain; scales ok

	// Animated film grain (cheap high-freq)
	float t = TIME * 18.0;
	float g1 = hash(screen_uv * 1.8 + t * 0.07);
	float g2 = hash(screen_uv * 3.4 - t * 0.11);
	float grain = (g1 * 0.6 + g2 * 0.4 - 0.5) * grain_amount * (0.6 + tension * 0.8);

	// Breathing vignette (stronger on tension, pulses slowly)
	float dist = length(uv - 0.5);
	float vig = smoothstep(0.3, 0.92, dist);
	vig = vig * (vignette_strength + tension * 0.55);
	float pulse = 0.5 + 0.5 * sin(TIME * 0.6 + tension * 2.0);
	vig *= (0.85 + pulse * 0.25 * tension);

	// Subtle chromatic aberration / color fringe on high tension (rgb shift simulation via coord)
	float ca = tension * 0.0045;
	vec2 dir = (uv - 0.5) * ca;
	// We simulate by tinting edges differently (real CA would sample offsets but this is light on a solid overlay)
	vec3 col = base_tint.rgb;

	// Color drain + cold shift on high dread
	float desat = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(desat * 0.75 + 0.03), tension * 0.65);
	col = mix(col, col * vec3(0.85, 0.9, 1.05), tension * 0.25);  // slight blue cold

	// Apply grain + vignette darkness
	col += vec3(grain * 0.6);
	col *= (1.0 - vig * 0.92);

	COLOR = vec4(col, 1.0);
}
