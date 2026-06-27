class_name NoirRipples
extends RefCounted
## Expanding puddle ripples on the wet floor, each tinted by the light above it (or bloody on a
## blood rain scene). A scene owned system; drawn additively to the light layer.

var list: Array = []


func spawn(f: NoirFrame) -> void:
	var x := randf() * f.W
	var y := f.gy + randf() * (f.H - f.gy) * 0.9
	var blood: bool = f.scene.data.get("blood_rain", false) == true
	var col: Color = Color(220.0 / 255.0, 24.0 / 255.0, 34.0 / 255.0) if blood else f.lit_color(x, Color(150.0 / 255.0, 162.0 / 255.0, 180.0 / 255.0))
	list.append({"x": x, "y": y, "r": 1.0, "max": 10.0 + randf() * 26.0, "life": 1.0, "col": col, "blood": blood})


func clear() -> void:
	list.clear()


func update(dt: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		p["r"] += dt * 34.0
		p["life"] -= dt * 1.1
		if p["life"] <= 0.0 or p["r"] > p["max"]:
			list.remove_at(i)


func draw(f: NoirFrame) -> void:
	for p in list:
		var a: float = (0.42 if p["blood"] else 0.22) * p["life"]
		var width: float = 1.9 if p["blood"] else 1.2
		f.glow_ring(p["x"], p["y"], p["r"], p["r"] * 0.4, p["col"], a, width)
