extends SceneTree
## Dev tool: bakes a tangent-space normal map from the brick albedo so the board's 2D lights carve
## real relief into the alley walls. The height comes from the albedo luminance and the gradient is
## sampled with wraparound, so the result tiles seamlessly like the source. Run headless:
##   Godot --path . --headless --script res://tools/bake_brick_normal.gd
## Not part of the game. Safe to delete once the normal map is baked.

## Source albedo to read, and where the contrast-boosted albedo and the normal map are written.
const SRC := "res://scenes/backdrops/brick_wall_src.png"
const DST_ALBEDO := "res://scenes/backdrops/brick_wall.png"
const DST_NORMAL := "res://scenes/backdrops/brick_wall_n.png"
const STRENGTH := 6.0    ## higher carves deeper relief, so dim glancing light still catches bricks
const MORTAR_DEPTH := 0.45   ## how far the dark mortar is pushed down (lower = punchier bricks)


func _initialize() -> void:
	var img := Image.new()
	if img.load(SRC) != OK:
		push_error("bake_brick_normal: could not load " + SRC)
		quit()
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var height := PackedFloat32Array()
	height.resize(w * h)
	for y in h:
		for x in w:
			height[y * w + x] = img.get_pixel(x, y).get_luminance()

	# Punchy albedo: deepen the dark mortar relative to the brick faces so the pattern survives the
	# heavy noir grade even when the wall is tinted dark. Bricks (high luminance) keep their value.
	var albedo := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var f: float = lerpf(MORTAR_DEPTH, 1.0, smoothstep(0.12, 0.5, height[y * w + x]))
			albedo.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f, c.a))

	# Tangent-space normal from the luminance height, sampled with wraparound so it tiles seamlessly.
	var normal := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var l := height[y * w + (x - 1 + w) % w]
			var r := height[y * w + (x + 1) % w]
			var u := height[((y - 1 + h) % h) * w + x]
			var d := height[((y + 1) % h) * w + x]
			var n := Vector3((l - r) * STRENGTH, (d - u) * STRENGTH, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))

	var ok := albedo.save_png(ProjectSettings.globalize_path(DST_ALBEDO)) == OK
	ok = normal.save_png(ProjectSettings.globalize_path(DST_NORMAL)) == OK and ok
	if ok:
		print("bake_brick_normal: wrote albedo and normal (", w, "x", h, ")")
	else:
		push_error("bake_brick_normal: save failed")
	quit()
