extends Node2D
## The view controller. Builds the world container, the post-FX layer, the cinematic camera and
## the UI, then drives the flow by reading SceneDirector, running Transitions, and cueing audio.

var _world: Node2D
var _camera: Camera2D
var _post_mat: ShaderMaterial
var _ui: CanvasLayer
var _start: StartScreen
var _hud: Hud
var _gate: RotationGate

var _panel: Node2D
var _playing := false
var _busy := false
var _ended := false

var _shake := 0.0
var _vp: Vector2


func _ready() -> void:
	_vp = get_viewport_rect().size

	_build_environment()
	_world = Node2D.new()
	add_child(_world)
	_build_camera()
	_build_post()
	_build_ui()

	get_viewport().size_changed.connect(_on_resize)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = _vp * 0.5
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/post.gdshader")
	_post_mat.set_shader_parameter("screen_size", _vp)
	rect.material = _post_mat
	layer.add_child(rect)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	_hud = Hud.new()
	_ui.add_child(_hud)
	_hud.nav_selected.connect(_on_nav_selected)

	_start = StartScreen.new()
	_ui.add_child(_start)
	_start.entered.connect(_on_enter)

	_gate = RotationGate.new()
	_ui.add_child(_gate)


func _process(delta: float) -> void:
	if _post_mat:
		_post_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if _shake > 0.1:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = max(0.0, _shake - delta * 60.0)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


# --- flow ---------------------------------------------------------------

func _on_enter(index: int) -> void:
	SceneDirector.load_story(StoryLibrary.all()[index]["story"])
	_start.visible = false
	AudioDirector.start()
	var music := String(SceneDirector.story.get("music", ""))
	if music != "":
		AudioDirector.play_music(music, float(SceneDirector.story.get("music_vol", 0.5)))
	_hud.begin_play()
	_hud.build_nav(SceneDirector.scene_titles())
	await _enter_act(0, true)
	_playing = true


func _enter_act(index: int, first: bool) -> void:
	_busy = true
	SceneDirector.go_to_scene(index)
	var scene := SceneDirector.current_scene()

	_swap_panel(scene)
	_camera.zoom = Vector2(1.06, 1.06)
	create_tween().tween_property(_camera, "zoom", Vector2.ONE, 3.2).set_ease(Tween.EASE_OUT)

	if first:
		await Transitions.open()
	AudioDirector.enter_scene(
		String(scene.get("ambience", "")),
		scene.get("indoor", false) == true,
		float(scene.get("ambience_vol", 0.4)),
		float(scene.get("rain_vol", 0.16)))
	AudioDirector.whoosh()
	_hud.set_scene_tag(String(scene.get("title", "")))
	_show_line()
	_busy = false


func _swap_panel(scene: Dictionary) -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	var ps: PackedScene = load(String(scene.get("panel", "res://scenes/panels/NoirPanel.tscn")))
	_panel = ps.instantiate()
	_panel.setup(scene)
	_panel.shake_requested.connect(func(a): _shake = max(_shake, a))
	_world.add_child(_panel)


func _show_line() -> void:
	var line := SceneDirector.current_line()
	if _panel and _panel.has_method("set_line"):
		_panel.set_line(SceneDirector.line_index)
	_hud.show_caption(String(line.get("text", "")))
	for fx in line.get("fx", []):
		if _panel and _panel.has_method("on_fx"):
			_panel.on_fx(String(fx))


func advance() -> void:
	if not _playing or _busy or _ended:
		return
	if SceneDirector.has_next_line():
		AudioDirector.duck(0.45)
		SceneDirector.next_line()
		_show_line()
	elif not SceneDirector.at_last_scene():
		_to_act(SceneDirector.scene_index + 1)
	else:
		_end_story()


func _to_act(index: int) -> void:
	_busy = true
	_hud.hide_caption()
	AudioDirector.duck(0.8)
	await Transitions.close()
	await _enter_act_covered(index)


func _enter_act_covered(index: int) -> void:
	SceneDirector.go_to_scene(index)
	var scene := SceneDirector.current_scene()
	_swap_panel(scene)
	await Transitions.show_card(String(scene.get("title", "")))
	await Transitions.open()
	_camera.zoom = Vector2(1.06, 1.06)
	create_tween().tween_property(_camera, "zoom", Vector2.ONE, 3.2).set_ease(Tween.EASE_OUT)
	AudioDirector.enter_scene(
		String(scene.get("ambience", "")),
		scene.get("indoor", false) == true,
		float(scene.get("ambience_vol", 0.4)),
		float(scene.get("rain_vol", 0.16)))
	_hud.set_scene_tag(String(scene.get("title", "")))
	_show_line()
	_busy = false


func _end_story() -> void:
	_busy = true
	_ended = true
	_hud.hide_caption()
	_hud.set_tap_visible(false)
	AudioDirector.duck(0.8)
	await Transitions.close()
	if _panel:
		_panel.queue_free()
		_panel = null
	AudioDirector.whoosh()
	await Transitions.show_end()
	_hud.show_nav(true)
	_busy = false


func _on_nav_selected(index: int) -> void:
	if _busy:
		return
	_ended = false
	_hud.show_nav(false)
	Transitions.hide_end()
	_hud.set_tap_visible(true)
	await _to_act(index)
	_playing = true


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _busy:
		return
	if event.is_action_pressed("advance"):
		advance()
	elif event.is_action_pressed("lightning"):
		if _panel and _panel.has_method("on_fx"):
			_panel.on_fx("lightning")


func _on_resize() -> void:
	_vp = get_viewport_rect().size
	_camera.position = _vp * 0.5
	if _post_mat:
		_post_mat.set_shader_parameter("screen_size", _vp)
