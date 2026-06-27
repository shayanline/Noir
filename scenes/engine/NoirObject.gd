class_name NoirObject
extends RefCounted
## The base for everything placed in a scene, the native equal of Inkfall's Node. It holds the
## normalized transform plus every optional story param the library reads, and the lifecycle
## hooks (draw, update, emit_light). Library types subclass this and override the hooks, so a
## draw reads its params off self exactly like the original this-bound functions.

# core transform
var type := ""
var x := 0.5
var y = null            # null means "derive from ground" in many draws
var par = null          # null means 0.5 in the coordinate helpers
var scale = null        # null means 1
var depth := 0
var layer := "mid"      # "back" draws behind the backdrop, "mid" with the cast
var flip := false
var dy = null
var seed = null

# reveal by event flag (set by a line's fx)
var on_flag = null
var hide_on_flag = null

# animation / timed beats
var walk = null
var walk_dur = null
var pass_x = null
var raise_at = null
var light_at = null
var green_at = null
var fly_at = null
var delay = null
var drain_at = null
var drain_x = null
var drain_y = null
var rest_x = null

# prop / light params
var kind = null
var bloody = null
var glow = null
var label := ""
var angle = null
var red = null
var w = null
var h = null
var color = null
var intensity = null
var flicker = null
var ignite = null
var arrow = null
var r = null

# transient per-frame caches set in emit_light and read in draw
var _flick := 1.0
var _x := 0.0
var _s := 0.0
var _ly := 0.0
var _rim := 0


func apply_params(params: Dictionary) -> void:
	for k in params:
		set(k, params[k])


func visible_with(flags: Dictionary) -> bool:
	if on_flag != null and not flags.get(on_flag, false):
		return false
	if hide_on_flag != null and flags.get(hide_on_flag, false):
		return false
	return true


# lifecycle hooks, overridden by library types
func update(_dt: float, _f: NoirFrame) -> void:
	pass


func emit_light(_f: NoirFrame) -> void:
	pass


func draw(_f: NoirFrame) -> void:
	pass
