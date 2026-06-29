class_name PosterCanvas
extends Control
## Draws a shareable Inkfall poster, a faithful port of the legacy HTML makePoster. The captured
## scene sits in an inked white border with red ink splatter corners, under the skewed INKFALL
## wordmark, over the narration tagline, with a faint halftone wash on top.
##
## The poster is a fixed 900px wide, and the frame height follows the captured scene's aspect, so the
## whole scene shows undistorted and the layout never overflows, exactly as the original did.

const PW := 900       ## poster width (fixed, so the saved image is a consistent shape)
const MARGIN := 56    ## inset of the scene frame from the poster edge
const FY := 150       ## top of the scene frame (the wordmark sits above it)
const FOOT_GAP := 120 ## space kept below the frame for the tagline

const _INK := Color(0.882, 0, 0.063)        ## the red that bleeds
const _BONE := Color(0.847, 0.831, 0.784)   ## tagline
const _TITLE_PX := 88
const _TAG_PX := 24

var scene_tex: Texture2D
var tagline := ""

var _title_font: Font = preload("res://fonts/Oswald.ttf")
var _body_font: Font = preload("res://fonts/SpecialElite.ttf")
var _halftone: Texture2D


## The full poster size for the current scene, so the SubViewport can be sized before drawing.
func poster_size() -> Vector2i:
	return Vector2i(PW, FY + _frame_height() + FOOT_GAP)


func _frame_height() -> int:
	var s := scene_tex.get_size()
	return int(round((PW - MARGIN * 2) * float(s.y) / maxf(s.x, 1.0)))


func _draw() -> void:
	var fw := PW - MARGIN * 2
	var fh := _frame_height()
	var ph := FY + fh + FOOT_GAP

	draw_rect(Rect2(0, 0, PW, ph), Color.BLACK)
	# the captured scene, fit to the frame (the frame matches its aspect, so nothing is cropped)
	draw_texture_rect(scene_tex, Rect2(MARGIN, FY, fw, fh), false)
	# inked white border
	draw_rect(Rect2(MARGIN, FY, fw, fh), Color.WHITE, false, 5.0)
	_draw_splatter(fw, fh)
	_draw_title()
	_draw_tagline(fw, fh)
	# a faint halftone wash over the whole poster
	if _halftone == null:
		_halftone = _build_halftone()
	draw_texture_rect(_halftone, Rect2(0, 0, PW, ph), true, Color(1, 1, 1, 0.06))


## Nine red flecks scattered around each corner of the frame. The seed is the corner index alone, so
## the splatter is a fixed pattern on every poster (a deterministic decoration, matching the legacy).
func _draw_splatter(fw: int, fh: int) -> void:
	var corners := [
		Vector2(MARGIN, FY), Vector2(MARGIN + fw, FY),
		Vector2(MARGIN, FY + fh), Vector2(MARGIN + fw, FY + fh),
	]
	var rng := RandomNumberGenerator.new()
	for ci in corners.size():
		rng.seed = ci * 71 + 5
		for _k in 9:
			var a := rng.randf() * TAU
			var d := rng.randf() * 34.0
			var r := 1.0 + rng.randf() * 6.0
			draw_circle(corners[ci] + Vector2(cos(a), sin(a)) * d, r, _INK)


## INKFALL, white then red, skewed like the legacy canvas title.
func _draw_title() -> void:
	var ink_w := _title_font.get_string_size("INK", HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_PX).x
	var fall_w := _title_font.get_string_size("FALL", HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_PX).x
	var base_y := _title_font.get_ascent(_TITLE_PX) * 0.5
	var start_x := -(ink_w + fall_w) * 0.5
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.13, 1), Vector2(PW * 0.5, 92)))
	draw_string(_title_font, Vector2(start_x, base_y), "INK", HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_PX, Color.WHITE)
	draw_string(_title_font, Vector2(start_x + ink_w, base_y), "FALL", HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_PX, _INK)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The narration line under the frame, word wrapped to the frame width.
func _draw_tagline(fw: int, fh: int) -> void:
	if tagline == "":
		return
	var max_w := fw - 40.0
	var line := ""
	var y := FY + fh + 56
	for word in tagline.split(" ", false):
		var trial := (line + " " + word).strip_edges() if line != "" else word
		if _body_font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, _TAG_PX).x > max_w and line != "":
			draw_string(_body_font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, PW, _TAG_PX, _BONE)
			y += 34
			line = word
		else:
			line = trial
	if line != "":
		draw_string(_body_font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, PW, _TAG_PX, _BONE)


## An 8 by 8 grid of small dots, tiled across the poster for the printed halftone feel.
func _build_halftone() -> Texture2D:
	var tile := 6
	var size := tile * 8
	var rad := tile * 0.32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cy in 8:
		for cx in 8:
			var c := Vector2(cx * tile + tile * 0.5, cy * tile + tile * 0.5)
			for yy in range(int(c.y - rad - 1), int(c.y + rad + 2)):
				for xx in range(int(c.x - rad - 1), int(c.x + rad + 2)):
					if xx >= 0 and yy >= 0 and xx < size and yy < size and Vector2(xx + 0.5, yy + 0.5).distance_to(c) <= rad:
						img.set_pixel(xx, yy, Color.BLACK)
	return ImageTexture.create_from_image(img)
