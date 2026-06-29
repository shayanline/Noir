class_name RedCar
extends BoardObject
## A low slung noir sedan. The body bleeds deep red while the cabin and tyres stay near black. All
## art lives in the scene and stays mostly static. The base handles placement, the walk path,
## obj_scale, flip and depth. On spawn it lights its own lamps: a real warm headlight pool thrown
## forward onto the wet road and a small red taillight, replacing the old painted glow polygons.


func _ready() -> void:
	# Real car lamps. The bright Headlight / Taillight polygons stay as the visible bulbs (the bloom
	# spreads them); these PointLight2Ds are the actual light they throw on the street. They are
	# children, so they mirror with the car's facing below and stay on the correct ends.
	_add_lamp(Vector2(-78, -26), Color(1.0, 0.92, 0.72), 1.7, 1.1)   # headlight, warm, at the front
	_add_lamp(Vector2(80, -26), Color(1.0, 0.22, 0.13), 1.0, 0.6)    # taillight, red, at the back
	for fake in ["HeadlightGlow", "TaillightGlow"]:
		var g := get_node_or_null(fake)
		if g:
			g.queue_free()


## The art is drawn with the front (grille, headlight) on the left, but the car drives to the right,
## so by default it faces backwards. Flip it to face its driving direction, matching the legacy. An
## explicit flip param still toggles from this corrected base.
func place() -> void:
	super.place()
	scale.x = -scale.x


func _add_lamp(pos: Vector2, col: Color, energy: float, scl: float) -> void:
	var l := PointLight2D.new()
	l.texture = LightTex.radial()
	l.position = pos
	l.color = col
	l.energy = energy
	l.texture_scale = scl
	l.blend_mode = Light2D.BLEND_MODE_ADD
	LightKit.ambient(l)   # the lamps glow and pool on the road; they do not need hard shadows
	add_child(l)
