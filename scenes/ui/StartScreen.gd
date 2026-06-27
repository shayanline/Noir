class_name StartScreen
extends Control
## The opening screen: the bleeding-red title, a tale picker (every story in the library), the
## selected tale's blurb, and ENTER THE CITY. Built in code so it carries the Inkfall look with
## no scene wiring. Emits entered(index) with the chosen tale.

signal entered(index: int)

const OSWALD := "res://fonts/Oswald.ttf"

var _stories: Array = []
var _selected := 0
var _tale_buttons: Array = []
var _subtitle: Label
var _blurb: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stories = StoryLibrary.all()

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	vb.add_child(_title("NOIR"))
	_subtitle = _text("", 26, Color("ece6d6"), 0.28)
	vb.add_child(_subtitle)
	_blurb = _text("", 21, Color(0.92, 0.9, 0.84, 0.72), 0.02, 660)
	vb.add_child(_blurb)
	vb.add_child(_spacer(22))
	vb.add_child(_text("CHOOSE YOUR TALE", 17, Color(0.92, 0.9, 0.84, 0.55), 0.38))

	for i in _stories.size():
		var s: Dictionary = _stories[i]
		var b := _menu_button(String(s["name"]) + "   ·   " + String(s["tagline"]))
		var idx := i
		b.pressed.connect(func(): _select(idx))
		_tale_buttons.append(b)
		vb.add_child(b)

	vb.add_child(_spacer(18))
	var enter := _menu_button("ENTER THE CITY")
	enter.pressed.connect(func():
		AudioDirector.whoosh()
		entered.emit(_selected))
	vb.add_child(enter)

	_select(0)


func _select(i: int) -> void:
	_selected = i
	var s: Dictionary = _stories[i]
	_subtitle.text = String(s["story"].get("subtitle", ""))
	_blurb.text = String(s["story"].get("blurb", ""))
	for j in _tale_buttons.size():
		var b: Button = _tale_buttons[j]
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.border_color = Palette.RED_HOT if j == i else Color(0.92, 0.9, 0.84, 0.45)
		b.add_theme_color_override("font_color", Color.WHITE if j == i else Color("f2eee2"))


func _title(t: String) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := t.substr(0, max(1, int(t.length() / 2.0)))
	var tail := t.substr(head.length())
	hb.add_child(_title_part(head, Color.WHITE))
	hb.add_child(_title_part(tail, Palette.RED_HOT))
	return hb


func _title_part(t: String, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", load(OSWALD))
	l.add_theme_font_size_override("font_size", 140)
	l.add_theme_color_override("font_color", col)
	return l


func _text(t: String, size: int, col: Color, _spacing: float, max_w := 0) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if max_w > 0 else TextServer.AUTOWRAP_OFF
	if max_w > 0:
		l.custom_minimum_size.x = max_w
	l.add_theme_font_override("font", load(OSWALD))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _menu_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", load(OSWALD))
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("f2eee2"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.92, 0.9, 0.84, 0.45)
	normal.set_content_margin_all(16)
	var hover := normal.duplicate()
	hover.border_color = Palette.RED_HOT
	hover.bg_color = Color(0.92, 0.9, 0.84, 0.06)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
