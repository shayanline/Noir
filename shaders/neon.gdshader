shader_type canvas_item;
render_mode blend_add;
// A glowing neon tube, rendered along a wide Line2D. The line is made much wider than the glass so
// the across-line UV (UV.y) gives the distance from the tube centreline. UV.x gives the along-tube
// position (0 at the first point, 1 at the last), used for end taper, bend brightening, and a
// subtle gas discharge shimmer that travels through the tube. Additive, so it behaves like emitted
// light and does not depend on the screen bloom to glow. The per-frame flicker / modulate rides in
// through the vertex COLOR, so dimming the node dims the whole tube.

uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.1, 1.0);
uniform float core_width : hint_range(0.01, 0.5) = 0.08;   // half-width of the hot glass core, narrow so it reads as a thin bright line
uniform float glow_falloff : hint_range(0.5, 8.0) = 2.8;   // larger = tighter halo; steep so the glow clings to the tube, not a fog
uniform float core_heat : hint_range(0.0, 1.0) = 0.55;     // how much the core whitens (stays hued < 1)
uniform float brightness : hint_range(1.0, 6.0) = 2.8;     // overdrive to survive the CanvasModulate crush, enough to read as glowing glass

// along-tube modulation
uniform bool closed = false;                               // a closed loop (rect, arrow, ...): no end caps to taper
uniform float end_taper : hint_range(0.0, 0.2) = 0.06;      // fraction of tube length that fades at each end
uniform float bend_boost : hint_range(0.0, 0.5) = 0.18;     // extra brightness at bend points (corners)
uniform float shimmer_speed : hint_range(0.0, 4.0) = 0.7;   // speed of the gas discharge crawl
uniform float shimmer_amount : hint_range(0.0, 0.3) = 0.08; // amplitude of the travelling shimmer

// bend positions along UV.x (0..1), set by the script from the outline points. Up to 6 bends, with
// a count so the shader knows how many are valid. Unused slots stay 0.
uniform float bend_count : hint_range(0.0, 6.0) = 0.0;
uniform float bends[6];

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;                          // 0 at the centreline, 1 at the line edge
	float t = UV.x;                                            // 0..1 along the tube

	// end taper: an open tube's two glass caps are dark and fade to zero. A closed loop has no
	// free ends (the seam is a continuous run), so it keeps full brightness all the way round.
	float taper = 1.0;
	if (!closed && end_taper > 0.001) {
		taper = smoothstep(0.0, end_taper, t) * smoothstep(1.0, 1.0 - end_taper, t);
	}

	// bend brightening: gas concentrates where the tube bends, adding a local hot spot
	float bend_bright = 0.0;
	int bc = int(bend_count);
	for (int i = 0; i < 6; i++) {
		if (i >= bc) break;
		float dist_to_bend = abs(t - bends[i]);
		bend_bright += exp(-dist_to_bend * dist_to_bend * 800.0); // tight Gaussian around each bend
	}
	bend_bright = min(bend_bright, 1.0) * bend_boost;

	// gas discharge shimmer: a subtle brightness wave crawling along the tube. A whole number of
	// cycles along the length (3 * TAU) so on a closed loop the wave meets itself at the seam with
	// no step, and the seam stays invisible.
	float shimmer = sin(t * 18.8495559 - TIME * shimmer_speed * 6.28) * 0.5 + 0.5;
	float along_mod = taper * (1.0 + bend_bright + shimmer * shimmer_amount);

	float glow = exp(-d * d * glow_falloff * glow_falloff);   // the coloured glass halo
	float core = smoothstep(core_width, core_width * 0.3, d); // the bright tube itself
	vec3 col = glow_color.rgb * glow;
	col += mix(glow_color.rgb, vec3(1.0), core_heat) * core;  // hotter, slightly whiter core, still hued
	col *= brightness * along_mod;                             // overdrive + along-tube modulation
	col *= COLOR.rgb;                                          // flicker / modulate rides in here
	COLOR = vec4(col, 1.0);                                    // additive: the halo falls to ~0 by the edge
}
