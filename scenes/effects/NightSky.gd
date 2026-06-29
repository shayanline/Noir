class_name NightSky
extends Node2D
## The night sky behind the city: a graded sky, faint static stars, a pixel-art full moon ringed by
## a soft glow, and a low band of cloud drifting slowly along the horizon. Kept restrained so it
## stays noir, not busy.
##
## The moon we see lives here. The cool wash it casts on the scene is a separate, weak PointLight2D
## owned by the Board at the same point, so the grade still flows through the native light system.
##
## Brightness note: a CanvasModulate (~0.48) darkens the whole 2D canvas, so the sky is authored
## about twice its target and the moon is lifted a little so it reads as bright without blooming.

var area := Vector2(1920, 1080)
var ground_y := 576.0
var has_moon := true
var show_clouds := false
var moon_px := Vector2(1497.0, 194.0)
var seed_value := 20240

const _STAR_COUNT := 90
const _STAR_COL := Color(0.78, 0.82, 0.9)
const _GLOW_COL := Color(0.72, 0.8, 0.98)

const MOON_TEX := preload("res://art/sky/moon.png")
const CLOUD_TEX := preload("res://art/sky/cloud.png")
const RADIAL := preload("res://src/util/light_radial.tres")

var _stars: Array[Vector2] = []
var _cloud: Sprite2D
var _cloud_speed := 9.0


func _ready() -> void:
	_build_gradient()
	if show_clouds:
		_build_clouds()
	if has_moon:
		_build_moon()
	_seed_stars()
	# stars are drawn by this node, additively at low intensity: visible over the wash, never bloom
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add_mat
	queue_redraw()


func _process(delta: float) -> void:
	if _cloud:
		# scroll the tiled cloud band; the texture repeats so it wraps seamlessly
		_cloud.region_rect.position.x = fmod(_cloud.region_rect.position.x + _cloud_speed * delta, float(CLOUD_TEX.get_width()))


# --- build -------------------------------------------------------------------------------------

## The graded sky: deep indigo at the zenith lifting to a cool blue-grey horizon.
func _build_gradient() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.055, 0.075, 0.15),   # zenith, deep indigo
		Color(0.10, 0.12, 0.20),
		Color(0.20, 0.22, 0.31),     # horizon, lifted blue-grey
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 2
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var sky := Sprite2D.new()
	sky.texture = tex
	sky.centered = false
	sky.scale = Vector2(area.x / 2.0, area.y / 256.0)
	sky.z_index = -2
	add_child(sky)


## The moon: a soft glow behind, then the pixel-art disc on top, lifted so it stays bright.
func _build_moon() -> void:
	var diam := area.y * 0.094
	var glow := Sprite2D.new()
	glow.texture = RADIAL
	glow.position = moon_px
	glow.scale = Vector2(diam * 2.6 / 256.0, diam * 2.6 / 256.0)
	glow.modulate = Color(_GLOW_COL.r, _GLOW_COL.g, _GLOW_COL.b, 0.35)
	glow.material = _additive()
	glow.z_index = 1
	add_child(glow)

	var disc := Sprite2D.new()
	disc.texture = MOON_TEX
	disc.position = moon_px
	disc.scale = Vector2(diam / MOON_TEX.get_width(), diam / MOON_TEX.get_width())
	disc.modulate = Color(1.42, 1.45, 1.5)   # lifted to stay bright under the wash, keeps its blue detail
	disc.z_index = 2
	add_child(disc)


## A low band of cloud along the horizon, tiled across the width and tinted for the noir night.
func _build_clouds() -> void:
	var scl := 1.1
	var ch := CLOUD_TEX.get_height() * scl
	_cloud = Sprite2D.new()
	_cloud.texture = CLOUD_TEX
	_cloud.centered = false
	_cloud.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cloud.region_enabled = true
	# region wider than the board (in texture space) so it tiles fully across, with slack to scroll
	_cloud.region_rect = Rect2(0, 0, area.x / scl + CLOUD_TEX.get_width() * 2.0, CLOUD_TEX.get_height())
	_cloud.scale = Vector2(scl, scl)
	# a soft band in the lower sky; crests drift up toward the moon, base behind the rooflines
	_cloud.position = Vector2(0, ground_y * 0.42)
	_cloud.modulate = Color(0.5, 0.56, 0.72, 0.72)   # cool blue, kept subtle under the wash
	_cloud.z_index = 3
	add_child(_cloud)


## A scatter of faint stars in the upper sky, seeded so they are stable, static like the original.
func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var top_limit := ground_y * 0.9
	for i in _STAR_COUNT:
		var fy := rng.randf()
		fy = fy * fy   # bias toward the top
		_stars.append(Vector2(rng.randf() * area.x, fy * top_limit))


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# --- draw (faint static stars) -----------------------------------------------------------------

func _draw() -> void:
	for p in _stars:
		draw_rect(Rect2(p.x, p.y, 1.6, 1.6), _STAR_COL)
