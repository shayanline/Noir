extends Node
const SHOTS := "user://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var lib = load("res://stories/library.tres")
	var main = load("res://scenes/core/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._on_enter(lib.stories[0])
	await get_tree().create_timer(10.0).timeout
	get_viewport().get_texture().get_image().save_png("%s/neon_dark.png" % SHOTS)
	print("shot")
	get_tree().quit()
