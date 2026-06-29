class_name LightKit
extends RefCounted
## Shared setup for the genuine 2D lighting on the board. Drop a PointLight2D into any asset, then
## call one of these so it behaves like every other light in the world: a soft-edged shadow caster,
## a shadowless fill, or a brief flash. New assets (a truck, a torch, a desk lamp, a gunshot) adopt
## the system in one line, with no per-asset shadow tuning to get wrong.
##
##   LightKit.caster(light)                 # cool shadow caster: the key, a street lamp, a neon sign
##   LightKit.caster(light, LightKit.WARM)  # warm shadow caster: fire, a torch, a candle
##   LightKit.ambient(light)                # soft fill, no shadows: the moon, the bounce, an air glow
##   LightKit.flash(board, pos, LightKit.MUZZLE)  # a brief real burst: a muzzle flash, a struck lighter

# Shadow tints: near-black with a faint hue so shadows read coloured, never flat grey.
const COOL := Color(0.01, 0.012, 0.03, 0.9)    ## the default night shadow
const WARM := Color(0.03, 0.016, 0.006, 0.85)  ## firelight / tungsten shadow

# Flash colours for the brief bursts.
const MUZZLE := Color(1.0, 0.93, 0.7)          ## hot white-gold gunshot
const SPARK := Color(1.0, 0.7, 0.3)            ## warm lighter / struck match

const _TEX_RADIUS := 128.0   # half-width of the shared radial light texture, for px -> texture_scale


## Make a light a soft-edged noir shadow caster. smooth widens the PCF blur (larger = softer edge).
static func caster(light: PointLight2D, shadow_color: Color = COOL, smooth: float = 2.5) -> void:
	light.shadow_enabled = true
	light.shadow_color = shadow_color
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	light.shadow_filter_smooth = smooth


## Make a light a soft fill that lights without casting shadows (broad, placeless sources).
static func ambient(light: PointLight2D) -> void:
	light.shadow_enabled = false


## Spawn a brief real burst of light at pos (in parent's local space): a muzzle flash, a struck
## lighter, a spark. A genuine additive PointLight2D that flares then fades and frees itself, so it
## lights the scene and throws a hard momentary shadow. Add it to the board (unscaled) so radius_px
## reads in true screen pixels. Returns the light in case the caller wants to tune it further.
static func flash(parent: Node2D, pos: Vector2, color: Color = MUZZLE, peak: float = 3.2, \
		radius_px: float = 240.0, life: float = 0.16, shadows: bool = true) -> PointLight2D:
	var fl := PointLight2D.new()
	fl.texture = LightTex.radial()
	fl.position = pos
	fl.color = color
	fl.energy = 0.0
	fl.texture_scale = radius_px / _TEX_RADIUS
	fl.blend_mode = Light2D.BLEND_MODE_ADD
	if shadows:
		caster(fl, WARM, 1.5)
	parent.add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "energy", peak, life * 0.2)
	tw.tween_property(fl, "energy", 0.0, life * 0.8)
	tw.tween_callback(fl.queue_free)
	return fl
