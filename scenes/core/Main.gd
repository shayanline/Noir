extends Node2D
## The view controller. The global look (the CanvasModulate wash, the WorldEnvironment bloom, the
## camera and the post FX material) is authored in Main.tscn, so this script only drives the flow:
## it reads GameState, swaps the Board for each act, runs Transitions and cues audio, and feeds the
## post shader its runtime parameters. The board renders itself with native nodes and 2D lights.
## It also serves the HUD: pause (freeze the board and suspend sound), leave to the start screen,
## and pull a poster from the live frame.

const BOARD_SCENE := preload("res://scenes/board/Board.tscn")

@onready var _world: Node2D = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _post: ColorRect = $PostLayer/Post
@onready var _start: StartScreen = $UILayer/StartScreen
@onready var _hud: Hud = $UILayer/Hud

var _post_mat: ShaderMaterial
var _board: Board
var _playing := false
var _busy := false
var _ended := false
var _paused := false
var _shake := 0.0


func _ready() -> void:
	_post_mat = _post.material
	_post_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	_camera.position = get_viewport_rect().size * 0.5

	_start.entered.connect(_on_enter)
	_hud.nav_selected.connect(_on_nav_selected)
	_hud.pause_changed.connect(_on_pause_changed)
	_hud.exit_requested.connect(_on_exit_requested)
	_hud.poster_requested.connect(_on_poster_requested)
	get_viewport().size_changed.connect(_on_resize)


# --- flow ----------------------------------------------------------------------------------

func _on_enter(story: Story) -> void:
	GameState.load_story(story)
	_start.visible = false
	AudioDirector.start()
	if story.music != "":
		AudioDirector.play_music(story.music, story.music_vol)
	_hud.begin_play()
	_hud.build_nav(GameState.act_titles())
	await _enter_act(0, true)
	_playing = true


func _enter_act(index: int, first: bool) -> void:
	_busy = true
	GameState.go_to_act(index)
	var act := GameState.current_act()
	_swap_board(act)
	_zoom_in()
	if first:
		await Transitions.open()
	_cue_audio(act)
	AudioDirector.whoosh()
	_hud.set_scene_tag(act.title)
	_hud.set_current_act(GameState.act_index)
	GameState.notify_line()
	_fire_line_fx()
	_busy = false


func _swap_board(act: Act) -> void:
	if _board:
		_board.queue_free()
		_board = null
	_board = BOARD_SCENE.instantiate()
	_board.setup(act)
	_board.shake_requested.connect(func(a): _shake = maxf(_shake, a))
	_world.add_child(_board)


func _cue_audio(act: Act) -> void:
	AudioDirector.enter_scene(act.ambience, act.indoor, act.ambience_vol, act.rain_vol)


func _zoom_in() -> void:
	_camera.zoom = Vector2(1.06, 1.06)
	create_tween().tween_property(_camera, "zoom", Vector2.ONE, 3.2).set_ease(Tween.EASE_OUT)


## fire the current line's fx through GameState, so the board (and its objects) react via signal.
func _fire_line_fx() -> void:
	var line := GameState.current_line()
	if line == null:
		return
	for fx in line.fx:
		GameState.fire_fx(fx)


func advance() -> void:
	if not _playing or _busy or _ended or _paused:
		return
	if GameState.has_next_line():
		AudioDirector.duck(0.45)
		GameState.next_line()
		GameState.notify_line()
		_fire_line_fx()
	elif not GameState.at_last_act():
		_to_act(GameState.act_index + 1)
	else:
		_end_story()


func _to_act(index: int) -> void:
	_busy = true
	_hud.hide_caption()
	AudioDirector.duck(0.8)
	await Transitions.close()
	await _enter_act_covered(index)


func _enter_act_covered(index: int) -> void:
	GameState.go_to_act(index)
	var act := GameState.current_act()
	_swap_board(act)
	await Transitions.show_card(act.title)
	await Transitions.open()
	_zoom_in()
	_cue_audio(act)
	_hud.set_scene_tag(act.title)
	_hud.set_current_act(GameState.act_index)
	GameState.notify_line()
	_fire_line_fx()
	_busy = false


func _end_story() -> void:
	_busy = true
	_ended = true
	_hud.hide_caption()
	_hud.set_tap_visible(false)
	AudioDirector.duck(0.8)
	await Transitions.close()
	if _board:
		_board.queue_free()
		_board = null
	AudioDirector.whoosh()
	await Transitions.show_end()
	_hud.end_reached()
	_busy = false


func _on_nav_selected(index: int) -> void:
	if _busy:
		return
	_ended = false
	_hud.resume_from_end()
	Transitions.hide_end()
	await _to_act(index)
	_playing = true


# --- HUD service ---------------------------------------------------------------------------

func _on_pause_changed(p: bool) -> void:
	_paused = p
	if _board:
		_board.process_mode = Node.PROCESS_MODE_DISABLED if p else Node.PROCESS_MODE_INHERIT
	AudioDirector.set_suspended(p)


func _on_exit_requested() -> void:
	_playing = false
	_ended = false
	_busy = false
	_paused = false
	if _board:
		_board.process_mode = Node.PROCESS_MODE_INHERIT
		_board.queue_free()
		_board = null
	Transitions.clear()
	_hud.hide_caption()
	AudioDirector.reset()
	if GameState.story:
		GameState.load_story(GameState.story)
	_camera.zoom = Vector2.ONE
	_start.visible = true


func _on_poster_requested() -> void:
	if not _playing:
		return
	_hud.visible = false
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	_hud.visible = true
	var poster := await _compose_poster(frame)
	_hud.show_poster(poster[0], poster[1])


## compose a downloadable noir poster from the captured frame: an inked white border, the NOIR
## wordmark, the current caption as the tagline, and a footer. Built in a SubViewport so it uses the
## shared fonts and renders to a saveable image.
func _compose_poster(frame: Image) -> Array:
	var pw := 900
	var margin := 56
	var fw := pw - margin * 2
	var vp := get_viewport_rect().size
	var fh := int(fw * vp.y / vp.x)
	var fy := 150
	var ph := fy + fh + 170

	var sv := SubViewport.new()
	sv.size = Vector2i(pw, ph)
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)

	var root := Control.new()
	root.size = Vector2(pw, ph)
	sv.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(pw, ph)
	root.add_child(bg)

	var title := HBoxContainer.new()
	title.anchor_right = 1.0
	title.offset_top = 64.0
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 0)
	root.add_child(title)
	title.add_child(_poster_word("NO", Color(1, 1, 1, 1)))
	title.add_child(_poster_word("IR", Color(0.882, 0, 0.063, 1)))

	var pic := TextureRect.new()
	pic.texture = ImageTexture.create_from_image(frame)
	pic.position = Vector2(margin, fy)
	pic.size = Vector2(fw, fh)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.clip_contents = true
	root.add_child(pic)

	var border := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(5)
	sb.border_color = Color(1, 1, 1, 1)
	border.add_theme_stylebox_override("panel", sb)
	border.position = Vector2(margin, fy)
	border.size = Vector2(fw, fh)
	root.add_child(border)

	var tag := Label.new()
	tag.theme_type_variation = &"MenuRole"
	tag.add_theme_font_size_override("font_size", 24)
	tag.add_theme_color_override("font_color", Color(0.847, 0.831, 0.784, 1))
	tag.position = Vector2(margin, fy + fh + 26)
	tag.size = Vector2(fw, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.text = _poster_tagline()
	root.add_child(tag)

	var foot := Label.new()
	foot.theme_type_variation = &"TapNote"
	foot.add_theme_font_size_override("font_size", 13)
	foot.position = Vector2(0, ph - 46)
	foot.size = Vector2(pw, 0)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.text = "BASIN CITY  ·  NOIR"
	root.add_child(foot)

	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	sv.queue_free()
	return [tex, img]


func _poster_word(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.theme_type_variation = &"Title"
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.add_theme_color_override("font_color", col)
	lbl.text = text
	return lbl


func _poster_tagline() -> String:
	var line := GameState.current_line()
	var s := line.text if line else ""
	if s == "" and GameState.story:
		s = GameState.story.subtitle
	s = s.replace("<b>", "").replace("</b>", "")
	return s.to_upper()


func _process(delta: float) -> void:
	if _post_mat:
		_post_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if _shake > 0.1:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - delta * 60.0)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _busy or _paused:
		return
	if event.is_action_pressed("advance"):
		advance()
	elif event.is_action_pressed("lightning"):
		GameState.fire_fx("lightning")


func _on_resize() -> void:
	var vp := get_viewport_rect().size
	_camera.position = vp * 0.5
	if _post_mat:
		_post_mat.set_shader_parameter("screen_size", vp)
