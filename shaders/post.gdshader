shader_type canvas_item;
// Screen-space comic + noir finish: desaturate/grade, halftone (Ben-Day) dots,
// chromatic aberration, film grain, vignette. Reads the screen via the back buffer,
// so it must sit on a full-rect ColorRect under a BackBufferCopy(copy_mode = Viewport).

// Compatibility-safe: filter_linear (no mipmaps). The Compatibility renderer does not
// guarantee mip generation on the screen texture, so the bloom samples a disc explicitly
// rather than reading mip levels via textureLod.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float time = 0.0;

// bloom (screen-space, explicit disc-sampled glow off the bright pixels: neon, moon, lit windows)
uniform float bloom_intensity : hint_range(0.0, 3.0) = 0.45;
uniform float bloom_threshold : hint_range(0.1, 1.0) = 0.52;
uniform float bloom_radius : hint_range(1.0, 24.0) = 8.0;   // disc radius in px

// wet-floor mirror reflection: below the horizon, the scene above is mirrored down with a watery
// wobble and a depth fade. Set per act (strength 0 indoors). horizon is the ground line in screen uv.
uniform float reflect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float reflect_horizon : hint_range(0.0, 1.0) = 0.8;
uniform float reflect_depth : hint_range(0.05, 1.0) = 0.42;

// grade
uniform float desaturate : hint_range(0.0, 1.0) = 0.82;   // 1 = full grayscale
uniform float contrast : hint_range(0.5, 2.0) = 1.12;
uniform vec3 cool_tint : source_color = vec3(0.86, 0.90, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.10;

// selective colour keep (lets neon reds and the red coat survive the desaturation)
uniform float keep_red : hint_range(0.0, 1.0) = 0.92;

// halftone
uniform float halftone_amount : hint_range(0.0, 1.0) = 0.18;
uniform float halftone_scale : hint_range(1.0, 12.0) = 3.0;   // dot pitch in px

// chromatic aberration
uniform float aberration : hint_range(0.0, 6.0) = 0.45;

// grain
uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;

// vignette
uniform float vignette : hint_range(0.0, 1.0) = 0.7;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Bright-pass: keep only the part of a sample above the bloom threshold, with a soft knee.
// Uses max channel so saturated neon (low luma, high value) still blooms.
vec3 bright_pass(vec3 s) {
	float val = max(max(s.r, s.g), s.b);
	float soft = smoothstep(bloom_threshold - 0.12, bloom_threshold + 0.08, val);
	return s * soft;
}

// Disc-sampled bloom: sum the bright-pass over a golden-angle spiral of taps across a disc
// of bloom_radius pixels, weighted by a Gaussian on the tap distance. Mip-free, so it runs
// on the Compatibility renderer (WebGL2 / GLES3) where screen-texture mipmaps are not
// guaranteed. The glow is genuine, gathered from the actual bright pixels, not a per-object fake.
vec3 bloom_disc(vec2 uv, vec2 px) {
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	const int TAPS = 24;
	const float GA = 2.39996323;   // golden angle, for even spiral coverage
	float sig2 = 2.0 * (bloom_radius * 0.6) * (bloom_radius * 0.6);
	for (int i = 0; i < TAPS; i++) {
		float fi = float(i);
		float r = sqrt((fi + 0.5) / float(TAPS)) * bloom_radius;   // sqrt = even disc fill
		float a = fi * GA;
		vec2 offs = vec2(cos(a), sin(a)) * r * px;
		float w = exp(-r * r / sig2);
		acc += bright_pass(texture(screen_tex, uv + offs).rgb) * w;
		wsum += w;
	}
	return acc / max(wsum, 0.0001);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / screen_size;

	// --- chromatic aberration: offset R/B outward from centre ---
	vec2 dir = uv - vec2(0.5);
	vec2 off = dir * aberration * px;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	// --- wet-floor mirror: below the horizon, blend in the scene above it, mirrored, with a watery
	// wobble that grows with depth and a fade into the dark floor. Reflects signs, cast, moon. ---
	if (reflect_strength > 0.001 && uv.y > reflect_horizon) {
		float depth = uv.y - reflect_horizon;
		float wob = sin(uv.x * 42.0 + time * 1.4) * 0.0016 + sin(uv.y * 90.0 - time * 2.1) * 0.0011;
		vec2 ruv = vec2(uv.x + wob * (0.4 + depth * 4.0), reflect_horizon - depth + wob * 0.6);
		if (ruv.y > 0.0) {
			vec3 refl = texture(screen_tex, ruv).rgb * 0.72;   // wet asphalt darkens the reflection
			float fade = clamp(1.0 - depth / reflect_depth, 0.0, 1.0);
			col = mix(col, refl, fade * fade * reflect_strength);
		}
	}

	// --- bloom: gather the bright-pass over a disc of real screen pixels (mip-free) so saturated
	// neon, the moon and lit windows glow. Added before the grade, so the glow follows the noir
	// colour rules. This is genuine light spread off the bright sources, not a per-object overlay. ---
	col += bloom_disc(uv, px) * bloom_intensity;

	// --- grade: contrast, desaturate with a selective colour keep, cool tint ---
	col = (col - 0.5) * contrast + 0.5;
	float l = luma(col);
	// protect saturated colours (neon reds, yellows, the red coat) from the desaturate: the more
	// saturated a pixel is, the less desaturation it receives. This lets the noir grade crush
	// neutrals to grey while neon colours bleed through vivid.
	float mx = max(max(col.r, col.g), col.b);
	float mn = min(min(col.r, col.g), col.b);
	float sat = (mx > 0.001) ? (mx - mn) / mx : 0.0;
	// only protect colours above a saturation floor (neon, the red coat), let low-sat tones
	// (city windows, sky) desaturate fully into noir grey
	float sat_keep = smoothstep(0.3, 0.7, sat);
	float desat = desaturate * (1.0 - keep_red * sat_keep);
	col = mix(col, vec3(l), desat);
	col = mix(col, col * cool_tint, tint_amount);

	// --- halftone: dot pattern modulating the shadows, like comic print ---
	vec2 grid = SCREEN_UV * screen_size / halftone_scale;
	vec2 cell = fract(grid) - 0.5;
	float dot_d = length(cell);
	float tone = luma(col);
	float dot_r = (1.0 - tone) * 0.5;            // darker areas get bigger dots
	float dotmask = smoothstep(dot_r, dot_r - 0.15, dot_d);
	col = mix(col, col * (0.55 + 0.45 * dotmask), halftone_amount);

	// --- film grain ---
	float g = rand(SCREEN_UV * screen_size + vec2(time * 53.0, time * 11.0));
	col += (g - 0.5) * grain_amount;

	// --- vignette ---
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.75, 0.35, d);
	col *= mix(1.0, v, vignette);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
