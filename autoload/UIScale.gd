extends Node
## Responsive type scale mirroring the legacy Inkfall CSS vmin system.
##
## The legacy web version uses CSS vmin (the smaller viewport dimension) with clamp() to scale
## fonts fluidly across devices. Godot has no native equivalent, so this autoload computes the
## scale on every resize and exposes clamped font sizes that each UI component reads.
##
## The story content area is clamped to a landscape aspect band [ASPECT_MIN, ASPECT_MAX] (16:10 to
## 21:9). Outside that band the board is letterboxed (top and bottom bars when too tall, left and
## right when too wide). The HUD, captions and navigation use the full viewport.
## The vmin is computed from the clamped content area, not the raw viewport.
##
## HiDPI / web export note: Godot 4 web exports size the canvas to physical pixels
## (window.innerWidth * devicePixelRatio). The viewport therefore reports physical pixel
## dimensions. All constant bounds (the CSS-calibrated min/max clamp values) are multiplied by
## the device pixel ratio so font sizes, touch targets, and margins appear at the intended
## physical size on screen. The factor-based values (vmin * factor) already scale correctly
## because vmin is derived from the physical viewport.
##
## Usage: connect to `scale_changed`, then read the font sizes (fs_title, fs_sub, etc.) and
## apply them as theme font size overrides on your labels and buttons.

## Emitted whenever the viewport resizes and the scale values have been recomputed.
signal scale_changed

## The aspect band for the story content area. Below ASPECT_MIN the screen is too tall (letterbox
## top and bottom). Above ASPECT_MAX the screen is too wide (pillarbox left and right).
## The HUD, captions and navigation use the full viewport, only the board is masked.
const ASPECT_MIN := 16.0 / 10.0   # 1.6
const ASPECT_MAX := 21.0 / 9.0    # 2.333

## The clamped content rectangle in viewport coordinates. UI should be laid out within this.
## On a normal 16:9 or 16:10 display this equals the full viewport.
var content_rect := Rect2()

## Inset from the bottom of the viewport in px, accounting for letterbox bars.
## UI anchored at the bottom should offset by at least this much.
var safe_bottom := 0.0

## The smaller dimension of the clamped content area in physical pixels (the Godot equivalent
## of CSS vmin, already scaled by dpr). The constant bounds in each clamp call are also scaled
## by dpr, so callers that use `vmin * factor` get a physical-pixel result without extra work.
var vmin := 1080.0

## Device pixel ratio. On web exports the canvas is sized to physical pixels; on all other
## platforms Godot handles HiDPI internally and this is always 1.0.
var dpr := 1.0

## Cache of the authored border widths and corner radii per shared theme StyleBoxFlat, keyed by
## instance id. Captured once so the dpr scaling in _scale_theme_borders stays idempotent across
## resizes (it always scales from the base, never from an already scaled value).
var _border_bases := {}

## Gap between adjacent HUD chips (physical pixels). Scaled by dpr.
var gap := 6.0

## Screen edge inset for positioned HUD elements (physical pixels). Scaled by dpr.
var edge := 20.0

## Vertical extent of the end-of-story act row (physical pixels). Scaled by dpr.
var end_box_top := 240.0
var end_box_bottom := 90.0

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
	# On HiDPI web exports the viewport is in physical pixels. Divide by dpr to recover CSS
	# dimensions, clamp to the aspect band in CSS space, then multiply back to get physical
	# pixel content_rect and vmin. All constant bounds are scaled by dpr so physical outputs
	# match the CSS-calibrated targets.
	dpr = _dpr()
	var vw := vp.x / dpr
	var vh := vp.y / dpr
	var ar := vw / maxf(vh, 1.0)

	# clamp to the aspect band in CSS pixels (matching legacy engine.resize)
	var cw := vw
	var ch := vh
	if ar < ASPECT_MIN:
		ch = roundf(vw / ASPECT_MIN)   # too tall: cap the height
	elif ar > ASPECT_MAX:
		cw = roundf(vh * ASPECT_MAX)    # too wide: cap the width

	# content rect in physical viewport pixels, centered
	var cx := (vp.x - cw * dpr) * 0.5
	var cy := (vp.y - ch * dpr) * 0.5
	content_rect = Rect2(cx, cy, cw * dpr, ch * dpr)
	safe_bottom = vp.y - (cy + ch * dpr)

	# vmin in physical pixels: CSS vmin * dpr. The factor-based terms (vmin * factor) already
	# produce physical-pixel results, so only the constant bounds need multiplying by dpr.
	vmin = minf(cw, ch) * dpr

	# recompute every size: clamp(min_css * dpr, factor * vmin, max_css * dpr)
	fs_title = _clamp_i(roundi(54 * dpr), vmin * 0.14, roundi(130 * dpr))
	fs_sub = _clamp_i(roundi(15 * dpr), vmin * 0.03, roundi(22 * dpr))
	fs_body = _clamp_i(roundi(14 * dpr), vmin * 0.024, roundi(19 * dpr))
	fs_menu = _clamp_i(roundi(13 * dpr), vmin * 0.022, roundi(15 * dpr))
	fs_caption = _clamp_i(roundi(13 * dpr), vmin * 0.024, roundi(18 * dpr))
	fs_label = _clamp_i(roundi(11 * dpr), vmin * 0.02, roundi(14 * dpr))
	fs_hud = _clamp_i(roundi(10 * dpr), vmin * 0.02, roundi(13 * dpr))
	fs_icon = _clamp_i(roundi(14 * dpr), vmin * 0.03, roundi(18 * dpr))
	fs_note = _clamp_i(roundi(8 * dpr), vmin * 0.016, roundi(11 * dpr))
	fs_tagline = _clamp_i(roundi(12 * dpr), vmin * 0.02, roundi(15 * dpr))

	hud_cell = _clamp_i(roundi(34 * dpr), vmin * 0.06, roundi(52 * dpr))

	# transition cards scale from min(W, H) like the legacy canvas renderer
	var mn := minf(cw, ch) * dpr
	fs_card = maxi(roundi(24 * dpr), roundi(mn * 0.07))
	fs_end = maxi(roundi(30 * dpr), roundi(mn * 0.085))

	# derived layout values (all bounds scaled by dpr)
	card_min_w = clampf(cw * dpr * 0.16, 200 * dpr, 340 * dpr)
	enter_pad_h = clampf(vmin * 0.06, 36 * dpr, 64 * dpr)
	enter_pad_v = clampf(vmin * 0.022, 14 * dpr, 22 * dpr)
	card_pad_h = clampf(vmin * 0.04, 20 * dpr, 32 * dpr)
	card_pad_v = clampf(vmin * 0.026, 14 * dpr, 20 * dpr)
	gate_pad_h = clampf(vmin * 0.03, 16 * dpr, 30 * dpr)
	gate_pad_v = clampf(vmin * 0.018, 12 * dpr, 18 * dpr)
	spacer = clampf(vmin * 0.022, 10 * dpr, 30 * dpr)
	vbox_sep = _clamp_i(roundi(8 * dpr), vmin * 0.014, roundi(18 * dpr))
	tales_gap = _clamp_i(roundi(12 * dpr), vmin * 0.02, roundi(18 * dpr))
	card_sep = _clamp_i(roundi(6 * dpr), vmin * 0.012, roundi(10 * dpr))
	caption_min_w = clampf(cw * dpr * 0.30, 320 * dpr, 600 * dpr)
	caption_max_w = minf(cw * dpr * 0.9, 600 * dpr)
	caption_pad_h = clampf(vmin * 0.022, 12 * dpr, 18 * dpr)
	caption_pad_v = clampf(vmin * 0.017, 9 * dpr, 13 * dpr)
	caption_bottom = clampf(safe_bottom + vmin * 0.04, 24 * dpr, 60 * dpr)
	tap_bottom = maxf(safe_bottom + 6 * dpr, 10 * dpr)

	gap = 6.0 * dpr
	edge = 20.0 * dpr
	end_box_top = 240.0 * dpr
	end_box_bottom = 90.0 * dpr

	_scale_theme_borders()
	scale_changed.emit()


## clamp and round to int, used for font sizes
static func _clamp_i(lo: int, v: float, hi: int) -> int:
	return clampi(roundi(v), lo, hi)


## Scale the border widths and corner radii of the shared theme styleboxes by dpr.
##
## These are authored in the 1080 base coordinate space, so on a HiDPI canvas a 1px border renders
## as a sub pixel hairline that blurs or vanishes while the dpr scaled fonts around it grow. Scaling
## them in place on the shared StyleBoxFlat resources keeps every bordered control (buttons, panels,
## cards) crisp without per control overrides. The authored values are cached on first run so the
## scaling always starts from the base and stays idempotent when dpr changes (e.g. on rotation).
func _scale_theme_borders() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	for type in theme.get_type_list():
		for name in theme.get_stylebox_list(type):
			var flat := theme.get_stylebox(name, type) as StyleBoxFlat
			if flat == null:
				continue
			var key := flat.get_instance_id()
			if not _border_bases.has(key):
				_border_bases[key] = [
					flat.border_width_left, flat.border_width_top,
					flat.border_width_right, flat.border_width_bottom,
					flat.corner_radius_top_left, flat.corner_radius_top_right,
					flat.corner_radius_bottom_right, flat.corner_radius_bottom_left,
				]
			var b: Array = _border_bases[key]
			flat.border_width_left = _scale_px(b[0])
			flat.border_width_top = _scale_px(b[1])
			flat.border_width_right = _scale_px(b[2])
			flat.border_width_bottom = _scale_px(b[3])
			flat.corner_radius_top_left = _scale_px(b[4])
			flat.corner_radius_top_right = _scale_px(b[5])
			flat.corner_radius_bottom_right = _scale_px(b[6])
			flat.corner_radius_bottom_left = _scale_px(b[7])


## Scale an authored pixel value by dpr, keeping a positive value at least 1px so a thin border is
## never rounded away.
func _scale_px(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * dpr))


## Returns the device pixel ratio for the current platform.
## Web exports size the canvas to physical pixels via window.devicePixelRatio.
## All other platforms handle HiDPI internally, so the viewport is already in logical pixels.
##
## Two independent sources are queried and the larger is used. DisplayServer.screen_get_scale()
## reads the ratio natively at engine level and is available immediately, while the
## JavaScriptBridge eval can return null or run before the bridge is ready on some mobile
## browsers and in-app webviews. Relying on a single source left the ratio at 1.0 on those
## devices, which squashed the whole HUD. Taking the max means whichever source reports the real
## ratio wins, so the HUD is only left at 1.0 when the device genuinely has no pixel scaling.
static func _dpr() -> float:
	if not OS.has_feature("web"):
		return 1.0
	var best := 1.0
	var native := DisplayServer.screen_get_scale()
	if native > best:
		best = native
	var r = JavaScriptBridge.eval("window.devicePixelRatio", true)
	if r != null:
		best = maxf(best, float(r))
	return best
