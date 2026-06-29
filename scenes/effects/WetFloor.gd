class_name WetFloor
extends Node2D
## The wet asphalt floor as a genuine light receiver. A Sprite2D spanning the floor region runs
## wet_floor.gdshader, which writes a scrolling ripple NORMAL so the real 2D lights (neon, lamps,
## fire) pool and shimmer on it as actual reflections of the sources above. No hand-drawn flecks.

const FLOOR_SHADER := preload("res://shaders/wet_floor.gdshader")
const _TEX_BASE := 4.0   # edge of the tiny white base texture the sprite stretches

var area := Vector2(1920, 1080)
var ground_y := 576.0


func _ready() -> void:
	var floor_h := area.y - ground_y
	if floor_h < 2.0:
		return
	var spr := Sprite2D.new()
	spr.name = "Surface"
	spr.texture = _white_tex()
	spr.centered = false
	spr.position = Vector2(0, ground_y)
	spr.scale = Vector2(area.x / _TEX_BASE, floor_h / _TEX_BASE)
	spr.z_index = -90   # above the backdrop, below the cast; lights reach it regardless of z
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("ripple_normal", _ripple_normal())
	spr.material = mat
	add_child(spr)


## A 4x4 white base the sprite stretches over the whole floor. The shader paints the actual
## asphalt colour, so this only needs to give the sprite a 0..1 UV span to work with.
func _white_tex() -> ImageTexture:
	var img := Image.create(int(_TEX_BASE), int(_TEX_BASE), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## A seamless simplex noise baked to a normal map: the standing-water ripples the floor shader
## scrolls and lights respond to.
func _ripple_normal() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 3.0
	tex.noise = noise
	return tex
