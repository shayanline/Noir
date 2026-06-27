class_name Rooftop
extends BoardBackdrop
## A rooftop under a faint sky glow: two seeded skyline layers behind, a couple of antennas with
## sagging wires, and a flat tar roof with a low ledge.

var _seed := 55512


func on_object_params(p: Dictionary) -> void:
	_seed = int(p.get("seed", 55512))


func build(board_size: Vector2, ground_y: float) -> void:
	var vp := board_size
	var g := ground_y

	_grad_rect(0, vp.y * 0.5, vp.x, vp.y * 0.24, Color(0.157, 0.18, 0.235, 0.0), Color(0.275, 0.314, 0.412, 0.35))

	var c0 := {"top": 0.4, "shade": Palette.FAR_INK, "min_w": 40.0, "max_w": 100.0, "min_h": 0.2, "max_h": 0.45, "win": 0.22}
	var c1 := {"top": 0.46, "shade": Color8(6, 7, 11), "min_w": 60.0, "max_w": 140.0, "min_h": 0.16, "max_h": 0.38, "win": 0.18}
	var far := Sprite2D.new()
	far.texture = BackdropBaker.bake_skyline(vp, vp.y * 0.72, _seed, [c0, c1])
	far.centered = false
	add_child(far)

	_pole(vp.x * 0.05, vp.y * 0.18, vp.y * 0.2)
	_pole(vp.x * 0.92, vp.y * 0.12, vp.y * 0.26)
	_wire(vp.x * 0.05, vp.y * 0.22, vp.x * 0.93, vp.y * 0.16, vp.y * 0.3)
	_wire(vp.x * 0.05, vp.y * 0.27, vp.x * 0.93, vp.y * 0.22, vp.y * 0.36)

	_grad_rect(0, g, vp.x, vp.y - g, Palette.INK, Palette.INK)
	_grad_rect(0, g - 10.0, vp.x, 12.0, Color8(8, 9, 12), Color8(8, 9, 12))


func _pole(x: float, y: float, h: float) -> void:
	_grad_rect(x, y, 4.0, h, Color.BLACK, Color.BLACK)


func _wire(x0: float, y0: float, x1: float, y1: float, sag: float) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color.BLACK
	var pts := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var x := lerpf(x0, x1, u)
		var y := lerpf(y0, y1, u) + sin(u * PI) * sag
		pts.append(Vector2(x, y))
	line.points = pts
	add_child(line)


func _grad_rect(x: float, y: float, w: float, h: float, top: Color, bot: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.vertex_colors = PackedColorArray([top, top, bot, bot])
	add_child(poly)
