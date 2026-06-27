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
			ny_units = 0.0 if p[k] == null else float(p[k])
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


## position and scale the object in pixels from its normalized placement.
func place() -> void:
	z_index = depth
	var s := board.unit * obj_scale
	scale = Vector2(-s if flip else s, s)
	position = Vector2(_current_x(), _current_y())
	_refresh_visibility()


func _current_y() -> float:
	if anchor == "screen":
		return abs_y * board.size.y
	return board.ground_y + ny_units * board.unit


func _current_x() -> float:
	return current_nx() * board.size.x + board.look * par


## the live normalized x, walking between targets across lines when a walk path is set.
func current_nx() -> float:
	if walk.is_empty():
		return nx
	var i := mini(board.line_index, walk.size() - 1)
	var prev: float = walk[i - 1] if i > 0 else walk[0]
	var p := smoothstep(0.0, 1.0, board.beat() / walk_dur)
	return lerpf(prev, walk[i], p)


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
	if not walk.is_empty():
		position.x = _current_x()
	on_tick()


## subclasses override for per frame animation (sway, flicker, particles).
func on_tick() -> void:
	pass


## the board calls these as the story advances; subclasses react.
func on_line(_idx: int) -> void:
	_refresh_visibility()


func on_fx(_name: String) -> void:
	pass


func on_flags_changed() -> void:
	_refresh_visibility()
