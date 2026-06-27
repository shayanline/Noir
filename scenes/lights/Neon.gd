class_name Neon
extends BoardLight
## A neon sign: a glowing outline (a rectangle, or a right pointing arrow) with a label, all in the
## neon colour, plus a PointLight2D centred on the sign that casts a sign sized pool. The sign is
## screen anchored, so the object position sits at the sign's top left corner and the art fills the
## local box from (0, 0) to (w, h).

const _FONT := preload("res://fonts/Oswald.ttf")

var _w := 120.0
var _h := 40.0
var _label := ""
var _arrow := false
var _ignite := false


## read the neon shape, text and behaviour params on top of the base light params.
func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	if p.get("w") != null:
		_w = float(p["w"])
	if p.get("h") != null:
		_h = float(p["h"])
	if p.get("label") != null:
		_label = str(p["label"])
	_arrow = p.get("arrow", _arrow) == true
	_ignite = p.get("ignite", _ignite) == true


func _ready() -> void:
	_build_outline()
	_build_label()
	_place_light()


func place() -> void:
	super.place()
	if _ignite and _light:
		var tw := create_tween()
		_light.energy = _base_energy * 0.04
		tw.tween_interval(0.4)
		tw.tween_property(_light, "energy", _base_energy, 0.6)


func _build_outline() -> void:
	var line := Line2D.new()
	line.name = "Outline"
	line.width = 3.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	if _arrow:
		var pw := _h * 0.9
		line.points = PackedVector2Array([
			Vector2(0, 0), Vector2(_w, 0), Vector2(_w + pw, _h / 2.0),
			Vector2(_w, _h), Vector2(0, _h), Vector2(0, 0)])
	else:
		line.points = PackedVector2Array([
			Vector2(0, 0), Vector2(_w, 0), Vector2(_w, _h),
			Vector2(0, _h), Vector2(0, 0)])
	add_child(line)


func _build_label() -> void:
	if _label == "":
		return
	var label := Label.new()
	label.name = "SignLabel"
	label.text = _label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(_w, _h)
	label.position = Vector2(0, 0)
	label.add_theme_font_override("font", _FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", _label_size())
	add_child(label)


func _label_size() -> int:
	if _arrow:
		return maxi(8, int(_h * 0.56))
	var n := maxi(1, _label.length())
	return maxi(8, int(minf(_h * 0.6, (_w - 10.0) / float(n) * 1.7)))


func _place_light() -> void:
	var light := _find_light(self)
	if light == null:
		return
	if light.texture == null:
		light.texture = LightTex.radial()
	var off := (_h * 0.45) if _arrow else 0.0
	light.position = Vector2(_w / 2.0 + off, _h / 2.0)
	light.energy = 1.4
	light.texture_scale = maxf(_w, _h) * 1.8 / 128.0
