shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Corruption / burn / smear shader for documents and photos (Polaroid etc).
// Drive "corrupt" 0->1 from code on note events for animated reveal of the horror.
// Uses cheap procedural noise for distortion and burn edge. Self-contained.

uniform sampler2D albedo_tex : source_color;
uniform float corrupt : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 0.8;
uniform vec4 burn_tint : source_color = vec4(0.08, 0.04, 0.03, 1.0);

varying vec2 base_uv;

void vertex() {
	base_uv = UV;
	// Optional slight paper crumple on high corrupt
	vec2 uv = UV;
	float c = corrupt;
	float crumple = sin((uv.x + uv.y) * 18.0 + TIME * 1.5) * 0.004 * c;
	VERTEX += NORMAL * crumple;
}

void fragment() {
	vec2 uv = base_uv;

	// Procedural "noise" for distortion and burn (no extra textures)
	float t = TIME * time_scale;
	float n1 = sin(uv.x * 37.0 + t * 1.3) * 0.5 + sin(uv.y * 29.0 - t * 0.9) * 0.5;
	float n2 = sin(uv.x * 71.0 - t * 2.1 + uv.y * 11.0) * 0.5 + 0.5;
	float noise = (n1 * 0.6 + n2 * 0.4);

	// UV distortion grows with corrupt
	vec2 distort = vec2(noise * 0.018, (noise * 0.5 - 0.25) * 0.022) * corrupt;
	uv += distort;

	vec3 base = texture(albedo_tex, uv).rgb;

	// Desaturate + cool sickly shift
	float gray = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 desat = mix(base, vec3(gray * 0.6 + 0.08), corrupt * 0.85);

	// Burn / smear edge
	float burn = smoothstep(0.35, 0.82, noise * (0.6 + corrupt * 1.2)) * corrupt;
	vec3 burned = mix(desat, burn_tint.rgb, burn * 0.9);

	// Extra dark vignette on edges of the "ruin"
	float edge = 1.0 - smoothstep(0.0, 0.35, length(UV - 0.5) - 0.1);
	burned = mix(burned, burned * 0.2, (1.0 - edge) * corrupt * 0.7);

	ALBEDO = burned;
	ROUGHNESS = mix(0.65, 0.92, corrupt);
	METALLIC = 0.0;
	EMISSION = burned * burn * 0.08 * corrupt;  // subtle glow on the worst burns
}
