class_name Board
extends Node2D
## The act host. It builds the act as a real scene tree:
## the backdrop, the light fixtures, the cast (each a BoardObject scene), plus the key light, the
## moon and the weather as Godot nodes. Lighting is native (PointLight2D / DirectionalLight2D over
## a global CanvasModulate), so there is no per frame repaint. Main drives it by act and line.

signal shake_requested(amount: float)
## fanned out to the spawned objects; each object connects its on_line / on_fx on spawn.
signal line_changed(index: int)
signal fx(event: String)

const RAIN_SCENE := preload("res://scenes/effects/RainField.tscn")
const RIPPLES_SCENE := preload("res://scenes/effects/RainRipples.tscn")
const SPLASH_SCENE := preload("res://scenes/effects/RainSplash.gd")
const OBJECT_SPLASH_SCENE := preload("res://scenes/effects/ObjectRainSplash.gd")
const WET_FLOOR_SCENE := preload("res://scenes/effects/WetFloor.gd")
const NIGHTSKY_SCENE := preload("res://scenes/effects/NightSky.tscn")
const LIGHTNING_SCENE := preload("res://scenes/effects/Lightning.tscn")

var act: Act

var size := Vector2(1280, 720)
var unit := 2.0
var ground_y := 576.0
var look := 0.0

var line_index := 0

var flags := {}

## the moon's pixel position, shared by the visible moon (NightSky) and the moonlight (PointLight2D)
var _moon_px := Vector2.ZERO

var _key_light: PointLight2D
var _moon_light: PointLight2D
var _rain: RainField
var _ripples: RainRipples
var _splash: RainSplash
var _lightning: Lightning
var _light_sync_timer := 0.0
const _LIGHT_SYNC_INTERVAL := 0.2   ## how often ripple lights are refreshed (seconds)


func setup(a: Act) -> void:
	act = a


func _ready() -> void:
	var r := UIScale.content_rect
	size = r.size if r.size.x > 2.0 else get_viewport_rect().size
	if size.x < 2.0:
		size = Vector2(1280, 720)
	position = r.position
	unit = minf(size.x, size.y) / BoardObject.DESIGN_HEIGHT
	ground_y = act.ground * size.y
	_moon_px = Vector2(act.moon.x * size.x, act.moon.y * size.y)
	GameState.line_changed.connect(_on_state_line)
	GameState.fx_fired.connect(_on_state_fx)
	_build_sky()
	_build_lighting()
	_build_content()
	_build_weather()


# --- build ---------------------------------------------------------------------------------

## The graded night sky, stars, the visible moon and drifting clouds, placed behind the backdrop.
## Outdoor only. The moonlight itself is a PointLight2D built in _build_lighting at the same point.
func _build_sky() -> void:
	if act.indoor:
		return
	var sky: NightSky = NIGHTSKY_SCENE.instantiate()
	sky.area = size
	sky.ground_y = ground_y
	sky.has_moon = act.has_moon      # per-act: each act decides whether it shows a moon, and where
	sky.show_clouds = _is_rooftop()  # clouds only on the rooftop
	sky.moon_px = _moon_px
	sky.z_index = -150
	add_child(sky)
	# The sky is distant: only the moon and the broad fill light it. Keeping it off the foreground
	# layer stops the key (and the street lamp) from painting a bright patch across the night sky.
	_set_light_mask_deep(sky, LAYER_BACKDROP)


## Whether this act's backdrop is the rooftop (the only place we let clouds drift).
func _is_rooftop() -> bool:
	return act.backdrop != null and act.backdrop.scene != null \
		and act.backdrop.scene.resource_path.ends_with("Rooftop.tscn")


func _build_lighting() -> void:
	# a broad, dim fill so the cast never falls to pure black, the cool bounce of a rainy night
	var fill := PointLight2D.new()
	fill.texture = LightTex.radial()
	fill.position = Vector2(size.x * 0.5, size.y * 0.42)
	fill.texture_scale = size.x / 256.0 * 4.5
	# the ambient floor, a gentle lift so the cast reads without turning this into a second key.
	# Kept low so the key's shadows stay deep and read, rather than being filled back in.
	fill.energy = 0.42
	fill.color = Color(0.66, 0.72, 0.85) if not act.indoor else Color(0.5, 0.52, 0.6)
	LightKit.ambient(fill)   # broad bounce, never a shadow caster
	fill.range_item_cull_mask = LAYER_FOREGROUND | LAYER_BACKDROP   # lifts the whole scene, near and far
	add_child(fill)

	_key_light = PointLight2D.new()
	_key_light.texture = LightTex.radial()
	_key_light.position = Vector2(act.key_light.x * size.x, act.key_light.y * size.y)
	_key_light.texture_scale = size.x / 256.0 * 2.8
	_key_light.energy = 1.3
	_key_light.color = Color(1.0, 0.96, 0.86)
	# The key is a broad fill that shapes the scene (the legacy 'bounce/rim'); the hard, positioned
	# shadows come from the practical lights (the lamp gobo, fire, the doorway), not from this. A
	# huge key casting a sharp figure shadow across the whole city read as an unnatural shaft.
	LightKit.ambient(_key_light)
	_key_light.range_item_cull_mask = LAYER_FOREGROUND   # never paints the far sky
	add_child(_key_light)

	# the moonlight: two coincident PointLight2Ds at the visible moon position.
	# Layer 1, the fill: broad, shadowless, the cool grade that lifts the whole scene.
	# Layer 2, the caster: low energy, large radius, very soft PCF so shadows are crisp and long
	# (the moon is a distant, parallel-ish source) but not pixel-sharp. This is the shadow that
	# turns a rooftop coat or a fire escape rail into a classic noir silhouette.
	if act.has_moon and not act.indoor:
		_moon_light = PointLight2D.new()
		_moon_light.texture = LightTex.radial()
		_moon_light.position = _moon_px
		_moon_light.texture_scale = size.x / 256.0 * 3.4
		_moon_light.energy = 0.55   # a weak, broad cool wash, not a hot pool
		_moon_light.color = Palette.MOON
		LightKit.ambient(_moon_light)   # the fill: lifts the scene, casts no shadow
		_moon_light.range_item_cull_mask = LAYER_FOREGROUND | LAYER_BACKDROP   # lights sky too
		add_child(_moon_light)

		# Shadow caster: a second, lower-energy moon that throws the real cast shadows. It is
		# intentionally dim (0.18) so it does not relight the scene, only deepen the shadow story.
		# A very large radius (covers the whole frame from the moon position) and a very low smooth
		# (0.5) give long, near-parallel crisp shadows, which is physically correct for a distant source.
		var moon_caster := PointLight2D.new()
		moon_caster.texture = LightTex.radial()
		moon_caster.position = _moon_px
		moon_caster.texture_scale = size.x / 256.0 * 5.5
		moon_caster.energy = 0.18
		moon_caster.color = Palette.MOON
		LightKit.caster(moon_caster, LightKit.COOL, 0.5)   # crisp, long, cool shadows
		moon_caster.range_item_cull_mask = LAYER_FOREGROUND
		add_child(moon_caster)


## Light layers (CanvasItem.light_mask / Light2D.range_item_cull_mask):
##   bit 1 = the foreground (cast, floor, fixtures): lit by the key and the local lights, and where
##           real shadows fall.
##   bit 2 = the distant backdrop (sky, far city): lit only by the broad ambient (moon, fill) so it
##           keeps depth, but the key and local lights never reach it, so foreground figures cannot
##           cast hard shadows across the faraway skyline.
const LAYER_FOREGROUND := 1
const LAYER_BACKDROP := 2


func _build_content() -> void:
	if act.backdrop and act.backdrop.scene:
		# The city buildings stay on the foreground layer so the neon, the lamp and the traffic light
		# glow on them. Only the far sky is held back (see _build_sky), so nothing paints the night.
		_spawn(act.backdrop, -100)
	# Light fixtures do not build occluders: their own light sits right inside their structure (the
	# key light at a lamp, the glow at a sign), so self-occlusion only carves ugly wedges. The cast
	# and props are the shadow casters, their bright parts skipped so a flame never blocks itself.
	for p in act.lights:
		_spawn(p, -10)
	for p in act.cast:
		var obj := _spawn(p, 0)
		if obj:
			obj.build_occluders()
			obj.apply_volume_light()
			if not act.indoor:
				_attach_object_splash(obj)


## Set light_mask on a node and all its CanvasItem descendants, so a whole backdrop joins one layer.
func _set_light_mask_deep(node: Node, mask: int) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = mask
	for c in node.get_children():
		_set_light_mask_deep(c, mask)


func _spawn(p: Placement, base_z: int) -> BoardObject:
	if p == null or p.scene == null:
		return null
	var obj: BoardObject = p.scene.instantiate()
	obj.setup(p.params, self)
	add_child(obj)
	obj.place()
	obj.z_index = base_z + obj.depth
	obj.add_to_group("board_object")
	line_changed.connect(obj.on_line)
	fx.connect(obj.on_fx)
	return obj


## Hang a rain splash off the object's top silhouette, so drops visibly catch on it (a hat,
## shoulders, a car roof). Parented to the object so it scales, walks and hides with it. Skipped
## for objects with no solid art (a sign drawn only from lines or labels yields no silhouette).
func _attach_object_splash(obj: BoardObject) -> void:
	var pts := obj.top_silhouette_points()
	if pts.is_empty():
		return
	var splash := OBJECT_SPLASH_SCENE.new()
	splash.blood = act.blood_rain
	splash.points = pts
	splash.z_index = 1   # just above the object's own art
	obj.add_child(splash)


## Gather all light positions, colours and radii for ripple light sampling. BoardLight subclasses
## (Lamp, Neon, Bulb) report their own contributions through get_light_contributions(), so this
## method does not need to reach into each fixture's internals. Bare PointLight2Ds (the key, the
## moon, the fill) are collected directly.
func _collect_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in get_children():
		if child is BoardLight:
			out.append_array((child as BoardLight).get_light_contributions())
		elif child is PointLight2D:
			var L: PointLight2D = child
			out.append({
				"pos": L.position,
				"col": L.color,
				"radius": L.texture_scale * 128.0,
				"energy": L.energy,
			})
	return out


func _build_weather() -> void:
	if act.indoor:
		return
	_rain = RAIN_SCENE.instantiate()
	_rain.blood = act.blood_rain
	_rain.area = size
	_rain.ground_y = ground_y
	_rain.z_index = 60
	add_child(_rain)
	_ripples = RIPPLES_SCENE.instantiate()
	_ripples.blood = act.blood_rain
	_ripples.area = size
	_ripples.ground_y = ground_y
	_ripples.lights = _collect_lights()
	_ripples.z_index = 55
	add_child(_ripples)
	_splash = SPLASH_SCENE.new()
	_splash.blood = act.blood_rain
	_splash.area = size
	_splash.ground_y = ground_y
	_splash.z_index = 58
	add_child(_splash)
	var wet_floor := WetFloor.new()
	wet_floor.area = size
	wet_floor.ground_y = ground_y
	add_child(wet_floor)
	_lightning = LIGHTNING_SCENE.instantiate()
	_lightning.area = size
	_lightning.z_index = 70
	add_child(_lightning)


# --- live light sync (ripple coupling) -----------------------------------------------------

func _process(delta: float) -> void:
	if _ripples == null:
		return
	_light_sync_timer -= delta
	if _light_sync_timer <= 0.0:
		_light_sync_timer = _LIGHT_SYNC_INTERVAL
		_ripples.lights = _collect_lights()


# --- flow ----------------------------------------------------------------------------------

func _on_state_line(idx: int) -> void:
	line_index = idx
	line_changed.emit(idx)


func _on_state_fx(event: String) -> void:
	match event:
		"muzzle":
			flags["muzzle"] = true
			shake_requested.emit(6.0)
		"blood":
			flags["blood"] = true
		"lightning":
			if _lightning:
				_lightning.strike()
	fx.emit(event)
