class_name NoirBackdrop
extends RefCounted
## The base for a scene backdrop (skyline, alley, rooftop, room). Geometry that depends on the
## viewport is built once into `geom` and reused; draw paints it each frame with the camera look
## applied as parallax. `data` is the whole scene dictionary (for backdrop options + ground).

var data := {}
var geom = null
var indoor := false


func build(_f: NoirFrame):
	return null


func draw(_f: NoirFrame) -> void:
	pass
