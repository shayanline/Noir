class_name NoirActors
extends RefCounted
## The noir cast, ported from Inkfall's library/actors. Motion reads from scene timing (line_idx,
## beat) plus per actor params. Every figure uses the one shared directional ground shadow and the
## body gradient, so the whole cast is lit from the same sources.

const SWAY := 1.1
const WALK := 2.2


static func register(reg: NoirRegistry) -> void:
	reg.register_object("trenchMan", TrenchMan)
	reg.register_object("thug", Thug)
	reg.register_object("boss", Boss)
	reg.register_object("gunman", Gunman)
	reg.register_object("womanInRed", WomanInRed)
	reg.register_object("dealer", Dealer)
	reg.register_object("singer", Singer)
	reg.register_object("cat", Cat)
	reg.register_object("crow", Crow)


static func _dy(f: NoirFrame, o) -> float:
	return f.gy + (o.dy if o.dy != null else 0.0) * f.unit


# --- detective ----------------------------------------------------------------------------

class TrenchMan extends NoirObject:
	static func pose(f: NoirFrame, p) -> Dictionary:
		var s := f.scale_of(p)
		var X := f.x_of(p)
		var gy: float = f.gy + (p.dy if p.dy != null else 0.0) * f.unit
		var t := f.t
		var sway := sin(t * NoirActors.SWAY) * 1.2
		var aim := 1.0
		if p.raise_at != null:
			if f.line_idx < int(p.raise_at):
				aim = 0.0
			elif f.line_idx == int(p.raise_at):
				aim = NoirMath.smooth01(f.beat() / 2.2)
		var lit_cig := true if p.light_at == null else (f.line_idx >= int(p.light_at))
		var flash := 0.0
		if p.light_at != null and f.line_idx == int(p.light_at):
			flash = maxf(0.0, 1.0 - f.beat() / 0.8)
		var hx := NoirMath.lerp_f(17.0 * s, 13.0 * s, aim)
		var hy := NoirMath.lerp_f(-44.0 * s, -101.0 * s, aim)
		return {"s": s, "X": X, "gy": gy, "t": t, "sway": sway, "aim": aim, "lit_cig": lit_cig, "flash": flash, "hx": hx, "hy": hy}

	func draw(f: NoirFrame) -> void:
		var P := pose(f, self)
		var s: float = P["s"]
		var t: float = P["t"]
		var sway: float = P["sway"]
		var rim := NoirShared.rim_sign(f, self)
		var tint = f.lit_tint(P["X"])
		f.ground_shadow(P["X"] + sway, 22.0 * s, 96.0 * s)
		f.save()
		f.translate(P["X"] + sway, P["gy"])
		f.fill_rect(-13 * s, -32 * s, 11 * s, 32 * s, Color8(5, 6, 8))
		f.fill_rect(3 * s, -32 * s, 11 * s, 32 * s, Color8(5, 6, 8))
		f.ellipse_fill(-9 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		f.ellipse_fill(10 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		var coat := NoirPath.new()
		coat.move_to(-22 * s, -36 * s).line_to(-18 * s, -92 * s).line_to(18 * s, -92 * s).line_to(22 * s, -36 * s).quad_to(0, -28 * s, -22 * s, -36 * s)
		NoirShared.body_fill(f, coat.points(), s, rim, tint)
		f.line(Vector2(2 * s, -90 * s), Vector2(5 * s, -38 * s), Color(0, 0, 0, 0.6), 1.5 * s)
		f.fill_rect(-20 * s, -58 * s, 40 * s, 6 * s, Color8(12, 13, 16))
		f.fill_rect(-4 * s, -58 * s, 8 * s, 6 * s, Color8(38, 40, 46))
		var aim: float = P["aim"]
		var hx: float = P["hx"]
		var hy: float = P["hy"]
		var ex := NoirMath.lerp_f(16 * s, 26 * s, aim)
		var ey := NoirMath.lerp_f(-60 * s, -73 * s, aim)
		f.stroke_poly(PackedVector2Array([Vector2(11 * s, -87 * s), Vector2(ex, ey), Vector2(hx, hy)]), Color8(42, 47, 55), 8.5 * s, false, true)
		f.line(Vector2(-13 * s, -87 * s), Vector2(-21 * s, -50 * s), Color8(42, 47, 55), 8.5 * s, true)
		f.line(Vector2(12 * s, -90 * s), Vector2(ex, ey), Color(150.0 / 255.0, 160.0 / 255.0, 178.0 / 255.0, 0.3), 1.4 * s)
		f.circle(hx, hy, 2.9 * s, Color8(188, 186, 176))
		f.circle(-21 * s, -48 * s, 3.2 * s, Color8(188, 186, 176))
		var sh := NoirPath.new()
		sh.move_to(-26 * s, -90 * s).quad_to(0, -104 * s, 26 * s, -90 * s).line_to(18 * s, -84 * s).quad_to(0, -94 * s, -18 * s, -84 * s)
		NoirShared.body_fill(f, sh.points(), s, rim, tint)
		f.fill_poly(PackedVector2Array([Vector2(-10 * s, -96 * s), Vector2(-2 * s, -107 * s), Vector2(-1 * s, -92 * s)]), Palette.INK)
		f.fill_poly(PackedVector2Array([Vector2(10 * s, -96 * s), Vector2(2 * s, -107 * s), Vector2(1 * s, -92 * s)]), Palette.INK)
		f.fill_rect(-6 * s, -104 * s, 12 * s, 10 * s, Color8(21, 22, 26))
		f.circle(0, -112 * s, 10 * s, Color8(26, 27, 32))
		f.arc_fill(0, -112 * s, 10 * s, PI * 1.15, PI * 1.95, Palette.INK)
		NoirShared.fedora(f, 0, -120 * s, 13 * s, rim)
		if aim > 0.5:
			f.save()
			f.translate(hx, hy)
			f.fill_rect(2 * s, -1 * s, 7 * s, 2 * s, Color8(216, 210, 196))
			f.restore()
			if P["lit_cig"]:
				NoirShared.cig_smoke(f, hx + 9 * s, hy, s, t)
				NoirShared.ember(f, hx + 9 * s, hy, s, t)
			if P["flash"] > 0.0:
				f.glow_radial(hx + 6 * s, hy, 46 * s, Color(1.0, 170.0 / 255.0, 80.0 / 255.0), 0.55 * P["flash"])
		f.restore()

	func emit_light(f: NoirFrame) -> void:
		var P := pose(f, self)
		if P["aim"] > 0.5 and P["lit_cig"]:
			var s: float = P["s"]
			var cwx: float = P["X"] + P["sway"] + P["hx"] + 9 * s
			var cwy: float = P["gy"] + P["hy"]
			var inten: float = 0.3 + P["flash"] * 0.6
			f.add_light({"x": cwx, "y": cwy, "col": Color8(255, 150, 60), "r": 84 * s, "I": inten * 0.7, "ew": 4 * s, "eh": 4 * s})


# --- the heavy ----------------------------------------------------------------------------

class Thug extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var rim := NoirShared.rim_sign(f, self)
		f.ground_shadow(X, 30 * s, 86 * s)
		f.save()
		f.translate(X, gy)
		f.fill_rect(-18 * s, -36 * s, 15 * s, 36 * s, Color8(5, 6, 8))
		f.fill_rect(3 * s, -36 * s, 15 * s, 36 * s, Color8(5, 6, 8))
		f.ellipse_fill(-11 * s, -1 * s, 12 * s, 4 * s, Palette.INK)
		f.ellipse_fill(12 * s, -1 * s, 12 * s, 4 * s, Palette.INK)
		var body := NoirPath.new()
		body.move_to(-30 * s, -36 * s).line_to(-34 * s, -78 * s).quad_to(0, -96 * s, 34 * s, -78 * s).line_to(30 * s, -36 * s).quad_to(0, -28 * s, -30 * s, -36 * s)
		NoirShared.body_fill(f, body.points(), s, rim, null)
		f.fill_poly(PackedVector2Array([Vector2(-6 * s, -82 * s), Vector2(6 * s, -82 * s), Vector2(3 * s, -54 * s), Vector2(-3 * s, -54 * s)]), Color8(207, 205, 195))
		f.fill_poly(PackedVector2Array([Vector2(-2.5 * s, -80 * s), Vector2(2.5 * s, -80 * s), Vector2(1.5 * s, -56 * s), Vector2(-1.5 * s, -56 * s)]), Palette.RED_HOT)
		var la := PackedVector2Array([Vector2(-12 * s, -84 * s), Vector2(-6 * s, -82 * s), Vector2(-7 * s, -52 * s), Vector2(-16 * s, -56 * s)])
		NoirShared.body_fill(f, la, s, rim, null)
		var ra := PackedVector2Array([Vector2(12 * s, -84 * s), Vector2(6 * s, -82 * s), Vector2(7 * s, -52 * s), Vector2(16 * s, -56 * s)])
		NoirShared.body_fill(f, ra, s, rim, null)
		f.fill_rect(-34 * s, -80 * s, 9 * s, 42 * s, Palette.INK)
		f.fill_rect(25 * s, -80 * s, 9 * s, 42 * s, Palette.INK)
		f.circle(-30 * s, -36 * s, 7 * s, Palette.INK)
		f.circle(30 * s, -36 * s, 7 * s, Palette.INK)
		f.circle(0, -90 * s, 11 * s, Color8(26, 27, 32))
		f.arc_fill(0, -90 * s, 11 * s, PI * 1.1, PI * 2.0, Palette.INK)
		f.arc_fill(0, -98 * s, 11 * s, PI, 0.0, Palette.INK)
		f.ellipse_fill(-9 * s, -98 * s, 9 * s, 3 * s, Palette.INK)
		f.restore()


# --- mob boss -----------------------------------------------------------------------------

class Boss extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var t := f.t
		var rim := NoirShared.rim_sign(f, self)
		f.ground_shadow(X, 24 * s, 92 * s)
		f.save()
		f.translate(X, gy)
		f.fill_rect(-13 * s, -32 * s, 11 * s, 32 * s, Color8(5, 6, 8))
		f.fill_rect(3 * s, -32 * s, 11 * s, 32 * s, Color8(5, 6, 8))
		f.ellipse_fill(-9 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		f.ellipse_fill(10 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		var body := NoirPath.new()
		body.move_to(-24 * s, -34 * s).line_to(-20 * s, -88 * s).quad_to(0, -100 * s, 20 * s, -88 * s).line_to(24 * s, -34 * s).quad_to(0, -28 * s, -24 * s, -34 * s)
		NoirShared.body_fill(f, body.points(), s, rim, null)
		var pin := Color(150.0 / 255.0, 160.0 / 255.0, 180.0 / 255.0, 0.16)
		for i in range(-3, 4):
			f.line(Vector2(i * 6 * s, -88 * s), Vector2(i * 6 * s + i * 1.2 * s, -34 * s), pin, 1.0)
		f.fill_poly(PackedVector2Array([Vector2(-5 * s, -88 * s), Vector2(5 * s, -88 * s), Vector2(3 * s, -60 * s), Vector2(-3 * s, -60 * s)]), Color8(207, 205, 195))
		f.fill_poly(PackedVector2Array([Vector2(-2.5 * s, -86 * s), Vector2(2.5 * s, -86 * s), Vector2(1.4 * s, -58 * s), Vector2(-1.4 * s, -58 * s)]), Palette.RED_HOT)
		f.fill_rect(-5 * s, -100 * s, 10 * s, 10 * s, Color8(21, 22, 26))
		f.circle(0, -108 * s, 9 * s, Color8(26, 27, 32))
		f.arc_fill(0, -108 * s, 9 * s, PI * 1.1, PI * 2.0, Palette.INK)
		NoirShared.fedora(f, 0, -116 * s, 12 * s, rim)
		f.fill_rect(6 * s, -104 * s, 13 * s, 3 * s, Color8(58, 42, 28))
		NoirShared.cig_smoke(f, 19 * s, -104 * s, s, t)
		f.circle(19 * s, -102.5 * s, 2.4 * s, Color(1.0, 80.0 / 255.0, 30.0 / 255.0, 0.95))
		f.glow_radial(19 * s, -102.5 * s, 7 * s, Palette.EMBER, 0.5)
		f.restore()


# --- shooter ------------------------------------------------------------------------------

class Gunman extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var rim := NoirShared.rim_sign(f, self)
		var tint = f.lit_tint(X)
		var flash: float = f.flags.get("muzzle", 0.0)
		f.ground_shadow(X, 20 * s, 90 * s)
		f.save()
		f.translate(X, gy)
		if flip:
			f.scale(-1, 1)
		f.fill_rect(-12 * s, -32 * s, 10 * s, 32 * s, Color8(5, 6, 8))
		f.fill_rect(4 * s, -32 * s, 10 * s, 32 * s, Color8(5, 6, 8))
		f.ellipse_fill(-8 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		f.ellipse_fill(11 * s, -1 * s, 10 * s, 4 * s, Palette.INK)
		var body := NoirPath.new()
		body.move_to(-20 * s, -34 * s).line_to(-16 * s, -86 * s).quad_to(0, -98 * s, 16 * s, -86 * s).line_to(20 * s, -34 * s).quad_to(0, -28 * s, -20 * s, -34 * s)
		NoirShared.body_fill(f, body.points(), s, rim, tint)
		f.circle(0, -104 * s, 9 * s, Color8(26, 27, 32))
		f.arc_fill(0, -104 * s, 9 * s, PI * 1.1, PI * 2.0, Palette.INK)
		NoirShared.fedora(f, 0, -112 * s, 11 * s, rim)
		var aim := 1.0
		if raise_at != null:
			if f.line_idx < int(raise_at):
				aim = 0.0
			elif f.line_idx == int(raise_at):
				aim = NoirMath.smooth01(f.beat() / 2.4)
		var sx := 6 * s
		var sy := -86 * s
		var hx := NoirMath.lerp_f(13 * s, 34 * s, aim)
		var hy := NoirMath.lerp_f(-52 * s, -82 * s, aim)
		var ang := atan2(hy - sy, hx - sx)
		f.line(Vector2(sx, sy), Vector2(hx, hy), Palette.INK, 8 * s, true)
		f.save()
		f.translate(hx, hy)
		f.rotate(ang)
		NoirShared.pistol(f, 0, 0, s)
		f.restore()
		if flash > 0.0 and aim > 0.82:
			NoirShared.muzzle_flash(f, hx + cos(ang) * 18 * s, hy + sin(ang) * 18 * s, s, flash)
		f.restore()


# --- femme fatale -------------------------------------------------------------------------

class WomanInRed extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.walk_x(self)
		var gy := NoirActors._dy(f, self)
		var t := f.t
		var walk := sin(t * NoirActors.WALK)
		if self.walk != null:
			var arr: Array = self.walk
			var i: int = mini(f.line_idx, arr.size() - 1)
			var prev = arr[i - 1] if i > 0 else arr[0]
			var dur: float = float(walk_dur) if walk_dur != null else 3.4
			f.walk_sound(prev != arr[i] and f.beat() < dur - 0.2)
		var refl_a := 1.0
		if pass_x != null:
			var p: float = 0.5 if par == null else par
			var man_x: float = pass_x * f.W + f.look * p
			refl_a = NoirMath.smooth01((absf(X - man_x) - 20 * s) / (40 * s))
		f.ground_shadow(X, 13 * s, 84 * s)
		f.save()
		f.translate(X, gy)
		if refl_a > 0.01:
			f.save()
			f.set_alpha(0.4 * refl_a)
			f.fill_rect_vgrad(-14 * s, 0, 28 * s, 48 * s, Color(200.0 / 255.0, 0, 20.0 / 255.0, 0.5), Color(200.0 / 255.0, 0, 20.0 / 255.0, 0.0))
			f.restore()
		f.save()
		f.translate(walk * 2 * s, 0)
		f.fill_poly(PackedVector2Array([Vector2(-2 * s, -32 * s), Vector2(2 * s, -32 * s), Vector2(3 * s, -2 * s), Vector2(-1 * s, -2 * s)]), Palette.BONE)
		f.restore()
		f.fill_poly(PackedVector2Array([Vector2(1 * s, -2 * s), Vector2(7 * s, 0), Vector2(1 * s, 1 * s)]), Palette.RED_HOT)
		var dress_off := PackedFloat32Array([0.0, 0.5, 1.0])
		var dress_cols := [Color("8e0009"), Color("e2101a"), Color("9e000c")]
		var dress := NoirPath.new()
		dress.move_to(-7 * s, -58 * s).quad_to(-12 * s, -40 * s, -6 * s, -34 * s).quad_to(-16 * s, -18 * s, -12 * s + walk * 2 * s, 0).quad_to(0, 6 * s, 12 * s + walk * 2 * s, 0).quad_to(16 * s, -18 * s, 6 * s, -34 * s).quad_to(12 * s, -40 * s, 7 * s, -58 * s)
		f.fill_poly_grad(dress.points(), Vector2(-12 * s, 0), Vector2(12 * s, 0), dress_off, dress_cols)
		var torso := NoirPath.new()
		torso.move_to(-7 * s, -58 * s).quad_to(-8 * s, -70 * s, -5 * s, -76 * s).line_to(5 * s, -76 * s).quad_to(8 * s, -70 * s, 7 * s, -58 * s)
		f.fill_poly_grad(torso.points(), Vector2(-12 * s, 0), Vector2(12 * s, 0), dress_off, dress_cols)
		f.glow_radial(0, -36 * s, 16 * s, Color(210.0 / 255.0, 0, 24.0 / 255.0), 0.4)
		var arm := NoirPath.new()
		arm.move_to(-5 * s, -76 * s).quad_to(-12 * s, -72 * s, -10 * s, -50 * s).line_to(-7 * s, -50 * s).quad_to(-8 * s, -70 * s, -3 * s, -74 * s)
		f.fill_poly(arm.points(), Palette.BONE)
		f.circle(0, -84 * s, 6.5 * s, Palette.BONE)
		f.arc_fill(0, -86 * s, 8 * s, PI * 0.9, PI * 2.2, Color8(7, 7, 8))
		var lock := NoirPath.new()
		lock.move_to(6 * s, -88 * s).quad_to(12 * s, -78 * s, 7 * s, -66 * s).quad_to(4 * s, -74 * s, 4 * s, -84 * s)
		f.fill_poly(lock.points(), Color8(7, 7, 8))
		f.ellipse_fill(-1 * s, -81 * s, 2.2 * s, 1.1 * s, Palette.RED_HOT)
		f.restore()


# --- croupier -----------------------------------------------------------------------------

class Dealer extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var rim := NoirShared.rim_sign(f, self)
		f.save()
		f.translate(X, gy)
		var body := NoirPath.new()
		body.move_to(-19 * s, 0).line_to(-17 * s, -52 * s).quad_to(-22 * s, -64 * s, -12 * s, -68 * s).quad_to(0, -76 * s, 12 * s, -68 * s).quad_to(22 * s, -64 * s, 17 * s, -52 * s).line_to(19 * s, 0)
		NoirShared.body_fill(f, body.points(), s, rim, null)
		f.fill_poly(PackedVector2Array([Vector2(-4 * s, -66 * s), Vector2(4 * s, -66 * s), Vector2(3 * s, -30 * s), Vector2(-3 * s, -30 * s)]), Color8(205, 203, 193))
		f.fill_poly(PackedVector2Array([Vector2(-12 * s, -68 * s), Vector2(-4 * s, -66 * s), Vector2(-3 * s, -30 * s), Vector2(-13 * s, -36 * s)]), Palette.FAR_INK)
		f.fill_poly(PackedVector2Array([Vector2(12 * s, -68 * s), Vector2(4 * s, -66 * s), Vector2(3 * s, -30 * s), Vector2(13 * s, -36 * s)]), Palette.FAR_INK)
		f.fill_poly(PackedVector2Array([Vector2(-4.5 * s, -67 * s), Vector2(0, -64 * s), Vector2(-4.5 * s, -61 * s)]), Palette.RED_HOT)
		f.fill_poly(PackedVector2Array([Vector2(4.5 * s, -67 * s), Vector2(0, -64 * s), Vector2(4.5 * s, -61 * s)]), Palette.RED_HOT)
		f.fill_rect(-1.2 * s, -65.5 * s, 2.4 * s, 3 * s, Color8(122, 0, 8))
		f.line(Vector2(-13 * s, -56 * s), Vector2(-22 * s, -30 * s), Color8(16, 19, 25), 7 * s, true)
		f.line(Vector2(13 * s, -56 * s), Vector2(22 * s, -30 * s), Color8(16, 19, 25), 7 * s, true)
		f.circle(-23 * s, -28 * s, 3.5 * s, Color8(189, 187, 176))
		f.circle(23 * s, -28 * s, 3.5 * s, Color8(189, 187, 176))
		f.circle(0, -80 * s, 8 * s, Color8(26, 27, 32))
		f.arc_fill(0, -82 * s, 8 * s, PI, 0.0, Palette.INK)
		f.ellipse_arc_fill(0, -79 * s, 9.5 * s, 3 * s, 0.0, PI, Color(170.0 / 255.0, 135.0 / 255.0, 45.0 / 255.0, 0.6))
		f.restore()


# --- lounge singer ------------------------------------------------------------------------

class Singer extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var is_red: bool = red == true
		var gown := Color("cf0a16") if is_red else Color8(205, 201, 191)
		f.save()
		f.translate(X, gy)
		f.glow_radial(0, -60 * s, 84 * s, Color(1.0, 250.0 / 255.0, 230.0 / 255.0), 0.12)
		NoirShared.shadow_pool(f, 0, 4 * s, 22 * s, 6 * s)
		var dress := NoirPath.new()
		dress.move_to(-6 * s, -66 * s).quad_to(-10 * s, -30 * s, -16 * s, 0).quad_to(0, 5 * s, 16 * s, 0).quad_to(10 * s, -30 * s, 6 * s, -66 * s)
		f.fill_poly(dress.points(), gown)
		var torso := NoirPath.new()
		torso.move_to(-6 * s, -66 * s).quad_to(-7 * s, -78 * s, -4 * s, -84 * s).line_to(4 * s, -84 * s).quad_to(7 * s, -78 * s, 6 * s, -66 * s)
		f.fill_poly(torso.points(), gown)
		if is_red:
			f.glow_radial(0, -40 * s, 16 * s, Color(210.0 / 255.0, 0, 24.0 / 255.0), 0.4)
		f.line(Vector2(4 * s, -80 * s), Vector2(16 * s, -92 * s), gown, 5 * s, true)
		f.circle(16 * s, -92 * s, 3.5 * s, Palette.BONE)
		f.circle(0, -92 * s, 6.5 * s, Palette.BONE)
		f.arc_fill(0, -94 * s, 8 * s, PI * 0.85, PI * 2.25, Color8(7, 7, 8))
		f.ellipse_fill(0, -89 * s, 2.2 * s, 1.1 * s, Palette.RED_HOT)
		f.line(Vector2(21 * s, -86 * s), Vector2(21 * s, 0), Palette.INK, 2.5 * s)
		f.ellipse_fill(20 * s, -90 * s, 4 * s, 5 * s, Color8(26, 29, 34))
		f.ellipse_stroke(20 * s, -90 * s, 4 * s, 5 * s, Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.4), 1.0)
		f.restore()


# --- animals ------------------------------------------------------------------------------

class Cat extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirActors._dy(f, self)
		var t := f.t
		f.save()
		f.translate(X, gy)
		if flip:
			f.scale(-1, 1)
		f.ellipse_fill(0, -5 * s, 12 * s, 5 * s, Palette.INK)
		f.fill_rect(-11 * s, -6 * s, 2.5 * s, 6 * s, Palette.INK)
		f.fill_rect(8 * s, -6 * s, 2.5 * s, 6 * s, Palette.INK)
		f.circle(11 * s, -12 * s, 4 * s, Palette.INK)
		f.fill_poly(PackedVector2Array([Vector2(8 * s, -15 * s), Vector2(9 * s, -20 * s), Vector2(11 * s, -15 * s)]), Palette.INK)
		f.fill_poly(PackedVector2Array([Vector2(11 * s, -15 * s), Vector2(13 * s, -20 * s), Vector2(14 * s, -15 * s)]), Palette.INK)
		var tail := NoirPath.new()
		tail.move_to(-11 * s, -6 * s).quad_to(-20 * s, -10 * s + sin(t * 2.0) * 3 * s, -16 * s, -18 * s)
		f.stroke_poly(tail.points(), Palette.INK, 2.5 * s, false, true)
		f.circle(12.5 * s, -12 * s, 1 * s, Palette.AMBER)
		f.glow_radial(12.5 * s, -12 * s, 4 * s, Palette.AMBER, 0.6)
		f.restore()


class Crow extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var t := f.t
		var sc: float = scale if scale != null else 1.0
		var fly := 0.0
		if fly_at != null and f.line_idx >= int(fly_at):
			var dl: float = float(delay) if delay != null else 0.0
			fly = NoirMath.clamp01((NoirMath.smooth01(f.beat() / 11.0) - dl) / (1.0 - dl))
		if fly >= 0.99:
			return
		var X := f.x_of(self) + fly * f.W * 0.5
		var yy: float = y * f.H - fly * f.H * 0.6
		var flying := fly > 0.02
		var w := sin(t * (2.4 if flying else 1.0)) * 0.5 + 0.5
		var wing_tip_y := -2.0 - (13.0 if flying else 4.0) * w
		var tail := sin(t * 1.6) * 2.2
		f.save()
		f.translate(X, yy)
		f.scale(-sc, sc)
		f.set_alpha(1.0 - fly)
		f.ellipse_fill(0, 0, 7, 4, Palette.INK)
		f.circle(-6, -3, 3, Palette.INK)
		f.fill_rect(-10, -3, 4, 1.4, Palette.INK)
		var tl := NoirPath.new()
		tl.move_to(5, -1).quad_to(11, 1 + tail, 14, 2 + tail).line_to(5, 2)
		f.fill_poly(tl.points(), Palette.INK)
		var wing := NoirPath.new()
		wing.move_to(2, -1).quad_to(8, wing_tip_y * 0.6, 13, wing_tip_y).quad_to(8, 1, 3, 1.5)
		f.fill_poly(wing.points(), Palette.INK)
		if not flying:
			f.fill_rect(1, 4, 1.4, 5, Palette.INK)
		f.restore()
