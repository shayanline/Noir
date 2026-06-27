class_name NoirFrame
extends RefCounted
## The per-frame facade handed to every backdrop, light and object, the native equal of Inkfall's
## Frame. It bundles the live timing and sizes, a canvas like drawing API over Godot's _draw (a
## transform stack, alpha, gradients, curves, ellipses), the coordinate and animation helpers, and
## the lighting facade (delegating to NoirLight). Solid draws go to the world canvas, additive glow
## draws are deferred and replayed on the light canvas so the look composites like the original.

var W := 1280.0
var H := 720.0
var unit := 2.0
var t := 0.0
var dt := 0.0
var look := 0.0

var scene = null            # NoirScene
var lights: Array = []      # rebuilt each frame
var glows: Array = []       # deferred additive commands (world space), replayed on the light layer

var _c: CanvasItem = null
var _xform := Transform2D.IDENTITY
var _alpha := 1.0
var _stack: Array = []
var _defer := false
var _font: Font


func _init() -> void:
	_font = load("res://fonts/Oswald.ttf")


# --- live, scene derived values -----------------------------------------------------------

var gy: float:
	get: return float(scene.ground if scene else 0.8) * H

var key_light: Dictionary:
	get: return scene.key_light if scene else {"x": 0.3, "y": 0.3}

var flags: Dictionary:
	get: return scene.flags if scene else {}

var line_idx: int:
	get: return scene.line_idx if scene else 0


func beat() -> float:
	return maxf(0.0, t - scene.line_start) if scene else 0.0


func scene_t() -> float:
	return maxf(0.0, t - scene.scene_start) if scene else 0.0


# --- coordinate + animation helpers -------------------------------------------------------

func x_of(n) -> float:
	var par: float = 0.5 if n.par == null else n.par
	return n.x * W + look * par


func scale_of(n) -> float:
	return unit * (n.scale if n.scale != null else 1.0)


func walk_x(n) -> float:
	if n.walk == null or (n.walk as Array).is_empty():
		return x_of(n)
	var w: Array = n.walk
	var i: int = mini(line_idx, w.size() - 1)
	var prev: float = w[i - 1] if i > 0 else w[0]
	var dur: float = n.walk_dur if n.walk_dur != null else 3.4
	var nx := NoirMath.lerp_f(prev, w[i], NoirMath.smooth01(beat() / dur))
	var par: float = 0.5 if n.par == null else n.par
	return nx * W + look * par


func walk_sound(on: bool) -> void:
	AudioDirector.set_loop("footstep", on)


# --- lighting facade ----------------------------------------------------------------------

func add_light(rec: Dictionary) -> void:
	NoirLight.add_light(self, rec)


func dominant_light(x: float):
	return NoirLight.dominant_light(self, x)


func lit_tint(x: float):
	return NoirLight.lit_tint(self, x)


func lit_color(x: float, base: Color) -> Color:
	return NoirLight.lit_color(self, x, base)


func ground_shadow(x: float, half_w: float, obj_h: float) -> void:
	NoirLight.ground_shadow(self, x, half_w, obj_h)


# --- canvas state -------------------------------------------------------------------------

func begin(canvas: CanvasItem, deferring: bool) -> void:
	_c = canvas
	_xform = Transform2D.IDENTITY
	_alpha = 1.0
	_stack.clear()
	_defer = deferring


func save() -> void:
	_stack.append([_xform, _alpha])


func restore() -> void:
	if _stack.is_empty():
		return
	var s: Array = _stack.pop_back()
	_xform = s[0]
	_alpha = s[1]


func translate(x: float, y: float) -> void:
	_xform = _xform.translated_local(Vector2(x, y))


func rotate(a: float) -> void:
	_xform = _xform.rotated_local(a)


func scale(sx: float, sy: float) -> void:
	_xform = _xform.scaled_local(Vector2(sx, sy))


func set_alpha(a: float) -> void:
	_alpha = a


func _apply() -> void:
	_c.draw_set_transform_matrix(_xform)


func _ca(col: Color) -> Color:
	return Color(col.r, col.g, col.b, col.a * _alpha)


# --- solid drawing (world canvas, current transform) --------------------------------------

func fill_rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	_apply()
	_c.draw_rect(Rect2(x, y, w, h), _ca(col), true)


func stroke_rect(x: float, y: float, w: float, h: float, col: Color, width := 1.0) -> void:
	_apply()
	_c.draw_rect(Rect2(x, y, w, h), _ca(col), false, width)


## a rectangle with a top to bottom 2 stop vertical gradient (draw_polygon interpolates).
func fill_rect_vgrad(x: float, y: float, w: float, h: float, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var cols := PackedColorArray([_ca(top), _ca(top), _ca(bot), _ca(bot)])
	_apply()
	_c.draw_polygon(pts, cols)


## a rectangle with a 3 stop vertical gradient, the middle stop at `mid_off` (0..1).
func fill_rect_vgrad3(x: float, y: float, w: float, h: float, top: Color, mid: Color, bot: Color, mid_off: float) -> void:
	var ym := y + h * mid_off
	fill_rect_vgrad(x, y, w, h * mid_off, top, mid)
	fill_rect_vgrad(x, ym, w, h - h * mid_off, mid, bot)


## a rectangle with a left to right 2 stop horizontal gradient.
func fill_rect_hgrad(x: float, y: float, w: float, h: float, left: Color, right: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var cols := PackedColorArray([_ca(left), _ca(right), _ca(right), _ca(left)])
	_apply()
	_c.draw_polygon(pts, cols)


func fill_poly(points: PackedVector2Array, col: Color) -> void:
	if points.size() < 3:
		return
	_apply()
	_c.draw_colored_polygon(points, _ca(col))


func fill_poly_cols(points: PackedVector2Array, cols: PackedColorArray) -> void:
	if points.size() < 3:
		return
	_apply()
	_c.draw_polygon(points, cols)


## a polygon filled with a linear gradient, sampling each vertex along the p0->p1 axis.
func fill_poly_grad(points: PackedVector2Array, p0: Vector2, p1: Vector2, offsets: PackedFloat32Array, colors: Array) -> void:
	if points.size() < 3:
		return
	var axis := p1 - p0
	var ln := axis.length_squared()
	var cols := PackedColorArray()
	for v in points:
		var u := 0.0 if ln < 0.0001 else clampf((v - p0).dot(axis) / ln, 0.0, 1.0)
		cols.append(_ca(_sample_grad(offsets, colors, u)))
	_apply()
	_c.draw_polygon(points, cols)


func stroke_poly(points: PackedVector2Array, col: Color, width := 1.0, closed := false, round_cap := false) -> void:
	if points.size() < 2:
		return
	var pts := points
	if closed:
		pts = points.duplicate()
		pts.append(points[0])
	_apply()
	_c.draw_polyline(pts, _ca(col), width, true)
	if round_cap:
		var r := width * 0.5
		for p in points:
			_c.draw_circle(p, r, _ca(col))


func line(p0: Vector2, p1: Vector2, col: Color, width := 1.0, round_cap := false) -> void:
	_apply()
	_c.draw_line(p0, p1, _ca(col), width, true)
	if round_cap:
		var r := width * 0.5
		_c.draw_circle(p0, r, _ca(col))
		_c.draw_circle(p1, r, _ca(col))


func circle(cx: float, cy: float, r: float, col: Color) -> void:
	_apply()
	_c.draw_circle(Vector2(cx, cy), r, _ca(col))


func ring(cx: float, cy: float, r: float, col: Color, width := 1.0) -> void:
	_apply()
	_c.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 48, _ca(col), width, true)


## a filled arc. By default it fills the circular segment (chord), like canvas beginPath+arc+fill.
## with_center true makes a pie wedge (canvas moveTo(centre)+arc+fill), used by the roulette.
func arc_fill(cx: float, cy: float, r: float, a0: float, a1: float, col: Color, with_center := false) -> void:
	var pts := PackedVector2Array()
	if with_center:
		pts.append(Vector2(cx, cy))
	var n := maxi(3, int(absf(a1 - a0) / TAU * 48.0))
	for i in range(n + 1):
		var a := NoirMath.lerp_f(a0, a1, float(i) / float(n))
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	fill_poly(pts, col)


func _ellipse_points(cx: float, cy: float, rx: float, ry: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func ellipse_fill(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	fill_poly(_ellipse_points(cx, cy, rx, ry), col)


## a filled elliptical segment from a0 to a1 (canvas ellipse arc + fill).
func ellipse_arc_fill(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := maxi(4, int(absf(a1 - a0) / TAU * 40.0))
	for i in range(n + 1):
		var a := NoirMath.lerp_f(a0, a1, float(i) / float(n))
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	fill_poly(pts, col)


func ellipse_stroke(cx: float, cy: float, rx: float, ry: float, col: Color, width := 1.0) -> void:
	stroke_poly(_ellipse_points(cx, cy, rx, ry), col, width, true)


## an approximate radial gradient fill via a few concentric discs (outer to inner).
func fill_radial(cx: float, cy: float, r: float, inner: Color, outer: Color, steps := 7) -> void:
	for i in steps:
		var u := float(i) / float(steps - 1)
		var rr := r * (1.0 - u)
		if rr <= 0.0:
			continue
		var col := outer.lerp(inner, u)
		circle(cx, cy, rr, col)


func text_center(s: String, cx: float, cy: float, size: int, col: Color) -> void:
	if s == "":
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_apply()
	_c.draw_string(_font, Vector2(cx - w * 0.5, cy + size * 0.34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _ca(col))


# --- additive glow (deferred in the world pass, immediate in the light pass) ---------------

func _scale_len() -> float:
	var sc := _xform.get_scale()
	return (absf(sc.x) + absf(sc.y)) * 0.5


func glow_radial(cx: float, cy: float, r: float, col: Color, a: float) -> void:
	var c := _xform * Vector2(cx, cy)
	var rr := r * _scale_len()
	if _defer:
		glows.append({"k": "radial", "c": c, "r": rr, "col": col, "a": a * _alpha})
	else:
		blit_light(NoirSoft.radial(), c.x - rr, c.y - rr, rr * 2.0, rr * 2.0, col, a * _alpha)


func glow_circle(cx: float, cy: float, r: float, col: Color, a: float) -> void:
	var c := _xform * Vector2(cx, cy)
	var rr := r * _scale_len()
	if _defer:
		glows.append({"k": "circle", "c": c, "r": rr, "col": col, "a": a * _alpha})
	else:
		_c.draw_set_transform_matrix(Transform2D.IDENTITY)
		_c.draw_circle(c, rr, Color(col.r, col.g, col.b, a * _alpha))


func glow_poly(points: PackedVector2Array, col: Color, a: float) -> void:
	var world := PackedVector2Array()
	for p in points:
		world.append(_xform * p)
	if _defer:
		glows.append({"k": "poly", "pts": world, "col": col, "a": a * _alpha})
	else:
		_c.draw_set_transform_matrix(Transform2D.IDENTITY)
		_c.draw_colored_polygon(world, Color(col.r, col.g, col.b, a * _alpha))


func glow_ring(cx: float, cy: float, rx: float, ry: float, col: Color, a: float, width := 1.0) -> void:
	var pts := PackedVector2Array()
	var n := 36
	for i in n + 1:
		var ang := TAU * float(i) / float(n)
		pts.append(_xform * Vector2(cx + cos(ang) * rx, cy + sin(ang) * ry))
	if _defer:
		glows.append({"k": "line", "pts": pts, "col": col, "a": a * _alpha, "w": width})
	else:
		_c.draw_set_transform_matrix(Transform2D.IDENTITY)
		_c.draw_polyline(pts, Color(col.r, col.g, col.b, a * _alpha), width, true)


func replay_glows() -> void:
	_c.draw_set_transform_matrix(Transform2D.IDENTITY)
	for cmd in glows:
		match cmd["k"]:
			"radial":
				var r: float = cmd["r"]
				var c: Vector2 = cmd["c"]
				var col: Color = cmd["col"]
				_c.draw_texture_rect(NoirSoft.radial(), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, Color(col.r, col.g, col.b, cmd["a"]))
			"circle":
				var col2: Color = cmd["col"]
				_c.draw_circle(cmd["c"], cmd["r"], Color(col2.r, col2.g, col2.b, cmd["a"]))
			"poly":
				var col3: Color = cmd["col"]
				_c.draw_colored_polygon(cmd["pts"], Color(col3.r, col3.g, col3.b, cmd["a"]))
			"line":
				var col4: Color = cmd["col"]
				_c.draw_polyline(cmd["pts"], Color(col4.r, col4.g, col4.b, cmd["a"]), cmd["w"], true)


# --- soft sprite blits (used by NoirLight, identity transform, world coords) ---------------

func blit_world(tex: Texture2D, x: float, y: float, w: float, h: float, col: Color, a: float) -> void:
	_c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_c.draw_texture_rect(tex, Rect2(x, y, w, h), false, Color(col.r, col.g, col.b, a))


func blit_light(tex: Texture2D, x: float, y: float, w: float, h: float, col: Color, a: float) -> void:
	_c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_c.draw_texture_rect(tex, Rect2(x, y, w, h), false, Color(col.r, col.g, col.b, a))


# --- helpers ------------------------------------------------------------------------------

static func _sample_grad(offsets: PackedFloat32Array, colors: Array, u: float) -> Color:
	if offsets.is_empty():
		return Color.WHITE
	if u <= offsets[0]:
		return colors[0]
	for i in range(1, offsets.size()):
		if u <= offsets[i]:
			var span := offsets[i] - offsets[i - 1]
			var k := 0.0 if span < 0.0001 else (u - offsets[i - 1]) / span
			return (colors[i - 1] as Color).lerp(colors[i], k)
	return colors[colors.size() - 1]
