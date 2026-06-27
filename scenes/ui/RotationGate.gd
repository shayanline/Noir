class_name RotationGate
extends Control
## On touch devices held in portrait, covers the screen and asks the player to rotate to
## landscape. Auto-hides in landscape. Harmless on desktop (it only shows when taller than wide
## on a touchscreen), so it never gets in the way of mouse play. The layout is authored in the
## scene, this script only decides when the gate is visible.

var _is_touch := false


func _ready() -> void:
	_is_touch = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var s := get_viewport().get_visible_rect().size
	visible = _is_touch and s.y > s.x
