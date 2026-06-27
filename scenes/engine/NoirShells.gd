class_name NoirShells
extends RefCounted
## Ejected brass casings, spawned on a muzzle flash, tumbling and settling in slow motion. A
## scene owned system (not a placed object). Drawn to the world canvas, over the cast.

var list: Array = []


func spawn(x: float, y: float, s: float, gy: float) -> void:
	list.append({
		"x": x, "y": y, "s": s, "gy": gy,
		"vx": 0.2 + randf() * 0.7, "vy": -2.6 - randf() * 1.0,
		"rot": randf() * 6.0, "vr": (randf() - 0.5) * 0.7, "rest": false,
	})


func clear() -> void:
	list.clear()


func update(dt: float, _f: NoirFrame) -> void:
	var sdt: float = minf(dt, 0.05) * 0.32
	for sh in list:
		if sh["rest"]:
			continue
		sh["vy"] += 16.0 * sdt
		sh["x"] += sh["vx"] * 60.0 * sdt
		sh["y"] += sh["vy"] * 60.0 * sdt
		sh["rot"] += sh["vr"] * sdt * 18.0
		if sh["y"] >= sh["gy"]:
			if sh["vy"] > 1.0:
				AudioDirector.shell_clink()
			sh["y"] = sh["gy"]
			sh["vy"] *= -0.34
			sh["vx"] *= 0.5
			sh["vr"] *= 0.5
			if absf(sh["vy"]) < 0.7:
				sh["rest"] = true
				sh["vy"] = 0.0


func draw(f: NoirFrame) -> void:
	for sh in list:
		var s: float = sh["s"]
		f.save()
		f.translate(sh["x"], sh["y"])
		f.rotate(sh["rot"])
		f.fill_rect(-3.4 * s, -1.4 * s, 6.8 * s, 2.8 * s, Color("c9a24a"))
		f.fill_rect(-3.4 * s, -1.4 * s, 2.0 * s, 2.8 * s, Color("e6c878"))
		f.restore()
