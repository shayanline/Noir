class_name BoardLight
extends BoardObject
## A light fixture: drives a native PointLight2D (colour, energy, flicker) from its params. The
## visible fixture (a street lamp, a neon sign, a bare bulb) is built as child nodes in the scene,
## with a PointLight2D placed where the glow should sit.

@export var color := Color(1.0, 0.98, 0.88)
@export var intensity := 1.0
@export var flicker := false
## Shadow softness for this fixture's PointLight2D shadow_filter_smooth. A tighter value (1.0)
## gives the hard, near-source shadow a neon tube or barrel fire would cast; a wider value (3.0)
## gives the soft far-source penumbra of a distant lamp. Subclasses that call LightKit.caster()
## directly (Lamp) read _softness themselves; this base value is used by any fixture that does not.
@export var softness := 2.5

var _light: PointLight2D
var _base_energy := 1.0
var _t := 0.0


func on_object_params(p: Dictionary) -> void:
	if p.get("color") != null:
		color = p["color"]
	if p.get("intensity") != null:
		intensity = float(p["intensity"])
	flicker = p.get("flicker", flicker) == true
	if p.get("softness") != null:
		softness = float(p["softness"])
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


## Return this fixture's light contributions for the ripple and rain colour sampling. Each entry
## has pos (global), col, radius, and energy. Subclasses with multiple lights (Neon) override this.
func get_light_contributions() -> Array[Dictionary]:
	if _light == null:
		return []
	return [{
		"pos": global_position + _light.position,
		"col": _light.color,
		"radius": _light.texture_scale * 128.0,
		"energy": _light.energy,
	}]


func on_tick() -> void:
	if _light == null or not flicker:
		return
	_t += get_process_delta_time() * Palette.FLICKER_SPEED
	var f := 0.82 + 0.18 * (sin(_t) * 0.5 + 0.5) + randf() * 0.06
	_light.energy = _base_energy * f
