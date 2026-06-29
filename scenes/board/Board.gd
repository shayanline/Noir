class_name Board
extends Node2D
## The act host. It builds the act as a real scene tree:
## the backdrop, the light fixtures, the cast (each a BoardObject scene), plus the key light, the
## moon and the weather as Godot nodes. Lighting is native (PointLight2D / DirectionalLight2D over
## a global CanvasModulate), so there is no per frame repaint. Main drives it by act and line.

signal shake_requested(amount: float)
## fanned out to the spawned objects; each object connects its on_line / on_fx on spawn.
signal line_changed(index: int)
signal fx(event: String)

const RAIN_SCENE := preload("res://scenes/effects/RainField.tscn")
const RIPPLES_SCENE := preload("res://scenes/effects/RainRipples.tscn")
const SHIMMER_SCENE := preload("res://scenes/effects/WetFloorShimmer.gd")
const LIGHTNING_SCENE := preload("res://scenes/effects/Lightning.tscn")

var act: Act

var size := Vector2(1280, 720)
var unit := 2.0
var ground_y := 576.0
var look := 0.0

var line_index := 0

var flags := {}

var _key_light: PointLight2D
var _moon_light: PointLight2D
var _rain: RainField
var _ripples: RainRipples
var _lightning: Lightning


func setup(a: Act) -> void:
	act = a


func _ready() -> void:
	var r := UIScale.content_rect
	size = r.size if r.size.x > 2.0 else get_viewport_rect().size
	if size.x < 2.0:
		size = Vector2(1280, 720)
	position = r.position
	unit = minf(size.x, size.y) / BoardObject.DESIGN_HEIGHT
	ground_y = act.ground * size.y
	GameState.line_changed.connect(_on_state_line)
	GameState.fx_fired.connect(_on_state_fx)
	_build_lighting()
	_build_content()
	_build_weather()


# --- build ---------------------------------------------------------------------------------

func _build_lighting() -> void:
	# a broad, dim fill so the cast never falls to pure black, the cool bounce of a rainy night
	var fill := PointLight2D.new()
	fill.texture = LightTex.radial()
	fill.position = Vector2(size.x * 0.5, size.y * 0.42)
	fill.texture_scale = size.x / 256.0 * 4.5
	# the ambient floor, a gentle lift so the cast reads without turning this into a second key.
	# Kept broad and dim so it reads as bounce, not a second key.
	fill.energy = 0.9
	fill.color = Color(0.66, 0.72, 0.85) if not act.indoor else Color(0.5, 0.52, 0.6)
	add_child(fill)

	_key_light = PointLight2D.new()
	_key_light.texture = LightTex.radial()
	_key_light.position = Vector2(act.key_light.x * size.x, act.key_light.y * size.y)
	_key_light.texture_scale = size.x / 256.0 * 2.6
	_key_light.energy = 1.6
	_key_light.color = Color(1.0, 0.96, 0.86)
	_key_light.shadow_enabled = true
	add_child(_key_light)

	if act.has_moon and not act.indoor:
		_moon_light = PointLight2D.new()
		_moon_light.texture = LightTex.radial()
		_moon_light.position = Vector2(act.moon.x * size.x, act.moon.y * size.y)
		_moon_light.texture_scale = size.x / 256.0 * 3.0
		_moon_light.energy = 1.0
		_moon_light.color = Color(0.82, 0.87, 0.96)
		add_child(_moon_light)


func _build_content() -> void:
	if act.backdrop and act.backdrop.scene:
		_spawn(act.backdrop, -100)
	for p in act.lights:
		_spawn(p, -10)
	for p in act.cast:
		_spawn(p, 0)


func _spawn(p: Placement, base_z: int) -> BoardObject:
	if p == null or p.scene == null:
		return null
	var obj: BoardObject = p.scene.instantiate()
	obj.setup(p.params, self)
	add_child(obj)
	obj.place()
	obj.z_index = base_z + obj.depth
	obj.add_to_group("board_object")
	line_changed.connect(obj.on_line)
	fx.connect(obj.on_fx)
	return obj


## Gather all PointLight2D positions, colours and radii for ripple light sampling.
func _collect_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in get_children():
		if child is PointLight2D:
			var L: PointLight2D = child
			out.append({
				"pos": L.position,
				"col": L.color,
				"radius": L.texture_scale * 256.0,
				"energy": L.energy,
			})
		elif child is BoardLight:
			var bl: BoardLight = child
			if bl._light:
				out.append({
					"pos": bl.global_position + bl._light.position,
					"col": bl._light.color,
					"radius": bl._light.texture_scale * 256.0,
					"energy": bl._light.energy,
				})
	return out


func _build_weather() -> void:
	if act.indoor:
		return
	_rain = RAIN_SCENE.instantiate()
	_rain.blood = act.blood_rain
	_rain.area = size
	_rain.ground_y = ground_y
	_rain.z_index = 60
	add_child(_rain)
	_ripples = RIPPLES_SCENE.instantiate()
	_ripples.blood = act.blood_rain
	_ripples.area = size
	_ripples.ground_y = ground_y
	_ripples.lights = _collect_lights()
	_ripples.z_index = 55
	add_child(_ripples)
	var shimmer := WetFloorShimmer.new()
	shimmer.area = size
	shimmer.ground_y = ground_y
	shimmer.z_index = 50
	add_child(shimmer)
	_lightning = LIGHTNING_SCENE.instantiate()
	_lightning.area = size
	_lightning.z_index = 70
	add_child(_lightning)


# --- flow ----------------------------------------------------------------------------------

func _on_state_line(idx: int) -> void:
	line_index = idx
	line_changed.emit(idx)


func _on_state_fx(event: String) -> void:
	match event:
		"muzzle":
			flags["muzzle"] = true
			shake_requested.emit(6.0)
		"blood":
			flags["blood"] = true
		"lightning":
			if _lightning:
				_lightning.strike()
	fx.emit(event)
