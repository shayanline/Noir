extends Control
## A drawn phone outline that tips from portrait to landscape on a loop, matching the legacy
## Inkfall rotation hint. The phone is a 58x102 rounded rectangle with a 14px camera circle at
## the bottom, drawn with the foreground colour. The tipping animation runs on a 2.6s ease in
## out loop: upright for the first 22%, tips to landscape (-90 deg) by 55%, holds until 88%,
## then tips back.

const PHONE_W := 58.0
const PHONE_H := 102.0
const BORDER := 4.0
const RADIUS := 12.0
const CAM_R := 7.0
const CAM_Y := 7.0  ## distance from bottom edge to camera centre
const CYCLE := 2.6
const FG := Color("d8d4c8")


func _ready() -> void:
	custom_minimum_size = Vector2(PHONE_W + BORDER * 2, PHONE_H + BORDER * 2)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var t := fmod(Time.get_ticks_msec() / 1000.0, CYCLE) / CYCLE
	var angle := _rotation_angle(t)

	var cx := size.x * 0.5
	var cy := size.y * 0.5

	draw_set_transform(Vector2(cx, cy), angle, Vector2.ONE)

	# phone body (centred on origin)
	var half_w := PHONE_W * 0.5
	var half_h := PHONE_H * 0.5
	var rect := Rect2(-half_w, -half_h, PHONE_W, PHONE_H)
	# draw rounded rect as four arcs plus four lines, or use the draw_rect with no fill plus manual
	# rounded corners. Godot's draw_rect does not support corner radius, so we draw it as a polyline.
	_draw_rounded_rect(rect, RADIUS, BORDER, FG)

	# camera circle at the bottom
	var cam_center := Vector2(0.0, half_h - CAM_Y - CAM_R)
	draw_arc(cam_center, CAM_R, 0, TAU, 32, FG, 2.0, true)

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _rotation_angle(t: float) -> float:
	# Keyframes: 0..0.22 = 0 deg, 0.22..0.55 = ease to -90, 0.55..0.88 = -90, 0.88..1.0 = ease back
	if t <= 0.22:
		return 0.0
	elif t <= 0.55:
		var f := (t - 0.22) / (0.55 - 0.22)
		return lerpf(0.0, -PI * 0.5, _ease_in_out(f))
	elif t <= 0.88:
		return -PI * 0.5
	else:
		var f := (t - 0.88) / (1.0 - 0.88)
		return lerpf(-PI * 0.5, 0.0, _ease_in_out(f))


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _draw_rounded_rect(rect: Rect2, radius: float, width: float, color: Color) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := x0 + rect.size.x
	var y1 := y0 + rect.size.y
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var segs := 8

	# top left arc
	_draw_arc_segment(Vector2(x0 + r, y0 + r), r, PI, PI * 1.5, segs, color, width)
	# top edge
	draw_line(Vector2(x0 + r, y0), Vector2(x1 - r, y0), color, width, true)
	# top right arc
	_draw_arc_segment(Vector2(x1 - r, y0 + r), r, -PI * 0.5, 0, segs, color, width)
	# right edge
	draw_line(Vector2(x1, y0 + r), Vector2(x1, y1 - r), color, width, true)
	# bottom right arc
	_draw_arc_segment(Vector2(x1 - r, y1 - r), r, 0, PI * 0.5, segs, color, width)
	# bottom edge
	draw_line(Vector2(x1 - r, y1), Vector2(x0 + r, y1), color, width, true)
	# bottom left arc
	_draw_arc_segment(Vector2(x0 + r, y1 - r), r, PI * 0.5, PI, segs, color, width)
	# left edge
	draw_line(Vector2(x0, y1 - r), Vector2(x0, y0 + r), color, width, true)


func _draw_arc_segment(center: Vector2, radius: float, start: float, end: float, segments: int, color: Color, width: float) -> void:
	draw_arc(center, radius, start, end, segments, color, width, true)
