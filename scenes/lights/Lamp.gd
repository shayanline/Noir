class_name Lamp
extends BoardLight
## A street lamp: a thin pole rises from the ground to a small arm bracket that carries a warm lamp
## head. The fixture is near black ink, authored as child polygons in the scene. A PointLight2D with
## a cone texture casts the real gobo (the warm pool and the figure's shadow), and a faint additive
## cone draws the visible shaft of light in the rainy air. The glass lens is driven bright so the
## bloom catches it.


func _ready() -> void:
	var light := _find_light(self)
	if light:
		# The street lamp projects a real downward cone (the noir gobo), warm tungsten, casting the
		# soft shadow of whoever stands beneath it down through the beam onto the wet floor.
		light.texture = LightTex.cone()
		light.color = Color(1.0, 0.93, 0.78)
		light.energy = 1.9
		light.texture_scale = 1.7
		LightKit.caster(light, LightKit.WARM)
		_build_beam(light.position)
	# Overdrive the glass lens so the bloom pass reads it as a real bright source.
	var glass := get_node_or_null("Glass")
	if glass is Polygon2D:
		(glass as Polygon2D).color = Color(1.5, 1.45, 1.2)


## The visible shaft of light hanging in the rainy air below the lamp: the same cone shape, drawn
## faint and additive so it reads as the glow in the air (the noir gobo you can see), distinct from
## the PointLight2D that actually lights the figure and the floor.
func _build_beam(light_pos: Vector2) -> void:
	var beam := Sprite2D.new()
	beam.name = "Beam"
	beam.texture = LightTex.cone()
	beam.position = light_pos
	beam.scale = Vector2(1.7, 1.7)   # match the cone light's reach
	beam.modulate = Color(1.0, 0.93, 0.78, 0.13)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = m
	beam.z_index = -3   # hangs in the air behind the cast
	add_child(beam)
