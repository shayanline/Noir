class_name Alley
extends BoardBackdrop
## A narrow alley: two dark walls converging on a far skyline sliver, a fire escape on the left,
## and the shared wet floor. The far buildings are seeded and baked like the skyline backdrop.

var _seed := 77123

## Stylized brick (Kenney-style CC0 wall) with a baked normal map, so the board's 2D lights carve
## real relief into the walls. Tiled under the existing dark wall tint, it stays inky in shadow and
## only reveals where the key light, the neon and lightning reach. tools/bake_brick_normal.gd bakes
## the normal map from the albedo.
const _BRICK_DIFFUSE := preload("res://scenes/backdrops/brick_wall.png")
const _BRICK_NORMAL := preload("res://scenes/backdrops/brick_wall_n.png")
const _BRICK_PX := 512.0     ## the brick texture is 512x512
const _BRICK_TILE := 200.0   ## base pixels per full texture tile (larger = bigger bricks)
const _BASE_W := 1920.0      ## the project base width; tiling is keyed to it so brick on-screen
                             ## size stays the same on any display (the live board is in real
                             ## framebuffer pixels, which is far larger on a retina screen)

var _brick: CanvasTexture
var _uv_scale := 1.0


func on_object_params(p: Dictionary) -> void:
	_seed = int(p.get("seed", 77123))


## The shared brick CanvasTexture (diffuse plus normal), built once and reused by both walls.
func _brick_tex() -> CanvasTexture:
	if _brick == null:
		_brick = CanvasTexture.new()
		_brick.diffuse_texture = _BRICK_DIFFUSE
		_brick.normal_texture = _BRICK_NORMAL
		_brick.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _brick


func build(board_size: Vector2, ground_y: float) -> void:
	var vp := board_size
	var g := ground_y
	# texture pixels per board pixel, keyed to the base width so a tile covers the same fraction of
	# the wall at any resolution (board pixels grow with the framebuffer, hidpi included).
	_uv_scale = (_BRICK_PX / _BRICK_TILE) * (_BASE_W / maxf(vp.x, 1.0))
	var vx := vp.x * 0.5
	var vy := vp.y * 0.4

	# the sky sliver between the walls is drawn behind us by NightSky; a distant city shows in the gap
	CitySkyline.build_far(self, vp, vp.y * 0.62, _seed)

	_grad_rect(vx - vp.x * 0.12, vy, vp.x * 0.24, g - vy, Color8(40, 44, 58), Color8(12, 14, 20))

	# keep the brick dim and warm so the wall sits in shadow, and the key light, the neon and
	# lightning are what pull the texture out of the dark, the noir reveal the doc comment describes.
	var wall_top := Color8(56, 48, 42)
	var wall_bot := Color8(26, 22, 19)
	_wall(PackedVector2Array([Vector2(0, 0), Vector2(vp.x * 0.4, 0), Vector2(vx - vp.x * 0.1, vy), Vector2(vx - vp.x * 0.1, g), Vector2(0, g)]), wall_top, wall_bot, g)
	_wall(PackedVector2Array([Vector2(vp.x, 0), Vector2(vp.x * 0.6, 0), Vector2(vx + vp.x * 0.1, vy), Vector2(vx + vp.x * 0.1, g), Vector2(vp.x, g)]), wall_top, wall_bot, g)

	_fire_escape(vp.x * 0.14, vp.y * 0.16, vp.y * 0.5, 64.0)
	_add_wet_floor(vp, g)


func _wall(points: PackedVector2Array, top: Color, bot: Color, g: float) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for pt in points:
		cols.append(top.lerp(bot, clampf(pt.y / g, 0.0, 1.0)))
		# Polygon2D uv is in texture pixels, so scale board pixels into texture space to tile.
		uvs.append(pt * _uv_scale)
	poly.vertex_colors = cols
	poly.texture = _brick_tex()
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.uv = uvs
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
