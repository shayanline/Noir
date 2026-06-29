shader_type canvas_item;
render_mode blend_add;
// The visible shaft of light hanging in the rain below a street lamp. Draws the cone shape with
// scrolling simplex noise to simulate backlit rain particles and dust drifting through the beam.
// Additive, so it layers over the scene as a visible atmospheric glow, distinct from the
// PointLight2D that actually lights the surfaces below.
//
// The UV maps the cone texture (same shape as the gobo): UV.y = 0 at the top (lamp), 1 at the
// bottom (floor). The noise scrolls downward to read as falling rain catching the light.

uniform vec4 beam_color : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform float beam_alpha : hint_range(0.0, 0.5) = 0.13;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.4;
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.5;

// Simple value noise (no external texture needed, Compatibility safe).
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Two octaves for a richer look without being expensive.
float fbm(vec2 p) {
	float v = value_noise(p) * 0.6;
	v += value_noise(p * 2.1 + vec2(17.0)) * 0.4;
	return v;
}

void fragment() {
	// The cone texture alpha carries the beam shape (bright centre, dark edges).
	float shape = texture(TEXTURE, UV).a;

	// Scrolling noise: two layers at different speeds and scales for depth.
	vec2 nuv = UV * noise_scale;
	float n = fbm(nuv + vec2(0.0, -TIME * noise_speed));
	float n2 = fbm(nuv * 1.4 + vec2(TIME * noise_speed * 0.3, -TIME * noise_speed * 0.7));
	float noise = mix(n, n2, 0.5);

	// Mix the static shape with the animated noise.
	float intensity = shape * mix(1.0, noise * 1.6, noise_strength);

	// The vertex COLOR carries the flicker modulate from the parent node.
	vec3 col = beam_color.rgb * intensity * beam_alpha * COLOR.rgb;
	COLOR = vec4(col, intensity * beam_alpha * COLOR.a);
}
