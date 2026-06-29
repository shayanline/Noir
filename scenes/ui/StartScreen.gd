class_name StartScreen
extends Control
## The opening screen: the INKFALL wordmark, the selected tale's subtitle and blurb, a horizontal tale
## picker (every story in the library, each a framed card with its name and tagline) and ENTER THE
## CITY. The layout and look are authored in the scene and the shared theme, this script fills in the
## tales and the chosen blurb and tracks the selection. Emits entered(story). Carries over Inkfall's
## start screen.

signal entered(story: Story)

const DEFAULT_LIBRARY := "res://stories/library.tres"

const _NAME_DIM := Color(0.949, 0.933, 0.886, 1)
const _NAME_HI := Color(1, 1, 1, 1)
const _TAG_DIM := Color(0.925, 0.902, 0.839, 0.6)
const _TAG_HI := Color(0.925, 0.902, 0.839, 0.88)
const _TAG_CUR := Color(0.918, 0.353, 0.353, 1)

@export var library: StoryLibrary

@onready var _title_head: Label = $Center/VBox/Title/Head
@onready var _title_tail: Label = $Center/VBox/Title/Tail
@onready var _subtitle: Label = $Center/VBox/Subtitle
@onready var _blurb: Label = $Center/VBox/Blurb
@onready var _heading: Label = $Center/VBox/Heading
@onready var _tales: HBoxContainer = $Center/VBox/Tales
@onready var _enter: Button = $Center/VBox/Enter
@onready var _vbox: VBoxContainer = $Center/VBox
@onready var _spacer1: Control = $Center/VBox/Spacer1
@onready var _spacer2: Control = $Center/VBox/Spacer2

var _stories: Array[Story] = []
var _selected := 0
var _hovered := -1
var _cards: Array[PanelContainer] = []


func _ready() -> void:
	if library == null and ResourceLoader.exists(DEFAULT_LIBRARY):
		library = load(DEFAULT_LIBRARY)
	_stories = library.stories if library else ([] as Array[Story])

	for i in _stories.size():
		_tales.add_child(_make_card(_stories[i], i))

	_enter.pressed.connect(func():
		AudioDirector.whoosh()
		entered.emit(_stories[_selected]))

	if not _stories.is_empty():
		_select(0)

	UIScale.scale_changed.connect(_rescale)
	_rescale()


func _make_card(s: Story, idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"StoryCard"
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var name_lbl := Label.new()
	name_lbl.theme_type_variation = &"StoryName"
	name_lbl.text = s.picker_name if s.picker_name else s.subtitle
	name_lbl.custom_minimum_size = Vector2(300, 0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.theme_type_variation = &"StoryTagline"
	tag_lbl.text = s.picker_tagline if s.picker_tagline else s.subtitle
	tag_lbl.custom_minimum_size = Vector2(300, 0)
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag_lbl)

	card.set_meta(&"name_lbl", name_lbl)
	card.set_meta(&"tag_lbl", tag_lbl)
	card.set_meta(&"inner_box", box)
	card.gui_input.connect(func(e: InputEvent): _on_card_input(e, idx))
	card.mouse_entered.connect(func(): _set_hovered(idx))
	card.mouse_exited.connect(func(): _set_hovered(-1, idx))
	_cards.append(card)
	return card


func _on_card_input(e: InputEvent, idx: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_select(idx)


func _select(i: int) -> void:
	_selected = i
	_hovered = -1
	var s: Story = _stories[i]
	_subtitle.text = s.subtitle
	_blurb.text = s.blurb
	_repaint_cards()


## track the hovered card. `only_if` clears the hover only when it still belongs to that card, so a
## stale mouse_exited cannot wipe a newer hover. Touch input rarely fires mouse_exited, so the styling
## never relies on it staying balanced: every change repaints all cards from _selected and _hovered.
func _set_hovered(idx: int, only_if := -2) -> void:
	if only_if != -2 and _hovered != only_if:
		return
	_hovered = idx
	_repaint_cards()


## paint every card from the single source of truth (_selected and _hovered), so exactly one card can
## be marked current and at most one hovered, and none can get stuck highlighted.
func _repaint_cards() -> void:
	for idx in _cards.size():
		_restyle(idx)


func _restyle(idx: int) -> void:
	var card := _cards[idx]
	var name_lbl: Label = card.get_meta(&"name_lbl")
	var tag_lbl: Label = card.get_meta(&"tag_lbl")
	if idx == _selected:
		card.theme_type_variation = &"StoryCardCur"
		name_lbl.add_theme_color_override("font_color", _NAME_HI)
		tag_lbl.add_theme_color_override("font_color", _TAG_CUR)
	elif idx == _hovered:
		card.theme_type_variation = &"StoryCardHover"
		name_lbl.add_theme_color_override("font_color", _NAME_HI)
		tag_lbl.add_theme_color_override("font_color", _TAG_HI)
	else:
		card.theme_type_variation = &"StoryCard"
		name_lbl.add_theme_color_override("font_color", _NAME_DIM)
		tag_lbl.add_theme_color_override("font_color", _TAG_DIM)
	# the padding override below shadows the variation's panel, so re-sync it to the new variation,
	# otherwise the selected (red) border would stick on whichever card was current at the last scale
	_apply_card_padding(card)


## Override the card's panel stylebox with the dpr scaled padding, duplicated from the theme base of
## the card's current variation so the variation's border colour is preserved.
func _apply_card_padding(card: PanelContainer) -> void:
	var sb: StyleBox = ThemeDB.get_project_theme().get_stylebox("panel", card.theme_type_variation)
	if sb is StyleBoxFlat:
		var dup := sb.duplicate() as StyleBoxFlat
		dup.content_margin_left = UIScale.card_pad_h
		dup.content_margin_right = UIScale.card_pad_h
		dup.content_margin_top = UIScale.card_pad_v
		dup.content_margin_bottom = UIScale.card_pad_v
		card.add_theme_stylebox_override("panel", dup)


## Apply responsive font sizes from the UIScale autoload, mirroring the legacy CSS vmin system.
func _rescale() -> void:
	_title_head.add_theme_font_size_override("font_size", UIScale.fs_title)
	_title_tail.add_theme_font_size_override("font_size", UIScale.fs_title)
	_subtitle.add_theme_font_size_override("font_size", UIScale.fs_sub)
	_blurb.add_theme_font_size_override("font_size", UIScale.fs_body)
	_heading.add_theme_font_size_override("font_size", UIScale.fs_label)
	_enter.add_theme_font_size_override("font_size", UIScale.fs_sub)
	_vbox.add_theme_constant_override("separation", UIScale.vbox_sep)
	_tales.add_theme_constant_override("separation", UIScale.tales_gap)
	_spacer1.custom_minimum_size.y = UIScale.spacer
	_spacer2.custom_minimum_size.y = UIScale.spacer
	# enter button padding. Duplicate from the theme base (not the resolved stylebox, which is our
	# own override after the first pass) so the dpr scaled border width stays current.
	for state in ["normal", "hover", "pressed"]:
		var sb: StyleBox = ThemeDB.get_project_theme().get_stylebox(state, _enter.theme_type_variation)
		if sb is StyleBoxFlat:
			var dup := sb.duplicate() as StyleBoxFlat
			dup.content_margin_left = UIScale.enter_pad_h
			dup.content_margin_right = UIScale.enter_pad_h
			dup.content_margin_top = UIScale.enter_pad_v
			dup.content_margin_bottom = UIScale.enter_pad_v
			_enter.add_theme_stylebox_override(state, dup)
	# story cards
	for card in _cards:
		var name_lbl: Label = card.get_meta(&"name_lbl")
		var tag_lbl: Label = card.get_meta(&"tag_lbl")
		name_lbl.add_theme_font_size_override("font_size", UIScale.fs_sub)
		name_lbl.custom_minimum_size.x = UIScale.card_min_w
		tag_lbl.add_theme_font_size_override("font_size", UIScale.fs_tagline)
		tag_lbl.custom_minimum_size.x = UIScale.card_min_w
		var inner_box: VBoxContainer = card.get_meta(&"inner_box")
		inner_box.add_theme_constant_override("separation", UIScale.card_sep)
		_apply_card_padding(card)
	# the bigger phone sizes can make this dense column taller than a short landscape phone, so
	# shrink it to fit once the new sizes have settled. It stays centered and never clips.
	call_deferred("_fit_to_height")


## Scale the centered column down if it is taller than the screen, so nothing clips on a short
## viewport. When it fits, the scale is 1 and the layout is untouched.
func _fit_to_height() -> void:
	_vbox.pivot_offset = Vector2.ZERO
	_vbox.scale = Vector2.ONE
	await get_tree().process_frame
	var needed := _vbox.size.y
	if needed <= 0.0:
		return
	var s := minf(1.0, size.y / needed)
	if s < 1.0:
		_vbox.pivot_offset = _vbox.size * 0.5
		_vbox.scale = Vector2(s, s)
