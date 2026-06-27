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
uniform vec4 cap_rect = vec4(0.0, 0.0, 1.0, 1.0);    // the panel's UV bounds (x0,y0,x1,y1) within the
                                                      // render target, so the sweep maps to the visible
                                                      // caption, not the whole (mostly empty) viewport

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
	// map to the panel's local 0..1, so the sweep crosses the visible caption over the full duration
	vec2 span = max(cap_rect.zw - cap_rect.xy, vec2(0.0001));
	vec2 lp = (UV - cap_rect.xy) / span;
	// taper the torn teeth to nothing at the ends, so a fully shown (or hidden) line has a clean edge,
	// and push the front a touch past 0 and 1 so the sweep fully clears the panel
	float taper = 4.0 * reveal * (1.0 - reveal);
	float jitter = (ragged(lp.y) - 0.5) * depth * 2.0 * taper;
	float front = reveal * 1.1 - 0.05 + jitter;
	float shown;
	if (variant == 1) {                       // right to left
		float d = 1.0 - lp.x;
		shown = 1.0 - smoothstep(front - fwidth(d) - 0.0015, front + fwidth(d) + 0.0015, d);
	} else if (variant == 2) {                // centre out
		float d = abs(lp.x - 0.5);
		float f = front * 0.5;
		shown = 1.0 - smoothstep(f - fwidth(d) - 0.0015, f + fwidth(d) + 0.0015, d);
	} else {                                  // left to right
		shown = 1.0 - smoothstep(front - fwidth(lp.x) - 0.0015, front + fwidth(lp.x) + 0.0015, lp.x);
	}
	COLOR = vec4(tex.rgb, tex.a * shown);
}
