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


## Build real shadow casters from this object's own art. Walks the solid Polygon2D children and
## adds a LightOccluder2D matching each, so the 2D lights throw genuine shadows shaped like the
## actual figure. Bright (emissive) polygons such as flames, lamp glass and neon are skipped so
## light sources do not block their own light, and the legacy painted "Shadow" ellipse is removed
## (real cast shadows replace it). Called by Board after place(); safe to call once.
func build_occluders() -> void:
	var fake := get_node_or_null("Shadow")
	if fake:
		fake.queue_free()
	for c in get_children():
		if not (c is Polygon2D):
			continue
		var poly := c as Polygon2D
		if poly.polygon.size() < 3:
			continue
		# Skip emissive shapes: anything drawn bright is a light source, not an occluder.
		var col := poly.color
		if maxf(maxf(col.r, col.g), col.b) > 0.6:
			continue
		var occ := LightOccluder2D.new()
		var shape := OccluderPolygon2D.new()
		shape.polygon = poly.polygon
		shape.closed = true
		occ.occluder = shape
		occ.transform = poly.transform   # match the polygon's own placement within the object
		add_child(occ)


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
