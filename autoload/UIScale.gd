extends Node
## Responsive type scale mirroring the legacy Inkfall CSS vmin system.
##
## The legacy web version uses CSS vmin (the smaller viewport dimension) with clamp() to scale
## fonts fluidly across devices. Godot has no native equivalent, so this autoload computes the
## scale on every resize and exposes clamped font sizes that each UI component reads.
##
## The content area is clamped to a landscape aspect band [ASPECT_MIN, ASPECT_MAX], matching the
## legacy letterbox behaviour. Too tall: bars top and bottom. Too wide: bars left and right.
## The vmin is computed from the clamped content area, not the raw viewport.
##
## Usage: connect to `scale_changed`, then read the font sizes (fs_title, fs_sub, etc.) and
## apply them as theme font size overrides on your labels and buttons.

## Emitted whenever the viewport resizes and the scale values have been recomputed.
signal scale_changed

## The legacy aspect band. Below ASPECT_MIN the screen is too tall (letterbox top and bottom).
## Above ASPECT_MAX the screen is too wide (pillarbox left and right).
const ASPECT_MIN := 16.0 / 10.0   # 1.6
const ASPECT_MAX := 2.6

## The clamped content rectangle in viewport coordinates. UI should be laid out within this.
## On a normal 16:9 or 16:10 display this equals the full viewport.
var content_rect := Rect2()

## Inset from the bottom of the viewport in px, accounting for letterbox bars.
## UI anchored at the bottom should offset by at least this much.
var safe_bottom := 0.0

## The smaller dimension of the clamped content area, the Godot equivalent of CSS vmin.
var vmin := 1080.0

# --- the type scale, matching the legacy CSS variables ---
# Each is recomputed on resize as clamp(min_px, factor * vmin, max_px).

var fs_title := 130   ## the INKFALL wordmark
var fs_sub := 22      ## subtitle, ENTER button, story card names
var fs_body := 19     ## blurb text
var fs_menu := 15     ## menu items (pause menu), gate buttons
var fs_caption := 18  ## the typed narration caption
var fs_label := 14    ## headings ("CHOOSE YOUR TALE"), scene tag
var fs_hud := 13      ## HUD chip text, REVIEW ACT
var fs_icon := 18     ## icon buttons (the fullscreen, poster, menu chips)
var fs_note := 11     ## tap note, tiny hints
var fs_tagline := 15  ## story card tagline. Legacy: clamp(12, 2vmin, 15).

## HUD cell size (touch target for chips). Legacy: clamp(34, 6vmin, 52).
var hud_cell := 52

## TransCard (act title) and TransEnd (THE END) scale from min(W, H) to match the legacy
## canvas based sizing (not vmin CSS). Exposed so Transitions can read them.
var fs_card := 75     ## legacy: min(W, H) * 0.07
var fs_end := 92      ## legacy: min(W, H) * 0.085

## Story card minimum width, scales with the content width.
var card_min_w := 300.0

## Enter button padding, scales with vmin.
var enter_pad_h := 64.0  ## horizontal
var enter_pad_v := 22.0  ## vertical

## Story card padding. Legacy: clamp(14, 2.6vmin, 20) vertical, clamp(20, 4vmin, 32) horizontal.
var card_pad_h := 32.0
var card_pad_v := 20.0

## Gate button padding.
var gate_pad_h := 30.0
var gate_pad_v := 18.0

## Spacer height between sections on the start screen.
var spacer := 22.0

## VBox separation on start screen.
var vbox_sep := 14

## Story picker gap (between cards). Legacy: clamp(12, 2vmin, 18).
var tales_gap := 18

## Separation between the name and tagline inside a story card. Legacy: clamp(6, 1.2vmin, 10).
var card_sep := 10

## Caption min width.
var caption_min_w := 560.0

## Caption max width. Legacy: min(90vw, 600px), wide desktop override: min(52vw, 600px).
var caption_max_w := 600.0

## Caption padding. Legacy: clamp(9, 1.7vmin, 13) vertical, clamp(12, 2.2vmin, 18) horizontal.
var caption_pad_h := 18.0
var caption_pad_v := 13.0

## Caption bottom offset (from the bottom of the viewport).
var caption_bottom := 48.0

## Tap note bottom offset.
var tap_bottom := 10.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_recompute)
	# initial computation
	call_deferred("_recompute")


func _recompute() -> void:
	var vp := get_viewport().get_visible_rect().size
	var vw := vp.x
	var vh := vp.y
	var ar := vw / maxf(vh, 1.0)

	# clamp to the aspect band (matching legacy engine.resize)
	var cw := vw
	var ch := vh
	if ar < ASPECT_MIN:
		ch = roundf(vw / ASPECT_MIN)   # too tall: cap the height
	elif ar > ASPECT_MAX:
		cw = roundf(vh * ASPECT_MAX)    # too wide: cap the width

	# content rect, centered in the viewport
	var cx := (vw - cw) * 0.5
	var cy := (vh - ch) * 0.5
	content_rect = Rect2(cx, cy, cw, ch)
	safe_bottom = vh - (cy + ch)

	# vmin: the smaller clamped dimension
	vmin = minf(cw, ch)

	# recompute every size, mirroring the legacy CSS clamp(min, factor * vmin, max)
	fs_title = _clamp_i(54, vmin * 0.14, 130)
	fs_sub = _clamp_i(15, vmin * 0.03, 22)
	fs_body = _clamp_i(14, vmin * 0.024, 19)
	fs_menu = _clamp_i(13, vmin * 0.022, 15)
	fs_caption = _clamp_i(13, vmin * 0.024, 18)
	fs_label = _clamp_i(11, vmin * 0.02, 14)
	fs_hud = _clamp_i(10, vmin * 0.02, 13)
	fs_icon = _clamp_i(14, vmin * 0.03, 18)
	fs_note = _clamp_i(8, vmin * 0.016, 11)
	fs_tagline = _clamp_i(12, vmin * 0.02, 15)

	hud_cell = _clamp_i(34, vmin * 0.06, 52)

	# transition cards scale from min(W, H) like the legacy canvas renderer
	var mn := minf(cw, ch)
	fs_card = maxi(24, roundi(mn * 0.07))
	fs_end = maxi(30, roundi(mn * 0.085))

	# derived layout values
	card_min_w = clampf(cw * 0.16, 200, 340)
	enter_pad_h = clampf(vmin * 0.06, 36, 64)
	enter_pad_v = clampf(vmin * 0.022, 14, 22)
	card_pad_h = clampf(vmin * 0.04, 20, 32)
	card_pad_v = clampf(vmin * 0.026, 14, 20)
	gate_pad_h = clampf(vmin * 0.03, 16, 30)
	gate_pad_v = clampf(vmin * 0.018, 12, 18)
	spacer = clampf(vmin * 0.022, 10, 30)
	vbox_sep = _clamp_i(8, vmin * 0.014, 18)
	tales_gap = _clamp_i(12, vmin * 0.02, 18)
	card_sep = _clamp_i(6, vmin * 0.012, 10)
	caption_min_w = clampf(cw * 0.30, 320, 600)
	caption_max_w = minf(cw * 0.9, 600)
	caption_pad_h = clampf(vmin * 0.022, 12, 18)
	caption_pad_v = clampf(vmin * 0.017, 9, 13)
	caption_bottom = clampf(safe_bottom + vmin * 0.04, 24, 60)
	tap_bottom = maxf(safe_bottom + 6, 10)

	scale_changed.emit()


## clamp and round to int, used for font sizes
static func _clamp_i(lo: int, v: float, hi: int) -> int:
	return clampi(roundi(v), lo, hi)
