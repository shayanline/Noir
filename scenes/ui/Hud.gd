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

const _ELITE := preload("res://fonts/SpecialElite.ttf")   # the typewriter font, for the scene tag tracking

const _BONE := Color(0.847, 0.831, 0.784, 1)
const _WHITE := Color(1, 1, 1, 1)
const _LINE := Color(0.863, 0.847, 0.784, 0.16)
const _SCRIM := Color(0, 0, 0, 0.92)
const _CELL := 52.0
const _GAP := 6
const _EDGE := 20.0
const _CAP_VP := Vector2i(1200, 360)   # the caption render target, tall enough that a multi line panel
                                       # (anchored at the bottom, growing up) never clips against the top
const _CAP_IN := 1.15                  # narration torn reveal in (s)
const _CAP_OUT := 0.46                 # narration torn wipe out (s)
const _CAP_VARIANTS := 3

var _tag: Label
var _caption: PanelContainer
var _caption_label: RichTextLabel
var _cap_vp: SubViewport
var _cap_tex: TextureRect
var _cap_mat: ShaderMaterial
var _cap_shown := false
var _cap_tween: Tween
var _tap: Label

var _review_btn: Button
var _navdrop: VBoxContainer
var _end_box: CenterContainer
var _end_row: HBoxContainer

var _modal_layer: CanvasLayer
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
var _controls_seen := false
var _poster_image: Image

# references kept for rescaling
var _topbar: HBoxContainer
var _chips: Array[Button] = []
var _actsel_col: VBoxContainer


func _ready() -> void:
	# the pause menu lives here, so the HUD must keep processing input while the rest of the tree is
	# paused (Main pauses the whole tree on pause), otherwise the menu could never be dismissed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_scene_tag()
	_build_caption()
	_build_tap()
	_build_topbar()
	_build_actsel()
	_build_menu()
	_build_poster()
	GameState.line_changed.connect(_on_line_changed)
	UIScale.scale_changed.connect(_rescale)
	_rescale()


# --- construction --------------------------------------------------------

func _build_scene_tag() -> void:
	_tag = Label.new()
	_tag.theme_type_variation = &"SceneTag"
	_tag.modulate.a = 0.0
	_tag.position = Vector2(_EDGE, _EDGE)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)


func _build_caption() -> void:
	# the caption (paper panel plus text) renders into a SubViewport, so the torn reveal shader can
	# mask the whole thing as one image. The panel hugs its text, anchored near the viewport's bottom.
	_cap_vp = SubViewport.new()
	# render at 2x and present at the logical size, so the caption text stays crisp when the canvas
	# is scaled up (the layout still happens at _CAP_VP via the size override)
	_cap_vp.size = _CAP_VP * 2
	_cap_vp.size_2d_override = _CAP_VP
	_cap_vp.size_2d_override_stretch = true
	_cap_vp.transparent_bg = true
	_cap_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_cap_vp.gui_disable_input = true
	add_child(_cap_vp)

	_caption = PanelContainer.new()
	_caption.theme_type_variation = &"CaptionPanel"
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_bottom = -16.0
	_cap_vp.add_child(_caption)
	_caption_label = RichTextLabel.new()
	_caption_label.bbcode_enabled = true
	# fit_content is off on purpose: with it on, RichTextLabel ignores the width cap and lays a long
	# line out in one row (running off the screen). Instead the width is pinned and the size is set
	# from the measured wrapped content in _hug_caption.
	_caption_label.fit_content = false
	_caption_label.scroll_active = false
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.custom_minimum_size = Vector2(560, 0)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# legacy CSS uses text-align: center on the caption box
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_child(_caption_label)

	_cap_mat = ShaderMaterial.new()
	_cap_mat.shader = load("res://shaders/caption_clip.gdshader")
	_cap_mat.set_shader_parameter("reveal", 0.0)
	_cap_tex = TextureRect.new()
	_cap_tex.texture = _cap_vp.get_texture()
	_cap_tex.material = _cap_mat
	_cap_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# ignore the texture's own size (it is rendered at 2x for crispness): present it at the logical
	# size below, otherwise the rect grows to the 2x backing and the caption runs off the screen
	_cap_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cap_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_cap_tex.custom_minimum_size = Vector2(_CAP_VP)
	_cap_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_tex.anchor_left = 0.5
	_cap_tex.anchor_right = 0.5
	_cap_tex.anchor_top = 1.0
	_cap_tex.anchor_bottom = 1.0
	_cap_tex.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cap_tex.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cap_tex.offset_bottom = -48.0
	add_child(_cap_tex)


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
	_topbar = HBoxContainer.new()
	_topbar.add_theme_constant_override("separation", _GAP)
	_topbar.mouse_filter = Control.MOUSE_FILTER_PASS
	_topbar.anchor_left = 1.0
	_topbar.anchor_right = 1.0
	_topbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_topbar.offset_left = -220.0
	_topbar.offset_right = -_EDGE
	_topbar.offset_top = _EDGE
	_topbar.alignment = BoxContainer.ALIGNMENT_END
	add_child(_topbar)
	_chips.append(_chip(HudIcon.Kind.POSTER, func(): poster_requested.emit(), "Save a poster of this frame"))
	_chips.append(_chip(HudIcon.Kind.FULLSCREEN, _toggle_fullscreen, "Fullscreen"))
	_chips.append(_chip(HudIcon.Kind.MENU, _open_menu, "Menu"))
	for c in _chips:
		_topbar.add_child(c)


func _chip(kind: HudIcon.Kind, on_press: Callable, tip: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"HudButton"
	b.custom_minimum_size = Vector2(_CELL, _CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	var icon := HudIcon.new()
	icon.kind = kind
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	b.mouse_entered.connect(func(): icon.set_tint(_WHITE))
	b.mouse_exited.connect(func(): icon.set_tint(Color(0.788, 0.769, 0.714, 1)))
	return b


func _build_actsel() -> void:
	_actsel_col = VBoxContainer.new()
	var col := _actsel_col
	col.add_theme_constant_override("separation", _GAP)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.position = Vector2(_EDGE, _EDGE)
	col.add_theme_constant_override("alignment", 0)
	add_child(col)

	_review_btn = Button.new()
	_review_btn.theme_type_variation = &"ReviewButton"
	_review_btn.text = "REVIEW ACT"
	_review_btn.custom_minimum_size = Vector2(_CELL * 3 + _GAP * 2, _CELL)
	_review_btn.focus_mode = Control.FOCUS_NONE
	_review_btn.visible = false
	_review_btn.pressed.connect(_toggle_drop)
	# the dropdown chevron, drawn in code so it renders on the web Compatibility build
	var chevron := Glyph.new()
	chevron.kind = Glyph.Kind.CHEVRON
	chevron.color = Color(0.847, 0.831, 0.784, 1)
	chevron.anchor_left = 1.0
	chevron.anchor_right = 1.0
	chevron.anchor_top = 0.5
	chevron.anchor_bottom = 0.5
	chevron.offset_left = -22.0
	chevron.offset_right = -8.0
	chevron.offset_top = -5.0
	chevron.offset_bottom = 5.0
	_review_btn.add_child(chevron)
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
	# a centered horizontal row of act chips at THE END (like Inkfall's ended scene picker)
	_end_row = HBoxContainer.new()
	_end_row.add_theme_constant_override("separation", 16)
	_end_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_box.add_child(_end_row)


## The pause menu and the poster modal must sit above everything, including the Transitions layer
## (100) that draws the act cards and THE END, and the start screen. A dedicated high CanvasLayer
## lifts them over the lot. It inherits the HUD's PROCESS_MODE_ALWAYS, so the menu still works paused.
func _modal_root() -> CanvasLayer:
	if _modal_layer == null:
		_modal_layer = CanvasLayer.new()
		_modal_layer.layer = 200
		add_child(_modal_layer)
	return _modal_layer


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	_modal_root().add_child(_menu)
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
		v.custom_minimum_size = Vector2(400, 0)
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
	# the red diamond markers only appear on the hovered item, never at rest
	var dl := _menu_dot(0.08)
	var dr := _menu_dot(0.92)
	b.add_child(dl)
	b.add_child(dr)
	dl.modulate.a = 0.0
	dr.modulate.a = 0.0
	b.mouse_entered.connect(func():
		dl.modulate.a = 1.0
		dr.modulate.a = 1.0)
	b.mouse_exited.connect(func():
		dl.modulate.a = 0.0
		dr.modulate.a = 0.0)
	return b


func _menu_dot(ax: float) -> Glyph:
	# drawn in code (not a font glyph), so the red diamond renders on the web Compatibility build too
	var d := Glyph.new()
	d.kind = Glyph.Kind.DIAMOND
	d.color = Color(0.882, 0, 0.063)
	d.anchor_left = ax
	d.anchor_right = ax
	d.anchor_top = 0.5
	d.anchor_bottom = 0.5
	d.offset_left = -5.0
	d.offset_right = 5.0
	d.offset_top = -5.0
	d.offset_bottom = 5.0
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


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
	line.custom_minimum_size = Vector2(0, 2)
	wrap.add_child(line)
	return wrap


func _build_poster() -> void:
	_poster = Control.new()
	_poster.set_anchors_preset(Control.PRESET_FULL_RECT)
	_poster.visible = false
	_modal_root().add_child(_poster)
	# same chrome as the pause menu: a dimmed scrim behind one double ruled framed card
	var scrim := ColorRect.new()
	scrim.color = _SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_poster())
	_poster.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poster.add_child(center)
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

	# the poster preview is the hero: it already carries the INKFALL wordmark and the narration, so
	# the modal adds no title or caption of its own, just the image and the save and close actions
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	# the composed poster already carries its own inked frame, so the modal shows it directly with
	# no extra matte (that was a border within a border)
	_poster_img = TextureRect.new()
	_poster_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_poster_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_poster_img)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_poster_save = _menu_item("SAVE POSTER", &"MenuItemPrimary", _save_poster)
	row.add_child(_poster_save)
	row.add_child(_menu_item("CANCEL", &"MenuItem", _close_poster))


# --- public API ----------------------------------------------------------

func begin_play() -> void:
	_playing = true
	_ended = false
	if not _controls_seen:
		create_tween().tween_property(_tap, "modulate:a", 1.0, 0.6)
	_refresh_actsel()


## the control hint shows on the first line only, then retires after the first advance, as in Inkfall.
func mark_controls_seen() -> void:
	if _controls_seen:
		return
	_controls_seen = true
	create_tween().tween_property(_tap, "modulate:a", 0.0, 0.4)


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


## reveal a narration line with the torn paper-cut sweep. The direction and torn edge are
## deterministic from the act and line, so a replay always draws the same cut.
func show_caption(text: String) -> void:
	var bb := text.replace("<b>", "[color=#c20012][b]").replace("</b>", "[/b][/color]")
	var variant := (GameState.act_index * 31 + GameState.line_index) % _CAP_VARIANTS
	var seed := float(GameState.act_index * 1009 + GameState.line_index + 1)
	if _cap_tween:
		_cap_tween.kill()
	_cap_tween = create_tween()
	if _cap_shown:
		# wipe the current line out (with its own torn edge), then cut the new line in
		_cap_tween.tween_method(_set_cap_reveal, 1.0, 0.0, _CAP_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_cap_tween.tween_callback(func(): _apply_caption(bb, variant, seed))
	else:
		_apply_caption(bb, variant, seed)
	_cap_tween.tween_method(_set_cap_reveal, 0.0, 1.0, _CAP_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cap_shown = true


func _apply_caption(bb: String, variant: int, seed: float) -> void:
	# pin to the wrap width so the text wraps, then _hug_caption sizes the box to the wrapped content
	_caption_label.custom_minimum_size = Vector2(UIScale.caption_max_w, 0)
	_caption_label.custom_maximum_size.x = UIScale.caption_max_w
	_caption_label.text = bb
	_cap_mat.set_shader_parameter("variant", variant)
	_cap_mat.set_shader_parameter("seed", seed)
	call_deferred("_hug_caption")


## Size the caption box to the measured wrapped content: the width hugs the longest line (within the
## min and max) and the height fits all the lines, so a short line sits in a tight card while a long
## line wraps at the max width instead of running off the screen.
func _hug_caption() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_caption_label):
		return
	var w := clampf(_caption_label.get_content_width(), UIScale.caption_min_w, UIScale.caption_max_w)
	var h := _caption_label.get_content_height()
	_caption_label.custom_minimum_size = Vector2(w, h)
	_caption_label.custom_maximum_size.x = w


func _set_cap_reveal(v: float) -> void:
	_cap_mat.set_shader_parameter("reveal", v)


func _process(_delta: float) -> void:
	# feed the panel's live bounds (UV within the render target) to the reveal shader, so the torn
	# sweep crosses the visible caption over its full duration rather than racing across empty margins
	if _cap_shown and _caption and _cap_mat:
		# normalize against the live override size, not the _CAP_VP constant: cap_w grows past 1200 on
		# high dpr, and using the wrong width misaligns the torn reveal sweep
		var vp := Vector2(_cap_vp.size_2d_override)
		var p := _caption.position
		var s := _caption.size
		_cap_mat.set_shader_parameter("cap_rect",
			Vector4(p.x / vp.x, p.y / vp.y, (p.x + s.x) / vp.x, (p.y + s.y) / vp.y))


func hide_caption() -> void:
	if _cap_tween:
		_cap_tween.kill()
	_set_cap_reveal(0.0)
	_cap_shown = false


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
	if not _controls_seen:
		set_tap_visible(true)


## tex and image are the same composed poster: tex previews it, image is written on SAVE. The
## preview fills most of the screen so the viewer can judge it before saving, then leaves room for
## the save and close row.
func show_poster(tex: Texture2D, image: Image) -> void:
	_poster_image = image
	_poster_img.texture = tex
	var ts := tex.get_size()
	var vp := get_viewport_rect().size
	var h := clampf(minf(vp.x * 0.6, vp.y * 0.6), 280.0, 900.0)
	_poster_img.custom_minimum_size = Vector2(h * ts.x / maxf(ts.y, 1.0), h)
	_poster_save.text = "SAVE POSTER"
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
	# size and font scale with the device pixel ratio, like the rest of the HUD
	var cell := float(UIScale.hud_cell)
	var gap := roundi(UIScale.gap)
	for i in _titles.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = String(_titles[i]).strip_edges()
		b.add_theme_font_size_override("font_size", UIScale.fs_hud)
		if is_drop:
			b.theme_type_variation = &"NavDrop"
			b.custom_minimum_size = Vector2(cell * 3 + gap * 2, cell)
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
	# read the real window mode each time so the toggle never desyncs (the window may start
	# fullscreen, or the viewer may leave fullscreen with Esc or the OS controls)
	var mode := DisplayServer.window_get_mode()
	var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- poster --------------------------------------------------------------

func _close_poster() -> void:
	_poster.visible = false
	pause_changed.emit(false)


func _save_poster() -> void:
	if _poster_image == null:
		return
	var dir := "user://posters"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/inkfall_%d.png" % [dir, Time.get_unix_time_from_system()]
	if _poster_image.save_png(path) == OK:
		_poster_save.text = "SAVED"
		_poster_save.disabled = true


func _on_line_changed(_idx: int) -> void:
	var line := GameState.current_line()
	if line:
		show_caption(line.text)


# --- responsive scaling --------------------------------------------------

## Apply responsive sizes from UIScale, mirroring the legacy CSS vmin system.
func _rescale() -> void:
	var cell := float(UIScale.hud_cell)
	# round the gap once and use the same integer for both the container separation and the width
	# reservation, so the reserved width matches the laid out width and never clips by a pixel
	var gap := roundi(UIScale.gap)
	var edg := UIScale.edge
	# scene tag position
	_tag.position = Vector2(edg, edg)
	_tag.add_theme_font_size_override("font_size", UIScale.fs_label)
	# the scene tag carries the legacy's wide 0.25em tracking, proportional to its size
	var tag_font := FontVariation.new()
	tag_font.base_font = _ELITE
	tag_font.spacing_glyph = roundi(UIScale.fs_label * 0.25)
	_tag.add_theme_font_override("font", tag_font)
	# caption: resize the SubViewport to match caption_max_w so text is never clipped on HiDPI.
	# supersample 2x only at low dpr, since a HiDPI canvas is already crisp, to save render target memory
	var cap_w := maxi(roundi(UIScale.caption_max_w), _CAP_VP.x)
	var cap_ss := 1 if UIScale.dpr >= 2.0 else 2
	_cap_vp.size = Vector2i(cap_w, _CAP_VP.y) * cap_ss
	_cap_vp.size_2d_override = Vector2i(cap_w, _CAP_VP.y)
	_cap_tex.custom_minimum_size = Vector2(cap_w, _CAP_VP.y)
	_caption_label.add_theme_font_size_override("normal_font_size", UIScale.fs_caption)
	_caption_label.add_theme_font_size_override("bold_font_size", UIScale.fs_caption)
	# pin to the wrap width, then re-hug to the content so the box fits the new size without overflow
	_caption_label.custom_minimum_size.x = UIScale.caption_max_w
	_caption_label.custom_maximum_size.x = UIScale.caption_max_w
	if _cap_shown:
		call_deferred("_hug_caption")
	_cap_tex.offset_bottom = -UIScale.caption_bottom
	# scale the caption panel padding to match the legacy clamp. Duplicate from the theme base (not
	# the resolved stylebox, which is our own override after the first pass) so the border width,
	# scaled by UIScale, stays current.
	var cap_sb: StyleBox = ThemeDB.get_project_theme().get_stylebox("panel", "CaptionPanel")
	if cap_sb is StyleBoxFlat:
		var dup := cap_sb.duplicate() as StyleBoxFlat
		dup.content_margin_left = UIScale.caption_pad_h
		dup.content_margin_right = UIScale.caption_pad_h
		dup.content_margin_top = UIScale.caption_pad_v
		dup.content_margin_bottom = UIScale.caption_pad_v
		_caption.add_theme_stylebox_override("panel", dup)
	# tap note
	_tap.add_theme_font_size_override("font_size", UIScale.fs_note)
	_tap.offset_bottom = -UIScale.tap_bottom
	_tap.offset_top = -UIScale.tap_bottom - 24
	# top bar: recompute offset_left from chip count so chips are never clipped
	var chip_count := _chips.size()
	_topbar.offset_right = -edg
	_topbar.offset_top = edg
	_topbar.offset_left = -(cell * chip_count + gap * (chip_count - 1) + edg)
	_topbar.add_theme_constant_override("separation", gap)
	for chip in _chips:
		chip.custom_minimum_size = Vector2(cell, cell)
		chip.add_theme_font_size_override("font_size", UIScale.fs_hud)
	# review act column, button and the dropdown under it
	_actsel_col.position = Vector2(edg, edg)
	_actsel_col.add_theme_constant_override("separation", gap)
	_review_btn.custom_minimum_size = Vector2(cell * 3 + gap * 2, cell)
	_review_btn.add_theme_font_size_override("font_size", UIScale.fs_hud)
	_navdrop.add_theme_constant_override("separation", gap)
	# end of story act row
	_end_box.offset_top = -UIScale.end_box_top
	_end_box.offset_bottom = -UIScale.end_box_bottom
	_end_row.add_theme_constant_override("separation", roundi(16.0 * UIScale.dpr))
	# rebuild any visible act buttons so their size and font pick up the new scale
	_repaint_nav()
