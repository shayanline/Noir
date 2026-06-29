extends Node2D
## Throwaway visual check (delete when done). Builds an act with the Main render setup and saves a
## screenshot. Run: Godot --path . --rendering-driver opengl3 --resolution 1920x1080 tools/LightShot.tscn

const ENV := preload("res://scenes/core/Environment.tres")
const POST_MAT := preload("res://scenes/core/post_material.tres")

const STORY_INDEX := 0
const ACT_INDEX := 0
const LINE_INDEX := 1
const OUT_PATH := "/tmp/inkfall_check.png"


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cm := CanvasModulate.new()
	cm.color = Color(0.30, 0.32, 0.40)
	add_child(cm)
	var we := WorldEnvironment.new()
	we.environment = ENV
	add_child(we)
	var cam := Camera2D.new()
	cam.position = vp * 0.5
	add_child(cam)
	var world := Node2D.new()
	add_child(world)

	var lib: StoryLibrary = load("res://stories/library.tres")
	var story: Story = lib.stories[STORY_INDEX]
	GameState.load_story(story)
	var act: Act = story.acts[ACT_INDEX]
	var board: Board = load("res://scenes/board/Board.tscn").instantiate()
	board.setup(act)
	world.add_child(board)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var post := ColorRect.new()
	post.material = POST_MAT
	post.anchor_right = 1.0
	post.anchor_bottom = 1.0
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(post)

	var pm: ShaderMaterial = POST_MAT
	pm.set_shader_parameter("screen_size", vp)
	pm.set_shader_parameter("reflect_horizon", clampf((board.position.y + board.ground_y) / vp.y, 0.0, 1.0))
	pm.set_shader_parameter("reflect_strength", 0.0 if act.indoor else 0.35)

	await get_tree().process_frame
	await get_tree().process_frame
	GameState.line_index = LINE_INDEX
	GameState.notify_line()

	var t := 0.0
	for i in 110:
		pm.set_shader_parameter("time", t)
		t += 1.0 / 60.0
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PATH)
	print("SHOT SAVED ", OUT_PATH)
	get_tree().quit()
