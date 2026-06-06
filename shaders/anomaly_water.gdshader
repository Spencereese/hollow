shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

// Animated rippling black water / threshold for the HOLLOW anomaly.
// Vertex waves + time-driven emission and fake surface "skin" for technical horror payoff.
// Self-contained, no external textures.

uniform vec4 base_color : source_color = vec4(0.015, 0.012, 0.018, 1.0);
uniform vec4 emission_color : source_color = vec4(0.008, 0.006, 0.012, 1.0);
uniform float emission_energy : hint_range(0.0, 2.0) = 0.35;
uniform float ripple_speed = 1.4;
uniform float ripple_amp = 0.035;
uniform float ripple_freq = 6.0;
uniform float tension : hint_range(0.0, 1.0) = 0.0;  // driven from GameManager / Audio

varying vec3 world_pos;
varying float height_wave;

void vertex() {
	// Multiple sine waves for organic water ripples (radial-ish feel on cylinder)
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = wp;

	float t = TIME * ripple_speed;
	float r = length(VERTEX.xz) * ripple_freq;

	// Primary slow swell + faster chop + tension modulated high freq
	float w1 = sin(t * 0.7 + r) * 0.6;
	float w2 = sin(t * 1.9 + r * 1.7 + VERTEX.y * 3.0) * 0.35;
	float w3 = sin(t * 3.4 + r * 2.3) * 0.15 * (0.6 + tension * 1.4);

	float wave = (w1 + w2 + w3) * ripple_amp * (0.7 + tension * 0.8);
	VERTEX.y += wave;

	height_wave = wave;  // pass for fragment
}

void fragment() {
	// Base dark "void" water
	vec3 col = base_color.rgb;

	// Fake animated surface normal / highlight from wave height (cheap)
	float n = height_wave * 18.0;
	vec3 fake_normal = normalize(vec3(sin(n * 0.8), 1.0, cos(n * 1.1)));
	float rim = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 2.0 + tension * 2.0);

	// Emission pulse that syncs with tension / heartbeat feel
	float pulse = 0.5 + 0.5 * sin(TIME * (1.6 + tension * 1.8) + world_pos.x * 2.0);
	float e = emission_energy * (0.6 + tension * 1.8) * (0.7 + pulse * 0.6);

	// Slight color shift toward sickly on high tension
	vec3 emit = emission_color.rgb * (1.0 + tension * 0.6);
	EMISSION = emit * e + rim * 0.04 * (1.0 + tension);

	ALBEDO = col;
	ROUGHNESS = 0.08 + tension * 0.15;
	METALLIC = 0.05;
	SPECULAR = 0.6;
}
