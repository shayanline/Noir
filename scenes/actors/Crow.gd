class_name Crow
extends BoardObject
## A perched crow. The body, the looping wing/tail flap (AnimationPlayer autoplaying "perch") and
## the one-shot fly-off ("fly", which beats faster, lifts the bird away and fades it out) are all
## authored in the scene. This script only triggers the fly-off once the story reaches fly_at.

@onready var _anim: AnimationPlayer = $AnimationPlayer

var _fly_at = null
var _delay := 0.0
var _flew := false


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	_fly_at = null
	if p.has("fly_at"):
		_fly_at = int(p["fly_at"])
	_delay = float(p.get("delay", 0.0))


func on_line(idx: int) -> void:
	super.on_line(idx)
	if _flew or _fly_at == null or idx < int(_fly_at):
		return
	_flew = true
	if _delay > 0.0:
		await get_tree().create_timer(_delay).timeout
	_anim.play("fly")
