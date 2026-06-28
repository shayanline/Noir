class_name RainField
extends Node2D
## Native rain: a GPUParticles2D of falling streaks, authored in the scene with a shared process
## material. This script tints it (grey for a normal night, red for blood rain) and sizes the
## emission band, count and position to the board's content area.

@export var blood := false

## The board sets this before the node enters the tree, so effects stay within the letterboxed area.
var area := Vector2(1920, 1080)

@onready var _p: GPUParticles2D = $Rain


func _ready() -> void:
	_p.amount = int((area.x * area.y) / 2600.0)
	_p.position = Vector2(area.x * 0.5, -30.0)
	_p.modulate = Color(0.66, 0.03, 0.06, 0.7) if blood else Color(0.72, 0.76, 0.84, 0.5)
	var mat: ParticleProcessMaterial = _p.process_material.duplicate()
	mat.emission_box_extents = Vector3(area.x * 0.75, 6.0, 1.0)
	_p.process_material = mat
