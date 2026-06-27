class_name BloodDrain
extends BoardObject
## A thin red rivulet that creeps along the ground toward a drain point. The source, streak and tip
## are authored in the scene. An AnimationPlayer "grow" animation drives a normalized progress (0..1)
## once the story reaches drain_at; the progress setter lays the streak along the curved path, which
## is built from the per placement drain params. Appears on the blood flag, handled by the base.

const GROW_DURATION := 5.0

@onready var _streak: Line2D = $Streak
@onready var _tip: Polygon2D = $Tip
@onready var _anim: AnimationPlayer = $AnimationPlayer

@export var progress := 0.0: set = _set_progress

var _drain_at := 0
var _drain_x := 120.0
var _drain_y := 12.0
var _path: PackedVector2Array
var _started := false


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	_drain_at = int(p.get("drain_at", 0))
	_drain_x = float(p.get("drain_x", 120.0))
	_drain_y = float(p.get("drain_y", 12.0))


func _ready() -> void:
	var mid := Vector2(_drain_x, _drain_y) * 0.5 + Vector2(0.0, 14.0)
	_path = _quad(Vector2(0.0, 0.0), mid, Vector2(_drain_x, _drain_y), 40)


func on_line(idx: int) -> void:
	super.on_line(idx)
	if _started or idx < _drain_at:
		return
	_started = true
	_anim.play("grow")


func _set_progress(v: float) -> void:
	progress = v
	if not is_node_ready() or _path.is_empty():
		return
	var count := int(round(v * float(_path.size() - 1)))
	var pts := PackedVector2Array()
	for i in count + 1:
		pts.append(_path[i])
	_streak.points = pts
	if pts.size() > 0:
		_tip.position = pts[pts.size() - 1]
		_tip.visible = v > 0.8


func _quad(p0: Vector2, c: Vector2, p1: Vector2, steps: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / float(steps)
		var iu := 1.0 - u
		pts.append(iu * iu * p0 + 2.0 * iu * u * c + u * u * p1)
	return pts
