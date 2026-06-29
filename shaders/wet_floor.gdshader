shader_type canvas_item;
// Wet asphalt floor. A genuine light receiver: it writes a per-pixel NORMAL from a scrolling
// ripple normal map, so Godot's 2D light pass lights it for real. Neon signs, lamps and fire
// pool and shimmer on it as actual reflections of the lights above, not a painted streak.
//
// The diffuse is dark asphalt that darkens toward the bottom of the screen (distance from the
// light sources at eye level). The ripples scroll slowly so the wet surface reads as alive.
// Compatibility-safe: only texture(), TIME and NORMAL, all supported on GLES3 / WebGL2.

uniform sampler2D ripple_normal : hint_normal, filter_linear, repeat_enable;
uniform vec2 tiling = vec2(3.0, 2.0);      // how many times the ripple map repeats across the floor
uniform float scroll_speed = 0.04;          // slow drift of the wet surface
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec3 asphalt_top : source_color = vec3(0.10, 0.11, 0.135);   // near the ground line
uniform vec3 asphalt_bottom : source_color = vec3(0.04, 0.045, 0.06); // foreground, darker

void fragment() {
	// Dark asphalt base, darkening toward the bottom (UV.y = 1 is the foreground).
	vec3 base = mix(asphalt_top, asphalt_bottom, UV.y);
	COLOR = vec4(base, 1.0);

	// Scroll the ripple map; two layers at different rates so it never reads as a single sheet.
	// The 2D light pass uses this NORMAL, so neon, lamps and fire pool and shimmer on the floor
	// as genuine reflections of the sources above. The bright wet highlights then feed the post
	// bloom and the screen-space mirror, which carry the long vertical reflection streaks.
	vec2 ruv = UV * tiling;
	vec3 n0 = texture(ripple_normal, ruv + vec2(0.0, TIME * scroll_speed)).xyz * 2.0 - 1.0;
	vec3 n1 = texture(ripple_normal, ruv * 1.7 - vec2(TIME * scroll_speed * 0.6, 0.0)).xyz * 2.0 - 1.0;
	NORMAL = normalize(mix(vec3(0.0, 0.0, 1.0), normalize(n0 + n1), ripple_strength));
}
