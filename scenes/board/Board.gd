class_name Board
extends Node2D
## The act host, the native equal of the old NoirPanel. It builds the act as a real scene tree:
## the backdrop, the light fixtures, the cast (each a BoardObject scene), plus the key light, the
## moon and the weather as Godot nodes. Lighting is native (PointLight2D / DirectionalLight2D over
## a global CanvasModulate), so there is no per frame repaint. Main drives it by act and line.

signal shake_requested(amount: float)

const RAIN_SCENE := preload("res://scenes/effects/RainField.tscn")
const LIGHTNING_SCENE := preload("res://scenes/effects/Lightning.tscn")

var act: Act

var size := Vector2(1280, 720)
var unit := 2.0
var ground_y := 576.0
var look := 0.0

var line_index := 0
var _line_start := 0.0

var flags := {}

var _objects: Array[BoardObject] = []
var _key_light: PointLight2D
var _moon_light: PointLight2D
var _rain: RainField
var _lightning: Lightning


func setup(a: Act) -> void:
	act = a


func _ready() -> void:
	size = get_viewport_rect().size
	if size.x < 2.0:
		size = Vector2(1280, 720)
	unit = minf(size.x, size.y) / BoardObject.DESIGN_HEIGHT
	ground_y = act.ground * size.y
	_line_start = _now()
	_build_lighting()
	_build_content()
	_build_weather()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func beat() -> float:
	return maxf(0.0, _now() - _line_start)


# --- build ---------------------------------------------------------------------------------

func _build_lighting() -> void:
	# a broad, dim fill so the cast never falls to pure black, the cool bounce of a rainy night
	var fill := PointLight2D.new()
	fill.texture = LightTex.radial()
	fill.position = Vector2(size.x * 0.5, size.y * 0.42)
	fill.texture_scale = size.x / 256.0 * 4.5
	fill.energy = 0.55
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
	_objects.append(obj)
	return obj


func _build_weather() -> void:
	if act.indoor:
		return
	_rain = RAIN_SCENE.instantiate()
	_rain.blood = act.blood_rain
	_rain.z_index = 60
	add_child(_rain)
	_lightning = LIGHTNING_SCENE.instantiate()
	_lightning.z_index = 70
	add_child(_lightning)


# --- flow ----------------------------------------------------------------------------------

func set_line(idx: int) -> void:
	line_index = idx
	_line_start = _now()
	for o in _objects:
		o.on_line(idx)


func on_fx(event: String) -> void:
	match event:
		"muzzle":
			flags["muzzle"] = true
			shake_requested.emit(6.0)
		"blood":
			flags["blood"] = true
		"lightning":
			if _lightning:
				_lightning.strike()
	for o in _objects:
		o.on_flags_changed()
		o.on_fx(event)
	GameState.fire_fx(event)
