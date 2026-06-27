class_name NoirBackdrops
extends RefCounted
## The settings: skyline, alley, rooftop and room, ported from Inkfall's library/backdrops. The
## procedural skyline (seeded buildings + windows), the shared wet floor, and the alley furniture
## live here. Each backdrop builds viewport geometry once and paints it with the camera look as
## parallax. register() adds them all to the registry.

const PAD := 0.0


static func register(reg: NoirRegistry) -> void:
	reg.register_backdrop("skyline", Skyline)
	reg.register_backdrop("alley", Alley)
	reg.register_backdrop("rooftop", Rooftop)
	reg.register_backdrop("room", Room)


# --- shared skyline core ------------------------------------------------------------------

static func build_skyline(f: NoirFrame, seed_value: int, cfg_list: Array, ground_y: float) -> Array:
	var rng := NoirMath.rand32(seed_value)
	var layers := []
	for cfg in cfg_list:
		var blds := []
		var x := -140.0
		while x < f.W + 220.0:
			var w: float = cfg["min_w"] + rng.nextf() * (cfg["max_w"] - cfg["min_w"])
			var h: float = (cfg["min_h"] + rng.nextf() * (cfg["max_h"] - cfg["min_h"])) * (ground_y - cfg["top"])
			var top := ground_y - h
			var wins := []
			var cols: int = maxi(2, int(w / 16.0))
			var rows: int = maxi(3, int(h / 20.0))
			for r in rows:
				for ci in cols:
					if rng.nextf() > cfg["win"]:
						continue
					wins.append({
						"x": x + 7.0 + ci * (w - 14.0) / cols,
						"y": top + 10.0 + r * (h - 16.0) / rows,
						"warm": rng.nextf() > 0.8,
					})
			var cap = null
			if rng.nextf() < 0.25:
				var ctype := "tank" if rng.nextf() < 0.5 else "ant"
				var capx := x + w * (0.3 + rng.nextf() * 0.4)
				cap = {"type": ctype, "x": capx}
			blds.append({"x": x, "w": w, "top": top, "h": h, "wins": wins, "cap": cap})
			x += w + 2.0 + rng.nextf() * 16.0
		layers.append({"depth": cfg["depth"], "shade": cfg["shade"], "blds": blds})
	return layers


static func paint_skyline(f: NoirFrame, layers: Array, par: float) -> void:
	for L in layers:
		var ox: float = par * L["depth"]
		var shade: Color = L["shade"]
		for b in L["blds"]:
			f.fill_rect(b["x"] + ox, b["top"], b["w"], b["h"] + 6.0, shade)
			if b["cap"]:
				var cx: float = b["cap"]["x"] + ox
				if b["cap"]["type"] == "tank":
					f.fill_rect(cx - 7.0, b["top"] - 14.0, 14.0, 14.0, shade)
					f.fill_rect(cx - 9.0, b["top"] - 2.0, 18.0, 3.0, shade)
				else:
					f.fill_rect(cx - 1.0, b["top"] - 22.0, 2.0, 22.0, shade)
		for b in L["blds"]:
			for wn in b["wins"]:
				var wc: Color = Palette.WARM_WIN if wn["warm"] else Palette.COOL_WIN
				f.fill_rect(wn["x"] + ox, wn["y"], 4.0, 5.0, wc)


static func wet_floor(f: NoirFrame) -> void:
	var g := f.gy
	f.fill_rect_vgrad(0, g, f.W, f.H - g, Color8(10, 11, 15), Palette.INK)
	for i in 30:
		var rx := fmod(i * 137.5 + f.t * 6.0, f.W)
		f.fill_rect(rx, g + (i % 6) * (f.H - g) / 6.0, 2.0 + (i % 4), 2.0, Color(Palette.STEEL.r, Palette.STEEL.g, Palette.STEEL.b, 0.10))


static func wall_poly(f: NoirFrame, points: PackedVector2Array) -> void:
	# the alley wall: a dark vertical gradient (the fine brick grid is dropped, walls sit in shadow)
	f.fill_poly_grad(points, Vector2(0, 0), Vector2(0, f.gy), PackedFloat32Array([0.0, 1.0]), [Color8(16, 10, 6), Color8(5, 3, 2)])


static func fire_escape(f: NoirFrame, x: float, top_y: float, h: float, w: float) -> void:
	var rail := Color(120.0 / 255.0, 130.0 / 255.0, 144.0 / 255.0, 0.75)
	var fillc := Color(96.0 / 255.0, 104.0 / 255.0, 116.0 / 255.0, 0.7)
	var floors := int(h / 34.0)
	for i in floors:
		var y := top_y + i * 34.0
		f.fill_rect(x, y, w, 4.0, fillc)
		f.stroke_rect(x, y - 14.0, w, 14.0, rail, 2.0)
		if i % 2 == 0:
			f.line(Vector2(x + 2.0, y + 4.0), Vector2(x + w - 6.0, y + 30.0), rail, 2.0)
		else:
			f.line(Vector2(x + w - 2.0, y + 4.0), Vector2(x + 6.0, y + 30.0), rail, 2.0)


static func balcony(f: NoirFrame, x: float, y: float, w: float) -> void:
	var rail := Color(120.0 / 255.0, 130.0 / 255.0, 144.0 / 255.0, 0.75)
	var fillc := Color(96.0 / 255.0, 104.0 / 255.0, 116.0 / 255.0, 0.7)
	f.fill_rect(x, y, w, 4.0, fillc)
	f.stroke_rect(x, y - 22.0, w, 22.0, rail, 2.0)
	for i in range(1, 7):
		var rx := x + i * w / 7.0
		f.line(Vector2(rx, y - 22.0), Vector2(rx, y), rail, 2.0)


# --- backdrops ----------------------------------------------------------------------------

class Skyline extends NoirBackdrop:
	func build(f: NoirFrame):
		var layers := []
		for l in data["backdrop"]["layers"]:
			var c := (l as Dictionary).duplicate()
			c["top"] = c["top"] * f.H
			c["shade"] = NoirBackdrops._to_color(c["shade"])
			layers.append(c)
		return NoirBackdrops.build_skyline(f, int(data["backdrop"]["seed"]), layers, float(data.get("ground", 0.8)) * f.H)

	func draw(f: NoirFrame) -> void:
		NoirBackdrops.paint_skyline(f, geom, f.look)
		NoirBackdrops.wet_floor(f)


class Alley extends NoirBackdrop:
	func build(f: NoirFrame):
		var cfg := {"depth": 0.4, "top": f.H * 0.3, "shade": Palette.FAR_INK, "min_w": 50.0, "max_w": 110.0, "min_h": 0.3, "max_h": 0.55, "win": 0.18}
		var seed_value: int = int(data["backdrop"].get("seed", 77123))
		return NoirBackdrops.build_skyline(f, seed_value, [cfg], f.H * 0.62)

	func draw(f: NoirFrame) -> void:
		var g := f.gy
		var look := f.look
		var vx := f.W * 0.5 + look * 0.3
		var vy := f.H * 0.4
		f.fill_rect_vgrad(vx - f.W * 0.12, vy, f.W * 0.24, g - vy, Color8(18, 20, 27), Color8(6, 7, 8))
		NoirBackdrops.paint_skyline(f, geom, look * 0.4)
		var left := PackedVector2Array([Vector2(0, 0), Vector2(f.W * 0.4, 0), Vector2(vx - f.W * 0.1, vy), Vector2(vx - f.W * 0.1, g), Vector2(0, g)])
		var right := PackedVector2Array([Vector2(f.W, 0), Vector2(f.W * 0.6, 0), Vector2(vx + f.W * 0.1, vy), Vector2(vx + f.W * 0.1, g), Vector2(f.W, g)])
		NoirBackdrops.wall_poly(f, left)
		NoirBackdrops.wall_poly(f, right)
		NoirBackdrops.fire_escape(f, f.W * 0.14, f.H * 0.16, f.H * 0.5, 64.0)
		NoirBackdrops.balcony(f, f.W * 0.14 + 64.0, f.H * 0.40, f.W * 0.1)
		NoirBackdrops.wet_floor(f)


class Rooftop extends NoirBackdrop:
	func build(f: NoirFrame):
		var c0 := {"depth": 0.3, "top": f.H * 0.4, "shade": Palette.FAR_INK, "min_w": 40.0, "max_w": 100.0, "min_h": 0.2, "max_h": 0.45, "win": 0.22}
		var c1 := {"depth": 0.6, "top": f.H * 0.46, "shade": Color8(6, 7, 11), "min_w": 60.0, "max_w": 140.0, "min_h": 0.16, "max_h": 0.38, "win": 0.18}
		var seed_value: int = int(data["backdrop"].get("seed", 55512))
		return NoirBackdrops.build_skyline(f, seed_value, [c0, c1], f.H * 0.72)

	func draw(f: NoirFrame) -> void:
		var g := f.gy
		var par := f.look
		f.fill_rect_vgrad(0, f.H * 0.5, f.W, f.H * 0.24, Color(40.0 / 255.0, 46.0 / 255.0, 60.0 / 255.0, 0.0), Color(70.0 / 255.0, 80.0 / 255.0, 105.0 / 255.0, 0.35))
		NoirBackdrops.paint_skyline(f, geom, par * 0.5)
		f.fill_rect(f.W * 0.05, f.H * 0.18, 4.0, f.H * 0.2, Color.BLACK)
		f.fill_rect(f.W * 0.92, f.H * 0.12, 4.0, f.H * 0.26, Color.BLACK)
		var l1 := NoirPath.new()
		l1.move_to(f.W * 0.05, f.H * 0.22).quad_to(f.W * 0.5, f.H * 0.3, f.W * 0.93, f.H * 0.16)
		f.stroke_poly(l1.points(), Color.BLACK, 2.0)
		var l2 := NoirPath.new()
		l2.move_to(f.W * 0.05, f.H * 0.27).quad_to(f.W * 0.5, f.H * 0.36, f.W * 0.93, f.H * 0.22)
		f.stroke_poly(l2.points(), Color.BLACK, 2.0)
		f.fill_rect(0, g, f.W, f.H - g, Palette.INK)
		f.fill_rect(0, g - 10.0, f.W, 12.0, Color8(8, 9, 12))


class Room extends NoirBackdrop:
	func _init() -> void:
		indoor = true

	func draw(f: NoirFrame) -> void:
		var g := f.gy
		var b: Dictionary = data.get("backdrop", {})
		var ox := f.look * 0.3
		f.fill_rect_vgrad(0, 0, f.W, g, NoirBackdrops._to_color(b.get("wall_top", "#0a0c11")), NoirBackdrops._to_color(b.get("wall", "#06070b")))
		var seam := Color(1, 1, 1, 0.03)
		var x := 0.0
		while x < f.W + 60.0:
			f.line(Vector2(x + ox, 0), Vector2(x + ox, g), seam, 1.0)
			x += 60.0
		if b.has("door"):
			var dx: float = b["door"] * f.W + ox
			var dw := 64.0 * (f.unit / 1.2)
			var dh := g * 0.40
			var dtop := g - dh
			var gap := 11.0 * (f.unit / 1.2)
			f.fill_rect(dx - dw / 2.0 - 5.0, dtop - 5.0, dw + 10.0, dh + 5.0, Color8(10, 12, 16))
			f.fill_rect_hgrad(dx + dw / 2.0 - gap, dtop, gap, dh, Color(1.0, 234.0 / 255.0, 190.0 / 255.0, 0.0), Color(1.0, 234.0 / 255.0, 190.0 / 255.0, 0.55))
			f.fill_rect(dx - dw / 2.0, dtop, dw - gap, dh, Color8(16, 19, 25))
			f.stroke_rect(dx - dw / 2.0 + 6.0, dtop + 8.0, dw - gap - 12.0, dh * 0.4, Color(1, 1, 1, 0.05), 1.0)
			f.stroke_rect(dx - dw / 2.0 + 6.0, dtop + dh * 0.52, dw - gap - 12.0, dh * 0.4, Color(1, 1, 1, 0.05), 1.0)
			f.circle(dx + dw / 2.0 - gap - 6.0, dtop + dh * 0.55, 2.4, Color8(138, 143, 152))
			var spill := PackedVector2Array([Vector2(dx + dw / 2.0 - gap, g), Vector2(dx + dw / 2.0 + 26.0, g + 52.0), Vector2(dx - 8.0, g + 52.0)])
			f.fill_poly(spill, Color(1.0, 234.0 / 255.0, 190.0 / 255.0, 0.10))
			f.stroke_rect(dx - dw / 2.0, dtop, dw, dh, Color8(5, 6, 10), 4.0)
		f.fill_rect_vgrad(0, g, f.W, f.H - g, Color8(8, 10, 14), Palette.INK)
		f.fill_rect(0, g - 6.0, f.W, 6.0, Palette.FAR_INK)
		for i in 16:
			var rx := fmod(i * 97.0 + f.t * 4.0, f.W)
			f.fill_rect(rx, g + (i % 5) * (f.H - g) / 5.0, 30.0, 1.0, Color(Palette.STEEL.r, Palette.STEEL.g, Palette.STEEL.b, 0.06))


static func _to_color(v) -> Color:
	if v is Color:
		return v
	return Color(String(v))
