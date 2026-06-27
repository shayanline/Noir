extends Node2D
## A natively rendered noir act, the data driven host. It builds the world / light / weather
## canvases, the registry, the frame and the scene from the story data, then each frame rebuilds
## the lights, updates the simulation and repaints. Solid art draws to the world canvas, the
## additive light buffer composites the glow + reflections, weather falls over the lit scene.
## This is the native equal of Inkfall's compositor + scene, driven entirely by the story.

signal shake_requested(amount: float)

var _data := {}
var _registry: NoirRegistry
var _frame: NoirFrame
var _scene: NoirScene

var _world: _Canvas
var _light: _Canvas
var _weather: _Canvas

var _size: Vector2
var _drops: Array = []


class _Canvas extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _ready() -> void:
	_size = get_viewport_rect().size
	if _size.x < 2.0:
		_size = Vector2(1280, 720)

	_registry = NoirRegistry.new()
	NoirLibrary.register_all(_registry)

	_frame = NoirFrame.new()
	_frame.W = _size.x
	_frame.H = _size.y
	_frame.unit = min(_size.x, _size.y) / 360.0

	_scene = NoirScene.new(_data, _registry)
	_scene.build_content()
	_frame.scene = _scene

	_world = _Canvas.new()
	_world.z_index = 0
	_world.painter = _paint_world
	add_child(_world)

	_light = _Canvas.new()
	_light.z_index = 10
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add_mat
	_light.painter = _paint_light
	add_child(_light)

	_weather = _Canvas.new()
	_weather.z_index = 20
	_weather.painter = _paint_weather
	add_child(_weather)

	_init_rain()

	# prime the frame clock + geometry + first line so the very first paint is correct
	_frame.t = Time.get_ticks_msec() / 1000.0
	_scene.scene_start = _frame.t
	_scene.line_start = _frame.t
	_scene.ensure_geometry(_frame)


# called by Main before the panel is added to the tree
func setup(scene_data: Dictionary) -> void:
	_data = scene_data


func _process(delta: float) -> void:
	if _scene == null:
		return
	_frame.t = Time.get_ticks_msec() / 1000.0
	_frame.dt = min(delta, 0.05)
	_scene.ensure_geometry(_frame)

	# update simulation, then rebuild the light list for this frame (flicker + moving sources)
	_scene.update(_frame.dt, _frame)
	_frame.lights = []
	_emit_sky_light(_frame)
	_scene.collect_lights(_frame)

	_world.queue_redraw()
	_light.queue_redraw()
	_weather.queue_redraw()


# --- flow hooks called by Main -------------------------------------------------------------

func set_line(idx: int) -> void:
	_scene.set_line(idx, _frame)


func on_fx(name: String) -> void:
	match name:
		"muzzle":
			_scene.flags["muzzle"] = 1.0
			_scene.fire_gun(_frame, self)
			shake_requested.emit(6.0)
		"blood":
			_scene.flags["blood"] = true
			_scene.flags["_blood_t"] = _frame.t
		"lightning":
			_scene.lightning = maxf(_scene.lightning, 0.8)
			if randf() < 0.85:
				_scene.bolt_seed = randi()
			get_tree().create_timer(0.2 + randf() * 0.4).timeout.connect(AudioDirector.thunder)
		"hammer":
			AudioDirector.gun_cock()
		"lighter":
			AudioDirector.lid_open()
			get_tree().create_timer(0.65).timeout.connect(AudioDirector.flint)


# --- paint passes --------------------------------------------------------------------------

func _paint_world(canvas: CanvasItem) -> void:
	_frame.begin(canvas, true)
	_frame.glows.clear()
	_draw_sky(_frame)
	_scene.draw_back(_frame)
	_scene.draw_backdrop(_frame)
	_scene.draw_fixtures(_frame)
	_scene.draw_objects(_frame)


func _paint_light(canvas: CanvasItem) -> void:
	_frame.begin(canvas, false)
	NoirLight.draw_light_layer(_frame)
	_frame.replay_glows()
	_scene.draw_light_extras(_frame)


func _paint_weather(canvas: CanvasItem) -> void:
	_frame.begin(canvas, false)
	if _scene.indoor:
		_scene.lightning = 0.0
		return
	_draw_rain(_frame, _scene.blood_rain)
	if _scene.bolt_seed != null:
		_draw_bolt(_frame, int(_scene.bolt_seed))
	if _scene.lightning > 0.0:
		_frame.fill_rect(0, 0, _frame.W, _frame.H, Color(1, 1, 1, _scene.lightning * 0.5))


# --- sky (port of render/passes/sky.js) ----------------------------------------------------

func _emit_sky_light(f: NoirFrame) -> void:
	if _scene.indoor:
		return
	var m = _scene.moon if _scene.moon != null else {"x": 0.78, "y": 0.18}
	var mx: float = m["x"] * f.W + f.look * 0.1
	var my: float = m["y"] * f.H
	if my < f.gy:
		f.add_light({
			"x": mx, "y": my, "col": Color(210.0 / 255.0, 222.0 / 255.0, 245.0 / 255.0),
			"r": f.H * 0.62, "I": 0.3, "glow": false,
			"refl_w": 26.0, "refl_i": 0.13, "refl_len": 0.8,
		})


func _draw_sky(f: NoirFrame) -> void:
	f.fill_rect_vgrad3(0, 0, f.W, f.H, Palette.SKY_TOP, Palette.SKY_MID, Palette.SKY_LOW, 0.55)
	for i in 40:
		var sx := fmod(i * 197.3, f.W)
		var sy := fmod(i * 91.7, f.H * 0.4)
		if (i * 13) % 5 == 0:
			f.fill_rect(sx, sy, 1.4, 1.4, Color(200.0 / 255.0, 210.0 / 255.0, 230.0 / 255.0, 0.5))
	if _scene.indoor:
		return
	var m = _scene.moon if _scene.moon != null else {"x": 0.78, "y": 0.18}
	var mx: float = m["x"] * f.W + f.look * 0.1
	var my: float = m["y"] * f.H
	var mr := 34.0
	f.fill_radial(mx, my, mr, Color("f6f8fc"), Color("bcc4d4"))
	var crater := Color(116.0 / 255.0, 128.0 / 255.0, 152.0 / 255.0, 0.55)
	f.circle(mx - 9, my - 5, 6, crater)
	f.circle(mx + 11, my + 9, 8, crater)
	f.circle(mx + 5, my - 13, 3.5, crater)
	f.circle(mx - 13, my + 11, 4, crater)
	# halo ring, additive on the light layer (registered as a deferred glow during the world pass)
	f.glow_radial(mx, my, 94.0, Color(210.0 / 255.0, 222.0 / 255.0, 245.0 / 255.0), 0.22)


# --- weather (port of render/passes/weather.js) --------------------------------------------

func _init_rain() -> void:
	_drops.clear()
	var n := int((_size.x * _size.y) / 5200.0)
	for i in n:
		_drops.append({
			"x": randf() * (_size.x + 200.0) - 100.0,
			"y": randf() * _size.y,
			"len": 8.0 + randf() * 16.0,
			"sp": 9.0 + randf() * 9.0,
		})


func _draw_rain(f: NoirFrame, blood_rain: bool) -> void:
	var lit := not blood_rain and not f.lights.is_empty()
	var base_col := Color(168.0 / 255.0, 8.0 / 255.0, 16.0 / 255.0, Palette.RAIN_ALPHA + 0.22) if blood_rain else Color(180.0 / 255.0, 190.0 / 255.0, 210.0 / 255.0, Palette.RAIN_ALPHA)
	var width := 1.6 if blood_rain else 1.1
	var drift := []
	drift.resize(_drops.size())
	for i in _drops.size():
		var d: Dictionary = _drops[i]
		d["y"] += d["sp"] * f.dt * 60.0
		d["x"] -= d["sp"] * f.dt * 21.0
		if d["y"] > f.H:
			d["y"] = -10.0
			d["x"] = randf() * (f.H + 200.0) - 50.0
		var bi := -1
		if lit:
			var bw := 0.3
			for k in f.lights.size():
				var L: Dictionary = f.lights[k]
				var w: float = L["I"] * (1.0 - Vector2(d["x"] - L["x"], (d["y"] - L["y"]) * 0.6).length() / L["r"])
				if w > bw:
					bw = w
					bi = k
		drift[i] = bi
		if bi < 0:
			f.line(Vector2(d["x"], d["y"]), Vector2(d["x"] - d["len"] * 0.35, d["y"] + d["len"]), base_col, width)
	if lit:
		for k in f.lights.size():
			var L: Dictionary = f.lights[k]
			var lc: Color = L["col"]
			var col := Color(lc.r, lc.g, lc.b, Palette.RAIN_ALPHA + 0.1)
			for i in _drops.size():
				if drift[i] == k:
					var d: Dictionary = _drops[i]
					f.line(Vector2(d["x"], d["y"]), Vector2(d["x"] - d["len"] * 0.35, d["y"] + d["len"]), col, width)


func _draw_bolt(f: NoirFrame, seed_value: int) -> void:
	var rng := NoirMath.rand32(seed_value)
	var x := f.W * (0.2 + rng.nextf() * 0.6)
	var y := 0.0
	var pts := PackedVector2Array([Vector2(x, y)])
	var segs := 9 + int(rng.nextf() * 5.0)
	for i in segs:
		x += (rng.nextf() - 0.5) * 70.0
		y += f.H * 0.55 / float(segs)
		pts.append(Vector2(x, y))
	f.stroke_poly(pts, Color(1, 1, 1, 0.95), 2.5, false, true)
	# a soft glow along the bolt
	for p in pts:
		f.glow_radial(p.x, p.y, 10.0, Color(0.81, 0.88, 1.0), 0.5)
