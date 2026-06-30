class_name Room
extends BoardBackdrop
## An interior: a dark wall with faint panel seams, a door leaking a warm sliver of light, and a
## dim floor. Used for the underground casino acts.

var _wall := Color("191c26")
var _wall_top := Color("262a37")
var _door := -1.0


func on_object_params(p: Dictionary) -> void:
	if p.get("wall") != null:
		_wall = p["wall"] if p["wall"] is Color else Color(String(p["wall"]))
	if p.get("wall_top") != null:
		_wall_top = p["wall_top"] if p["wall_top"] is Color else Color(String(p["wall_top"]))
	if p.get("door") != null:
		_door = float(p["door"])


func build(board_size: Vector2, ground_y: float) -> void:
	var vp := board_size
	var g := ground_y

	_grad_rect(0, 0, vp.x, g, _wall_top, _wall)

	var seam := Color(1, 1, 1, 0.03)
	var x := 0.0
	while x < vp.x + 60.0:
		var s := Line2D.new()
		s.width = 1.0
		s.default_color = seam
		s.points = PackedVector2Array([Vector2(x, 0), Vector2(x, g)])
		add_child(s)
		x += 60.0

	if _door >= 0.0:
		_build_door(vp, g)

	_grad_rect(0, g, vp.x, vp.y - g, Color8(8, 10, 14), Palette.INK)
	_grad_rect(0, g - 6.0, vp.x, 6.0, Palette.FAR_INK, Palette.FAR_INK)


func _build_door(vp: Vector2, g: float) -> void:
	var dx := _door * vp.x
	var dw := 64.0 * (board.unit / 1.2)
	var dh := g * 0.40
	var dtop := g - dh
	var gap := 11.0 * (board.unit / 1.2)
	var warm := Color(1.0, 0.918, 0.745, 0.55)

	_grad_rect(dx - dw / 2.0 - 5.0, dtop - 5.0, dw + 10.0, dh + 5.0, Color8(10, 12, 16), Color8(10, 12, 16))
	_grad_rect_h(dx + dw / 2.0 - gap, dtop, gap, dh, Color(1.0, 0.918, 0.745, 0.0), warm)
	_grad_rect(dx - dw / 2.0, dtop, dw - gap, dh, Color8(16, 19, 25), Color8(16, 19, 25))

	var spill := Polygon2D.new()
	spill.polygon = PackedVector2Array([Vector2(dx + dw / 2.0 - gap, g), Vector2(dx + dw / 2.0 + 26.0, g + 52.0), Vector2(dx - 8.0, g + 52.0)])
	spill.color = Color(1.0, 0.918, 0.745, 0.10)
	add_child(spill)

	# A real warm light leaking through the gap: it pools on the floor and throws a long shadow of
	# anyone standing in the doorway back into the room. The genuine indoor companion to the street key.
	var door_light := PointLight2D.new()
	door_light.texture = LightTex.radial()
	door_light.position = Vector2(dx + dw / 2.0 - gap * 0.5, dtop + dh * 0.55)
	door_light.color = Color(1.0, 0.86, 0.62)
	door_light.energy = 1.25
	door_light.texture_scale = dh / 128.0 * 1.7
	door_light.blend_mode = Light2D.BLEND_MODE_ADD
	LightKit.caster(door_light, LightKit.WARM, 2.0)
	add_child(door_light)


func _grad_rect(x: float, y: float, w: float, h: float, top: Color, bot: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.vertex_colors = PackedColorArray([top, top, bot, bot])
	add_child(poly)


func _grad_rect_h(x: float, y: float, w: float, h: float, left: Color, right: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.vertex_colors = PackedColorArray([left, right, right, left])
	add_child(poly)
