extends CanvasLayer
## Scene transitions: a shader-driven ink wipe, an act-name title card, and the THE END
## screen. The nodes and their look are authored in the scene, this script drives them. The
## caller orchestrates a scene change as: await close(); swap board; await show_card(title);
## await open().

@onready var _ink: ColorRect = $Ink
@onready var _cards: Array[Label] = [$Card, $CardB]
@onready var _end: Label = $End

var _progress := 0.0
var _card_slot := 0


func _ready() -> void:
	UIScale.scale_changed.connect(_rescale)
	_rescale()


func _set_progress(v: float) -> void:
	_progress = v
	_ink.material.set_shader_parameter("progress", v)


## cover the screen with ink at once (no wipe), used to open a tale on the story-title card.
func cover() -> void:
	_set_progress(1.0)


func close(dur := -1.0) -> void:
	if dur < 0.0:
		dur = Palette.TRANS_IN
	_ink.material.set_shader_parameter("direction", 1.0)
	var from := _progress
	var tw := create_tween()
	tw.tween_method(_set_progress, from, 1.0, dur)
	await tw.finished


func open(dur := -1.0) -> void:
	if dur < 0.0:
		dur = Palette.TRANS_OUT
	_ink.material.set_shader_parameter("direction", -1.0)
	var tw := create_tween()
	tw.tween_method(_set_progress, 1.0, 0.0, dur)
	await tw.finished


## show a title card over the ink. Back to back calls crossfade: the old title fades out on one
## label while the new one fades in on the other. If `last` is true (the default) the method awaits
## the full fade out before returning. Set `last` to false when another card follows immediately:
## the fade out starts, and the method returns after (1 - CARD_OVERLAP) of the fade out has elapsed,
## so the next show_card can start its fade in while the old one is still partially visible.
## CARD_OVERLAP = 0 means fully sequential (fade out finishes, then fade in starts).
## CARD_OVERLAP = 1 means fully simultaneous (both run at the same time).
func show_card(title: String, hold := -1.0, last := true) -> void:
	if hold < 0.0:
		hold = Palette.CARD_HOLD
	var prev := _cards[_card_slot]
	_card_slot = 1 - _card_slot
	var cur := _cards[_card_slot]
	cur.text = title
	cur.modulate.a = 0.0
	# crossfade: fade out the previous card (fire and forget) while fading in the new one
	if prev.modulate.a > 0.0:
		create_tween().tween_property(prev, "modulate:a", 0.0, Palette.CARD_FADE)
	var tw := create_tween()
	tw.tween_property(cur, "modulate:a", 1.0, Palette.CARD_FADE)
	tw.tween_interval(hold)
	if last:
		tw.tween_property(cur, "modulate:a", 0.0, Palette.CARD_FADE)
		await tw.finished
	else:
		await tw.finished
		# start the fade out, then wait for part of it before returning so the next card overlaps
		create_tween().tween_property(cur, "modulate:a", 0.0, Palette.CARD_FADE)
		var wait := Palette.CARD_FADE * (1.0 - Palette.CARD_OVERLAP)
		if wait > 0.01:
			await get_tree().create_timer(wait).timeout


func show_end() -> void:
	var tw := create_tween()
	tw.tween_property(_end, "modulate:a", 1.0, 1.6)
	await tw.finished


func hide_end() -> void:
	_end.modulate.a = 0.0


## clear every overlay at once (used when leaving a story mid play), so the screen is clean.
func clear() -> void:
	_set_progress(0.0)
	for c in _cards:
		c.modulate.a = 0.0
	_end.modulate.a = 0.0


## Apply responsive font sizes from UIScale.
func _rescale() -> void:
	for c in _cards:
		c.add_theme_font_size_override("font_size", UIScale.fs_card)
	_end.add_theme_font_size_override("font_size", UIScale.fs_end)
