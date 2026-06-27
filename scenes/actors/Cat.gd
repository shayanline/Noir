class_name Cat
extends BoardObject
## A small alley cat sitting on the ground: a near black ink silhouette with a faint amber eye and
## a tail that sways. The body is authored in the scene; this script only animates the tail. Art is
## in design units, y=0 at the base and up is negative y.

@onready var _tail: Line2D = $Tail

var _t := 0.0


func on_tick() -> void:
	_t += get_process_delta_time()
	_tail.points = _quad(Vector2(-11, -6), Vector2(-20, -10.0 + sin(_t * 2.0) * 3.0), Vector2(-16, -18))


func _quad(p0: Vector2, c: Vector2, p1: Vector2, steps: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / float(steps)
		var iu := 1.0 - u
		pts.append(iu * iu * p0 + 2.0 * iu * u * c + u * u * p1)
	return pts
