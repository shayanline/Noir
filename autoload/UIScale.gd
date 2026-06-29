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

## Extra multiplier applied to text and touch target sizes on phones (touch web), on top of dpr.
## The legacy sizes are calibrated for a desktop CSS viewport and read small on a phone, so this
## lifts them to a comfortable size. Raise it for bigger UI, lower it toward 1.0 for smaller.
const MOBILE_UI_BOOST := 1.4

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

## Caches of the authored theme values, captured once so the dpr scaling in _scale_theme always
## starts from the base and stays idempotent. _style_bases keys a StyleBox by instance id (border
## widths, corner radii and content margins). _font_bases keys a theme font size by "type/name".
var _style_bases := {}
var _font_bases := {}
var _spacing_bases := {}

## The dpr the theme was last scaled at, so the pass is skipped when nothing changed. size_changed
## fires often on mobile web (address bar show or hide, pinch), but the theme scaling only depends
## on dpr, never the viewport size.
var _scaled_dpr := -1.0

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
	# pixel content_rect and vmin.
	dpr = _dpr()
	# ui is the text and touch target scale: dpr plus a boost on phones, so the legacy CSS sized
	# chrome is not left tiny on a small high density screen. Geometry, widths, spacing and the
	# theme (the pause menu, borders) stay on the true dpr so the layout does not overflow and
	# thin borders stay crisp. On desktop the boost is 1.0, so the look there is unchanged.
	var ui := dpr * _ui_boost()
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
	# produce physical-pixel results, so only the constant bounds need multiplying.
	vmin = minf(cw, ch) * dpr

	# font sizes: clamp(min_css * ui, factor * vmin, max_css * ui). The ui boost lifts the small
	# end of the range on phones, which is where the HUD lands on a 1080 tall content area.
	fs_title = _clamp_i(roundi(54 * ui), vmin * 0.14, roundi(130 * ui))
	fs_sub = _clamp_i(roundi(15 * ui), vmin * 0.03, roundi(22 * ui))
	fs_body = _clamp_i(roundi(14 * ui), vmin * 0.024, roundi(19 * ui))
	fs_menu = _clamp_i(roundi(13 * ui), vmin * 0.022, roundi(15 * ui))
	fs_caption = _clamp_i(roundi(13 * ui), vmin * 0.024, roundi(18 * ui))
	fs_label = _clamp_i(roundi(11 * ui), vmin * 0.02, roundi(14 * ui))
	fs_hud = _clamp_i(roundi(10 * ui), vmin * 0.02, roundi(13 * ui))
	fs_icon = _clamp_i(roundi(14 * ui), vmin * 0.03, roundi(18 * ui))
	fs_note = _clamp_i(roundi(8 * ui), vmin * 0.016, roundi(11 * ui))
	fs_tagline = _clamp_i(roundi(12 * ui), vmin * 0.02, roundi(15 * ui))

	# the chip touch target scales with ui so it stays comfortable to tap on a phone
	hud_cell = _clamp_i(roundi(34 * ui), vmin * 0.06, roundi(52 * ui))

	# transition cards scale from min(W, H) like the legacy canvas renderer
	var mn := minf(cw, ch) * dpr
	fs_card = maxi(roundi(24 * ui), roundi(mn * 0.07))
	fs_end = maxi(roundi(30 * ui), roundi(mn * 0.085))

	# widths stay on dpr (content relative, must not overflow); paddings scale with ui (touch)
	card_min_w = clampf(cw * dpr * 0.16, 200 * dpr, 340 * dpr)
	enter_pad_h = clampf(vmin * 0.06, 36 * ui, 64 * ui)
	enter_pad_v = clampf(vmin * 0.022, 14 * ui, 22 * ui)
	card_pad_h = clampf(vmin * 0.04, 20 * ui, 32 * ui)
	card_pad_v = clampf(vmin * 0.026, 14 * ui, 20 * ui)
	gate_pad_h = clampf(vmin * 0.03, 16 * ui, 30 * ui)
	gate_pad_v = clampf(vmin * 0.018, 12 * ui, 18 * ui)
	spacer = clampf(vmin * 0.022, 10 * dpr, 30 * dpr)
	vbox_sep = _clamp_i(roundi(8 * dpr), vmin * 0.014, roundi(18 * dpr))
	tales_gap = _clamp_i(roundi(12 * dpr), vmin * 0.02, roundi(18 * dpr))
	card_sep = _clamp_i(roundi(6 * dpr), vmin * 0.012, roundi(10 * dpr))
	caption_min_w = clampf(cw * dpr * 0.30, 320 * dpr, 600 * dpr)
	caption_max_w = minf(cw * dpr * 0.9, 600 * dpr)
	caption_pad_h = clampf(vmin * 0.022, 12 * ui, 18 * ui)
	caption_pad_v = clampf(vmin * 0.017, 9 * ui, 13 * ui)
	caption_bottom = clampf(safe_bottom + vmin * 0.04, 24 * dpr, 60 * dpr)
	tap_bottom = maxf(safe_bottom + 6 * dpr, 10 * dpr)

	gap = 6.0 * dpr
	edge = 20.0 * dpr
	end_box_top = 240.0 * dpr
	end_box_bottom = 90.0 * dpr

	_scale_theme()
	scale_changed.emit()


## clamp and round to int, used for font sizes
static func _clamp_i(lo: int, v: float, hi: int) -> int:
	return clampi(roundi(v), lo, hi)


## Scale every value the theme authors in the 1080 base coordinate space (font sizes, border
## widths, corner radii and content margins) by dpr, in place on the shared theme.
##
## On a HiDPI web canvas the stretch shrinks the whole UI, so a theme size of 24 or a 1px border
## ends up tiny or sub pixel thin. Scaling the theme itself means every theme driven control (the
## pause menu, the poster modal, the act dropdown, every bordered panel and button) scales without
## per control code, in any orientation. Controls that already apply an explicit UIScale font size
## or padding override are unaffected, the override still wins, so there is no double scaling. At
## dpr 1 (desktop) every value resolves back to its authored size, so the look there is unchanged.
##
## The pass is skipped when dpr has not changed, and shared StyleBox instances (many states reuse
## one resource) are scaled once per pass, so frequent mobile resizes stay cheap.
func _scale_theme() -> void:
	if is_equal_approx(dpr, _scaled_dpr):
		return
	_scaled_dpr = dpr
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var seen := {}
	for type in theme.get_type_list():
		for fname in theme.get_font_size_list(type):
			var fkey := str(type) + "/" + str(fname)
			if not _font_bases.has(fkey):
				_font_bases[fkey] = theme.get_font_size(fname, type)
			var fbase: int = _font_bases[fkey]
			if fbase > 0:
				theme.set_font_size(fname, type, maxi(1, roundi(fbase * dpr)))
		# letter spacing is authored in pixels at the design size, so scale it with dpr too, else the
		# bigger mobile text reads cramped (the spacing would not keep pace with the glyphs)
		for fontname in theme.get_font_list(type):
			var fv := theme.get_font(fontname, type) as FontVariation
			if fv == null or seen.has(fv.get_instance_id()):
				continue
			seen[fv.get_instance_id()] = true
			if not _spacing_bases.has(fv.get_instance_id()):
				_spacing_bases[fv.get_instance_id()] = fv.spacing_glyph
			fv.spacing_glyph = roundi(_spacing_bases[fv.get_instance_id()] * dpr)
		for sname in theme.get_stylebox_list(type):
			var sb := theme.get_stylebox(sname, type)
			if sb == null or seen.has(sb.get_instance_id()):
				continue
			seen[sb.get_instance_id()] = true
			_scale_stylebox(sb)


## Scale one shared stylebox's content margins, and (if flat) its border widths and corner radii.
func _scale_stylebox(sb: StyleBox) -> void:
	var key := sb.get_instance_id()
	if not _style_bases.has(key):
		var base := {
			"ml": sb.content_margin_left, "mt": sb.content_margin_top,
			"mr": sb.content_margin_right, "mb": sb.content_margin_bottom,
		}
		if sb is StyleBoxFlat:
			base["bl"] = sb.border_width_left
			base["bt"] = sb.border_width_top
			base["br"] = sb.border_width_right
			base["bb"] = sb.border_width_bottom
			base["cl"] = sb.corner_radius_top_left
			base["cr"] = sb.corner_radius_top_right
			base["cb"] = sb.corner_radius_bottom_right
			base["ca"] = sb.corner_radius_bottom_left
		_style_bases[key] = base
	var b: Dictionary = _style_bases[key]
	sb.content_margin_left = _scale_margin(b["ml"])
	sb.content_margin_top = _scale_margin(b["mt"])
	sb.content_margin_right = _scale_margin(b["mr"])
	sb.content_margin_bottom = _scale_margin(b["mb"])
	if sb is StyleBoxFlat:
		sb.border_width_left = _scale_px(b["bl"])
		sb.border_width_top = _scale_px(b["bt"])
		sb.border_width_right = _scale_px(b["br"])
		sb.border_width_bottom = _scale_px(b["bb"])
		sb.corner_radius_top_left = _scale_px(b["cl"])
		sb.corner_radius_top_right = _scale_px(b["cr"])
		sb.corner_radius_bottom_right = _scale_px(b["cb"])
		sb.corner_radius_bottom_left = _scale_px(b["ca"])


## Scale an authored pixel value by dpr, keeping a positive value at least 1px so a thin border is
## never rounded away.
func _scale_px(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(base * dpr))


## Scale a content margin by dpr. An unset margin (-1) is left untouched so the stylebox keeps
## deriving it; a real margin (0 or more) scales.
func _scale_margin(base: float) -> float:
	if base < 0.0:
		return base
	return base * dpr


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


## The mobile UI boost, applied on touch web (phones and tablets) and 1.0 everywhere else, so
## desktop and native are unchanged. is_touchscreen_available is the same signal the rotation gate
## uses to decide a device is touch.
static func _ui_boost() -> float:
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return MOBILE_UI_BOOST
	return 1.0
