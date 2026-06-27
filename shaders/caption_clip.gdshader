shader_type canvas_item;
// A torn paper-cut reveal for narration lines, carried over from Inkfall's captionfx. reveal 0 = hidden,
// 1 = fully shown. The leading edge is a soft, continuously ragged tear (seeded, interpolated between
// teeth so it never reads as hard blocky bands), antialiased in screen space. The sweep runs in one of
// three deterministic directions chosen per line: 0 = left to right, 1 = right to left, 2 = centre out.

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform int variant = 0;
uniform float seed = 1.0;
uniform float depth : hint_range(0.0, 0.2) = 0.05;   // how deep the torn teeth reach, fraction of width
uniform float rows = 11.0;                            // number of teeth down the edge

float hash(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

// a smooth ragged offset along the cut, interpolated between seeded teeth so the edge is a continuous
// torn line rather than stepped bands
float ragged(float t) {
	float y = t * rows;
	float i = floor(y);
	float f = smoothstep(0.0, 1.0, fract(y));
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float jitter = (ragged(UV.y) - 0.5) * depth * 2.0;
	float front = reveal + jitter;
	float shown;
	if (variant == 1) {                       // right to left
		float d = 1.0 - UV.x;
		shown = 1.0 - smoothstep(front - fwidth(d) - 0.0015, front + fwidth(d) + 0.0015, d);
	} else if (variant == 2) {                // centre out
		float d = abs(UV.x - 0.5);
		float f = front * 0.5;
		shown = 1.0 - smoothstep(f - fwidth(d) - 0.0015, f + fwidth(d) + 0.0015, d);
	} else {                                  // left to right
		shown = 1.0 - smoothstep(front - fwidth(UV.x) - 0.0015, front + fwidth(UV.x) + 0.0015, UV.x);
	}
	COLOR = vec4(tex.rgb, tex.a * shown);
}
