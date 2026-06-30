extends Node
## Dev capture tool: runs the real Main, drives it into several acts, and saves PNG frames so the
## look can be reviewed without clicking through by hand. Run windowed (not headless):
##   Godot --path . tools/Shoot.tscn
## Not part of the game. Safe to delete.

const SHOT_DIR := "/tmp/inkfall_shots"

var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_main = load("res://scenes/core/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(0.4).timeout
	await _shot("00_start_screen")

	var lib: StoryLibrary = load("res://stories/library.tres")
	var s0: Story = lib.stories[0]
	var s1: Story = lib.stories[1]

	await _main._on_enter(s0)
	await _settle()
	await _shot("01_hallucination_street")

	_main._playing = true
	await _main._to_act(1)
	await _settle()
	_main._playing = true
	for i in 3:
		_main.advance()
		await get_tree().create_timer(0.5).timeout
	await _shot("02_hallucination_alley_blood")

	_main._playing = true
	await _main._to_act(2)
	await _settle()
	await _shot("03_hallucination_rooftop")

	await _main._on_enter(s1)
	await _settle()
	await _shot("04_danny_street")

	_main._playing = true
	await _main._to_act(1)
	await _settle()
	await _shot("05_danny_casino")

	_main._playing = true
	await _main._to_act(2)
	await _settle()
	await _shot("06_danny_loss")

	print("SHOOT DONE")
	get_tree().quit()


func _settle() -> void:
	await get_tree().create_timer(0.9).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + "/" + name + ".png")
	print("SHOT ", name)
