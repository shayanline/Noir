class_name Neon
extends BoardLight
## A neon sign, built as layers so it reads as real glowing glass, not a flat coloured stroke:
##   1. Tube: a wide Line2D running neon.gdshader, which draws a hot glass core bleeding into an
##      exponential coloured halo. The shader uses both UV.x (along the tube: end taper, bend
##      brightening, gas discharge shimmer) and UV.y (across: core and halo). The halo follows the
##      actual tube shape, so there is no separate sprite halo node.
##   2. Label: the sign text, glowing in the same colour, sitting over the halo.
##   3. Spill lights: two PointLight2Ds that throw the sign's colour onto the wall, the wet floor
##      and the rain (the genuine lighting), shadowless because a sign is a glow, not a key.
## The bloom then lifts it all a touch further.
##
## Shapes: the sign shape is data driven. The params "shape" key selects a preset ("rect", "arrow",
## "pill", "chevron", "vertical", "circle") or pass "points" as a PackedVector2Array for any custom
## contour. The default is "rect".
##
## Sizing: w and h are HTML legacy pixels on a 1280 wide reference. Divided by board.unit in
## place() so the board scale renders them at the correct screen size.
##
## Flicker state machine: the sign has five states (LIVE, DYING, DEAD, RE_STRIKING, BUZZ) driven by
## story data. A slow 5 + 13 Hz sine matches the legacy. One designated sign per act can have
## dropout: true for the occasional full blackout and re-strike. The sign also responds to fx events
## ("power_cut" kills it, flags "neon_dead" / "neon_live" control it from the story). The
## neon_crackle SFX fires on dropout and re-strike.

const _FONT := preload("res://fonts/Oswald.ttf")
const _LIGHT_TEX := preload("res://src/util/soft_glow.tres")
const _NEON_SHADER := preload("res://shaders/neon.gdshader")
const _LABEL_BASE := 24   # the label renders at this size, then scales to fit the sign box
const _TUBE_WIDTH := 6.0  # the glow diameter of the tube in design units: thin so it reads as glass, not a smear

static var _white_tex: ImageTexture


## A tiny white texture so the tube Line2D has a valid across-width UV for the neon shader to read.
static func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

## Legacy pixel dimensions, converted to design units in place().
var _w_px := 120.0
var _h_px := 40.0
var _w := 120.0
var _h := 40.0

var _label := ""
var _shape := "rect"
var _custom_points: PackedVector2Array = PackedVector2Array()
var _ignite := false
var _dropout := false

## The two PointLight2Ds, built in place().
var _surface_light: PointLight2D   ## sign shaped, tight surface glow
var _air_light: PointLight2D       ## wide soft air bloom

var _buzz_t := 0.0
var _buzz_on := false

## Flicker state machine
enum _State { LIVE, DYING, DEAD, RE_STRIKING, BUZZ }
var _state := _State.LIVE
var _state_timer := 0.0
const _DROP_INTERVAL_MIN := 4.0
const _DROP_INTERVAL_MAX := 14.0
const _DARK_DUR_MIN := 0.08
const _DARK_DUR_MAX := 0.30
const _DYING_DUR := 0.12          # how long the sign takes to die
const _RESTRIKE_DUR := 0.6        # how long the cold re-strike warm up takes

## Dead flag: when set by a story flag or fx, the sign stays dark until cleared.
var _force_dead := false


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	if p.get("w") != null:
		_w_px = float(p["w"])
	if p.get("h") != null:
		_h_px = float(p["h"])
	if p.get("label") != null:
		_label = str(p["label"])
	if p.get("shape") != null:
		_shape = str(p["shape"])
	elif p.get("arrow", false) == true:
		_shape = "arrow"   # legacy compat: "arrow": true maps to shape "arrow"
	if p.get("points") != null:
		_custom_points = p["points"] as PackedVector2Array
	_ignite = p.get("ignite", _ignite) == true
	_dropout = p.get("dropout", _dropout) == true


var _built := false

func place() -> void:
	super.place()
	if _built:
		return
	_built = true
	var u := board.unit if board else 1.0
	_w = _w_px / u
	_h = _h_px / u
	_build_outline()
	_build_label()
	_build_lights()
	if _dropout:
		_state = _State.LIVE
		_state_timer = randf_range(_DROP_INTERVAL_MIN, _DROP_INTERVAL_MAX)
	if _ignite:
		# Cold start: the sign sits near dark, then strikes after a beat and the tubes warm up.
		modulate = Color(0.15, 0.15, 0.15)
		_set_light_energy(0.04)
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(func(): _buzz_on = true)
		tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.6)
		if _surface_light:
			tw.parallel().tween_property(_surface_light, "energy", _surface_energy(), 0.6)
		if _air_light:
			tw.parallel().tween_property(_air_light, "energy", _air_energy(), 0.6)
		AudioDirector.neon_zap()
	else:
		_buzz_on = true


# --- shape presets ---------------------------------------------------------------------------

## Return the outline points for the current shape, all in the w/h design space.
func _outline_points() -> PackedVector2Array:
	if not _custom_points.is_empty():
		return _custom_points
	match _shape:
		"arrow":
			var pw := _h * 0.9
			return PackedVector2Array([
				Vector2(0, 0), Vector2(_w, 0), Vector2(_w + pw, _h / 2.0),
				Vector2(_w, _h), Vector2(0, _h), Vector2(0, 0)])
		"pill":
			# A stadium (rounded rectangle): two straight edges joined by smooth semicircular caps.
			# Eight segments per cap so the ends read as true curves, not facets. The straight top
			# and bottom edges are the implicit segments between the caps.
			var r := minf(_h, _w) * 0.5
			var segs := 8
			var pts := PackedVector2Array()
			# right cap, top tangent round to bottom tangent (centre at _w - r, r)
			for i in range(segs + 1):
				var a := -PI / 2.0 + PI * float(i) / float(segs)
				pts.append(Vector2(_w - r + cos(a) * r, r + sin(a) * r))
			# left cap, bottom tangent round to top tangent (centre at r, r)
			for i in range(segs + 1):
				var a := PI / 2.0 + PI * float(i) / float(segs)
				pts.append(Vector2(r + cos(a) * r, r + sin(a) * r))
			pts.append(pts[0])   # close the loop back to the top right tangent
			return pts
		"chevron":
			var indent := _h * 0.4
			return PackedVector2Array([
				Vector2(0, 0), Vector2(_w, 0), Vector2(_w + indent, _h / 2.0),
				Vector2(_w, _h), Vector2(0, _h), Vector2(indent, _h / 2.0), Vector2(0, 0)])
		"vertical":
			# A tall vertical banner, w and h are swapped conceptually (w = narrow, h = tall).
			return PackedVector2Array([
				Vector2(0, 0), Vector2(_w, 0), Vector2(_w, _h),
				Vector2(0, _h), Vector2(0, 0)])
		"circle":
			var cx := _w * 0.5
			var cy := _h * 0.5
			var rx := _w * 0.5
			var ry := _h * 0.5
			var pts := PackedVector2Array()
			var segs := 24
			for i in range(segs + 1):
				var a := TAU * float(i) / float(segs)
				pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
			return pts
		_:  # "rect" and fallback
			return PackedVector2Array([
				Vector2(0, 0), Vector2(_w, 0), Vector2(_w, _h),
				Vector2(0, _h), Vector2(0, 0)])


# --- geometry -------------------------------------------------------------------------------

## The glowing glass tube: a wide Line2D running neon.gdshader. The texture mode is STRETCH so UV.x
## maps 0..1 along the full tube, giving the shader the along-tube position for end taper, bend
## brightening, and the gas discharge shimmer. default_color stays white so the flicker (node
## modulate) rides cleanly into the shader through the vertex COLOR.
func _build_outline() -> void:
	var tube := Line2D.new()
	tube.name = "Outline"
	tube.width = _TUBE_WIDTH
	tube.default_color = Color.WHITE
	tube.texture = _white()
	tube.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	tube.joint_mode = Line2D.LINE_JOINT_ROUND
	tube.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tube.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pts := _outline_points()
	# A closed shape (rect, arrow, pill, ...) is one continuous loop. Drawn as a plain Line2D it
	# would begin and end on the same corner, stacking two round caps and two dark end tapers there,
	# the overlapped nub that broke the top left corner. Move the seam to the middle of the first
	# edge so the two caps meet on a straight run (the join vanishes) and every real corner becomes a
	# clean interior joint, and tell the shader the tube is closed so it keeps full brightness round.
	var is_closed := pts.size() >= 4 and pts[0].is_equal_approx(pts[pts.size() - 1])
	if is_closed:
		pts = _seam_at_midedge(pts)
		# No end caps on a loop: the seam sits mid edge where the two segments already meet, so a
		# round cap on each end would only stack two half discs there and, with additive blend,
		# burn a bright pip into the tube. The interior corners still get round joints.
		tube.begin_cap_mode = Line2D.LINE_CAP_NONE
		tube.end_cap_mode = Line2D.LINE_CAP_NONE
	tube.points = pts
	var mat := ShaderMaterial.new()
	mat.shader = _NEON_SHADER
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("closed", is_closed)
	# Feed the bend positions (as fractions of total arc length) to the shader.
	var bends := _compute_bend_fractions(pts)
	mat.set_shader_parameter("bend_count", float(bends.size()))
	var bend_arr: Array[float] = []
	for i in range(6):
		bend_arr.append(bends[i] if i < bends.size() else 0.0)
	mat.set_shader_parameter("bends", bend_arr)
	tube.material = mat
	tube.z_index = 1   # behind the label (z_index 2), above the lights
	add_child(tube)


## Reorder a closed outline (first point equals last) so its open seam falls at the midpoint of the
## first edge rather than on a corner. The Line2D then begins and ends mid edge, where its two round
## caps line up on a straight run and disappear, while every real corner becomes an interior round
## joint. Returns a path whose first and last points are that midpoint.
func _seam_at_midedge(pts: PackedVector2Array) -> PackedVector2Array:
	var ring := pts.duplicate()
	if ring.size() >= 2 and ring[0].is_equal_approx(ring[ring.size() - 1]):
		ring.remove_at(ring.size() - 1)
	if ring.size() < 3:
		return pts
	var seam := (ring[0] + ring[1]) * 0.5
	var out := PackedVector2Array()
	out.append(seam)
	for i in range(1, ring.size()):
		out.append(ring[i])
	out.append(ring[0])
	out.append(seam)
	return out


## Compute the fractional arc-length position (0..1) of each sharp corner in the outline, for the
## shader's bend brightening. Only genuine corners count: a vertex whose direction changes sharply.
## Smooth arc vertices (a pill cap, a circle) turn only a little at each step, so they are skipped
## and never pick up stray hot spots.
func _compute_bend_fractions(pts: PackedVector2Array) -> Array[float]:
	if pts.size() < 3:
		return []
	# compute cumulative arc lengths
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		lengths.append(total)
	if total < 0.001:
		return []
	var fracs: Array[float] = []
	for i in range(1, pts.size() - 1):
		var into := pts[i] - pts[i - 1]
		var out_dir := pts[i + 1] - pts[i]
		if into.length() < 0.001 or out_dir.length() < 0.001:
			continue
		# only a sharp turn (more than ~34 degrees) reads as a corner where the gas pools
		if absf(into.angle_to(out_dir)) > 0.6:
			fracs.append(lengths[i] / total)
		if fracs.size() >= 6:
			break
	return fracs


func _build_label() -> void:
	if _label == "":
		return
	var label := Label.new()
	label.name = "SignLabel"
	label.text = _label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _FONT)
	# The label text is the brightest part of the sign: white-hot at the centre, so the letters
	# read as the lit glass tubes themselves, not as captions painted on top of a glow. The outline
	# gives each letter a coloured fringe that ties it to the sign colour.
	var hot := Color(
		minf(color.r * 1.4 + 0.5, 1.0),
		minf(color.g * 1.4 + 0.5, 1.0),
		minf(color.b * 1.4 + 0.5, 1.0))
	label.add_theme_color_override("font_color", hot)
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _LABEL_BASE)
	# Sit above the tube glow so the letters are always readable.
	label.z_index = 2
	add_child(label)
	# A Control parented to a Node2D auto-sizes to its text and ignores any size we set, so instead
	# we render the label at a fixed base size, then scale the whole label to fit inside the sign
	# box (with a small margin) and centre it on the box.
	label.reset_size()
	var pad := 0.88
	var bbox := _label_bbox()
	var is_tall := _shape == "vertical" and _h > _w * 1.5
	if is_tall:
		# Vertical banner: rotate the text 90 degrees so it reads downward, then fit the rotated
		# label (swapped width/height) into the tall narrow box.
		label.rotation = PI / 2.0
		var s: float = minf(bbox.x / maxf(label.size.y, 1.0), bbox.y / maxf(label.size.x, 1.0)) * pad
		label.scale = Vector2(s, s)
		# After a 90-degree rotation, the label's visual top-left shifts. Centre it manually:
		# rotated, the label's visual width = original height * s, visual height = original width * s.
		var vis_w := label.size.y * s
		var vis_h := label.size.x * s
		label.position = _label_centre() + Vector2(-vis_w * 0.5 + vis_h, -vis_h * 0.5)
	else:
		var s: float = minf(bbox.x / maxf(label.size.x, 1.0), bbox.y / maxf(label.size.y, 1.0)) * pad
		label.scale = Vector2(s, s)
		label.position = (_label_centre() - label.size * s * 0.5)


## The bounding box the label should fit inside, accounting for shape.
func _label_bbox() -> Vector2:
	match _shape:
		"arrow":
			return Vector2(_w, _h)
		"chevron":
			return Vector2(_w * 0.8, _h)
		"circle":
			return Vector2(_w * 0.7, _h * 0.7)
		_:
			return Vector2(_w, _h)


## The visual centre of the sign shape, where the label should be centred.
func _label_centre() -> Vector2:
	match _shape:
		"arrow":
			return Vector2(_w * 0.5, _h * 0.5)
		"chevron":
			return Vector2(_w * 0.5 + _h * 0.1, _h * 0.5)
		"circle":
			return Vector2(_w * 0.5, _h * 0.5)
		_:
			return Vector2(_w * 0.5, _h * 0.5)


# --- lights ---------------------------------------------------------------------------------
## Two additive PointLight2Ds matching the HTML v2 light model:
## surface glow (sign shaped ellipse) and air glow (large soft disc).

func _build_lights() -> void:
	var cx := _shape_centre_x()
	var cy := _h / 2.0

	# Surface light: shaped to the sign's w/h ratio.
	_surface_light = PointLight2D.new()
	_surface_light.texture = _LIGHT_TEX
	_surface_light.color = color
	_surface_light.energy = _surface_energy()
	_surface_light.position = Vector2(cx, cy)
	var aspect := _w / maxf(_h, 1.0)
	var base_scale := maxf(_w, _h) * 1.3 / 64.0
	_surface_light.texture_scale = base_scale
	_surface_light.scale = Vector2(aspect if aspect < 1.0 else 1.0, 1.0 if aspect < 1.0 else 1.0 / aspect)
	_surface_light.blend_mode = Light2D.BLEND_MODE_ADD
	# Reach both the near surfaces (foreground) and the far backdrop (the sky, the distant city), so a
	# sign hung against open sky still casts its colour onto whatever sits behind it, the wall glow.
	# Without this the spill is foreground only and a sky sign shows only its own tube halo.
	_surface_light.range_item_cull_mask = Board.LAYER_FOREGROUND | Board.LAYER_BACKDROP
	LightKit.ambient(_surface_light)
	add_child(_surface_light)

	# Air light: the soft atmospheric bloom hanging in the air around the sign. It follows the sign's
	# proportions (a wide sign casts a wide haze, not a round blob) but stays rounder than the surface
	# light, so the haze reads as a soft cloud loosely shaped to the sign rather than a hard ellipse.
	_air_light = PointLight2D.new()
	_air_light.texture = _LIGHT_TEX
	_air_light.color = color
	_air_light.energy = _air_energy()
	_air_light.position = Vector2(cx, cy)
	# A generous haze with a floor, so even a small sign throws a soft cloud large enough to read as
	# light hanging in the night air, not a tight ring clamped to the glass.
	_air_light.texture_scale = maxf(maxf(_w, _h) * 3.6, 90.0) / 64.0
	var air_squash := Vector2(aspect if aspect < 1.0 else 1.0, 1.0 if aspect < 1.0 else 1.0 / aspect)
	_air_light.scale = Vector2.ONE.lerp(air_squash, 0.6)
	_air_light.blend_mode = Light2D.BLEND_MODE_ADD
	# Same reach as the surface light: the soft haze lands on the sky and far city behind the sign.
	_air_light.range_item_cull_mask = Board.LAYER_FOREGROUND | Board.LAYER_BACKDROP
	LightKit.ambient(_air_light)
	add_child(_air_light)

	# Keep _light (from BoardLight) pointing at the surface light for the base class.
	_light = _surface_light
	_base_energy = _surface_energy()


## The centre x of the sign shape, accounting for arrow and chevron offset.
func _shape_centre_x() -> float:
	match _shape:
		"arrow":
			return _w / 2.0 + _h * 0.45
		"chevron":
			return _w / 2.0 + _h * 0.2
		_:
			return _w / 2.0


func _surface_energy() -> float:
	return 2.0 * intensity


func _air_energy() -> float:
	return 1.3 * intensity


# --- light contribution (improvement 4) ----------------------------------------------------

## Return the light contributions for the ripple and rain sampling, so Board does not need to
## reach into this object's internals with isinstance checks. Each entry has pos (global), col,
## radius, and energy.
func get_light_contributions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _surface_light:
		out.append({
			"pos": to_global(_surface_light.position),
			"col": color,
			"radius": _surface_light.texture_scale * 64.0 * maxf(_surface_light.scale.x, _surface_light.scale.y),
			"energy": _surface_light.energy,
		})
	if _air_light:
		out.append({
			"pos": to_global(_air_light.position),
			"col": color,
			"radius": _air_light.texture_scale * 64.0 * 0.5,
			"energy": _air_light.energy,
		})
	return out


# --- flicker state machine ------------------------------------------------------------------

func on_tick() -> void:
	# Do not call super.on_tick(): BoardLight.on_tick() drives the single _light which we
	# manage ourselves here. Calling super would double-flicker the surface light.
	if _force_dead:
		_set_brightness(0.0)
		return
	if not _buzz_on:
		return
	var dt := get_process_delta_time()
	_state_timer -= dt
	match _state:
		_State.LIVE:
			_apply_buzz(dt)
			if _dropout and _state_timer <= 0.0:
				_enter_state(_State.DYING)
		_State.BUZZ:
			_apply_buzz(dt)
		_State.DYING:
			var progress := 1.0 - maxf(_state_timer / _DYING_DUR, 0.0)
			_set_brightness(1.0 - progress)
			if _state_timer <= 0.0:
				_enter_state(_State.DEAD)
		_State.DEAD:
			_set_brightness(0.0)
			if _state_timer <= 0.0:
				_enter_state(_State.RE_STRIKING)
		_State.RE_STRIKING:
			var progress := 1.0 - maxf(_state_timer / _RESTRIKE_DUR, 0.0)
			# flicker on and off during re-strike for a realistic warm up
			var flicker := 1.0 if fmod(progress * 12.0, 1.0) > 0.3 else 0.15
			_set_brightness(progress * flicker)
			if _state_timer <= 0.0:
				_enter_state(_State.LIVE)
				AudioDirector.neon_zap()


func _enter_state(new_state: _State) -> void:
	_state = new_state
	match new_state:
		_State.DYING:
			_state_timer = _DYING_DUR
			AudioDirector.neon_zap()
		_State.DEAD:
			_state_timer = randf_range(_DARK_DUR_MIN, _DARK_DUR_MAX)
		_State.RE_STRIKING:
			_state_timer = _RESTRIKE_DUR
		_State.LIVE:
			_state_timer = randf_range(_DROP_INTERVAL_MIN, _DROP_INTERVAL_MAX)
			_buzz_t = 0.0
		_State.BUZZ:
			_state_timer = 0.0


func _apply_buzz(dt: float) -> void:
	_buzz_t += dt
	var f: float
	if sin(_buzz_t * 5.0) > -0.95:
		f = 0.88 + 0.12 * sin(_buzz_t * 13.0)
	else:
		f = 0.5
	_set_brightness(f)


# --- story reactivity -----------------------------------------------------------------------

## React to story fx events: "power_cut" kills the sign, other fx that story authors invent.
func on_fx(event: String) -> void:
	super.on_fx(event)
	if event == "power_cut":
		_force_dead = true
		_set_brightness(0.0)
		AudioDirector.neon_zap()


## React to flag changes on each line advance. "neon_dead" forces the sign dark, "neon_live"
## re-strikes it. This lets the story author kill and revive neons per line.
func on_line(idx: int) -> void:
	super.on_line(idx)
	if board == null:
		return
	if board.flags.get("neon_dead", false) and not _force_dead:
		_force_dead = true
		_set_brightness(0.0)
		AudioDirector.neon_zap()
	elif board.flags.get("neon_live", false) and _force_dead:
		_force_dead = false
		_cold_restrike()


## Trigger a cold re-strike from dead: the sign warms up over _RESTRIKE_DUR.
func _cold_restrike() -> void:
	modulate = Color(0.15, 0.15, 0.15)
	_set_light_energy(0.04)
	_buzz_on = true
	AudioDirector.neon_zap()
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, _RESTRIKE_DUR)
	if _surface_light:
		tw.parallel().tween_property(_surface_light, "energy", _surface_energy(), _RESTRIKE_DUR)
	if _air_light:
		tw.parallel().tween_property(_air_light, "energy", _air_energy(), _RESTRIKE_DUR)
	_enter_state(_State.BUZZ)


# --- brightness control ---------------------------------------------------------------------

func _set_brightness(f: float) -> void:
	modulate = Color(f, f, f)
	_set_light_energy(f)


func _set_light_energy(f: float) -> void:
	if _surface_light:
		_surface_light.energy = _surface_energy() * f
	if _air_light:
		_air_light.energy = _air_energy() * f
