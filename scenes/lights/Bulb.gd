class_name Bulb
extends BoardLight
## A bare hanging bulb: a thin wire drops from above to a small glass bulb, with a warm PointLight2D
## at the bulb that lights the room around it.


func _ready() -> void:
	var light := _find_light(self)
	if light == null:
		return
	if light.texture == null:
		light.texture = LightTex.radial()
	# A bare bulb that pools on the table and just reaches the near floor and wall, keeping the rest of
	# the room in noir dark rather than washing the back wall to grey.
	light.energy = 0.85
	light.texture_scale = 1.4
