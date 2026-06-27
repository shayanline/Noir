class_name Hud
extends Control
## In-play overlay: the paper caption box, the typed scene tag, the input hint, a mute toggle,
## and the act picker shown at THE END. The nodes and their look are authored in the scene and the
## shared theme, this script only drives them and builds the per-act nav buttons.

signal nav_selected(index: int)

@onready var _tag: Label = $SceneTag
@onready var _caption: PanelContainer = $Caption
@onready var _caption_label: RichTextLabel = $Caption/Text
@onready var _tap: Label = $TapNote
@onready var _mute: Button = $Mute
@onready var _nav: HBoxContainer = $Nav


func _ready() -> void:
	_mute.pressed.connect(_on_mute)


func _on_mute() -> void:
	var on := AudioDirector.toggle_mute()
	_mute.text = "♪" if on else "✕"
	_mute.modulate.a = 1.0 if on else 0.55


# --- API ----------------------------------------------------------------

func begin_play() -> void:
	_mute.visible = true
	create_tween().tween_property(_tap, "modulate:a", 1.0, 0.6)


func set_scene_tag(title: String) -> void:
	_tag.text = title
	_tag.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_tag, "modulate:a", 0.0, 0.5)


func show_caption(text: String) -> void:
	# convert the story's <b>..</b> to red bold bbcode
	var bb := text.replace("<b>", "[color=#c20012][b]").replace("</b>", "[/b][/color]")
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 0.0, 0.17)
	tw.tween_callback(func(): _caption_label.text = bb)
	tw.tween_property(_caption, "modulate:a", 1.0, 0.2)


func hide_caption() -> void:
	_caption.modulate.a = 0.0


func set_tap_visible(v: bool) -> void:
	create_tween().tween_property(_tap, "modulate:a", 1.0 if v else 0.0, 0.3)


func build_nav(titles: Array) -> void:
	for c in _nav.get_children():
		c.queue_free()
	for i in titles.size():
		var b := Button.new()
		b.theme_type_variation = &"NavButton"
		b.text = String(titles[i]).strip_edges()
		var idx := i
		b.pressed.connect(func(): nav_selected.emit(idx))
		_nav.add_child(b)


func show_nav(v: bool) -> void:
	_nav.visible = v
