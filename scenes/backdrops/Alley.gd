class_name Alley
extends BoardBackdrop
## A narrow alley: two dark walls converging on a far skyline sliver, a fire escape on the left,
## and the shared wet floor. The far buildings are seeded and baked like the skyline backdrop.

var _seed := 77123


func on_object_params(p: Dictionary) -> void:
	_seed = int(p.get("seed", 77123))


func build(board_size: Vector2, ground_y: float) -> void:
	var vp := board_size
	var g := ground_y
	var vx := vp.x * 0.5
	var vy := vp.y * 0.4

	# the sky sliver between the walls is drawn behind us by NightSky; a distant city shows in the gap
	CitySkyline.build_far(self, vp, vp.y * 0.62, _seed)

	_grad_rect(vx - vp.x * 0.12, vy, vp.x * 0.24, g - vy, Color8(40, 44, 58), Color8(12, 14, 20))

	var wall_top := Color8(16, 10, 6)
	var wall_bot := Color8(5, 3, 2)
	_wall(PackedVector2Array([Vector2(0, 0), Vector2(vp.x * 0.4, 0), Vector2(vx - vp.x * 0.1, vy), Vector2(vx - vp.x * 0.1, g), Vector2(0, g)]), wall_top, wall_bot, g)
	_wall(PackedVector2Array([Vector2(vp.x, 0), Vector2(vp.x * 0.6, 0), Vector2(vx + vp.x * 0.1, vy), Vector2(vx + vp.x * 0.1, g), Vector2(vp.x, g)]), wall_top, wall_bot, g)

	_fire_escape(vp.x * 0.14, vp.y * 0.16, vp.y * 0.5, 64.0)
	_add_wet_floor(vp, g)


func _wall(points: PackedVector2Array, top: Color, bot: Color, g: float) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	var cols := PackedColorArray()
	for pt in points:
		cols.append(top.lerp(bot, clampf(pt.y / g, 0.0, 1.0)))
	poly.vertex_colors = cols
	add_child(poly)


func _grad_rect(x: float, y: float, w: float, h: float, top: Color, bot: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.vertex_colors = PackedColorArray([top, top, bot, bot])
	add_child(poly)


func _fire_escape(x: float, top_y: float, h: float, w: float) -> void:
	var rail := Color(0.47, 0.51, 0.565, 0.75)
	var floors := int(h / 34.0)
	for i in floors:
		var y := top_y + i * 34.0
		_grad_rect(x, y, w, 4.0, rail, rail)
		var r := Line2D.new()
		r.width = 2.0
		r.default_color = rail
		r.points = PackedVector2Array([Vector2(x, y - 14.0), Vector2(x + w, y - 14.0)])
		add_child(r)


func _add_wet_floor(vp: Vector2, g: float) -> void:
	var wet := Polygon2D.new()
	wet.polygon = PackedVector2Array([Vector2(0, g), Vector2(vp.x, g), Vector2(vp.x, vp.y), Vector2(0, vp.y)])
	wet.vertex_colors = PackedColorArray([Color8(10, 11, 15), Color8(10, 11, 15), Palette.INK, Palette.INK])
	add_child(wet)
