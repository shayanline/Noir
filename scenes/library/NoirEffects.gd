class_name NoirEffects
extends RefCounted
## Atmosphere and aftermath, ported from Inkfall's library/effects: drifting steam, the rooftop
## searchlight, a blown in tabloid, and the blood, body, chalk outline and drain. Most are
## revealed by a line's blood flag (on_flag: "blood").


static func register(reg: NoirRegistry) -> void:
	reg.register_object("steam", Steam)
	reg.register_object("searchlight", Searchlight)
	reg.register_object("newspaper", Newspaper)
	reg.register_object("bloodSplat", BloodSplat)
	reg.register_object("bodyOnGround", BodyOnGround)
	reg.register_object("chalkOutline", ChalkOutline)
	reg.register_object("bloodDrain", BloodDrain)


static func _dy(f: NoirFrame, o) -> float:
	return f.gy + (o.dy if o.dy != null else 0.0) * f.unit


class Steam extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var X := f.x_of(self)
		var gy: float = (y * f.H) if y != null else f.gy
		var t := f.t
		var sd := float(seed) if seed != null else 0.0
		for i in 5:
			var life := fmod(t * 0.25 + i * 0.2 + sd, 1.0)
			var yy := gy - life * 150.0
			var rr := 8.0 + life * 46.0
			var a := 0.10 * (1.0 - life)
			f.glow_radial(X + sin(t + i + sd) * 14.0, yy, rr, Color8(200, 210, 225), a)


class Searchlight extends NoirObject:
	func _init() -> void:
		layer = "back"

	func draw(f: NoirFrame) -> void:
		var t := f.t
		var ang := sin(t * 0.4) * 0.5
		f.save()
		f.translate((x if x != null else 0.5) * f.W, f.H)
		f.rotate(ang)
		f.glow_poly(PackedVector2Array([Vector2(0, 0), Vector2(-70, -f.H), Vector2(70, -f.H)]), Color8(190, 200, 220), 0.06)
		f.restore()


class Newspaper extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var st := f.scene_t()
		var pp := NoirMath.smooth01(st / 4.5)
		var tumbling := pp < 0.97
		var k := f.scale_of(self) * 0.6
		var rest := (float(rest_x) if rest_x != null else 0.2) * f.W
		var px := NoirMath.lerp_f(-50.0 * k, rest, pp)
		var py := (f.gy - 6.0 * k - absf(sin(st * 3.0)) * 50.0 * k * (1.0 - pp)) if tumbling else (f.gy + 16.0 * k)
		var rot := sin(st * 5.0) if tumbling else 0.1
		var w := 72.0
		var h := 48.0
		f.save()
		f.translate(px, py)
		f.rotate(rot)
		f.scale(k, k)
		f.fill_rect(-w / 2.0, -h / 2.0, w, h, Color(228.0 / 255.0, 225.0 / 255.0, 214.0 / 255.0, 0.92))
		f.stroke_rect(-w / 2.0, -h / 2.0, w, h, Color(0, 0, 0, 0.55), 1.0)
		f.text_center("THE BASIN HERALD", 0, -h / 2.0 + 6.0, 5, Color8(11, 11, 11))
		f.line(Vector2(-w / 2.0 + 5.0, -h / 2.0 + 11.0), Vector2(w / 2.0 - 5.0, -h / 2.0 + 11.0), Color(0, 0, 0, 0.5), 1.0)
		f.text_center("ANOTHER ONE", 0, -h / 2.0 + 20.0, 7, Color8(11, 11, 11))
		f.text_center("IN THE RAIN", 0, -h / 2.0 + 29.0, 7, Color8(11, 11, 11))
		for i in 4:
			var yy := -h / 2.0 + 37.0 + i * 2.0
			f.line(Vector2(-w / 2.0 + 6.0, yy), Vector2(w / 2.0 - 6.0, yy), Color(0, 0, 0, 0.28), 0.6)
		f.restore()


class BloodSplat extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s: float = f.unit * (scale if scale != null else 1.0) / 1.4
		var X := f.x_of(self)
		var yy: float = (y if y != null else (f.gy / f.H + 0.02)) * f.H
		var rng := NoirMath.rand32(int(seed) if seed != null else 999)
		f.ellipse_fill(X, yy, 14 * s, 5 * s, Color("b00010"))
		f.glow_radial(X, yy, 9.0, Color(150.0 / 255.0, 0, 12.0 / 255.0), 0.4)
		for i in 16:
			var a := rng.nextf() * TAU
			var d := (10.0 + rng.nextf() * 44.0) * s
			var rr := (1.0 + rng.nextf() * 4.0) * s
			f.circle(X + cos(a) * d, yy + sin(a) * d * 0.5, rr, Color("b00010"))


class BodyOnGround extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirEffects._dy(f, self)
		var fp := -1.0 if flip else 1.0
		f.ellipse_fill(X + fp * 30 * s, gy + 2 * s, 34 * s, 9 * s, Color("9e000e"))
		f.glow_radial(X + fp * 30 * s, gy + 2 * s, 11.0, Color(150.0 / 255.0, 0, 12.0 / 255.0), 0.5)
		f.save()
		f.translate(X, gy)
		f.scale(fp, 1)
		f.ellipse_fill(-6 * s, -7 * s, 26 * s, 9 * s, Palette.INK)
		f.circle(-30 * s, -9 * s, 8 * s, Palette.INK)
		f.ellipse_fill(-48 * s, -3 * s, 9 * s, 3 * s, Palette.INK)
		f.fill_rect(-52 * s, -10 * s, 8 * s, 6 * s, Palette.INK)
		f.fill_rect(14 * s, -11 * s, 24 * s, 6 * s, Palette.INK)
		f.fill_rect(14 * s, -3 * s, 22 * s, 6 * s, Palette.INK)
		f.restore()


class ChalkOutline extends NoirObject:
	func draw(f: NoirFrame) -> void:
		var s := f.scale_of(self)
		var X := f.x_of(self)
		var gy := NoirEffects._dy(f, self)
		f.save()
		f.translate(X, gy)
		f.scale(1, 0.42)
		var chalk := Color(232.0 / 255.0, 234.0 / 255.0, 240.0 / 255.0, 0.7)
		f.ring(-28 * s, 0, 8 * s, chalk, 2 * s)
		var p1 := NoirPath.new()
		p1.move_to(-20 * s, -6 * s).quad_to(0, -14 * s, 20 * s, -22 * s)
		f.stroke_poly(p1.points(), chalk, 2 * s, false, true)
		var p2 := NoirPath.new()
		p2.move_to(-20 * s, 4 * s).quad_to(0, 10 * s, 24 * s, 4 * s)
		f.stroke_poly(p2.points(), chalk, 2 * s, false, true)
		var p3 := NoirPath.new()
		p3.move_to(-18 * s, 0).quad_to(10 * s, 2 * s, 30 * s, 16 * s)
		f.stroke_poly(p3.points(), chalk, 2 * s, false, true)
		f.restore()


class BloodDrain extends NoirObject:
	func draw(f: NoirFrame) -> void:
		if not f.flags.get("blood", false):
			return
		var drain_at_v := int(drain_at) if drain_at != null else 0
		if f.line_idx < drain_at_v:
			return
		var amt := 1.0 if f.line_idx > drain_at_v else NoirMath.smooth01(f.beat() / 5.0)
		var p: float = f.look * (par if par != null else 0.5)
		var x := self.x * f.W + p
		var yy := f.gy + 12.0
		var dx: float = (drain_x if drain_x != null else 0.5) * f.W + p
		var dy: float = (drain_y * f.H) if drain_y != null else (f.gy + (f.H - f.gy) * 0.42)
		var cx2 := (x + dx) / 2.0
		var cy2 := maxf(yy, dy) + 16.0
		var reach := minf(1.0, amt)
		var n := 46
		f.ellipse_fill(x, yy, 14.0 + 12.0 * amt, 5.0 + 4.0 * amt, Color(116.0 / 255.0, 0, 12.0 / 255.0, 0.82))
		for i in range(n + 1):
			var u := float(i) / float(n)
			if u > reach:
				break
			var iu := 1.0 - u
			var bx := iu * iu * x + 2.0 * iu * u * cx2 + u * u * dx
			var by := iu * iu * yy + 2.0 * iu * u * cy2 + u * u * dy
			var wob := sin(u * 8.0 + f.t * 1.3) * (1.0 + u * 2.4)
			var rr := NoirMath.lerp_f(5.2, 1.8, u)
			var col := Color(NoirMath.lerp_f(120, 200, u) / 255.0, NoirMath.lerp_f(0, 60, u) / 255.0, NoirMath.lerp_f(12, 72, u) / 255.0, NoirMath.lerp_f(0.85, 0.4, u))
			f.ellipse_fill(bx + wob, by, rr, rr * 0.78, col)
		if reach > 0.8:
			f.ellipse_fill(dx, dy, 11.0, 4.4, Color(170.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0, 0.42))
