class_name BarrelFire
extends BoardObject
## An oil drum fire on the noir street. The barrel, bands, flames and the warm PointLight2D are
## authored in the scene; this script pulses the flame heights and the light energy every frame.

const FLAME_COUNT := 6
const BASE_Y := -44.0

@onready var _light: PointLight2D = $Fire
@onready var _flames: Array[Polygon2D] = [$Flame0, $Flame1, $Flame2, $Flame3, $Flame4, $Flame5]

var _light_base := 1.1


func on_tick() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in FLAME_COUNT:
		var fx := (i - 2.5) * 5.0
		var fh := 18.0 + sin(t * 8.0 + i) * 8.0
		_flames[i].polygon = PackedVector2Array([
			Vector2(fx - 4.0, BASE_Y),
			Vector2(fx, BASE_Y - fh),
			Vector2(fx + 4.0, BASE_Y),
		])
	var fl := 0.7 + 0.3 * sin(t * 7.0) + 0.1 * sin(t * 19.0)
	_light.energy = _light_base * fl
