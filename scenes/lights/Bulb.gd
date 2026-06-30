class_name Bulb
extends BoardLight
## A bare hanging bulb. Rather than a sphere of light floating in the air, it throws a real DROP of
## light: the bright glass reads as the hot source the bloom spreads, and a warm, vertically stretched
## spill falls from it onto the table and floor below, pooling on the surface and thinning as it
## climbs back into the noir dark. Same idea as the neon floor spill, warm and centred under the bulb.

const _SPILL_TEX := preload("res://src/util/soft_glow.tres")

## How far the drop of light reaches below the glass, in design units. Left at 0 it falls to the
## ground line under the bulb. Data driven via the "drop" param.
var _fall := 0.0
var _spill: PointLight2D
var _spill_base := 1.0


func place() -> void:
	super.place()
	if _light == null:
		return
	# The scene light becomes a tight warm halo right at the glass: the hot source the bloom spreads,
	# not the whole room light. It is a shadow caster so the bulb throws a real downward shadow cone
	# and picks up the softness authored in the placement params.
	_light.texture = LightTex.radial()
	_light.texture_scale = 0.55
	_base_energy = 0.6 * intensity
	_light.energy = _base_energy
	LightKit.caster(_light, LightKit.FIRE, softness)
	_build_spill()


## The warm drop of light falling from the bulb: a vertically stretched spill centred below the glass,
## narrow across and tall down, so it reads as a shaft of light pooling on the table and floor rather
## than a disc in the air. Mirrors the neon floor spill, warm and under the bulb.
func _build_spill() -> void:
	if board == null:
		return
	var node_scale := maxf(board.unit * obj_scale, 0.001)
	var fall := _fall if _fall > 0.0 else (board.ground_y - global_position.y) / node_scale
	if fall <= 20.0:
		return
	_spill = PointLight2D.new()
	_spill.texture = _SPILL_TEX
	_spill.color = color
	_spill_base = 1.5 * intensity
	_spill.energy = _spill_base
	# Centre it low, between the glass and the floor, so the brightest part of the shaft lands on the
	# surface below the bulb.
	_spill.position = Vector2(0, fall * 0.6)
	# Tall and narrow: a downward shaft, not a round blob.
	_spill.texture_scale = fall * 2.0 / 64.0
	_spill.scale = Vector2(0.55, 1.0)
	_spill.blend_mode = Light2D.BLEND_MODE_ADD
	_spill.range_item_cull_mask = Board.LAYER_FOREGROUND
	LightKit.ambient(_spill)   # a soft spill, never a shadow caster
	add_child(_spill)


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	if p.get("drop") != null:
		_fall = float(p["drop"])


## Flicker the glass halo and the drop together so the bulb reads as one source.
func on_tick() -> void:
	if not flicker or _light == null:
		return
	_t += get_process_delta_time() * Palette.FLICKER_SPEED
	var f := 0.82 + 0.18 * (sin(_t) * 0.5 + 0.5) + randf() * 0.06
	_light.energy = _base_energy * f
	if _spill:
		_spill.energy = _spill_base * f
