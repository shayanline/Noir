class_name NoirLights
extends RefCounted
## Declared light sources: lamp, neon, bulb, glow. Each registers its light record in emit_light
## (consumed by the light pass and by rim/shadow) and paints its visible fixture in draw. Ported
## from Inkfall's library/lights.js. The per frame flicker is computed in emit and reused in draw.


static func register(reg: NoirRegistry) -> void:
	reg.register_object("lamp", Lamp)
	reg.register_object("neon", Neon)
	reg.register_object("bulb", Bulb)
	reg.register_object("glow", Glow)


static func _flicker(t: float, seed_value: float, on: bool) -> float:
	if not on:
		return 1.0
	var base := 1.0 if sin(t * 30.0 + seed_value) > -0.9 else 0.4
	return base * (0.85 + 0.15 * sin(t * 7.0))


static func _with_alpha(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)


class Lamp extends NoirObject:
	func emit_light(f: NoirFrame) -> void:
		var t := f.t
		var X := f.x_of(self)
		var sc: float = scale if scale != null else 1.0
		var s := f.unit * sc
		var flick := NoirLights._flicker(t, float(seed if seed != null else 0), flicker == true)
		_flick = flick
		_x = X
		_s = s
		f.add_light({"x": X + 26.0 * s, "y": f.gy - 150.0 * s, "col": Color8(255, 250, 225), "r": 150.0 * sc, "I": 0.5 * flick, "ew": 6.0 * s, "eh": 6.0 * s})

	func draw(f: NoirFrame) -> void:
		var X := _x
		var s := _s
		var gy := f.gy
		var fl: float = (intensity if intensity != null else 1.0) * _flick
		var ink := Palette.INK
		var top_y := gy - 150.0 * s
		f.fill_rect(X - 2.0 * s, top_y, 4.0 * s, 150.0 * s, ink)
		f.fill_poly(PackedVector2Array([Vector2(X, top_y), Vector2(X + 26.0 * s, top_y - 4.0 * s), Vector2(X + 26.0 * s, top_y + 3.0 * s)]), ink)
		var lx := X + 26.0 * s
		var ly := top_y - 2.0 * s
		var warm := Color8(255, 250, 225)
		f.glow_poly(PackedVector2Array([Vector2(lx, ly), Vector2(lx - 70.0 * s, gy), Vector2(lx + 70.0 * s, gy)]), warm, 0.07 * fl)
		f.glow_radial(lx, ly + 4.0 * s, 26.0 * s, Color8(255, 250, 230), fl)
		f.circle(lx, ly + 4.0 * s, 4.0 * s, NoirLights._with_alpha(Color8(255, 250, 230), fl))
		f.fill_poly(PackedVector2Array([Vector2(lx - 7.0 * s, ly - 6.0 * s), Vector2(lx + 7.0 * s, ly - 6.0 * s), Vector2(lx + 4.0 * s, ly + 2.0 * s), Vector2(lx - 4.0 * s, ly + 2.0 * s)]), ink)


class Neon extends NoirObject:
	func emit_light(f: NoirFrame) -> void:
		var t := f.t
		var sd := float(seed if seed != null else 0)
		var X := f.x_of(self)
		var yy: float = (y if y != null else 0.5) * f.H
		var flick := (0.88 + 0.12 * sin(t * 13.0 + sd)) if sin(t * 5.0 + sd) > -0.95 else 0.5
		if ignite:
			var st := f.scene_t()
			if st < 0.4:
				flick = 0.04
			elif st < 1.9:
				flick = flick if sin(st * 34.0) > -0.1 else 0.12
			if st >= 0.4 and not f.flags.get("_ign", false):
				f.flags["_ign"] = true
				AudioDirector.neon_zap()
		_flick = flick
		_x = X
		_ly = yy
		var lx: float = X + w / 2.0 + (h * 0.45 if arrow else 0.0)
		var ly: float = yy + h / 2.0
		f.add_light({"x": lx, "y": ly, "col": color, "r": maxf(w, h) * 1.8, "I": 0.9 * flick, "ew": w * 0.55, "eh": h * 0.55})

	func draw(f: NoirFrame) -> void:
		NoirLights._neon_fixture(f, _x, _ly, w, h, color, label, _flick, arrow == true)


class Bulb extends NoirObject:
	func emit_light(f: NoirFrame) -> void:
		var t := f.t
		var X := f.x_of(self)
		var yy: float = (y if y != null else 0.5) * f.H
		var flick := NoirLights._flicker(t, float(seed if seed != null else 0), flicker == true)
		_flick = flick
		_x = X
		_ly = yy
		f.add_light({"x": X, "y": yy, "col": Color8(255, 244, 210), "r": 150.0, "I": 0.6 * flick, "ew": 5.0, "eh": 5.0})

	func draw(f: NoirFrame) -> void:
		var x := _x
		var yy := _ly
		var fl: float = (intensity if intensity != null else 1.0) * _flick
		f.line(Vector2(x, yy - 95.0), Vector2(x, yy), Palette.INK, 1.0)
		f.glow_radial(x, yy, 120.0, Color8(255, 244, 210), 0.22 * fl)
		f.glow_radial(x, yy, 16.0, Color8(255, 246, 220), fl)
		f.circle(x, yy, 3.5, NoirLights._with_alpha(Color8(255, 246, 220), fl))


class Glow extends NoirObject:
	func emit_light(f: NoirFrame) -> void:
		var X := f.x_of(self)
		var yy: float = (y if y != null else 0.5) * f.H
		var inten: float = 0.5 * (intensity if intensity != null else 1.0)
		f.add_light({"x": X, "y": yy, "col": color, "r": r, "I": inten, "ew": r * 0.3, "eh": r * 0.3})


static func _neon_fixture(f: NoirFrame, x: float, y: float, w: float, h: float, color: Color, label: String, fl: float, arrow: bool) -> void:
	var a := 0.35 + 0.65 * fl
	f.glow_radial(x + w / 2.0, y + h / 2.0, maxf(w, h) * 0.85, color, 0.5 * fl)
	if arrow:
		var pw := h * 0.9
		var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w + pw, y + h / 2.0), Vector2(x + w, y + h), Vector2(x, y + h)])
		f.stroke_poly(pts, _with_alpha(color, a), 3.0, true, true)
		f.text_center(label, x + w / 2.0, y + h / 2.0, int(h * 0.56), _with_alpha(color, a))
		return
	f.stroke_rect(x, y, w, h, _with_alpha(color, a), 3.0)
	var n: int = maxi(1, label.length())
	if h > w * 1.5:
		var fs: int = int(minf(w * 0.66, (h - 8.0) / n))
		for i in n:
			f.text_center(label[i], x + w / 2.0, y + (i + 0.5) * h / n, fs, _with_alpha(color, a))
	else:
		var fs2: int = int(minf(h * 0.6, (w - 10.0) / n * 1.7))
		f.text_center(label, x + w / 2.0, y + h / 2.0, fs2, _with_alpha(color, a))
