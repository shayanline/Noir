shader_type canvas_item;
// Three ink bars sweep from alternating sides (left, right, left) to cover the frame, staggered so
// they cascade like spilled ink hitting the page at slightly different moments. Each bar has a dual
// edge: a faint watercolour haze runs ahead of the solid pigment, and fine directional paper grain
// textures the front so it reads as ink bleeding along real fibres, not a smooth gradient. On the
// reveal (direction = -1) the warp shifts so the opening feels like tearing wet paper apart rather
// than the same soak in reverse. The ink is warm sepia rather than dead black, tying it to the
// parchment world of the captions.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink_color : source_color = vec4(0.039, 0.031, 0.024, 1.0);  // #0a0806 warm sepia
uniform float softness : hint_range(0.002, 0.15) = 0.035;
uniform float bleed : hint_range(0.0, 1.0) = 0.5;
uniform float stagger : hint_range(0.0, 0.15) = 0.06;     // timing offset between bars
uniform float direction : hint_range(-1.0, 1.0) = 1.0;    // 1 = closing (soak in), -1 = opening (tear apart)

// --- noise ---

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * vnoise(p);
		p = p * 2.02 + 3.1;
		a *= 0.5;
	}
	return v;
}

// directional paper grain: stretched horizontally to simulate fibres
float grain(vec2 uv, float seed) {
	vec2 stretched = vec2(uv.x * 1.0, uv.y * 4.0);  // elongate vertically = fibres run horizontal
	return fbm(stretched * 14.0 + seed, 3);
}

// --- per bar ink ---

float bar_ink(vec2 uv, float dir_x, float seed, float bar_progress) {
	if (bar_progress <= 0.0) return 0.0;

	// shift warp seeds on the reveal so open looks different from close
	float reveal_shift = direction < 0.0 ? 40.0 : 0.0;

	// warp the sampling coordinates so the front meanders
	float warp_strength = direction < 0.0 ? 0.42 : 0.32;  // reveal tears harder
	vec2 warp = vec2(
		fbm(uv * 3.0 + seed + 5.0 + reveal_shift, 5),
		fbm(uv * 3.0 + seed + 19.0 + reveal_shift, 5)
	) - 0.5;
	vec2 wuv = uv + warp * warp_strength;

	// horizontal gradient
	float grad = dir_x > 0.0 ? wuv.x : 1.0 - wuv.x;

	// large lobes: the big organic shapes of the ink front
	float lobes = fbm(uv * 2.0 + seed + 1.0 + reveal_shift, 5);

	// fine tendrils: smaller bleeds that race ahead
	float tendrils = fbm(uv * 5.5 + seed + 9.0 + reveal_shift, 4);

	// paper grain: very fine directional texture on the edge
	float g = grain(uv, seed + 30.0 + reveal_shift);

	float field = grad
		- (lobes - 0.5) * bleed
		- (tendrils - 0.5) * 0.12
		- (g - 0.5) * 0.06;

	// sweep threshold across the full field range
	float thr = mix(-0.6, 1.6, bar_progress);

	// dual edge: the haze runs ahead of the solid ink
	float haze_edge = softness * 3.5;
	float haze = 1.0 - smoothstep(thr - haze_edge, thr + softness * 0.5, field);
	float solid = 1.0 - smoothstep(thr - softness, thr + softness, field);

	// blend: the haze is faint (8%), the solid is opaque
	return max(solid, haze * 0.08);
}

// --- vertical masks ---

// smooth mask for a bar's vertical extent, with soft boundaries at overlaps
float bar_mask(float y, float y_start, float y_end) {
	float top = smoothstep(y_start - 0.02, y_start + 0.02, y);
	float bot = smoothstep(y_end + 0.02, y_end - 0.02, y);
	return top * bot;
}

void fragment() {
	vec2 uv = UV;
	float ink = 0.0;

	// at the extremes, skip the noise math entirely: progress 1 = solid ink, progress 0 = clear
	if (progress >= 1.0) {
		ink = 1.0;
	} else if (progress > 0.0) {
		// three bars: the outer two extend past the screen edges (-0.1 and 1.1) so the smoothstep
		// mask is fully opaque at the actual boundary (y = 0 and y = 1). Only interior overlaps fade.

		// 1.25x overshoot: the bars visually complete at progress ~0.8, matching the legacy feel
		// where the wipe reaches full coverage early and the last 20% is dead time (already solid).
		float op = min(progress * 1.25, 1.0);

		// stagger: bar 0 runs slightly ahead, bar 2 slightly behind
		float p0 = clamp(op + stagger, 0.0, 1.0);
		float p1 = op;
		float p2 = clamp(op - stagger, 0.0, 1.0);

		// bar 0: extends above screen so top edge is always fully covered
		float m0 = bar_mask(uv.y, -0.1, 0.42);
		if (m0 > 0.001) {
			ink = max(ink, bar_ink(uv, 1.0, 0.0, p0) * m0);
		}

		// bar 1
		float m1 = bar_mask(uv.y, 0.36, 0.70);
		if (m1 > 0.001) {
			ink = max(ink, bar_ink(uv, -1.0, 7.0, p1) * m1);
		}

		// bar 2: extends below screen so bottom edge is always fully covered
		float m2 = bar_mask(uv.y, 0.64, 1.1);
		if (m2 > 0.001) {
			ink = max(ink, bar_ink(uv, 1.0, 13.0, p2) * m2);
		}

		// overlap pooling: where two bars both contribute, the ink pools slightly denser
		float overlap = min(1.0, m0 * m1 + m1 * m2) * 0.04;
		ink = clamp(ink + overlap * ink, 0.0, 1.0);
	}

	COLOR = vec4(ink_color.rgb, ink_color.a * ink);
}
