class_name Lamp
extends BoardLight
## A street lamp fixture with multiple visual styles and a data driven light distribution.
##
## Style variants (set via the "style" param, default "classic"):
##   classic    the original thin pole with an arm bracket and a small lamp head.
##   cobra      a modern highway lamp: a curved arm and a flat rectangular shade.
##   hanging    a wire and shade, close to the Bulb but projecting a downward cone.
##   victorian  an ornate bracket with a lantern housing.
##
## Light character is data driven: temperature (colour warmth), softness (shadow PCF), reach
## (pool size), gobo (light distribution shape), and sway (a slow pendulum for hanging fixtures).
##
## The visible beam of light in the rainy air is an animated shader driven sprite that responds
## to the lamp's flicker state and only appears outdoors (when rain is present).

const _BEAM_SHADER := preload("res://shaders/lamp_beam.gdshader")
const _INK := Color(0.0078, 0.0078, 0.0118)

## Colour temperature presets: Kelvin mapped to a tinted white, from deep sodium amber to cool LED.
const _TEMP_COLORS := {
	2200: Color(1.0, 0.82, 0.50),   # sodium vapour, deep amber
	2700: Color(1.0, 0.87, 0.62),   # warm incandescent
	3500: Color(1.0, 0.93, 0.78),   # standard warm white (the original default)
	4200: Color(1.0, 0.96, 0.88),   # neutral white
	5000: Color(0.95, 0.96, 1.0),   # cool daylight LED
}

## Params read from the story placement.
var _style := "classic"
var _gobo := "cone"
var _temperature := 3500
var _softness := 2.5
var _reach := 1.7
var _sway := 0.0
var _beam: Sprite2D
var _beam_base_alpha := 0.13
var _sway_t := 0.0
var _light_base_x := 0.0


func on_object_params(p: Dictionary) -> void:
	super.on_object_params(p)
	if p.get("style") != null:
		_style = str(p["style"])
	if p.get("gobo") != null:
		_gobo = str(p["gobo"])
	if p.get("temperature") != null:
		_temperature = int(p["temperature"])
	if p.get("softness") != null:
		_softness = float(p["softness"])
	if p.get("reach") != null:
		_reach = float(p["reach"])
	if p.get("sway") != null:
		_sway = float(p["sway"])
	# Hanging style defaults to a pendant gobo and gentle sway if not overridden.
	if _style == "hanging":
		if p.get("gobo") == null:
			_gobo = "pendant"
		if p.get("sway") == null:
			_sway = 0.6
	elif _style == "cobra":
		if p.get("gobo") == null:
			_gobo = "cobra"
	elif _style == "victorian":
		if p.get("gobo") == null:
			_gobo = "globe"


func _ready() -> void:
	_build_style_geometry()
	var light := _find_light(self)
	if light:
		light.texture = LightTex.gobo(_gobo)
		light.color = _temp_color()
		light.energy = 1.9
		light.texture_scale = _reach
		LightKit.caster(light, LightKit.WARM, _softness)
		_light_base_x = light.position.x
		_build_beam(light.position)
	# Overdrive the glass lens so the bloom pass reads it as a real bright source.
	var glass := get_node_or_null("Glass")
	if glass is Polygon2D:
		var tc := _temp_color()
		(glass as Polygon2D).color = Color(tc.r * 1.5, tc.g * 1.48, tc.b * 1.35)


## Resolve the colour temperature to a tint. Snaps to the nearest preset.
func _temp_color() -> Color:
	var best_k := 3500
	var best_d := 99999
	for k in _TEMP_COLORS:
		var d := absi(k - _temperature)
		if d < best_d:
			best_d = d
			best_k = k
	return _TEMP_COLORS[best_k]


# --- beam (improvement 2) -------------------------------------------------------------------

## The visible shaft of light in the rainy air. Uses a shader with scrolling noise so the beam
## reads as backlit rain particles. Only builds outdoors (board has no act.indoor flag accessible
## here, but if the board is indoor the rain will not be there and a beam makes no visual sense,
## so we always build it and let the story author suppress it with "beam": false if needed).
func _build_beam(light_pos: Vector2) -> void:
	_beam = Sprite2D.new()
	_beam.name = "Beam"
	_beam.texture = LightTex.gobo(_gobo)
	_beam.position = light_pos
	_beam.scale = Vector2(_reach, _reach)
	var tc := _temp_color()
	_beam.modulate = Color(tc.r, tc.g, tc.b, _beam_base_alpha)
	var mat := ShaderMaterial.new()
	mat.shader = _BEAM_SHADER
	mat.set_shader_parameter("beam_color", tc)
	mat.set_shader_parameter("beam_alpha", _beam_base_alpha)
	_beam.material = mat
	_beam.z_index = -3
	add_child(_beam)


# --- flicker and sway (improvement 3) -------------------------------------------------------

func on_tick() -> void:
	super.on_tick()
	# Couple the beam brightness to the flicker state so the shaft dims with the lamp.
	if _beam and _light:
		var f := _light.energy / maxf(_base_energy, 0.01)
		_beam.modulate.a = _beam_base_alpha * clampf(f, 0.0, 1.0)
	# Sway: a slow pendulum offset on the light, giving hanging and victorian lamps a gentle
	# shadow rock. The fixture geometry stays still (it is authored as rigid ink), only the
	# PointLight2D and beam shift, which reads as the light source swinging.
	if _sway > 0.0 and _light:
		_sway_t += get_process_delta_time() * Palette.SWAY_SPEED
		var offset_x := sin(_sway_t) * _sway * 8.0
		_light.position.x = _light_base_x + offset_x
		if _beam:
			_beam.position.x = _light.position.x


# --- style geometry (improvement 5) ---------------------------------------------------------

## Build the fixture geometry for the chosen style. The "classic" style uses the Polygon2D nodes
## already authored in Lamp.tscn (Pole, Arm, Head, Glass). Other styles remove those and build
## their own silhouette as new child nodes.
func _build_style_geometry() -> void:
	if _style == "classic":
		_build_classic_details()
		return
	# Remove the default geometry (Pole, Arm, Head, Glass remain only for classic).
	for name in ["Pole", "Arm", "Head", "Glass"]:
		var n := get_node_or_null(name)
		if n:
			n.queue_free()
	match _style:
		"cobra":
			_build_cobra()
		"hanging":
			_build_hanging()
		"victorian":
			_build_victorian()
		_:
			_build_classic_details()


## Classic style: add a mounting plate at the base and a rivet detail at the arm joint.
func _build_classic_details() -> void:
	# Mounting plate at the base.
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(4, -3), Vector2(-4, -3)])
	plate.color = _INK
	add_child(plate)
	# Small rivet detail at the arm joint.
	var rivet := Polygon2D.new()
	rivet.name = "Rivet"
	rivet.polygon = _circle_poly(Vector2(0, -150), 2.5, 6)
	rivet.color = _INK
	add_child(rivet)


## Cobra style: a curved arm, a flat rectangular shade, no glass polygon. The light mounts
## under the flat shade.
func _build_cobra() -> void:
	# Pole: slightly wider than classic.
	var pole := Polygon2D.new()
	pole.name = "Pole"
	pole.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(3, 0), Vector2(3, -140), Vector2(-3, -140)])
	pole.color = _INK
	add_child(pole)
	# Curved arm: approximated as a series of line segments, drawn as a Line2D.
	var arm := Line2D.new()
	arm.name = "Arm"
	arm.width = 4.0
	arm.default_color = _INK
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var ax := t * 30.0
		var ay := -140.0 - sin(t * PI * 0.5) * 18.0
		pts.append(Vector2(ax, ay))
	arm.points = pts
	add_child(arm)
	# Flat rectangular shade.
	var shade := Polygon2D.new()
	shade.name = "Head"
	shade.polygon = PackedVector2Array([
		Vector2(15, -158), Vector2(40, -158), Vector2(40, -154), Vector2(15, -154)])
	shade.color = _INK
	add_child(shade)
	# Glass lens under the shade.
	var glass := Polygon2D.new()
	glass.name = "Glass"
	glass.polygon = PackedVector2Array([
		Vector2(20, -154), Vector2(35, -154), Vector2(35, -152), Vector2(20, -152)])
	glass.color = Color(1, 0.98, 0.9)
	add_child(glass)
	# Mounting plate.
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0), Vector2(5, -4), Vector2(-5, -4)])
	plate.color = _INK
	add_child(plate)
	# Move the light to the shade position.
	var light := get_node_or_null("Light")
	if light:
		light.position = Vector2(27, -152)


## Hanging style: a thin wire drops from above to a conical shade with a bulb.
func _build_hanging() -> void:
	var wire := Line2D.new()
	wire.name = "Wire"
	wire.width = 1.0
	wire.default_color = _INK
	wire.points = PackedVector2Array([Vector2(0, -180), Vector2(0, -150)])
	add_child(wire)
	# Conical shade.
	var shade := Polygon2D.new()
	shade.name = "Head"
	shade.polygon = PackedVector2Array([
		Vector2(-2, -156), Vector2(2, -156), Vector2(14, -148), Vector2(-14, -148)])
	shade.color = _INK
	add_child(shade)
	# Glass (the opening at the bottom of the shade).
	var glass := Polygon2D.new()
	glass.name = "Glass"
	glass.polygon = _circle_poly(Vector2(0, -148), 3.5, 8)
	glass.color = Color(1, 0.98, 0.9)
	add_child(glass)
	# Move the light to the shade opening.
	var light := get_node_or_null("Light")
	if light:
		light.position = Vector2(0, -146)


## Victorian style: an ornate bracket with a lantern housing.
func _build_victorian() -> void:
	# Pole with a slight taper.
	var pole := Polygon2D.new()
	pole.name = "Pole"
	pole.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(3, 0), Vector2(2.5, -145), Vector2(-2.5, -145)])
	pole.color = _INK
	add_child(pole)
	# Ornate bracket: a scrollwork curve, drawn as a Line2D.
	var bracket := Line2D.new()
	bracket.name = "Bracket"
	bracket.width = 3.0
	bracket.default_color = _INK
	var pts := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		var bx := t * 22.0
		var by := -145.0 - sin(t * PI) * 12.0
		pts.append(Vector2(bx, by))
	bracket.points = pts
	add_child(bracket)
	# A small scroll detail curling back from the bracket tip.
	var scroll := Line2D.new()
	scroll.name = "Scroll"
	scroll.width = 2.0
	scroll.default_color = _INK
	var spts := PackedVector2Array()
	for i in 7:
		var t := float(i) / 6.0
		var sx := 22.0 - t * 6.0
		var sy := -145.0 - sin(t * PI * 1.5) * 5.0
		spts.append(Vector2(sx, sy))
	scroll.points = spts
	add_child(scroll)
	# Lantern housing: four trapezoidal panes.
	var lantern_y := -160.0
	var lantern_w := 8.0
	var lantern_h := 16.0
	var lx := 22.0
	# Left pane.
	var lp := Polygon2D.new()
	lp.name = "LanternLeft"
	lp.polygon = PackedVector2Array([
		Vector2(lx - lantern_w, lantern_y), Vector2(lx - lantern_w * 0.6, lantern_y),
		Vector2(lx - lantern_w * 0.6, lantern_y + lantern_h), Vector2(lx - lantern_w, lantern_y + lantern_h)])
	lp.color = _INK
	add_child(lp)
	# Right pane.
	var rp := Polygon2D.new()
	rp.name = "LanternRight"
	rp.polygon = PackedVector2Array([
		Vector2(lx + lantern_w * 0.6, lantern_y), Vector2(lx + lantern_w, lantern_y),
		Vector2(lx + lantern_w, lantern_y + lantern_h), Vector2(lx + lantern_w * 0.6, lantern_y + lantern_h)])
	rp.color = _INK
	add_child(rp)
	# Top cap.
	var cap := Polygon2D.new()
	cap.name = "LanternCap"
	cap.polygon = PackedVector2Array([
		Vector2(lx - lantern_w * 0.7, lantern_y - 2), Vector2(lx + lantern_w * 0.7, lantern_y - 2),
		Vector2(lx + lantern_w * 0.4, lantern_y - 6), Vector2(lx - lantern_w * 0.4, lantern_y - 6)])
	cap.color = _INK
	add_child(cap)
	# Finial on top.
	var finial := Polygon2D.new()
	finial.name = "Finial"
	finial.polygon = _circle_poly(Vector2(lx, lantern_y - 8), 2.0, 6)
	finial.color = _INK
	add_child(finial)
	# Glass (the visible part between the panes).
	var glass := Polygon2D.new()
	glass.name = "Glass"
	glass.polygon = PackedVector2Array([
		Vector2(lx - lantern_w * 0.55, lantern_y + 2), Vector2(lx + lantern_w * 0.55, lantern_y + 2),
		Vector2(lx + lantern_w * 0.55, lantern_y + lantern_h - 2), Vector2(lx - lantern_w * 0.55, lantern_y + lantern_h - 2)])
	glass.color = Color(1, 0.98, 0.9)
	add_child(glass)
	# Mounting plate.
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(4, -3), Vector2(-4, -3)])
	plate.color = _INK
	add_child(plate)
	# Move the light to the lantern centre.
	var light := get_node_or_null("Light")
	if light:
		light.position = Vector2(lx, lantern_y + lantern_h * 0.5)


## Utility: generate a small circle as a PackedVector2Array for rivets, finials, and bulbs.
static func _circle_poly(centre: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(centre + Vector2(cos(a) * radius, sin(a) * radius))
	return pts
