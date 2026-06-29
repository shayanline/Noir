extends Node

const SHOTS := "user://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var lib: StoryLibrary = load("res://stories/library.tres")
	var main: Node = load("res://scenes/core/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._on_enter(lib.stories[0])
	await get_tree().create_timer(9.0).timeout

	# close direction (soak in)
	Transitions._ink.material.set_shader_parameter("direction", 1.0)
	for p in [0.15, 0.35, 0.55, 0.75, 0.90]:
		Transitions._set_progress(p)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"%s/close_%d.png" % [SHOTS, int(p * 100.0)])
		print("close ", p)

	# open direction (tear apart)
	Transitions._ink.material.set_shader_parameter("direction", -1.0)
	for p in [0.75, 0.55, 0.35, 0.15]:
		Transitions._set_progress(p)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"%s/open_%d.png" % [SHOTS, int(p * 100.0)])
		print("open ", p)

	Transitions._set_progress(0.0)
	get_tree().quit()
