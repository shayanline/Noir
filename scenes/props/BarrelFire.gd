class_name BarrelFire
extends BoardObject
## An oil drum fire on the noir street. The barrel, the six flames (base-anchored so they scale in
## height), the warm point light and the flicker are all authored in the scene: an AnimationPlayer
## autoplaying "flicker" pulses each flame's scale and the light energy. The fire is a real light
## that casts warm, dancing shadows (the barrel occludes it, so light spills up and out, not down).


func _ready() -> void:
	var fire := get_node_or_null("Fire")
	if fire is PointLight2D:
		LightKit.caster(fire, LightKit.WARM, 3.0)   # warm, soft, dancing firelight shadows
