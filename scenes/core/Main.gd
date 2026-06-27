extends Node2D
## The view controller. The global look (the CanvasModulate wash, the WorldEnvironment bloom, the
## camera and the post FX material) is authored in Main.tscn, so this script only drives the flow:
## it reads GameState, swaps the Board for each act, runs Transitions and cues audio, and feeds the
## post shader its runtime parameters. The board renders itself with native nodes and 2D lights.

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
var _shake := 0.0


func _ready() -> void:
	_post_mat = _post.material
	_post_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	_camera.position = get_viewport_rect().size * 0.5

	_start.entered.connect(_on_enter)
	_hud.nav_selected.connect(_on_nav_selected)
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
	_show_line()
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


func _show_line() -> void:
	var line := GameState.current_line()
	if line == null:
		return
	if _board:
		_board.set_line(GameState.line_index)
	_hud.show_caption(line.text)
	for fx in line.fx:
		if _board:
			_board.on_fx(fx)


func advance() -> void:
	if not _playing or _busy or _ended:
		return
	if GameState.has_next_line():
		AudioDirector.duck(0.45)
		GameState.next_line()
		_show_line()
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
	_show_line()
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


func _process(delta: float) -> void:
	if _post_mat:
		_post_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if _shake > 0.1:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - delta * 60.0)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _busy:
		return
	if event.is_action_pressed("advance"):
		advance()
	elif event.is_action_pressed("lightning") and _board:
		_board.on_fx("lightning")


func _on_resize() -> void:
	var vp := get_viewport_rect().size
	_camera.position = vp * 0.5
	if _post_mat:
		_post_mat.set_shader_parameter("screen_size", vp)
