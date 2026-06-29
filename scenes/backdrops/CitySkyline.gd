class_name CitySkyline
extends RefCounted
## Builds a tiled pixel-art city skyline from the CraftPix "city 1" layers, anchored at the ground
## line. Far layers sit back (dimmer, cooler, a touch smaller), the near layer carries the lit
## windows. The layers have transparent skies, so the NightSky behind shows through above and
## between the buildings.

const FAR := preload("res://art/city/far.png")
const MID := preload("res://art/city/mid.png")
const NEAR := preload("res://art/city/near.png")


## Full city skyline (street level): far, mid and the lit near buildings, scaled up so the towers
## rise high and read as a city around us rather than a distant band.
static func build(parent: Node2D, board_size: Vector2, ground_y: float, seed_value := 0) -> void:
	var scl := (board_size.x / 1.15) / float(FAR.get_width())
	# dim, near-black city silhouettes with sparse window dots, so the neon pops
	_layer(parent, FAR, -3, Color(0.22, 0.24, 0.32), scl * 0.78, -10.0, ground_y, board_size, seed_value)
	_layer(parent, MID, -2, Color(0.30, 0.32, 0.40), scl * 0.9, 6.0, ground_y, board_size, seed_value)
	_layer(parent, NEAR, -1, Color(0.40, 0.42, 0.48), scl, 18.0, ground_y, board_size, seed_value)


## A distant skyline only (rooftop vantage): the far and mid towers, smaller, sitting low.
static func build_distant(parent: Node2D, board_size: Vector2, ground_y: float, seed_value := 0) -> void:
	var scl := (board_size.x / 2.6) / float(FAR.get_width()) * 0.7
	_layer(parent, FAR, -3, Color(0.72, 0.78, 0.96), scl * 0.85, -4.0, ground_y, board_size, seed_value)
	_layer(parent, MID, -2, Color(0.92, 0.96, 1.1), scl, 6.0, ground_y, board_size, seed_value)


## A single far layer (alley sliver), seen only through the gap between the walls.
static func build_far(parent: Node2D, board_size: Vector2, ground_y: float, seed_value := 0) -> void:
	var scl := (board_size.x / 2.4) / float(FAR.get_width()) * 0.8
	_layer(parent, FAR, -3, Color(0.7, 0.76, 0.94), scl, 0.0, ground_y, board_size, seed_value)


static func _layer(parent: Node2D, tex: Texture2D, z: int, mod: Color, scl: float, bleed: float,
		ground_y: float, board_size: Vector2, seed_value: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	var off := float((seed_value * 37 + z * 113) % tex.get_width())   # vary the start so tiles do not always align
	spr.region_rect = Rect2(off, 0, board_size.x / scl + tex.get_width() * 2.0, tex.get_height())
	spr.scale = Vector2(scl, scl)
	var h := tex.get_height() * scl
	# bottom of the strip lands a touch below the ground line, so the bases tuck behind the floor
	spr.position = Vector2(0, ground_y - h + bleed + 8.0)
	spr.modulate = mod
	spr.z_index = z
	parent.add_child(spr)
