shader_type canvas_item;
// Gives a flat 2D figure (or prop) a rounded volume so the board's native 2D lights wrap it: the
// side facing a light warms, the far side falls to shadow, the way a body beside a barrel fire
// reads. It writes a synthesized NORMAL (a vertical cylinder bulge across the figure's width, a
// gentle barrel across its height) from the object's own silhouette bounds, so the 2D light pass
// shades it for real. No hand-painted normal map is needed: the form comes from the silhouette
// itself. The albedo (the polygon's own colour) is left untouched, so the ink look holds, only the
// lighting gains direction.
//
// Compatibility-safe: it only writes NORMAL, the same trick wet_floor.gdshader uses, so it runs on
// GLES3 / WebGL2 like the rest of the board.

// The object's bounds in this primitive's own local space (the board sets these per polygon).
uniform vec2 bounds_min = vec2(-1.0, -1.0);
uniform vec2 bounds_max = vec2(1.0, 1.0);
// How round the volume reads: x is the main left-right wrap, y a slight top-to-bottom barrel.
uniform float bulge_x : hint_range(0.0, 2.0) = 1.0;
uniform float bulge_y : hint_range(0.0, 2.0) = 0.3;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec2 c = (bounds_min + bounds_max) * 0.5;
	vec2 h = max((bounds_max - bounds_min) * 0.5, vec2(0.001));
	float nx = clamp((v_local.x - c.x) / h.x, -1.0, 1.0);
	float ny = clamp((v_local.y - c.y) / h.y, -1.0, 1.0);
	// A cylinder facing the viewer: edges tilt outward, the centre faces front. The light pass
	// then lights the side turned toward each source and shades the side turned away.
	NORMAL = normalize(vec3(nx * bulge_x, ny * bulge_y, 1.0));
}
