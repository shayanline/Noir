extends CanvasLayer
## Scene transitions: a shader-driven ink wipe, an act-name title card, and the THE END
## screen. The nodes and their look are authored in the scene, this script drives them. The
## caller orchestrates a scene change as: await close(); swap board; await show_card(title);
## await open().

@onready var _ink: ColorRect = $Ink
@onready var _card: Label = $Card
@onready var _end: Label = $End


func _set_progress(v: float) -> void:
	_ink.material.set_shader_parameter("progress", v)


func close(dur := -1.0) -> void:
	if dur < 0.0:
		dur = Palette.TRANS_IN
	var from: float = _ink.material.get_shader_parameter("progress")
	var tw := create_tween()
	tw.tween_method(_set_progress, from, 1.0, dur)
	await tw.finished


func open(dur := -1.0) -> void:
	if dur < 0.0:
		dur = Palette.TRANS_OUT
	var tw := create_tween()
	tw.tween_method(_set_progress, 1.0, 0.0, dur)
	await tw.finished


func show_card(title: String, hold := -1.0) -> void:
	if hold < 0.0:
		hold = Palette.CARD_HOLD
	_card.text = title
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	await tw.finished


func show_end() -> void:
	var tw := create_tween()
	tw.tween_property(_end, "modulate:a", 1.0, 1.6)
	await tw.finished


func hide_end() -> void:
	_end.modulate.a = 0.0
