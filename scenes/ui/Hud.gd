class_name Hud
extends Control
## In-play overlay, carried over from Inkfall: the typed scene tag, the paper caption box, the input
## hint, the top right icon chips (poster, fullscreen, menu), the top left REVIEW ACT dropdown (which
## becomes a centered act row at THE END), and the pause menu (resume, sound, controls, exit). The
## look comes from the shared theme, this script builds the controls and drives them.

signal nav_selected(index: int)
signal exit_requested
signal poster_requested
signal pause_changed(paused: bool)

const _BONE := Color(0.847, 0.831, 0.784, 1)
const _WHITE := Color(1, 1, 1, 1)
const _LINE := Color(0.863, 0.847, 0.784, 0.16)
const _SCRIM := Color(0, 0, 0, 0.92)
const _CELL := 40.0
const _GAP := 6

var _tag: Label
var _caption: PanelContainer
var _caption_label: RichTextLabel
var _tap: Label

var _review_btn: Button
var _navdrop: VBoxContainer
var _end_box: CenterContainer
var _end_row: HFlowContainer

var _menu: Control
var _menu_views := {}
var _sound_btn: Button
var _poster: Control
var _poster_img: TextureRect
var _poster_save: Button

var _titles: Array = []
var _cur_act := 0
var _unlocked := false
var _playing := false
var _ended := false
var _poster_image: Image
var _fullscreen := false


func _ready() -> void:
	_build_scene_tag()
	_build_caption()
	_build_tap()
	_build_topbar()
	_build_actsel()
	_build_menu()
	_build_poster()
	GameState.line_changed.connect(_on_line_changed)


# --- construction --------------------------------------------------------

func _build_scene_tag() -> void:
	_tag = Label.new()
	_tag.theme_type_variation = &"SceneTag"
	_tag.modulate.a = 0.0
	_tag.position = Vector2(27, 24)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)


func _build_caption() -> void:
	_caption = PanelContainer.new()
	_caption.theme_type_variation = &"CaptionPanel"
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_bottom = -54.0
	add_child(_caption)
	_caption_label = RichTextLabel.new()
	_caption_label.bbcode_enabled = true
	_caption_label.fit_content = true
	_caption_label.scroll_active = false
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.custom_minimum_size = Vector2(560, 0)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(_caption_label)


func _build_tap() -> void:
	_tap = Label.new()
	_tap.theme_type_variation = &"TapNote"
	_tap.text = "TAP  ·  NEXT       L  ·  LIGHTNING"
	_tap.modulate.a = 0.0
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap.anchor_left = 0.5
	_tap.anchor_right = 0.5
	_tap.anchor_top = 1.0
	_tap.anchor_bottom = 1.0
	_tap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tap.offset_top = -34.0
	_tap.offset_bottom = -10.0
	add_child(_tap)


func _build_topbar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", _GAP)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = -200.0
	bar.offset_right = -16.0
	bar.offset_top = 16.0
	bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(bar)
	bar.add_child(_chip(HudIcon.Kind.POSTER, func(): poster_requested.emit()))
	bar.add_child(_chip(HudIcon.Kind.FULLSCREEN, _toggle_fullscreen))
	bar.add_child(_chip(HudIcon.Kind.MENU, _open_menu))


func _chip(kind: HudIcon.Kind, on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"HudButton"
	b.custom_minimum_size = Vector2(_CELL, _CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	var icon := HudIcon.new()
	icon.kind = kind
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	b.mouse_entered.connect(func(): icon.set_tint(_WHITE))
	b.mouse_exited.connect(func(): icon.set_tint(Color(0.788, 0.769, 0.714, 1)))
	return b


func _build_actsel() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", _GAP)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.position = Vector2(16, 16)
	col.add_theme_constant_override("alignment", 0)
	add_child(col)

	_review_btn = Button.new()
	_review_btn.theme_type_variation = &"ReviewButton"
	_review_btn.text = "REVIEW ACT  ▾"
	_review_btn.custom_minimum_size = Vector2(_CELL * 3 + _GAP * 2, _CELL)
	_review_btn.focus_mode = Control.FOCUS_NONE
	_review_btn.visible = false
	_review_btn.pressed.connect(_toggle_drop)
	col.add_child(_review_btn)

	_navdrop = VBoxContainer.new()
	_navdrop.add_theme_constant_override("separation", _GAP)
	_navdrop.visible = false
	col.add_child(_navdrop)

	# the centered act row shown at THE END
	_end_box = CenterContainer.new()
	_end_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_end_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_end_box.offset_top = -240.0
	_end_box.offset_bottom = -90.0
	_end_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_end_box.visible = false
	add_child(_end_box)
	_end_row = HFlowContainer.new()
	_end_row.add_theme_constant_override("h_separation", 16)
	_end_row.add_theme_constant_override("v_separation", 12)
	_end_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_end_box.add_child(_end_row)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	add_child(_menu)
	var scrim := ColorRect.new()
	scrim.color = _SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_menu())
	_menu.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(center)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"MenuFrame"
	center.add_child(frame)
	var pad := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 5)
	frame.add_child(pad)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuPanel"
	pad.add_child(panel)

	_menu_views["main"] = _view_main()
	_menu_views["controls"] = _view_controls()
	_menu_views["confirm"] = _view_confirm()
	for v in _menu_views.values():
		v.custom_minimum_size = Vector2(320, 0)
		panel.add_child(v)
	_set_view("main")


func _view() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


func _view_main() -> VBoxContainer:
	var v := _view()
	v.add_child(_menu_title("PAUSED"))
	v.add_child(_menu_item("RESUME", &"MenuItemPrimary", _close_menu))
	_sound_btn = _menu_item(_sound_label(), &"MenuItem", _toggle_sound)
	v.add_child(_sound_btn)
	v.add_child(_menu_item("CONTROLS", &"MenuItem", func(): _set_view("controls")))
	v.add_child(_sep())
	v.add_child(_menu_item("EXIT TO START", &"MenuItemDanger", func(): _set_view("confirm")))
	return v


func _view_controls() -> VBoxContainer:
	var v := _view()
	v.add_child(_menu_title("CONTROLS"))
	v.add_child(_key_row("TAP", "advance the story"))
	v.add_child(_key_row("L", "call down lightning"))
	v.add_child(_sep())
	v.add_child(_menu_item("BACK", &"MenuItemPrimary", func(): _set_view("main")))
	return v


func _view_confirm() -> VBoxContainer:
	var v := _view()
	v.add_child(_menu_title("LEAVE THE STORY?"))
	var note := Label.new()
	note.theme_type_variation = &"MenuNote"
	note.text = "This returns you to the start screen."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	v.add_child(_menu_item("EXIT TO START", &"MenuItemDanger", _do_exit))
	v.add_child(_menu_item("STAY", &"MenuItemPrimary", func(): _set_view("main")))
	return v


func _menu_title(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.theme_type_variation = &"MenuTitle"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var rule := CenterContainer.new()
	var bar := ColorRect.new()
	bar.color = Color(0.882, 0, 0.063, 1)
	bar.custom_minimum_size = Vector2(46, 2)
	rule.add_child(bar)
	box.add_child(rule)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	return box


func _menu_item(text: String, variation: StringName, on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _key_row(key: String, role: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var k := Label.new()
	k.theme_type_variation = &"MenuKey"
	k.text = key
	k.custom_minimum_size = Vector2(64, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(k)
	var r := Label.new()
	r.theme_type_variation = &"MenuRole"
	r.text = role
	row.add_child(r)
	return row


func _sep() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 10)
	wrap.add_theme_constant_override("margin_bottom", 10)
	var line := ColorRect.new()
	line.color = _LINE
	line.custom_minimum_size = Vector2(0, 1)
	wrap.add_child(line)
	return wrap


func _build_poster() -> void:
	_poster = Control.new()
	_poster.set_anchors_preset(Control.PRESET_FULL_RECT)
	_poster.visible = false
	add_child(_poster)
	var scrim := ColorRect.new()
	scrim.color = _SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_poster.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poster.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	_poster_img = TextureRect.new()
	_poster_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(_poster_img)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	_poster_save = _menu_item("SAVE", &"MenuItem", _save_poster)
	row.add_child(_poster_save)
	row.add_child(_menu_item("BACK TO THE RAIN", &"MenuItem", _close_poster))


# --- public API ----------------------------------------------------------

func begin_play() -> void:
	_playing = true
	_ended = false
	create_tween().tween_property(_tap, "modulate:a", 1.0, 0.6)
	_refresh_actsel()


func build_nav(titles: Array) -> void:
	_titles = titles


func set_current_act(index: int) -> void:
	_cur_act = index
	_repaint_nav()


func set_scene_tag(title: String) -> void:
	if _unlocked:
		return
	_tag.text = title
	_tag.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_tag, "modulate:a", 0.0, 0.5)


func show_caption(text: String) -> void:
	var bb := text.replace("<b>", "[color=#c20012][b]").replace("</b>", "[/b][/color]")
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 0.0, 0.17)
	tw.tween_callback(func(): _caption_label.text = bb)
	tw.tween_property(_caption, "modulate:a", 1.0, 0.2)


func hide_caption() -> void:
	_caption.modulate.a = 0.0


func set_tap_visible(v: bool) -> void:
	create_tween().tween_property(_tap, "modulate:a", 1.0 if v else 0.0, 0.3)


## called by Main when THE END card is shown: unlock the act picker and lay it out as a centered row.
func end_reached() -> void:
	_ended = true
	_unlocked = true
	_refresh_actsel()


## called by Main when the viewer picks an act from THE END to replay it.
func resume_from_end() -> void:
	_ended = false
	_playing = true
	_navdrop.visible = false
	_refresh_actsel()
	set_tap_visible(true)


func show_poster(tex: Texture2D, image: Image) -> void:
	_poster_image = image
	_poster_img.texture = tex
	var ts := tex.get_size()
	var h := 720.0
	_poster_img.custom_minimum_size = Vector2(h * ts.x / maxf(ts.y, 1.0), h)
	_poster_save.text = "SAVE"
	_poster_save.disabled = false
	_poster.visible = true
	pause_changed.emit(true)


# --- act picker ----------------------------------------------------------

func _toggle_drop() -> void:
	_navdrop.visible = not _navdrop.visible


func _refresh_actsel() -> void:
	_review_btn.visible = _playing and _unlocked and not _ended
	if not (_playing and _unlocked and not _ended):
		_navdrop.visible = false
	_end_box.visible = _ended
	_repaint_nav()


func _repaint_nav() -> void:
	if _ended:
		_populate(_end_row, false)
	elif _review_btn.visible:
		_populate(_navdrop, true)


func _populate(container: Container, is_drop: bool) -> void:
	for c in container.get_children():
		c.queue_free()
	for i in _titles.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = String(_titles[i]).strip_edges()
		if is_drop:
			b.theme_type_variation = &"NavDrop"
			b.custom_minimum_size = Vector2(_CELL * 3 + _GAP * 2, _CELL)
			if i == _cur_act:
				b.add_theme_color_override("font_color", _WHITE)
		else:
			b.theme_type_variation = &"NavButtonCur" if i == _cur_act else &"NavButton"
		var idx := i
		b.pressed.connect(func(): nav_selected.emit(idx))
		container.add_child(b)


# --- pause menu ----------------------------------------------------------

func _open_menu() -> void:
	_set_view("main")
	_sound_btn.text = _sound_label()
	_menu.visible = true
	pause_changed.emit(true)


func _close_menu() -> void:
	_menu.visible = false
	_set_view("main")
	pause_changed.emit(false)


func _set_view(name: String) -> void:
	for k in _menu_views:
		_menu_views[k].visible = (k == name)


func _toggle_sound() -> void:
	AudioDirector.toggle_mute()
	_sound_btn.text = _sound_label()


func _sound_label() -> String:
	return "SOUND: ON" if AudioDirector.is_on() else "SOUND: OFF"


func _do_exit() -> void:
	_menu.visible = false
	_set_view("main")
	_navdrop.visible = false
	_ended = false
	_playing = false
	_unlocked = false
	hide_caption()
	_tap.modulate.a = 0.0
	_refresh_actsel()
	pause_changed.emit(false)
	exit_requested.emit()


# --- fullscreen ----------------------------------------------------------

func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# --- poster --------------------------------------------------------------

func _close_poster() -> void:
	_poster.visible = false
	pause_changed.emit(false)


func _save_poster() -> void:
	if _poster_image == null:
		return
	var dir := "user://posters"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/noir_%d.png" % [dir, Time.get_unix_time_from_system()]
	if _poster_image.save_png(path) == OK:
		_poster_save.text = "SAVED"
		_poster_save.disabled = true


func _on_line_changed(_idx: int) -> void:
	var line := GameState.current_line()
	if line:
		show_caption(line.text)
