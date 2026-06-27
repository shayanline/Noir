class_name NoirScene
extends RefCounted
## One act. Owns its built content (backdrop, lights, objects) and its per scene runtime (flags,
## current line, timing, lightning, brass + ripples). The panel drives the flow; the scene knows
## how to build, light, update and draw itself. Ported from Inkfall's scene/scene.js.

const ANIM_BOLT_GAP := Vector2(5.0, 13.0)

var data := {}
var registry: NoirRegistry

var flags := {}
var line_idx := 0
var scene_start := 0.0
var line_start := 0.0

var lightning := 0.0
var next_bolt := 4.0
var bolt_seed = null

var shells := NoirShells.new()
var ripples := NoirRipples.new()

var backdrop: NoirBackdrop = null
var light_nodes: Array = []
var objects: Array = []


func _init(scene_data: Dictionary, reg: NoirRegistry) -> void:
	data = scene_data
	registry = reg


var ground: float:
	get: return float(data.get("ground", 0.8))

var key_light: Dictionary:
	get: return data.get("key_light", {"x": 0.3, "y": 0.3})

var moon:
	get: return data.get("moon", null)

var indoor: bool:
	get:
		if data.has("indoor"):
			return data["indoor"] == true
		return backdrop != null and backdrop.indoor

var blood_rain: bool:
	get: return data.get("blood_rain", false) == true


func build_content() -> void:
	var bd = data.get("backdrop", null)
	backdrop = registry.create_backdrop(String(bd["type"]), data) if bd else null
	light_nodes.clear()
	for l in data.get("lights", []):
		var node := registry.create(String(l["type"]), l)
		if node:
			light_nodes.append(node)
	objects.clear()
	for p in data.get("cast", []):
		var node := registry.create(String(p["type"]), p)
		if node:
			objects.append(node)


func ensure_geometry(f: NoirFrame) -> void:
	if backdrop and backdrop.geom == null:
		backdrop.geom = backdrop.build(f)


func invalidate_geometry() -> void:
	if backdrop:
		backdrop.geom = null


func on_enter(f: NoirFrame) -> void:
	flags = {}
	line_idx = 0
	scene_start = f.t
	line_start = f.t
	shells.clear()
	ripples.clear()
	lightning = 0.0
	next_bolt = 4.0


func set_line(idx: int, f: NoirFrame) -> void:
	line_idx = idx
	line_start = f.t


func visible(o) -> bool:
	return o.visible_with(flags)


func collect_lights(f: NoirFrame) -> void:
	for L in light_nodes:
		L.emit_light(f)
	for o in objects:
		if visible(o):
			o.emit_light(f)


func draw_backdrop(f: NoirFrame) -> void:
	if backdrop:
		backdrop.draw(f)


func draw_fixtures(f: NoirFrame) -> void:
	for L in light_nodes:
		L.draw(f)


func _layer(layer_name: String) -> Array:
	var out: Array = []
	for o in objects:
		if visible(o) and String(o.layer if o.layer else "mid") == layer_name:
			out.append(o)
	out.sort_custom(func(a, b): return int(a.depth) < int(b.depth))
	return out


func draw_back(f: NoirFrame) -> void:
	for o in _layer("back"):
		o.draw(f)


func draw_objects(f: NoirFrame) -> void:
	for o in _layer("mid"):
		o.draw(f)
	shells.draw(f)


func draw_light_extras(f: NoirFrame) -> void:
	ripples.draw(f)


func update(dt: float, f: NoirFrame) -> void:
	if flags.get("muzzle", 0.0) > 0.0:
		flags["muzzle"] = maxf(0.0, flags["muzzle"] - dt * 2.2)
	for o in objects:
		o.update(dt, f)
	shells.update(dt, f)
	ripples.update(dt)
	bolt_seed = null
	if not indoor:
		if randf() < 0.85:
			ripples.spawn(f)
		next_bolt -= dt
		if next_bolt <= 0.0:
			lightning = maxf(lightning, 0.9)
			if randf() < 0.7:
				bolt_seed = randi()
			next_bolt = ANIM_BOLT_GAP.x + randf() * (ANIM_BOLT_GAP.y - ANIM_BOLT_GAP.x)
		if lightning > 0.0:
			lightning = maxf(0.0, lightning - dt * 3.0)
	else:
		lightning = 0.0


## two shots: each its own gunshot + a brass casing ejected from the gunman in the cast.
func fire_gun(f: NoirFrame, host: Node) -> void:
	var g = null
	for o in objects:
		if o.type == "gunman":
			g = o
			break
	var shot := func():
		AudioDirector.gun()
		if g:
			var s := f.scale_of(g)
			var sx := f.x_of(g) + 48.0 * s
			var sy := f.gy - 84.0 * s
			shells.spawn(sx, sy, s, f.gy + 6.0)
	shot.call()
	host.get_tree().create_timer(0.23).timeout.connect(shot)
