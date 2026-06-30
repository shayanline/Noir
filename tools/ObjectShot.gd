extends Node2D
## Throwaway isolation harness (delete when done). Hosts ONE object on its own, on a real Board with
## an otherwise empty act, so you can probe a single change (an actor, a prop, a light, a backdrop)
## without the rest of the cast or another act masking it. The object is built through the exact
## production path (Board._spawn: setup, place, occluders, volume light, signal wiring), just with
## nothing else around it. Run windowed:
##   Godot --path . --rendering-driver opengl3 --resolution 1920x1080 tools/ObjectShot.tscn
## Point it at what you changed with the constants below, then look at the saved PNG.

const ENV := preload("res://scenes/core/Environment.tres")
const POST_MAT := preload("res://scenes/core/post_material.tres")

## --- what to probe (edit these) -------------------------------------------------------------
const SCENE_PATH := "res://scenes/actors/Gunman.tscn"  ## the object scene under test
const ROLE := "cast"                                   ## "cast", "light" or "backdrop"
const PARAMS := {"x": 0.5}                              ## the Placement params (x, y, scale, flip, ...)
const LINE_INDEX := 0                                  ## the beat to deliver (drives on_line)
const FX := ""                                         ## one fx to fire after the line, e.g. "muzzle"
const INDOOR := true                                   ## true keeps the stage clean (no sky, no rain)
const WITH_POST := true                                ## the noir grade, turn off to inspect raw art
const GROUND := 0.8                                    ## ground line, 0..1 of board height
const KEY_LIGHT := Vector2(0.5, 0.35)                  ## key light position, 0..1 of the board
const OUT_PATH := "/tmp/inkfall_object.png"
## -------------------------------------------------------------------------------------------


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

	var board: Board = load("res://scenes/board/Board.tscn").instantiate()
	board.setup(_lone_act())
	world.add_child(board)

	var pm: ShaderMaterial = POST_MAT
	if WITH_POST:
		var layer := CanvasLayer.new()
		layer.layer = 1
		add_child(layer)
		var post := ColorRect.new()
		post.material = POST_MAT
		post.anchor_right = 1.0
		post.anchor_bottom = 1.0
		post.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(post)
		pm.set_shader_parameter("screen_size", vp)
		pm.set_shader_parameter("reflect_horizon", clampf((board.position.y + board.ground_y) / vp.y, 0.0, 1.0))
		pm.set_shader_parameter("reflect_strength", 0.0 if INDOOR else 0.35)

	await get_tree().process_frame
	await get_tree().process_frame
	GameState.line_index = LINE_INDEX
	GameState.notify_line()
	if FX != "":
		GameState.fire_fx(FX)

	var t := 0.0
	for i in 110:
		if WITH_POST:
			pm.set_shader_parameter("time", t)
		t += 1.0 / 60.0
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PATH)
	print("SHOT SAVED ", OUT_PATH)
	get_tree().quit()


## A real Act carrying only the one object under test, so the board stages it exactly as in a
## story but with nothing else on the stage.
func _lone_act() -> Act:
	var act := Act.new()
	act.indoor = INDOOR
	act.ground = GROUND
	act.key_light = KEY_LIGHT
	act.has_moon = false
	var pl := Placement.new()
	pl.scene = load(SCENE_PATH)
	pl.params = PARAMS
	match ROLE:
		"backdrop":
			act.backdrop = pl
		"light":
			var lights: Array[Placement] = [pl]
			act.lights = lights
		_:
			var cast: Array[Placement] = [pl]
			act.cast = cast
	return act
