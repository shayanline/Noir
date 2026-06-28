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
@onready var _gate: RotationGate = $UILayer/RotationGate

var _post_mat: ShaderMaterial
var _board: Board
var _playing := false
var _busy := false
var _ended := false
var _paused := false
var _snapping := false
var _shake := 0.0
var _xfade: TextureRect


func _ready() -> void:
	_post_mat = _post.material
	_post_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	_camera.position = get_viewport_rect().size * 0.5
	_build_void_fill()
	_build_crossfade()

	_start.entered.connect(_on_enter)
	_hud.nav_selected.connect(_on_nav_selected)
	_hud.pause_changed.connect(_on_pause_changed)
	_hud.exit_requested.connect(_on_exit_requested)
	_hud.poster_requested.connect(_on_poster_requested)
	get_viewport().size_changed.connect(_on_resize)


## a wide dark plate behind the whole world, so the first-act establishing push in (which opens on a
## wider field than the backdrop fills) reads as continuous night rather than a hard black border.
func _build_void_fill() -> void:
	var fill := ColorRect.new()
	fill.color = Color(0.1, 0.11, 0.14)
	fill.position = Vector2(-1200, -1100)
	fill.size = Vector2(4400, 3300)
	fill.z_index = -200
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(fill)


## a full screen overlay between the world and the HUD that holds a snapshot of the previous beat and
## dissolves it into the new one (Inkfall's beat crossfade).
func _build_crossfade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_xfade = TextureRect.new()
	_xfade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xfade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xfade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_xfade.stretch_mode = TextureRect.STRETCH_SCALE
	_xfade.modulate = Color(1, 1, 1, 0)
	layer.add_child(_xfade)


# --- flow ----------------------------------------------------------------------------------

func _on_enter(story: Story) -> void:
	GameState.load_story(story)
	_start.visible = false
	_gate.begin_story()
	if _gate.is_blocked():
		await _gate.unblocked
	_hud.build_nav(GameState.act_titles())
	await _open_story(story)
	_hud.begin_play()
	_playing = true


## the opening, the way Inkfall begins a tale: cover to black, hold the story-title card (the story
## subtitle), then start the score and open the first act behind its own card.
func _open_story(story: Story) -> void:
	Transitions.cover()
	var title := story.subtitle if story.subtitle != "" else story.title
	await Transitions.show_card(title, Palette.TITLE_HOLD)
	AudioDirector.start()
	await _enter_act(0, true)


func _enter_act(index: int, first: bool) -> void:
	_busy = true
	GameState.go_to_act(index)
	var act := GameState.current_act()
	_swap_board(act)
	if first:
		# the screen is already black from the story-title card, so show the first act card here too.
		# the score and the swoosh come in with the act title, not the story title.
		var story := GameState.story
		if story.music != "":
			AudioDirector.play_music(story.music, story.music_vol)
		AudioDirector.whoosh()
		await Transitions.show_card(act.title, Palette.OPEN_CARD_HOLD)
		_zoom_in()
		await Transitions.open()
	_cue_audio(act)
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
	# the establishing push in, Inkfall ran it on the first act only. Camera2D zoom below 1 shows a
	# wider field, so settling to 1.0 reads as a slow push in to the framed view.
	_camera.zoom = Vector2(0.93, 0.93)
	create_tween().tween_property(_camera, "zoom", Vector2.ONE, 3.4).set_ease(Tween.EASE_OUT)


## fire the current line's fx through GameState, so the board (and its objects) react via signal.
func _fire_line_fx() -> void:
	var line := GameState.current_line()
	if line == null:
		return
	for fx in line.fx:
		GameState.fire_fx(fx)
		_play_fx_sound(fx)


## play the sound cue for a line fx, mirroring Inkfall's central narration audio (the board handles
## the visual side through GameState.fire_fx). Manual lightning (the L key) stays silent, as it did
## in the original, only the scripted lightning beat brings thunder.
func _play_fx_sound(fx: String) -> void:
	match fx:
		"muzzle":
			AudioDirector.gun()
			await get_tree().create_timer(0.23).timeout
			AudioDirector.gun()
		"lightning":
			await get_tree().create_timer(randf_range(0.2, 0.6)).timeout
			AudioDirector.thunder()
		"hammer":
			AudioDirector.gun_cock()
		"lighter":
			AudioDirector.lid_open()
			await get_tree().create_timer(0.65).timeout
			AudioDirector.flint()


func advance() -> void:
	if not _playing or _busy or _ended or _paused or _snapping:
		return
	if GameState.has_next_line():
		_hud.mark_controls_seen()
		AudioDirector.duck(0.45)
		# snapshot the current beat (world plus post, without the HUD so the caption never ghosts),
		# advance the line, then dissolve the snapshot into the new beat
		_snapping = true
		_hud.visible = false
		await RenderingServer.frame_post_draw
		var snap := get_viewport().get_texture().get_image()
		_hud.visible = true
		_snapping = false
		GameState.next_line()
		GameState.notify_line()
		_fire_line_fx()
		_xfade.texture = ImageTexture.create_from_image(snap)
		_xfade.modulate.a = 1.0
		create_tween().tween_property(_xfade, "modulate:a", 0.0, Palette.BEAT_FADE)
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
	AudioDirector.whoosh()
	await Transitions.show_card(act.title)
	await Transitions.open()
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
	# Inkfall does not black out at THE END: it keeps the final scene, frozen and desaturated, and
	# fades THE END over it. So we keep the board alive, grade it out, and reopen the wipe at once.
	AudioDirector.whoosh()
	_set_ended_grade(true)
	Transitions.clear()
	await Transitions.show_end()
	_hud.end_reached()
	_busy = false


## push the post grade to a full desaturated, grainier finish for THE END, and back for normal play.
func _set_ended_grade(on: bool) -> void:
	if _post_mat == null:
		return
	var d0 = _post_mat.get_shader_parameter("desaturate")
	var g0 = _post_mat.get_shader_parameter("grain_amount")
	var v0 = _post_mat.get_shader_parameter("vignette")
	if typeof(d0) != TYPE_FLOAT:
		d0 = 0.82
	if typeof(g0) != TYPE_FLOAT:
		g0 = 0.05
	if typeof(v0) != TYPE_FLOAT:
		v0 = 0.7
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): _post_mat.set_shader_parameter("desaturate", v), d0, 1.0 if on else 0.82, 0.8)
	tw.tween_method(func(v: float): _post_mat.set_shader_parameter("grain_amount", v), g0, 0.15 if on else 0.05, 0.8)
	tw.tween_method(func(v: float): _post_mat.set_shader_parameter("vignette", v), v0, 0.86 if on else 0.7, 0.8)


func _on_nav_selected(index: int) -> void:
	if _busy:
		return
	_ended = false
	_set_ended_grade(false)
	_hud.resume_from_end()
	Transitions.hide_end()
	await _to_act(index)
	_playing = true


# --- HUD service ---------------------------------------------------------------------------

func _on_pause_changed(p: bool) -> void:
	# a real pause: freeze the whole tree so the camera push in, the board, the weather and the post
	# clock all stop together (the HUD stays live via PROCESS_MODE_ALWAYS, so the menu still works).
	_paused = p
	get_tree().paused = p
	AudioDirector.set_suspended(p)


func _on_exit_requested() -> void:
	_playing = false
	_ended = false
	_busy = false
	_paused = false
	get_tree().paused = false
	if _board:
		_board.queue_free()
		_board = null
	Transitions.clear()
	_set_ended_grade(false)
	_hud.hide_caption()
	AudioDirector.reset()
	_gate.reset()
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
	# the modal shows the clean pulled frame, SAVE writes the composed poster
	var frame_tex := ImageTexture.create_from_image(frame)
	var save_img := await _compose_poster(frame)
	_hud.show_poster(frame_tex, save_img)


## compose a downloadable noir poster from the captured frame: an inked white border, the INKFALL
## wordmark, the current caption as the tagline, and a footer. Built in a SubViewport so it uses the
## shared fonts and renders to a saveable image.
func _compose_poster(frame: Image) -> Image:
	var pw := 900
	var margin := 56
	var fw := pw - margin * 2
	var vp := get_viewport_rect().size
	var fh := int(fw * vp.y / vp.x)
	var fy := 190
	var ph := fy + fh + 160

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
	title.offset_top = 56.0
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
	tag.position = Vector2(margin, fy + fh + 30)
	tag.size = Vector2(fw, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.text = _poster_tagline()
	root.add_child(tag)

	var foot := Label.new()
	foot.theme_type_variation = &"TapNote"
	foot.add_theme_font_size_override("font_size", 13)
	foot.position = Vector2(0, ph - 44)
	foot.size = Vector2(pw, 0)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.text = "BASIN CITY  ·  INKFALL"
	root.add_child(foot)

	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	return img


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
