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

# letterbox bars (black rects that mask extreme aspect ratios)
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _bar_left: ColorRect
var _bar_right: ColorRect


func _ready() -> void:
	_post_mat = _post.material
	_post_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	_camera.position = get_viewport_rect().size * 0.5
	_build_void_fill()
	_build_crossfade()
	_build_letterbox()

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


## Black bars that mask extreme aspect ratios, matching the legacy letterbox.
## The bars sit on a CanvasLayer between the post FX (layer 1) and the UI (layer 10).
## On a normal 16:9 or 16:10 display none of them are visible. On a phone in portrait (too
## tall) the top and bottom bars show. On an ultrawide (too wide) the left and right bars show.
func _build_letterbox() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_bar_top = _make_bar(layer)
	_bar_bottom = _make_bar(layer)
	_bar_left = _make_bar(layer)
	_bar_right = _make_bar(layer)
	_layout_letterbox()


func _make_bar(parent: Node) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	parent.add_child(bar)
	return bar


func _layout_letterbox() -> void:
	var r := UIScale.content_rect
	var vp := get_viewport().get_visible_rect().size
	# too tall: bars top and bottom
	if r.position.y > 0.5:
		_bar_top.visible = true
		_bar_top.position = Vector2.ZERO
		_bar_top.size = Vector2(vp.x, r.position.y)
		_bar_bottom.visible = true
		_bar_bottom.position = Vector2(0, r.position.y + r.size.y)
		_bar_bottom.size = Vector2(vp.x, vp.y - r.position.y - r.size.y)
	else:
		_bar_top.visible = false
		_bar_bottom.visible = false
	# too wide: bars left and right
	if r.position.x > 0.5:
		_bar_left.visible = true
		_bar_left.position = Vector2.ZERO
		_bar_left.size = Vector2(r.position.x, vp.y)
		_bar_right.visible = true
		_bar_right.position = Vector2(r.position.x + r.size.x, 0)
		_bar_right.size = Vector2(vp.x - r.position.x - r.size.x, vp.y)
	else:
		_bar_left.visible = false
		_bar_right.visible = false


# --- flow ----------------------------------------------------------------------------------

func _on_enter(story: Story) -> void:
	GameState.load_story(story)
	_gate.begin_story()
	if _gate.is_blocked():
		await _gate.started
	_start.visible = false
	_hud.build_nav(GameState.act_titles())
	await _open_story(story)
	_hud.begin_play()
	_playing = true


## the opening, the way Inkfall begins a tale: cover to black, hold the story-title card (the story
## subtitle), then start the score and open the first act behind its own card.
func _open_story(story: Story) -> void:
	Transitions.cover()
	var title := story.subtitle if story.subtitle != "" else story.title
	await Transitions.show_card(title, Palette.TITLE_HOLD, false)
	await _enter_act(0, true)


func _enter_act(index: int, first: bool) -> void:
	_busy = true
	GameState.go_to_act(index)
	var act := GameState.current_act()
	_swap_board(act)
	if first:
		# the screen is already black from the story-title card, so show the first act card here too.
		# the score, the whoosh, and the audio system all start together on the first act title.
		# the music starts at full volume (no fade in) so it hits cleanly with the whoosh.
		AudioDirector.start()
		var story := GameState.story
		if story.music != "":
			AudioDirector.play_music(story.music, story.music_vol, 0.0)
		_cue_audio(act, 0.0)
		AudioDirector.whoosh()
		await Transitions.show_card(act.title, Palette.OPEN_CARD_HOLD)
		_zoom_in()
		await Transitions.open()
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
	_update_reflection(act)


## feed the post shader the wet-floor mirror: the ground line in screen uv, and the strength
## (off indoors, where the room floor would not mirror the night).
func _update_reflection(act: Act) -> void:
	if _post_mat == null or _board == null:
		return
	var vp := get_viewport_rect().size
	var horizon: float = (_board.position.y + _board.ground_y) / vp.y
	_post_mat.set_shader_parameter("reflect_horizon", clampf(horizon, 0.0, 1.0))
	_post_mat.set_shader_parameter("reflect_strength", 0.0 if act.indoor else 0.35)


func _cue_audio(act: Act, fade := 0.6) -> void:
	AudioDirector.enter_scene(act.ambience, act.indoor, act.ambience_vol, act.rain_vol, fade)


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
	# kill the old act's sound effects immediately so they do not leak through the wipe
	AudioDirector.duck(0.3)
	AudioDirector.stop_loops(0.3)
	await Transitions.close()
	await _enter_act_covered(index)


func _enter_act_covered(index: int) -> void:
	GameState.go_to_act(index)
	var act := GameState.current_act()
	_swap_board(act)
	_cue_audio(act)
	AudioDirector.whoosh()
	await Transitions.show_card(act.title)
	await Transitions.open()
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
	# crop the grab to the scene the viewer sees (the board area), dropping any letterbox bars, so
	# the poster shows the live frame, not the screen, and reads the same whatever the device shape
	var frame := _crop_to_scene(get_viewport().get_texture().get_image())
	_hud.visible = true
	# preview exactly what gets saved: the composed poster, watermark and narration baked in
	var poster := await _compose_poster(frame)
	_hud.show_poster(ImageTexture.create_from_image(poster), poster)


## Crop a full viewport grab down to the staged scene (UIScale.content_rect), so the poster carries
## the board the viewer is looking at and never the letterbox bars around it.
func _crop_to_scene(shot: Image) -> Image:
	var r := UIScale.content_rect
	var full := Rect2i(Vector2i.ZERO, shot.get_size())
	# floor the start and ceil the end so a fractional dpr content rect is fully contained, rather
	# than truncating and leaving a 1px letterbox bar or shaving a pixel off the scene
	var pos := Vector2i(floori(r.position.x), floori(r.position.y))
	var region := Rect2i(pos, Vector2i(ceili(r.end.x), ceili(r.end.y)) - pos).intersection(full)
	if region.has_area() and region != full:
		return shot.get_region(region)
	return shot


## Compose the downloadable poster from the captured scene, a faithful port of the legacy
## makePoster: the whole scene framed by an inked border with red splatter corners, the INKFALL
## wordmark, the narration tagline and a halftone wash. Rendered in a SubViewport whose
## height follows the scene aspect, so the full scene shows and the output is a consistent 900px wide.
func _compose_poster(frame: Image) -> Image:
	var canvas := PosterCanvas.new()
	canvas.scene_tex = ImageTexture.create_from_image(frame)
	canvas.tagline = _poster_tagline()
	var ps := canvas.poster_size()
	canvas.size = ps

	var sv := SubViewport.new()
	sv.size = ps
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	sv.add_child(canvas)
	canvas.queue_redraw()

	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	return img


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
	if _board and GameState.story:
		_update_reflection(GameState.current_act())
	_layout_letterbox()
