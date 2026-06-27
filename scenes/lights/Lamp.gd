class_name Lamp
extends BoardLight
## A street lamp: a thin pole rises from the ground to a small arm bracket that carries a warm lamp
## head. The fixture is near black ink, authored as child polygons in the scene, and a PointLight2D
## at the head casts the actual warm pool.


func _ready() -> void:
	var light := _find_light(self)
	if light == null:
		return
	if light.texture == null:
		light.texture = LightTex.radial()
	light.energy = 1.3
	light.texture_scale = 1.25
