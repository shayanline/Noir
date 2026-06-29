class_name Neon
extends BoardLight
## A neon sign, built as four layers so it reads as real glowing glass, not a flat coloured stroke:
##   1. Air halo: a soft additive coloured disc behind the sign, the haze hanging in the rainy air.
##   2. Tube: a wide Line2D running neon.gdshader, which draws a hot glass core bleeding into an
##      exponential coloured halo (the tube's own intrinsic glow, not reliant on the screen bloom).
##   3. Label: the sign text, glowing in the same colour, sitting over the halo.
##   4. Spill lights: two PointLight2Ds that throw the sign's colour onto the wall, the wet floor
##      and the rain (the genuine lighting), shadowless because a sign is a glow, not a key.
## The bloom then lifts it all a touch further.
##
## Sizing: w and h are HTML legacy pixels on a 1280-wide reference. Divided by board.unit in
## place() so the board scale renders them at the correct screen size.
##
## Flicker: slow 5 + 13 Hz sine, matching the legacy. One designated sign per act can have
## dropout: true for the occasional full blackout and re-strike; the modulate dims every layer and
## rides into the tube shader through the vertex COLOR, while the spill lights dim by energy.

const _FONT := preload("res://fonts/Oswald.ttf")
const _LIGHT_TEX := preload("res://src/util/soft_glow.tres")
const _NEON_SHADER := preload("res://shaders/neon.gdshader")
const _LABEL_BASE := 24   # the label renders at this size, then scales to fit the sign box
const _TUBE_WIDTH := 14.0 # the glow diameter of the tube in design units: wide so the shader has room to spread its halo

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
var _arrow := false
var _ignite := false
var _dropout := false

## The two PointLight2Ds, built in place().
var _surface_light: PointLight2D   ## sign-shaped, tight surface glow
var _air_light: PointLight2D       ## wide soft air bloom

var _buzz_t := 0.0
var _buzz_on := false

enum _DropState { LIVE, DARK }
var _drop_state := _DropState.LIVE
var _drop_timer := 0.0
const _DROP_INTERVAL_MIN := 4.0
const _DROP_INTERVAL_MAX := 14.0
const _DARK_DUR_MIN := 0.08
const _DARK_DUR_MAX := 0.30

func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	if p.get("w") != null:
		_w_px = float(p["w"])
	if p.get("h") != null:
		_h_px = float(p["h"])
	if p.get("label") != null:
		_label = str(p["label"])
	_arrow = p.get("arrow", _arrow) == true
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
	_build_halo()
	_build_outline()
	_build_label()
	_build_lights()
	if _dropout:
		_drop_timer = randf_range(_DROP_INTERVAL_MIN, _DROP_INTERVAL_MAX)
	if _ignite:
		# Cold start: the sign sits near-dark, then strikes after a beat and the tubes warm up.
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
	else:
		_buzz_on = true


# --- geometry ----------------------------------------------------------------------------------

## The glowing glass tube: a wide Line2D running neon.gdshader. The line is far wider than the glass
## so the shader's across-line UV gives the distance from the centreline, from which it draws the hot
## core and the coloured halo. default_color stays white so the flicker (node modulate) rides cleanly
## into the shader through the vertex COLOR.
func _build_outline() -> void:
	var tube := Line2D.new()
	tube.name = "Outline"
	tube.width = _TUBE_WIDTH
	tube.default_color = Color.WHITE
	tube.texture = _white()
	tube.texture_mode = Line2D.LINE_TEXTURE_TILE
	tube.joint_mode = Line2D.LINE_JOINT_ROUND
	tube.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tube.end_cap_mode = Line2D.LINE_CAP_ROUND
	tube.points = _outline_points()
	var mat := ShaderMaterial.new()
	mat.shader = _NEON_SHADER
	mat.set_shader_parameter("glow_color", color)
	tube.material = mat
	add_child(tube)


## The soft coloured haze hanging in the air around the sign (the glow in space). A radial sprite,
## additive and faint, shaped to the sign and sitting behind the tube. Distinct from the spill
## lights: this is the visible air glow, they are what actually lights the wall and floor.
func _build_halo() -> void:
	var halo := Sprite2D.new()
	halo.name = "Halo"
	halo.texture = _LIGHT_TEX
	halo.position = Vector2(_w * 0.5 + ((_h * 0.45) if _arrow else 0.0), _h * 0.5)
	var tex := float(_LIGHT_TEX.get_width())
	# scale the halo to the sign's footprint plus a comfortable margin, not the max dimension
	var diag := sqrt(_w * _w + _h * _h)
	halo.scale = Vector2((diag * 1.8) / tex, (diag * 1.4) / tex)
	halo.modulate = Color(color.r, color.g, color.b, 0.35)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = m
	add_child(halo)


func _outline_points() -> PackedVector2Array:
	if _arrow:
		var pw := _h * 0.9
		return PackedVector2Array([
			Vector2(0, 0), Vector2(_w, 0), Vector2(_w + pw, _h / 2.0),
			Vector2(_w, _h), Vector2(0, _h), Vector2(0, 0)])
	return PackedVector2Array([
		Vector2(0, 0), Vector2(_w, 0), Vector2(_w, _h),
		Vector2(0, _h), Vector2(0, 0)])


func _build_label() -> void:
	if _label == "":
		return
	var label := Label.new()
	label.name = "SignLabel"
	label.text = _label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _FONT)
	label.add_theme_color_override("font_color", color)
	# A coloured outline fattens the letters into glowing tubes; the halo behind and the bloom do
	# the rest, so the text reads as lit glass rather than a flat caption.
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_font_size_override("font_size", _LABEL_BASE)
	add_child(label)
	# A Control parented to a Node2D auto-sizes to its text and ignores any size we set, so instead
	# we render the label at a fixed base size, then scale the whole label to fit inside the sign
	# box (with a small margin) and centre it on the box. Works for any box shape, wide or tall.
	label.reset_size()
	var pad := 0.84
	var s: float = minf(_w / maxf(label.size.x, 1.0), _h / maxf(label.size.y, 1.0)) * pad
	label.scale = Vector2(s, s)
	label.position = (Vector2(_w, _h) - label.size * s) * 0.5


# --- lights ------------------------------------------------------------------------------------
## Two additive PointLight2Ds matching the HTML v2 light model:
## surface glow (sign-shaped ellipse) and air glow (large soft disc).

func _build_lights() -> void:
	var cx := _w / 2.0 + ((_h * 0.45) if _arrow else 0.0)
	var cy := _h / 2.0

	# Surface light: shaped to the sign's w/h ratio. The PointLight2D uses the radial texture;
	# we squash its own scale on x to match the sign's aspect ratio.
	_surface_light = PointLight2D.new()
	_surface_light.texture = _LIGHT_TEX
	_surface_light.color = color
	_surface_light.energy = _surface_energy()
	_surface_light.position = Vector2(cx, cy)
	# Sign aspect: scale x to match w/h so the light pool is elliptical.
	var aspect := _w / maxf(_h, 1.0)
	var base_scale := maxf(_w, _h) * 1.1 / 64.0   # 64 = texture size
	_surface_light.texture_scale = base_scale
	_surface_light.scale = Vector2(aspect if aspect < 1.0 else 1.0, 1.0 if aspect < 1.0 else 1.0 / aspect)
	_surface_light.blend_mode = Light2D.BLEND_MODE_ADD
	# A neon sign is a glow, not a key: it spills its colour onto the wall and the wet floor but does
	# not throw hard figure shadows (that is the lamp's job), so it stays a shadowless glow.
	LightKit.ambient(_surface_light)
	add_child(_surface_light)

	# Air light: a wide soft disc, the atmospheric bloom in the air around the sign.
	_air_light = PointLight2D.new()
	_air_light.texture = _LIGHT_TEX
	_air_light.color = color
	_air_light.energy = _air_energy()
	_air_light.position = Vector2(cx, cy)
	_air_light.texture_scale = maxf(_w, _h) * 2.6 / 64.0   # a wide coloured halo in the air
	_air_light.blend_mode = Light2D.BLEND_MODE_ADD
	LightKit.ambient(_air_light)   # pure atmosphere, no shadows of its own
	add_child(_air_light)

	# Keep _light (from BoardLight) pointing at the surface light for the base class flicker.
	_light = _surface_light
	_base_energy = _surface_energy()


func _surface_energy() -> float:
	# The tight coloured pool the sign throws on its own wall and the wet floor. Kept moderate now
	# the tube has its own intrinsic glow, so the layers do not stack up to white.
	return 1.4 * intensity


func _air_energy() -> float:
	# The broad coloured spill of the sign onto the surroundings and the rain.
	return 0.6 * intensity


# --- flicker -----------------------------------------------------------------------------------

func on_tick() -> void:
	# Do not call super.on_tick(): BoardLight.on_tick() drives the single _light which we
	# manage ourselves here. Calling super would double-flicker the surface light.
	if not _buzz_on:
		return
	var dt := get_process_delta_time()
	if _dropout:
		_tick_dropout(dt)
	else:
		_apply_buzz(dt)


func _apply_buzz(dt: float) -> void:
	_buzz_t += dt
	var f: float
	if sin(_buzz_t * 5.0) > -0.95:
		f = 0.88 + 0.12 * sin(_buzz_t * 13.0)
	else:
		f = 0.5
	_set_brightness(f)


func _tick_dropout(dt: float) -> void:
	_drop_timer -= dt
	match _drop_state:
		_DropState.LIVE:
			_apply_buzz(dt)
			if _drop_timer <= 0.0:
				_drop_state = _DropState.DARK
				_drop_timer = randf_range(_DARK_DUR_MIN, _DARK_DUR_MAX)
				_set_brightness(0.0)
		_DropState.DARK:
			if _drop_timer <= 0.0:
				_drop_state = _DropState.LIVE
				_drop_timer = randf_range(_DROP_INTERVAL_MIN, _DROP_INTERVAL_MAX)
				_buzz_t = 0.0
				_set_brightness(1.0)


func _set_brightness(f: float) -> void:
	modulate = Color(f, f, f)
	_set_light_energy(f)


func _set_light_energy(f: float) -> void:
	if _surface_light:
		_surface_light.energy = _surface_energy() * f
	if _air_light:
		_air_light.energy = _air_energy() * f
