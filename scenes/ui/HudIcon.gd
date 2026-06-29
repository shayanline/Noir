class_name HudIcon
extends Control
## A HUD chip icon drawn in code (so it centres exactly and renders the same everywhere, the way
## Inkfall drew its CSS icons). Three kinds: the hamburger menu, the fullscreen corners and the
## poster frame. The tint follows the parent button's hover state.
## The line draw calls pass antialiased = false, the web Compatibility renderer does not support
## antialiased 2D line drawing, which rendered the glyph lines incorrectly.

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
	# the glyph fills about 0.42 of the chip, scaling with the cell so it never looks lost in it
	var u := minf(size.x, size.y) * 0.42
	var lw := maxf(2.0, u * 0.12)
	match kind:
		Kind.MENU:
			var w := u
			for dy in [-u * 0.32, 0.0, u * 0.32]:
				draw_line(Vector2(c.x - w * 0.5, c.y + dy), Vector2(c.x + w * 0.5, c.y + dy), tint, lw, false)
		Kind.FULLSCREEN:
			var h := u * 0.45
			var ext := u * 0.5
			# top-left and bottom-right corner brackets
			draw_line(Vector2(c.x - ext, c.y - ext), Vector2(c.x - ext + h, c.y - ext), tint, lw, false)
			draw_line(Vector2(c.x - ext, c.y - ext), Vector2(c.x - ext, c.y - ext + h), tint, lw, false)
			draw_line(Vector2(c.x + ext, c.y + ext), Vector2(c.x + ext - h, c.y + ext), tint, lw, false)
			draw_line(Vector2(c.x + ext, c.y + ext), Vector2(c.x + ext, c.y + ext - h), tint, lw, false)
		Kind.POSTER:
			var r := Rect2(c.x - u * 0.5, c.y - u * 0.42, u, u * 0.84)
			draw_polyline(PackedVector2Array([
				r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y), r.position]), tint, lw, false)
