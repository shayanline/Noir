class_name Crow
extends BoardObject
## A perched crow that flaps and flies off. The body is authored in the scene; this script animates
## the wing and tail, then lifts the bird away across the frame and fades it out. Art is in design
## units, x centred on 0, with no scale premultiply.

const FLY_DURATION := 4.0

@onready var _art: Node2D = $Art
@onready var _tail: Polygon2D = $Art/Tail
@onready var _wing: Polygon2D = $Art/Wing
@onready var _leg: Polygon2D = $Art/Leg

var _t := 0.0
var _fly := 0.0
var _fly_active := false
var _fly_at = null
var _delay := 0.0


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	_fly_at = null
	if p.has("fly_at"):
		_fly_at = int(p["fly_at"])
	_delay = float(p.get("delay", 0.0))


func on_line(idx: int) -> void:
	super.on_line(idx)
	if _fly_at != null and idx >= int(_fly_at):
		_fly_active = true


func on_tick() -> void:
	var dt := get_process_delta_time()
	_t += dt
	if _fly_active and _delay > 0.0:
		_delay = maxf(0.0, _delay - dt)
	elif _fly_active:
		_fly = clampf(_fly + dt / FLY_DURATION, 0.0, 1.0)
	var flying := _fly > 0.02
	var w := sin(_t * (2.4 if flying else 1.0)) * 0.5 + 0.5
	var wob := sin(_t * 1.6) * 2.2
	_shape(flying, w, wob)
	var vp := get_viewport_rect().size
	_art.position = Vector2(_fly * vp.x * 0.5, -_fly * vp.y * 0.6)
	modulate.a = 1.0 - _fly
	_leg.visible = not flying
	if _fly >= 0.99:
		visible = false


func _shape(flying: bool, w: float, wob: float) -> void:
	var wt := -2.0 - (13.0 if flying else 4.0) * w
	var tl := _quad(Vector2(5, -1), Vector2(11, 1.0 + wob), Vector2(14, 2.0 + wob), 10)
	tl.append(Vector2(5, 2))
	_tail.polygon = tl
	var wg := _quad(Vector2(2, -1), Vector2(8, wt * 0.6), Vector2(13, wt), 10)
	var wg2 := _quad(Vector2(13, wt), Vector2(8, 1), Vector2(3, 1.5), 10)
	for i in range(1, wg2.size()):
		wg.append(wg2[i])
	_wing.polygon = wg


func _quad(p0: Vector2, c: Vector2, p1: Vector2, steps: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / float(steps)
		var iu := 1.0 - u
		pts.append(iu * iu * p0 + 2.0 * iu * u * c + u * u * p1)
	return pts
