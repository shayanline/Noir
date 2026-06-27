class_name NoirPath
extends RefCounted
## A tiny canvas style path builder so ported draw code can read like the originals
## (move_to / line_to / quad_to), tessellating quadratic curves into points to fill or stroke.

var pts := PackedVector2Array()


func move_to(x: float, y: float) -> NoirPath:
	pts.append(Vector2(x, y))
	return self


func line_to(x: float, y: float) -> NoirPath:
	pts.append(Vector2(x, y))
	return self


func quad_to(cx: float, cy: float, x: float, y: float, segments := 8) -> NoirPath:
	var p0: Vector2 = pts[pts.size() - 1] if pts.size() > 0 else Vector2(x, y)
	pts.append_array(NoirMath.quad_points(p0, Vector2(cx, cy), Vector2(x, y), segments))
	return self


func points() -> PackedVector2Array:
	return pts
