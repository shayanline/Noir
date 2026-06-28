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
## label while the new one fades in on the other, so there is never a frame of pure black between
## them. If `last` is true (the default) the method awaits the full fade out before returning. Set
## `last` to false when another card follows immediately, so the fade out runs in the background
## and the next show_card can crossfade into it.
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
		# return after the hold so the caller can start the next card while this one is still visible
		await tw.finished
		# kick off the fade out in the background (the next show_card will crossfade into it)
		create_tween().tween_property(cur, "modulate:a", 0.0, Palette.CARD_FADE)


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
