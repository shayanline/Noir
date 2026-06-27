class_name StartScreen
extends Control
## The opening screen: the NOIR wordmark, the selected tale's subtitle and blurb, a horizontal tale
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

@onready var _subtitle: Label = $Center/VBox/Subtitle
@onready var _blurb: Label = $Center/VBox/Blurb
@onready var _tales: HBoxContainer = $Center/VBox/Tales
@onready var _enter: Button = $Center/VBox/Enter

var _stories: Array[Story] = []
var _selected := 0
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
	name_lbl.text = s.subtitle
	name_lbl.custom_minimum_size = Vector2(300, 0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.theme_type_variation = &"StoryTagline"
	tag_lbl.text = _first_sentence(s.blurb)
	tag_lbl.custom_minimum_size = Vector2(300, 0)
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag_lbl)

	card.set_meta(&"name_lbl", name_lbl)
	card.set_meta(&"tag_lbl", tag_lbl)
	card.gui_input.connect(func(e: InputEvent): _on_card_input(e, idx))
	card.mouse_entered.connect(func(): _restyle(idx, true))
	card.mouse_exited.connect(func(): _restyle(idx, false))
	_cards.append(card)
	return card


## the tale's first sentence makes a short tagline under its name on the picker card.
func _first_sentence(blurb: String) -> String:
	var dot := blurb.find(". ")
	return blurb.substr(0, dot + 1).strip_edges() if dot != -1 else blurb.strip_edges()


func _on_card_input(e: InputEvent, idx: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_select(idx)


func _select(i: int) -> void:
	_selected = i
	var s: Story = _stories[i]
	_subtitle.text = s.subtitle
	_blurb.text = s.blurb
	for j in _cards.size():
		_restyle(j, false)


## paint a card for its state: the chosen tale stays marked (red frame), the rest light up on hover.
func _restyle(idx: int, hovered: bool) -> void:
	var card := _cards[idx]
	var name_lbl: Label = card.get_meta(&"name_lbl")
	var tag_lbl: Label = card.get_meta(&"tag_lbl")
	if idx == _selected:
		card.theme_type_variation = &"StoryCardCur"
		name_lbl.add_theme_color_override("font_color", _NAME_HI)
		tag_lbl.add_theme_color_override("font_color", _TAG_CUR)
	elif hovered:
		card.theme_type_variation = &"StoryCardHover"
		name_lbl.add_theme_color_override("font_color", _NAME_HI)
		tag_lbl.add_theme_color_override("font_color", _TAG_HI)
	else:
		card.theme_type_variation = &"StoryCard"
		name_lbl.add_theme_color_override("font_color", _NAME_DIM)
		tag_lbl.add_theme_color_override("font_color", _TAG_DIM)
