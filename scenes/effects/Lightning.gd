class_name Lightning
extends Node2D
## Lightning on the weather layer: a flash and an occasional procedural bolt. The flash and bolt
## nodes are authored in the scene. This script sizes the flash to the board's content area, fires
## by itself now and then, and draws a fresh random bolt on each strike.

@export var self_trigger := true

## The board sets this before the node enters the tree, so effects stay within the letterboxed area.
var area := Vector2(1920, 1080)

@onready var _flash: ColorRect = $Flash
@onready var _bolt: Line2D = $Bolt

var _rng := RandomNumberGenerator.new()
var _next := 5.0


func _ready() -> void:
	_flash.size = area


func _process(delta: float) -> void:
	if not self_trigger:
		return
	_next -= delta
	if _next <= 0.0:
		strike()
		_next = _rng.randf_range(6.0, 14.0)


func strike() -> void:
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.5, 0.05)
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	if _rng.randf() < 0.8:
		_draw_bolt()


func _draw_bolt() -> void:
	var pts := PackedVector2Array()
	var x := area.x * _rng.randf_range(0.2, 0.8)
	var y := 0.0
	var segs := 9 + _rng.randi_range(0, 5)
	for i in segs + 1:
		pts.append(Vector2(x, y))
		x += _rng.randf_range(-35.0, 35.0)
		y += area.y * 0.55 / float(segs)
	_bolt.points = pts
	_bolt.default_color = Color(1, 1, 1, 0.95)
	var tw := create_tween()
	tw.tween_property(_bolt, "default_color:a", 0.0, 0.45)
