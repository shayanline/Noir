extends Control
## A drawn phone outline that tips from portrait to landscape on a loop, matching the legacy
## Inkfall rotation hint. The phone is a 58x102 rounded rectangle with a camera notch at the
## bottom, drawn with the foreground colour. The tipping animation runs on a 2.6s ease in out
## loop: upright for the first 22%, tips to landscape (-90 deg) by 55%, holds until 88%, then
## tips back.
##
## The phone is drawn as a single continuous polyline (one packed path) rather than separate
## draw_line and draw_arc calls, because the web export's WebGL backend can drop individual
## thin line segments.

const PHONE_W := 58.0
const PHONE_H := 102.0
const BORDER := 3.0
const RADIUS := 12.0
const CAM_R := 5.0
const CAM_CY := 10.0  ## distance from bottom edge to camera centre
const CYCLE := 2.6
const FG := Color("d8d4c8")
const ARC_SEGS := 12


func _ready() -> void:
	# The minimum size must be large enough so the rotated phone (at -90 deg, the width and height
	# swap) is never clipped. Use the diagonal as a safe bound.
	var diag := Vector2(PHONE_W, PHONE_H).length()
	custom_minimum_size = Vector2(diag, diag)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var t := fmod(Time.get_ticks_msec() / 1000.0, CYCLE) / CYCLE
	var angle := _rotation_angle(t)

	var cx := size.x * 0.5
	var cy := size.y * 0.5
	# scale the fixed 58x102 phone up to fill the control, so it tracks the responsive icon size
	# (the rotated phone spans its diagonal, so fit that within the smaller side)
	var s := minf(size.x, size.y) / Vector2(PHONE_W, PHONE_H).length()

	# Build the phone outline as a single polyline, then scale and rotate it.
	var pts := _rounded_rect_points(-PHONE_W * 0.5, -PHONE_H * 0.5, PHONE_W, PHONE_H, RADIUS)

	# Scale around the origin, rotate, then translate to centre.
	var xf := Transform2D(angle, Vector2(cx, cy))
	var rotated: PackedVector2Array = []
	rotated.resize(pts.size())
	for i in pts.size():
		rotated[i] = xf * (pts[i] * s)

	draw_polyline(rotated, FG, BORDER * s, true)

	# Camera circle at the bottom of the phone (before rotation: below centre).
	var cam_local := Vector2(0.0, PHONE_H * 0.5 - CAM_CY) * s
	var cam_world := xf * cam_local
	_draw_circle_outline(cam_world, CAM_R * s, FG, 2.0 * s)


func _rotation_angle(t: float) -> float:
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


## Build a closed rounded rectangle as a packed point array. The path starts at the top edge
## (after the top left arc) and walks clockwise back to the same point.
func _rounded_rect_points(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	var pts: PackedVector2Array = []
	# top left arc (from 180 to 270 deg, i.e. PI to PI*1.5)
	_arc_points(pts, Vector2(x + r, y + r), r, PI, PI * 1.5)
	# top right arc (from 270 to 360 deg, i.e. -PI*0.5 to 0)
	_arc_points(pts, Vector2(x + w - r, y + r), r, -PI * 0.5, 0.0)
	# bottom right arc (from 0 to 90 deg)
	_arc_points(pts, Vector2(x + w - r, y + h - r), r, 0.0, PI * 0.5)
	# bottom left arc (from 90 to 180 deg)
	_arc_points(pts, Vector2(x + r, y + h - r), r, PI * 0.5, PI)
	# close the path
	pts.append(pts[0])
	return pts


func _arc_points(pts: PackedVector2Array, center: Vector2, radius: float, start: float, end: float) -> void:
	for i in range(ARC_SEGS + 1):
		var a := lerpf(start, end, float(i) / float(ARC_SEGS))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)


## Draw a circle outline as a polyline (avoids draw_arc which can vanish on web).
func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts: PackedVector2Array = []
	var segs := 24
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)
