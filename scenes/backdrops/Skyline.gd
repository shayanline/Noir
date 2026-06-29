class_name Skyline
extends BoardBackdrop
## A city skyline: a tiled pixel-art city (far, mid and lit near layers) over a wet floor. The sky
## behind is drawn by NightSky, so the city layers carry transparent skies. The story seed offsets
## the tiling so each act's skyline reads a little differently.

var _seed := 0


func on_object_params(p: Dictionary) -> void:
	_seed = int(p.get("seed", 0))


func build(board_size: Vector2, ground_y: float) -> void:
	CitySkyline.build(self, board_size, ground_y, _seed)
	_add_wet_floor(board_size, ground_y)


func _add_wet_floor(vp: Vector2, g: float) -> void:
	var wet := Polygon2D.new()
	wet.polygon = PackedVector2Array([Vector2(0, g), Vector2(vp.x, g), Vector2(vp.x, vp.y), Vector2(0, vp.y)])
	wet.vertex_colors = PackedColorArray([Color8(10, 11, 15), Color8(10, 11, 15), Palette.INK, Palette.INK])
	add_child(wet)
