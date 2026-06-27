class_name HudIcon
extends Control
## A HUD chip icon drawn in code (so it centres exactly and renders the same everywhere, the way
## Inkfall drew its CSS icons). Three kinds: the hamburger menu, the fullscreen corners and the
## poster frame. The tint follows the parent button's hover state.

enum Kind { MENU, FULLSCREEN, POSTER }

@export var kind: Kind = Kind.MENU
@export var tint := Color(0.788, 0.769, 0.714, 1)

const _W := 2.0


func _ready() -> void:
	custom_minimum_size = Vector2(18, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_tint(c: Color) -> void:
	tint = c
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	match kind:
		Kind.MENU:
			var w := 16.0
			for dy in [-5.0, 0.0, 5.0]:
				draw_line(Vector2(c.x - w * 0.5, c.y + dy), Vector2(c.x + w * 0.5, c.y + dy), tint, _W)
		Kind.FULLSCREEN:
			var h := 8.0
			var ext := 9.0
			# top-left and bottom-right corner brackets
			draw_line(Vector2(c.x - ext, c.y - ext), Vector2(c.x - ext + h, c.y - ext), tint, _W)
			draw_line(Vector2(c.x - ext, c.y - ext), Vector2(c.x - ext, c.y - ext + h), tint, _W)
			draw_line(Vector2(c.x + ext, c.y + ext), Vector2(c.x + ext - h, c.y + ext), tint, _W)
			draw_line(Vector2(c.x + ext, c.y + ext), Vector2(c.x + ext, c.y + ext - h), tint, _W)
		Kind.POSTER:
			var r := Rect2(c.x - 8.5, c.y - 7.0, 17.0, 14.0)
			draw_rect(r, tint, false, _W)
