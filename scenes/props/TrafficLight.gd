class_name TrafficLight
extends BoardObject
## A street traffic light. The pole, housing and lamp octagons are static in the scene. It shows red
## until the line given by green_at, then switches to green by swapping which lamp is bright. The lit
## lamp is a real coloured PointLight2D (a genuine signal glow), and the bright lamp face feeds the
## post bloom, so the glow is real light, not a painted halo.

const RED_ON := Color(1, 0.165, 0.165, 1.0)
const GREEN_ON := Color(0.212, 0.827, 0.431, 1.0)
const LAMP_DIM := Color(0.275, 0.275, 0.29, 0.5)

@onready var _red_lamp: Polygon2D = $RedLamp
@onready var _red_halo: Polygon2D = $RedHalo
@onready var _green_lamp: Polygon2D = $GreenLamp
@onready var _green_halo: Polygon2D = $GreenHalo

var _green_at := -1
var _is_green := false
var _red_light: PointLight2D
var _green_light: PointLight2D


func on_object_params(p: Dictionary) -> void:
	super(p)
	if p.has("green_at"):
		_green_at = int(p["green_at"])


func _ready() -> void:
	# the flat painted halos are gone; a real coloured light glows from the lit lamp instead
	_red_halo.visible = false
	_green_halo.visible = false
	_red_light = _build_signal(Vector2(0, -190), RED_ON)
	_green_light = _build_signal(Vector2(0, -160), GREEN_ON)
	_green_light.visible = false


func on_line(idx: int) -> void:
	super(idx)
	if not _is_green and _green_at >= 0 and idx >= _green_at:
		_set_green()


func _set_green() -> void:
	_is_green = true
	_red_lamp.color = LAMP_DIM
	_red_light.visible = false
	_green_lamp.color = GREEN_ON
	_green_light.visible = true


## A real coloured pool for the lit signal: small and shadowless, since a signal lamp is a glow in
## the rain, not a key light that throws figures' shadows.
func _build_signal(pos: Vector2, col: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = LightTex.radial()
	l.position = pos
	l.color = col
	l.energy = 1.1
	l.texture_scale = 0.42
	l.blend_mode = Light2D.BLEND_MODE_ADD
	LightKit.ambient(l)
	add_child(l)
	return l
