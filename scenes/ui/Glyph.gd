class_name Glyph
extends Control
## A small UI marker drawn in code, so it renders the same on every renderer (the web Compatibility
## build has no system font fallback, so the old Unicode symbols ◆ and ▾ showed up as a red codepoint
## box). Drawn as filled polygons, the way HudIcon draws its chips. Two kinds: the menu diamond and
## the dropdown chevron.

enum Kind { DIAMOND, CHEVRON }

@export var kind: Kind = Kind.DIAMOND
@export var color := Color(0.882, 0, 0.063, 1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(11, 11)


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) * 0.5
	match kind:
		Kind.DIAMOND:
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, c.y - u), Vector2(c.x + u, c.y),
				Vector2(c.x, c.y + u), Vector2(c.x - u, c.y)]), color)
		Kind.CHEVRON:
			# a down pointing triangle, the dropdown affordance
			var w := u * 0.9
			var h := u * 0.6
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - w, c.y - h), Vector2(c.x + w, c.y - h),
				Vector2(c.x, c.y + h)]), color)
