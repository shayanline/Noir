class_name BoardObject
extends Node2D
## Base for everything placed on the board: a backdrop, a light fixture, or a cast member. The
## board instances the object scene, calls setup(params, board), then place() positions it. Art
## lives as real child nodes (Polygon2D, Line2D, Sprite2D, Light2D) authored in design units
## (y = 0 at the object's base, up is negative, x centred on 0). The board scales those units to
## pixels, so a subclass never multiplies by a scale factor the way the old draw code did.

@export var nx := 0.5            ## horizontal placement, 0..1 of the board width
@export var ny_units := 0.0      ## vertical offset from the ground line, in design units
@export var anchor := "ground"   ## "ground" sits on the ground line, "screen" uses abs_y
@export var abs_y := 0.5         ## vertical placement, 0..1 of board height (screen anchor)
@export var par := 0.5           ## parallax factor for the look offset
@export var obj_scale := 1.0     ## extra scale on top of the board unit
@export var depth := 0           ## draw order within the layer (low draws behind)
@export var layer := "mid"       ## "back" draws behind the backdrop, "mid" with the cast
@export var flip := false

@export var on_flag := ""        ## revealed only once this flag is set
@export var hide_on_flag := ""   ## hidden once this flag is set

@export var walk: PackedFloat32Array = PackedFloat32Array()  ## per line target xs
@export var walk_dur := 3.4
@export var pass_x := NAN         ## x at which a footstep loop should stop

var board: Board

const DESIGN_HEIGHT := 360.0

## The shared volume-normal material that lets the board's 2D lights wrap a flat figure (see
## apply_volume_light and shaders/figure_light.gdshader).
const _FIGURE_SHADER := preload("res://shaders/figure_light.gdshader")


## called by the board before the object enters the tree.
func setup(p: Dictionary, b: Board) -> void:
	board = b
	_apply_params(p)


func _apply_params(p: Dictionary) -> void:
	for k in p:
		if k == "x":
			nx = p[k]
		elif k == "y":
			if p[k] != null:
				anchor = "screen"
				abs_y = float(p[k])
		elif k == "scale":
			obj_scale = 1.0 if p[k] == null else float(p[k])
		elif k == "dy":
			ny_units = float(p[k]) if p[k] != null else 0.0
		elif k in self:
			set(k, p[k])
	on_object_params(p)


## subclasses override to read any extra params not covered above.
func on_object_params(_p: Dictionary) -> void:
	pass


var _walk_tween: Tween
var _walk_i := -1


## position and scale the object in pixels from its normalized placement.
func place() -> void:
	z_index = depth
	var s := board.unit * obj_scale
	scale = Vector2(-s if flip else s, s)
	var start_nx: float = walk[0] if not walk.is_empty() else nx
	position = Vector2(_x_for(start_nx), _current_y())
	_refresh_visibility()


## Collect all solid (non-emissive) Polygon2D nodes in the subtree rooted at node, expressed in
## this object's local space. Used by build_occluders() and apply_volume_light(). Emissive polygons
## (max channel > 0.6: flames, lamp glass, neon tube) are skipped so light sources never occlude
## their own glow. LightOccluder2D children are skipped to avoid double-processing on re-entry.
func _collect_solid_polys(node: Node, xform: Transform2D, out: Array) -> void:
	for c in node.get_children():
		if c is LightOccluder2D:
			continue
		if c is Polygon2D:
			var poly := c as Polygon2D
			if poly.polygon.size() >= 3:
				var col := poly.color
				if maxf(maxf(col.r, col.g), col.b) <= 0.6:
					out.append({"poly": poly, "xform": xform * poly.transform})
		_collect_solid_polys(c, xform * (c as Node2D).transform if c is Node2D else xform, out)


## Build real shadow casters from this object's own art. Walks the full subtree of solid Polygon2D
## nodes (recursively, so nested limb groups are covered) and adds a LightOccluder2D matching each,
## so the 2D lights throw genuine shadows shaped like the actual figure. Bright (emissive) polygons
## such as flames, lamp glass and neon are skipped so light sources do not block their own light,
## and the legacy painted "Shadow" ellipse is removed (real cast shadows replace it). Called by
## Board after place(); safe to call once.
func build_occluders() -> void:
	var fake := get_node_or_null("Shadow")
	if fake:
		fake.queue_free()
	var entries: Array = []
	_collect_solid_polys(self, Transform2D.IDENTITY, entries)
	for entry in entries:
		var poly: Polygon2D = entry["poly"]
		var xform: Transform2D = entry["xform"]
		var occ := LightOccluder2D.new()
		var shape := OccluderPolygon2D.new()
		shape.polygon = poly.polygon
		shape.closed = true
		occ.occluder = shape
		occ.transform = xform   # world-relative placement within the object
		add_child(occ)


## Give this object a rounded volume so the board's 2D lights wrap it directionally: the side
## turned toward a source (a barrel fire, a street lamp) warms, the side turned away falls to
## shadow. Walks the full subtree of solid Polygon2D nodes (recursively, matching the occluder
## walk) and assigns the shared volume-normal material, sized to the object's own silhouette
## bounds (so the whole figure reads as one form, not a stack of flat plates). Bright (emissive)
## polygons are skipped, so flames, glass and neon keep their flat glow. Called by Board after
## build_occluders(); safe to call once.
func apply_volume_light() -> void:
	var entries: Array = []
	_collect_solid_polys(self, Transform2D.IDENTITY, entries)
	if entries.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for entry in entries:
		var poly: Polygon2D = entry["poly"]
		var xform: Transform2D = entry["xform"]
		for p in poly.polygon:
			var w: Vector2 = xform * p   # point in this object's local space
			lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
			hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	if hi.x <= lo.x:
		return
	for entry in entries:
		var poly: Polygon2D = entry["poly"]
		var xform: Transform2D = entry["xform"]
		var mat := ShaderMaterial.new()
		mat.shader = _FIGURE_SHADER
		# Express the shared object bounds in this polygon's own local space (via the accumulated
		# transform), so every polygon in the subtree sits correctly in one shared volume.
		var off: Vector2 = xform.origin
		mat.set_shader_parameter("bounds_min", lo - off)
		mat.set_shader_parameter("bounds_max", hi - off)
		poly.material = mat


func _current_y() -> float:
	if anchor == "screen":
		return abs_y * board.size.y
	return board.ground_y + ny_units * board.unit


## pixel x for a normalized x, including the parallax offset.
func _x_for(n: float) -> float:
	return n * board.size.x + board.look * par


func _refresh_visibility() -> void:
	visible = visible_with(board.flags)


func visible_with(flags: Dictionary) -> bool:
	if on_flag != "" and not flags.get(on_flag, false):
		return false
	if hide_on_flag != "" and flags.get(hide_on_flag, false):
		return false
	return true


func _process(_delta: float) -> void:
	if board == null:
		return
	on_tick()


## subclasses override for per frame animation (sway, flicker, particles).
func on_tick() -> void:
	pass


## the board fans these out by signal as the story advances; subclasses override and call super.
## both refresh flag-driven visibility, so a body that appears on the blood flag shows on the fx.
## a cast member with a walk path tweens to its target x for the new line.
func on_line(idx: int) -> void:
	_refresh_visibility()
	if walk.is_empty():
		return
	var i := mini(idx, walk.size() - 1)
	var prev := _walk_i
	_walk_i = i
	# the first placement, or a line with the same target, is not a walk, so no steps and no tween
	if prev < 0 or is_equal_approx(walk[i], walk[prev]):
		return
	if _walk_tween:
		_walk_tween.kill()
	# hold the footstep loop full while the walk plays, then let it fade as the walk arrives
	AudioDirector.set_loop("footstep", true)
	_walk_tween = create_tween()
	_walk_tween.tween_property(self, "position:x", _x_for(walk[i]), walk_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.tween_callback(func(): AudioDirector.set_loop("footstep", false))


func on_fx(_event: String) -> void:
	_refresh_visibility()


## Emit a brief real flash of light at a local point on this object: a muzzle flash, a struck
## lighter, a spark off metal. A genuine PointLight2D burst (see LightKit.flash), not a sprite.
## local_pos is in this object's authored design space (the same coords the art uses). The burst
## is parented to the board so its radius reads in true screen pixels regardless of object scale.
func emit_flash(local_pos: Vector2, color: Color = LightKit.MUZZLE, peak := 3.2, radius_px := 240.0) -> void:
	if board == null:
		return
	LightKit.flash(board, board.to_local(to_global(local_pos)), color, peak, radius_px)


## Sample the object's top silhouette as points in its own design space, so rain can splash where
## it actually lands (a hat, shoulders, a car roof) rather than along a flat box. Walks the solid
## Polygon2D children (the same art the occluders use) and, across evenly spaced columns, takes the
## topmost edge that any polygon presents at that column. Unlike the occluder pass this keeps bright
## parts too, since a cast member's red coat or a car roof is a real surface the rain hits, not a
## light. Returns local design-unit points (empty if the object has no solid polygons).
func top_silhouette_points(samples := 16) -> PackedVector2Array:
	var polys: Array[PackedVector2Array] = []
	var lo_x := INF
	var hi_x := -INF
	for c in get_children():
		if not (c is Polygon2D):
			continue
		var poly := c as Polygon2D
		if poly.polygon.size() < 3:
			continue
		var pts := PackedVector2Array()
		for p in poly.polygon:
			var w: Vector2 = poly.transform * p   # the point in this object's local space
			pts.append(w)
			lo_x = minf(lo_x, w.x)
			hi_x = maxf(hi_x, w.x)
		polys.append(pts)
	var out := PackedVector2Array()
	if polys.is_empty() or hi_x <= lo_x:
		return out
	for i in samples:
		var t := float(i) / float(maxi(samples - 1, 1))
		var x: float = lerp(lo_x, hi_x, t)
		var top_y := INF
		for pts in polys:
			var y := _top_y_at_column(pts, x)
			if y < top_y:
				top_y = y
		if top_y < INF:
			out.append(Vector2(x, top_y))   # up is negative y, so the minimum is the top surface
	return out


## The topmost edge y a closed polygon presents at vertical line x (INF if the column misses it).
func _top_y_at_column(pts: PackedVector2Array, x: float) -> float:
	var n := pts.size()
	var best := INF
	for j in n:
		var a := pts[j]
		var b := pts[(j + 1) % n]
		if x < minf(a.x, b.x) or x > maxf(a.x, b.x):
			continue
		var y: float
		if is_equal_approx(a.x, b.x):
			y = minf(a.y, b.y)
		else:
			y = a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)
		if y < best:
			best = y
	return best
