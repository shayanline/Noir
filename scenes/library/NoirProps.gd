class_name NoirProps
extends RefCounted
## Set pieces and the red car, ported from Inkfall's library/props + movers/vehicles. barrelFire
## and trafficLight emit light; the rest are unlit furniture. The car can glide on a walk path and
## registers its head + tail lamps as lights.


static func register(reg: NoirRegistry) -> void:
	reg.register_object("cardTable", CardTable)
	reg.register_object("slotMachine", SlotMachine)
	reg.register_object("rouletteWheel", RouletteWheel)
	reg.register_object("drink", Drink)
	reg.register_object("cash", Cash)
	reg.register_object("barrelFire", BarrelFire)
	reg.register_object("trafficLight", TrafficLight)
	reg.register_object("fireHydrant", FireHydrant)
	reg.register_object("payphone", Payphone)
	reg.register_object("streetSign", StreetSign)
	reg.register_object("waterTower", WaterTower)
	reg.register_object("dumpster", Dumpster)
	reg.register_object("manhole", Manhole)
	reg.register_object("knife", Knife)
	reg.register_object("pistol", PistolProp)
	reg.register_object("tommyGun", TommyGun)
	reg.register_object("redCar", RedCar)


static func _dy(f: NoirFrame, o) -> float:
	return f.gy + (o.dy if o.dy != null else 0.0) * f.unit


static func _ycoord(f: NoirFrame, o, fallback: float) -> float:
	return (o.y * f.H) if o.y != null else fallback


static func _poly(arr: Array, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in arr:
		pts.append(Vector2(p[0] * s, p[1] * s))
	return pts


# --- casino -------------------------------------------------------------------------------

class CardTable extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var top := gy - 46 * s
		var w := 132 * s
		var h := 42 * s
		NoirShared.shadow_pool(f, X, gy + 4 * s, w * 0.58, 10 * s)
		f.fill_rect(X - w * 0.5, top, w, 48 * s, Color8(7, 7, 8))
		f.ellipse_fill(X, top, w * 0.5, h * 0.5, Color("0c130f"))
		f.ellipse_fill(X, top, w * 0.34, h * 0.34, Color("1c2a22"))
		f.ellipse_stroke(X, top, w * 0.5, h * 0.5, Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.18), 2.0)
		for i in 4:
			f.save()
			f.translate(X - 30 * s + i * 14 * s, top - 2 * s)
			f.rotate(-0.3 + i * 0.18)
			f.fill_rect(-6 * s, -9 * s, 12 * s, 18 * s, Color8(232, 230, 220))
			if i % 2:
				f.circle(0, 0, 1.6 * s, Color8(187, 34, 34))
			f.restore()
		for dx in [-10, 6]:
			f.save()
			f.translate(X + 16 * s + dx * s, top + 2 * s)
			f.fill_rect(-3 * s, -3 * s, 6 * s, 6 * s, Color8(232, 230, 220))
			f.circle(0, 0, 1 * s, Color8(176, 0, 16))
			f.restore()
		var hot: bool = glow != false
		for i in 5:
			var col := Palette.RED_HOT if (hot and i == 4) else (Color8(207, 207, 207) if i % 2 else Color8(42, 42, 42))
			f.ellipse_fill(X + 42 * s, top - 2 * s - i * 3 * s, 7 * s, 3 * s, col)
		if hot:
			f.glow_radial(X + 42 * s, top - 14 * s, 12.0, Palette.RED_HOT, 0.7)
			f.ellipse_fill(X + 42 * s, top - 14 * s, 7 * s, 3 * s, Palette.RED_HOT)


class SlotMachine extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var w := 46 * s
		var h := 86 * s
		f.save()
		f.translate(X, gy)
		NoirShared.shadow_pool(f, 0, 4 * s, w * 0.7, 7 * s)
		f.fill_rect_hgrad(-w / 2.0, -h, w, h, Color8(12, 14, 18), Color8(12, 14, 18))
		f.fill_rect_hgrad(-w / 2.0, -h, w / 2.0, h, Color8(12, 14, 18), Color8(27, 31, 37))
		f.fill_rect_hgrad(0, -h, w / 2.0, h, Color8(27, 31, 37), Color8(12, 14, 18))
		var crown := NoirPath.new()
		crown.move_to(-w / 2.0, -h).quad_to(0, -h - 16 * s, w / 2.0, -h)
		f.fill_poly(crown.points(), Color8(27, 31, 37))
		f.glow_radial(0, -h - 3 * s, 14 * s, Palette.RED_HOT, 0.6)
		f.fill_rect(-w / 2.0 + 4 * s, -h - 6 * s, w - 8 * s, 5 * s, Palette.RED_HOT)
		f.fill_rect(-w / 2.0 + 6 * s, -h + 14 * s, w - 12 * s, 26 * s, Color8(5, 6, 10))
		var syms := ["$", "7", "$"]
		for i in 3:
			var rx := -w / 2.0 + 6 * s + (i + 0.5) * (w - 12 * s) / 3.0
			f.fill_rect(rx - 5 * s, -h + 16 * s, 10 * s, 22 * s, Color8(232, 230, 220))
			f.text_center(syms[i], rx, -h + 27 * s, int(10 * s), Palette.RED_HOT if i == 1 else Color8(26, 26, 26))
		f.fill_rect(-10 * s, -h + 50 * s, 20 * s, 3 * s, Color8(5, 6, 10))
		f.fill_rect(-w / 2.0 + 6 * s, -18 * s, w - 12 * s, 14 * s, Color8(10, 12, 16))
		f.circle(-6 * s, -11 * s, 2 * s, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.85))
		f.circle(2 * s, -11 * s, 2 * s, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.85))
		f.line(Vector2(w / 2.0, -h + 22 * s), Vector2(w / 2.0 + 10 * s, -h + 10 * s), Color8(58, 63, 71), 3 * s)
		f.glow_radial(w / 2.0 + 10 * s, -h + 10 * s, 8.0, Palette.RED_HOT, 0.6)
		f.circle(w / 2.0 + 10 * s, -h + 10 * s, 4 * s, Palette.RED_HOT)
		f.restore()


class RouletteWheel extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 2 * f.unit)
		var t := f.t
		var R := 30 * s
		f.save()
		f.translate(X, yy)
		f.scale(1, 0.5)
		f.rotate(t * 0.4)
		for i in 18:
			var a0 := float(i) / 18.0 * TAU
			var a1 := float(i + 1) / 18.0 * TAU
			f.arc_fill(0, 0, R, a0, a1, Color8(176, 0, 16) if i % 2 else Color8(10, 10, 10), true)
		f.circle(0, 0, R * 0.45, Color8(26, 29, 34))
		f.circle(0, 0, R * 0.12, Color8(201, 178, 122))
		f.circle(R * 0.8 * cos(-t * 1.3), R * 0.8 * sin(-t * 1.3), 2.4 * s, Color8(240, 240, 240))
		f.restore()
		f.save()
		f.translate(X, yy)
		f.scale(1, 0.5)
		f.ring(0, 0, R + 2 * s, Color8(42, 46, 53), 4 * s)
		f.restore()


class Drink extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 2 * f.unit)
		f.save()
		f.translate(X, yy)
		var glass_stroke := Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0, 0.7)
		if kind == "martini":
			var cup := PackedVector2Array([Vector2(-10 * s, -20 * s), Vector2(10 * s, -20 * s), Vector2(0, -8 * s)])
			f.fill_poly(cup, Color(200.0 / 255.0, 215.0 / 255.0, 235.0 / 255.0, 0.12))
			f.stroke_poly(cup, glass_stroke, 1.5 * s, true)
			f.fill_poly(PackedVector2Array([Vector2(-7 * s, -17 * s), Vector2(7 * s, -17 * s), Vector2(0, -9 * s)]), Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.8))
			f.line(Vector2(0, -8 * s), Vector2(0, 0), glass_stroke, 1.5 * s)
			f.line(Vector2(-6 * s, 0), Vector2(6 * s, 0), glass_stroke, 1.5 * s)
			f.circle(2 * s, -12 * s, 1.6 * s, Palette.RED_HOT)
		else:
			f.fill_rect(-7 * s, -14 * s, 14 * s, 14 * s, Color(200.0 / 255.0, 215.0 / 255.0, 235.0 / 255.0, 0.1))
			f.stroke_rect(-7 * s, -14 * s, 14 * s, 14 * s, Color(210.0 / 255.0, 220.0 / 255.0, 235.0 / 255.0, 0.6), 1.5 * s)
			f.fill_rect(-6 * s, -7 * s, 12 * s, 6 * s, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.85))
			f.glow_radial(0, -4 * s, 8 * s, Palette.AMBER, 0.4)
			f.fill_rect(-3 * s, -6 * s, 3 * s, 3 * s, Color(230.0 / 255.0, 235.0 / 255.0, 245.0 / 255.0, 0.5))
		f.restore()


class Cash extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 2 * f.unit)
		f.save()
		f.translate(X, yy)
		for i in 4:
			f.fill_rect(-14 * s, -i * 3 * s, 28 * s, 8 * s, Color8(60, 74, 58) if i % 2 else Color8(70, 85, 63))
			f.stroke_rect(-14 * s, -i * 3 * s, 28 * s, 8 * s, Color(0, 0, 0, 0.45), 1.0)
			f.circle(0, -i * 3 * s + 4 * s, 2 * s, Color(210.0 / 255.0, 215.0 / 255.0, 200.0 / 255.0, 0.45))
		f.fill_rect(-14 * s, -9 * s, 28 * s, 2.6 * s, Palette.RED_HOT)
		f.restore()


# --- street -------------------------------------------------------------------------------

class BarrelFire extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var t := f.t
		f.save()
		f.translate(X, gy)
		f.glow_radial(0, -46 * s, 64 * s, Color(1.0, 140.0 / 255.0, 30.0 / 255.0), 0.35)
		f.fill_rect(-16 * s, -44 * s, 32 * s, 44 * s, Color8(21, 24, 29))
		f.line(Vector2(-16 * s, -30 * s), Vector2(16 * s, -30 * s), Color8(10, 12, 16), 2.0)
		f.line(Vector2(-16 * s, -14 * s), Vector2(16 * s, -14 * s), Color8(10, 12, 16), 2.0)
		f.ellipse_fill(0, -44 * s, 16 * s, 4 * s, Color8(5, 6, 10))
		for i in 6:
			var fx := (i - 2.5) * 5 * s
			var fh := (18.0 + sin(t * 8.0 + i) * 8.0) * s
			var flame := NoirPath.new()
			flame.move_to(fx - 4 * s, -44 * s).quad_to(fx, -44 * s - fh, fx + 4 * s, -44 * s)
			var fcol: Color = Color8(255, 122, 24) if i % 2 else Palette.AMBER
			f.fill_poly(flame.points(), Color(fcol.r, fcol.g, fcol.b, 0.85))
		for i in 5:
			var life := fmod(t * 0.6 + i * 0.2, 1.0)
			f.glow_radial(sin(i * 3 + t) * 14 * s, -44 * s - life * 50 * s, 1.5 * s, Color8(255, 176, 48), (1.0 - life) * 0.8)
		f.restore()

	func emit_light(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var t := f.t
		var fl := 0.7 + 0.3 * sin(t * 7.0) + 0.1 * sin(t * 19.0)
		f.add_light({"x": X, "y": gy - 46 * s, "col": Color8(255, 140, 40), "r": 170 * s, "I": 0.55 * fl, "ew": 15 * s, "eh": 20 * s})


class TrafficLight extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var green: bool = green_at != null and f.line_idx >= int(green_at)
		f.save()
		f.translate(X, gy)
		f.fill_rect(-2.5 * s, -150 * s, 5 * s, 150 * s, Color8(25, 28, 34))
		f.fill_rect(-2.5 * s, -150 * s, 1.6 * s, 150 * s, Color(150.0 / 255.0, 160.0 / 255.0, 175.0 / 255.0, 0.18))
		f.fill_rect(-11 * s, -202 * s, 22 * s, 54 * s, Color8(35, 39, 47))
		f.stroke_rect(-11 * s, -202 * s, 22 * s, 54 * s, Color(0, 0, 0, 0.5), 1.0)
		_lamp(f, -190 * s, not green, Color8(255, 42, 42), s)
		_lamp(f, -175 * s, false, Palette.AMBER, s)
		_lamp(f, -160 * s, green, Color8(54, 211, 110), s)
		f.restore()

	func _lamp(f: NoirFrame, yy: float, on: bool, col: Color, s: float) -> void:
		if on:
			f.glow_radial(0, yy, 16 * s, col, 0.9)
			f.circle(0, yy, 5 * s, col)
		else:
			f.circle(0, yy, 5 * s, Color(70.0 / 255.0, 70.0 / 255.0, 74.0 / 255.0, 0.5))

	func emit_light(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		var green: bool = green_at != null and f.line_idx >= int(green_at)
		var ly := gy - (160.0 if green else 190.0) * s
		var col := Color8(54, 211, 110) if green else Color8(255, 42, 42)
		var sc: float = scale if scale != null else 1.0
		f.add_light({"x": X, "y": ly, "col": col, "r": 150 * sc, "I": 0.6, "ew": 5 * s, "eh": 5 * s})


class FireHydrant extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		f.save()
		f.translate(X, gy)
		NoirShared.shadow_pool(f, 0, 2 * s, 12 * s, 3 * s)
		f.fill_rect(-6 * s, -22 * s, 12 * s, 22 * s, Color8(22, 25, 30))
		f.arc_fill(0, -22 * s, 7 * s, PI, 0.0, Color8(22, 25, 30))
		f.fill_rect(-9 * s, -16 * s, 3 * s, 5 * s, Color8(22, 25, 30))
		f.fill_rect(6 * s, -16 * s, 3 * s, 5 * s, Color8(22, 25, 30))
		f.circle(0, -26 * s, 2.5 * s, Color8(10, 12, 16))
		f.line(Vector2(-5 * s, -20 * s), Vector2(-5 * s, -2 * s), Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.3), 1.0)
		f.restore()


class Payphone extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		f.save()
		f.translate(X, gy)
		f.fill_rect(-12 * s, -60 * s, 24 * s, 46 * s, Color8(21, 24, 29))
		f.fill_rect(-9 * s, -56 * s, 18 * s, 18 * s, Color8(5, 6, 10))
		var grid := Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.25)
		for i in 3:
			for j in 3:
				f.stroke_rect(-7 * s + i * 5 * s, -34 * s + j * 5 * s, 3 * s, 3 * s, grid, 1.0)
		var cord := NoirPath.new()
		cord.move_to(-12 * s, -50 * s).quad_to(-20 * s, -40 * s, -14 * s, -28 * s)
		f.stroke_poly(cord.points(), Color8(10, 12, 16), 4 * s, false, true)
		f.circle(-12 * s, -50 * s, 3 * s, Color8(26, 29, 34))
		f.circle(-14 * s, -28 * s, 3 * s, Color8(26, 29, 34))
		f.restore()


class StreetSign extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirProps._dy(f, self)
		f.save()
		f.translate(X, gy)
		f.fill_rect(-1.5 * s, -120 * s, 3 * s, 120 * s, Palette.INK)
		f.save()
		f.translate(0, -116 * s)
		f.fill_rect(-30 * s, -7 * s, 60 * s, 12 * s, Color8(28, 42, 34))
		f.text_center(label if label != "" else "SIN ST", 0, -1 * s, int(7 * s), Color(220.0 / 255.0, 230.0 / 255.0, 225.0 / 255.0, 0.85))
		f.restore()
		f.restore()


class WaterTower extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var sc: float = scale if scale != null else 1.0
		var s := f.unit * sc
		var X := f.x_of(self)
		var b := f.gy
		f.fill_poly(PackedVector2Array([Vector2(X - 22 * s, b), Vector2(X - 16 * s, b - 60 * s), Vector2(X - 12 * s, b)]), Palette.INK)
		f.fill_poly(PackedVector2Array([Vector2(X + 22 * s, b), Vector2(X + 16 * s, b - 60 * s), Vector2(X + 12 * s, b)]), Palette.INK)
		f.fill_rect(X - 24 * s, b - 88 * s, 48 * s, 30 * s, Palette.INK)
		f.fill_poly(PackedVector2Array([Vector2(X - 24 * s, b - 88 * s), Vector2(X, b - 108 * s), Vector2(X + 24 * s, b - 88 * s)]), Palette.INK)


class Dumpster extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var g := f.gy
		var bw := 30 * s
		var bh := 46 * s
		f.fill_rect(X - bw / 2.0, g - bh, bw, bh, Color8(28, 32, 39))
		f.fill_rect(X - bw / 2.0 - 3 * s, g - bh - 3 * s, bw + 6 * s, 3.5 * s, Color8(39, 44, 53))
		f.stroke_rect(X - bw / 2.0, g - bh, bw, bh, Color(0, 0, 0, 0.55), 1.5)
		for i in range(1, 4):
			f.line(Vector2(X - bw / 2.0 + i * bw / 4.0, g - bh), Vector2(X - bw / 2.0 + i * bw / 4.0, g), Color(0, 0, 0, 0.55), 1.5)


class Manhole extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var sc: float = scale if scale != null else 1.0
		var s := f.unit * sc
		var cx := f.x_of(self)
		var cy := NoirProps._ycoord(f, self, f.gy + (f.H - f.gy) * 0.42)
		var sq := 0.42
		f.save()
		f.translate(cx, cy)
		f.ellipse_fill(0, 1.5 * s, 32 * s, 32 * s * sq, Color8(10, 12, 16))
		f.ellipse_fill(0, 0, 29 * s, 29 * s * sq, Color8(34, 38, 46))
		f.ellipse_fill(0, 0, 25 * s, 25 * s * sq, Color8(20, 23, 28))
		var rr := 7.0
		while rr <= 22.0:
			f.ellipse_stroke(0, 0, rr * s, rr * s * sq, Color(0, 0, 0, 0.55), 1.3 * s)
			rr += 7.0
		for a in 8:
			var cc := cos(a * PI / 4.0)
			var sn := sin(a * PI / 4.0) * sq
			f.line(Vector2(cc * 5 * s, sn * 5 * s), Vector2(cc * 23 * s, sn * 23 * s), Color(0, 0, 0, 0.55), 1.3 * s)
		f.ellipse_fill(0, 0, 3 * s, 1.6 * s, Color.BLACK)
		f.restore()


# --- weapons ------------------------------------------------------------------------------

class Knife extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 4 * f.unit)
		var L := 34 * s
		f.save()
		f.translate(X, yy)
		f.rotate(float(angle) if angle != null else 0.0)
		var blade := PackedVector2Array([Vector2(0, -4 * s), Vector2(L, -1.2 * s), Vector2(L + 6 * s, 0), Vector2(L, 1.2 * s), Vector2(0, 4 * s)])
		f.fill_poly_grad(blade, Vector2(0, -4 * s), Vector2(0, 4 * s), PackedFloat32Array([0.0, 0.5, 1.0]), [Color("e9edf3"), Color("9aa3b0"), Color("3a4049")])
		f.line(Vector2(0, -3 * s), Vector2(L, -1 * s), Color(1, 1, 1, 0.8), 1.0)
		f.fill_rect(-3 * s, -7 * s, 5 * s, 14 * s, Color8(26, 29, 34))
		f.fill_rect(-22 * s, -4 * s, 19 * s, 8 * s, Palette.INK)
		f.circle(-22 * s, 0, 3.5 * s, Color8(34, 38, 44))
		if bloody:
			var drip := NoirPath.new()
			drip.move_to(L * 0.55, 3 * s).quad_to(L * 0.55 + 1.4 * s, 9 * s, L * 0.55, 13 * s).quad_to(L * 0.55 - 1.4 * s, 9 * s, L * 0.55, 3 * s)
			f.fill_poly(drip.points(), Color("c00010"))
			f.glow_radial(L * 0.55, 9 * s, 6.0, Color(150.0 / 255.0, 0, 12.0 / 255.0), 0.5)
		f.restore()


class PistolProp extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 3 * f.unit)
		f.save()
		f.translate(X, yy)
		f.rotate(float(angle) if angle != null else 0.0)
		if flip:
			f.scale(-1, 1)
		NoirShared.pistol(f, 0, 0, s * 1.7)
		f.restore()


class TommyGun extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var yy := NoirProps._ycoord(f, self, f.gy - 22 * f.unit)
		f.save()
		f.translate(X, yy)
		f.rotate(float(angle) if angle != null else 0.0)
		if flip:
			f.scale(-1, 1)
		f.fill_rect(0, -3 * s, 46 * s, 6 * s, Color8(21, 24, 29))
		for i in 8:
			f.line(Vector2(6 * s + i * 4 * s, -3 * s), Vector2(6 * s + i * 4 * s, 3 * s), Color8(10, 12, 16), 1.0)
		f.fill_rect(40 * s, -6 * s, 22 * s, 12 * s, Color8(21, 24, 29))
		f.circle(50 * s, 8 * s, 10 * s, Color8(21, 24, 29))
		f.ring(50 * s, 8 * s, 7 * s, Color(150.0 / 255.0, 160.0 / 255.0, 175.0 / 255.0, 0.4), 1.0)
		f.fill_poly(PackedVector2Array([Vector2(62 * s, -5 * s), Vector2(80 * s, -9 * s), Vector2(82 * s, -2 * s), Vector2(64 * s, 3 * s)]), Color8(42, 28, 18))
		f.fill_rect(20 * s, 4 * s, 6 * s, 12 * s, Color8(21, 24, 29))
		f.line(Vector2(0, -3 * s), Vector2(46 * s, -3 * s), Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.4), 1.0)
		f.restore()


# --- the red car --------------------------------------------------------------------------

class RedCar extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.walk_x(self)
		var gy := NoirProps._dy(f, self)
		f.save()
		f.translate(X, gy)
		f.scale(1 if flip else -1, 1)
		f.save()
		f.translate(0, 1 * s)
		f.scale(1, 0.16)
		f.fill_radial(0, 0, 88 * s, Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0))
		f.restore()
		for pair in [[-82, -66], [66, 82]]:
			f.fill_rect_vgrad(pair[0] * s, -16 * s, (pair[1] - pair[0]) * s, 9 * s, Color8(69, 74, 82), Color8(27, 31, 37))
		var body := NoirProps._poly([[-78, -9], [-78, -21], [-72, -31], [-30, -34], [-26, -34], [-13, -54], [-7, -55], [29, -55], [41, -37], [71, -35], [76, -34], [78, -23], [78, -9]], s)
		f.fill_poly_grad(body, Vector2(0, -55 * s), Vector2(0, -9 * s), PackedFloat32Array([0.0, 0.5, 1.0]), [Color("54111b"), Color("3a0c14"), Color("22070e")])
		f.line(Vector2(-76 * s, -35 * s), Vector2(77 * s, -36 * s), Color(158.0 / 255.0, 52.0 / 255.0, 66.0 / 255.0, 0.5), 1.4 * s)
		f.fill_poly(NoirProps._poly([[-22, -35], [-12, -52], [27, -52], [38, -37]], s), Color8(10, 12, 18))
		f.fill_poly(NoirProps._poly([[-12, -51], [-1, -51], [-13, -37], [-20, -37]], s), Color(125.0 / 255.0, 145.0 / 255.0, 175.0 / 255.0, 0.08))
		f.fill_rect(6 * s, -52 * s, 3.5 * s, 17 * s, Color8(28, 10, 15))
		var seam := Color(0, 0, 0, 0.5)
		f.line(Vector2(-30 * s, -34 * s), Vector2(-30 * s, -9 * s), seam, 1 * s)
		f.line(Vector2(8 * s, -35 * s), Vector2(8 * s, -9 * s), seam, 1 * s)
		f.line(Vector2(40 * s, -37 * s), Vector2(40 * s, -9 * s), seam, 1 * s)
		f.fill_rect(-22 * s, -31 * s, 7 * s, 1.6 * s, Color(165.0 / 255.0, 170.0 / 255.0, 180.0 / 255.0, 0.45))
		f.fill_rect(18 * s, -32 * s, 7 * s, 1.6 * s, Color(165.0 / 255.0, 170.0 / 255.0, 180.0 / 255.0, 0.45))
		f.fill_rect(-78 * s, -30 * s, 7 * s, 14 * s, Color8(12, 14, 18))
		for i in 3:
			f.line(Vector2((-77 + i * 2.4) * s, -30 * s), Vector2((-77 + i * 2.4) * s, -16 * s), Color(92.0 / 255.0, 98.0 / 255.0, 110.0 / 255.0, 0.5), 1.0)
		f.fill_rect(-71 * s, -30 * s, 5 * s, 7 * s, Color8(255, 231, 173))
		f.fill_rect(72 * s, -31 * s, 5 * s, 10 * s, Color(1.0, 46.0 / 255.0, 42.0 / 255.0, 0.95))
		f.glow_radial(74 * s, -26 * s, 10.0, Palette.EMBER, 0.5)
		for wx in [-44, 46]:
			f.stroke_poly(PackedVector2Array([Vector2((wx - 14) * s, -24 * s), Vector2((wx - 14) * s, -12 * s), Vector2((wx + 14) * s, -12 * s), Vector2((wx + 14) * s, -24 * s)]), Color8(28, 10, 15), 2.4 * s)
			f.circle(wx * s, -12 * s, 12 * s, Color8(16, 18, 22))
			f.circle(wx * s, -12 * s, 5.5 * s, Color8(44, 49, 58))
			f.circle(wx * s, -12 * s, 2 * s, Color8(10, 11, 14))
		f.restore()

	func emit_light(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.walk_x(self)
		var gy := NoirProps._dy(f, self)
		var ly := gy - 9 * s
		var dir := -1.0 if flip else 1.0
		f.add_light({"x": X + dir * 78 * s, "y": ly, "col": Color8(255, 238, 196), "r": 150 * s, "I": 0.5, "ew": 10 * s, "eh": 7 * s})
		f.add_light({"x": X - dir * 74 * s, "y": ly, "col": Color8(255, 40, 30), "r": 90 * s, "I": 0.42, "ew": 8 * s, "eh": 6 * s})
