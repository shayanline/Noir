class_name BoardLight
extends BoardObject
## A light fixture: drives a native PointLight2D (colour, energy, flicker) from its params. The
## visible fixture (a street lamp, a neon sign, a bare bulb) is built as child nodes in the scene,
## with a PointLight2D placed where the glow should sit.

@export var color := Color(1.0, 0.98, 0.88)
@export var intensity := 1.0
@export var flicker := false

var _light: PointLight2D
var _base_energy := 1.0
var _t := 0.0


func on_object_params(p: Dictionary) -> void:
	if p.get("color") != null:
		color = p["color"]
	if p.get("intensity") != null:
		intensity = float(p["intensity"])
	flicker = p.get("flicker", flicker) == true
	if p.get("y") != null:
		anchor = "screen"
		abs_y = float(p["y"])


func place() -> void:
	super.place()
	_light = _find_light(self)
	if _light:
		_light.color = color
		_base_energy = _light.energy * intensity
		_light.energy = _base_energy


func _find_light(n: Node) -> PointLight2D:
	for c in n.get_children():
		if c is PointLight2D:
			return c
		var deep := _find_light(c)
		if deep:
			return deep
	return null


func on_tick() -> void:
	if _light == null or not flicker:
		return
	_t += get_process_delta_time() * Palette.FLICKER_SPEED
	var f := 0.82 + 0.18 * (sin(_t) * 0.5 + 0.5) + randf() * 0.06
	_light.energy = _base_energy * f
