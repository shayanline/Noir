shader_type canvas_item;
render_mode blend_add;
// A glowing neon tube, rendered along a wide Line2D. The line is made much wider than the glass so
// the across-line UV (UV.y) gives the distance from the tube centreline. From that one value we draw,
// in a single pass, a hot glass core bleeding into an exponential coloured halo, the way real neon
// reads: a bright (slightly whitened) centre wrapped in saturated colour. Additive, so it behaves
// like emitted light and does not depend on the screen bloom to glow. The per-frame flicker /
// modulate rides in through the vertex COLOR, so dimming the node dims the whole tube.

uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.1, 1.0);
uniform float core_width : hint_range(0.01, 0.5) = 0.12;   // half-width of the hot glass core (0..0.5)
uniform float glow_falloff : hint_range(0.5, 6.0) = 1.6;   // larger = tighter halo
uniform float core_heat : hint_range(0.0, 1.0) = 0.45;     // how much the core whitens (stays hued < 1)
uniform float brightness : hint_range(1.0, 6.0) = 3.2;     // overdrive to survive the CanvasModulate crush

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;                          // 0 at the centreline, 1 at the line edge
	float glow = exp(-d * d * glow_falloff * glow_falloff);   // the coloured glass halo
	float core = smoothstep(core_width, core_width * 0.3, d); // the bright tube itself
	vec3 col = glow_color.rgb * glow;
	col += mix(glow_color.rgb, vec3(1.0), core_heat) * core;  // hotter, slightly whiter core, still hued
	col *= brightness;                                         // overdrive so it reads through the dark wash
	col *= COLOR.rgb;                                          // flicker / modulate rides in here
	COLOR = vec4(col, 1.0);                                    // additive: the halo falls to ~0 by the edge
}
