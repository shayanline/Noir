class_name StartScreen
extends Control
## The opening screen: the bleeding-red title, a tale picker (every story in the library), the
## selected tale's blurb, and ENTER THE CITY. The layout and look are authored in the scene and the
## shared theme, this script only fills in the tales and the chosen blurb. Emits entered(story).

signal entered(story: Story)

const DEFAULT_LIBRARY := "res://stories/library.tres"

@export var library: StoryLibrary

@onready var _subtitle: Label = $Center/VBox/Subtitle
@onready var _blurb: Label = $Center/VBox/Blurb
@onready var _tales: VBoxContainer = $Center/VBox/Tales
@onready var _enter: Button = $Center/VBox/Enter

var _stories: Array[Story] = []
var _selected := 0
var _tale_buttons: Array[Button] = []


func _ready() -> void:
	if library == null and ResourceLoader.exists(DEFAULT_LIBRARY):
		library = load(DEFAULT_LIBRARY)
	_stories = library.stories if library else ([] as Array[Story])

	for i in _stories.size():
		var s: Story = _stories[i]
		var b := Button.new()
		b.theme_type_variation = &"ChoiceButton"
		b.text = s.title + "   ·   " + s.subtitle
		var idx := i
		b.pressed.connect(func(): _select(idx))
		_tale_buttons.append(b)
		_tales.add_child(b)

	_enter.pressed.connect(func():
		AudioDirector.whoosh()
		entered.emit(_stories[_selected]))

	if not _stories.is_empty():
		_select(0)


func _select(i: int) -> void:
	_selected = i
	var s: Story = _stories[i]
	_subtitle.text = s.subtitle
	_blurb.text = s.blurb
	for j in _tale_buttons.size():
		_tale_buttons[j].theme_type_variation = &"ChoiceButtonSelected" if j == i else &"ChoiceButton"
