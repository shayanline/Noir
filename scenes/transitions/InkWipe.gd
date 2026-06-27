class_name InkWipe
extends Control
## The exact Inkfall scene-transition wipe, drawn rather than shaded. Three torn-edged black bars
## slide in from alternating sides (left, right, left) and meet to cover the frame. progress 0 is
## clear, 1 is fully inked. Carried over 1:1 from Inkfall's panelWipe (render/passes/transition.js),
## including the mulberry32 seeded ink blobs and the faint white seam at each leading edge.

# each bar is (y, height) as a fraction of the screen height, overlapping so there are no gaps
const _BARS: Array[Vector2] = [Vector2(0.0, 0.40), Vector2(0.38, 0.30), Vector2(0.66, 0.40)]
const _BLOBS := 10
const _INK := Color(0, 0, 0, 1)
const _SEAM := Color(1, 1, 1, 0.06)

var progress := 0.0: set = set_progress


func set_progress(v: float) -> void:
	progress = v
	queue_redraw()


func _draw() -> void:
	if progress <= 0.0:
		return
	var w := size.x
	var h := size.y
	var bw := w * minf(1.0, progress * 1.25)
	for i in _BARS.size():
		var by := _BARS[i].x * h
		var bh := _BARS[i].y * h
		var from_left := i % 2 == 0
		var bx := 0.0 if from_left else w - bw
		draw_rect(Rect2(bx, by, bw, bh), _INK)
		if bw > 2.0 and bw < w:
			# torn leading edge: ten seeded ink blobs plus a faint white seam line
			var edge := bw if from_left else w - bw
			var rng := {"a": (i * 99 + int(progress * 40.0)) & 0xFFFFFFFF}
			for k in _BLOBS:
				var yy := by + _rand(rng) * bh
				var rr := 2.0 + _rand(rng) * 9.0
				draw_circle(Vector2(edge + (-rr if from_left else rr), yy), rr, _INK)
			draw_line(Vector2(edge, by), Vector2(edge, by + bh), _SEAM, 2.0, true)


# mulberry32, matching Inkfall's rand32 so the torn edge reads identically. The state dictionary is
# mutated in place across calls (one call advances the generator and returns a 0..1 float).
func _rand(s: Dictionary) -> float:
	s.a = (s.a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _imul(s.a ^ (s.a >> 15), (1 | s.a) & 0xFFFFFFFF)
	var u := (t + _imul(t ^ (t >> 7), (61 | t) & 0xFFFFFFFF)) & 0xFFFFFFFF
	u = (u ^ t) & 0xFFFFFFFF
	return float((u ^ (u >> 14)) & 0xFFFFFFFF) / 4294967296.0


# 32-bit integer multiply (the low 32 bits are correct even when the 64-bit product wraps)
func _imul(x: int, y: int) -> int:
	return (x * y) & 0xFFFFFFFF
