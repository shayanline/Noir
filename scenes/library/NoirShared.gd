class_name NoirShared
extends RefCounted
## Shared sub drawings and material shading the cast and props build on, ported from Inkfall's
## library/shared.js and style/materials.js: cigarette ember + smoke, a snap brim fedora, a
## pistol, a muzzle flash, plus the rim direction and the body gradient that lights every figure.

const EMBER_SPEED := 6.0


# --- materials ----------------------------------------------------------------------------

## which edge catches the light: toward the weighted centre of nearby lights, with a dead zone
## and hysteresis so a flickering source cannot snap the lit edge from side to side.
static func rim_sign(f: NoirFrame, node) -> int:
	var X := f.x_of(node)
	var wx := 0.0
	var wsum := 0.0
	for L in f.lights:
		var w: float = L["I"] * (1.0 - absf(X - L["x"]) / (L["r"] * 1.1))
		if w > 0.0:
			wx += L["x"] * w
			wsum += w
	var lx: float = (wx / wsum) if wsum > 0.05 else f.key_light["x"] * f.W
	var margin := 0.06 * f.W
	var sign: int = node._rim if node._rim != 0 else (-1 if lx < X else 1)
	if lx < X - margin:
		sign = -1
	elif lx > X + margin:
		sign = 1
	node._rim = sign
	return sign


## fill a polygon with the horizontal form gradient: a lit edge on the light side, tinted by it.
static func body_fill(f: NoirFrame, points: PackedVector2Array, s: float, rim: int, tint) -> void:
	var lit := Color8(58, 64, 73)
	if tint != null:
		lit = lit.lerp(tint, 0.5)
	var p0 := Vector2(rim * 34.0 * s, 0)
	var p1 := Vector2(-rim * 34.0 * s, 0)
	f.fill_poly_grad(points, p0, p1, PackedFloat32Array([0.0, 0.42, 1.0]), [lit, Color8(24, 27, 33), Color8(8, 9, 9)])


static func shadow_pool(f: NoirFrame, x: float, y: float, rx: float, ry: float) -> void:
	f.ellipse_fill(x, y, rx, ry, Color(0, 0, 0, 0.32))


# --- sub drawings -------------------------------------------------------------------------

static func ember(f: NoirFrame, x: float, y: float, s: float, t: float) -> void:
	var em := 0.6 + 0.4 * sin(t * EMBER_SPEED)
	f.circle(x, y, 1.9 * s, Color(1.0, 60.0 / 255.0, 30.0 / 255.0, 0.7 + 0.3 * em))
	f.glow_radial(x, y, 9.0 * s + 4.0, Color(1.0, 32.0 / 255.0, 16.0 / 255.0), 0.45 * em)


static func cig_smoke(f: NoirFrame, x: float, y: float, s: float, t: float) -> void:
	for i in 6:
		var life := fmod(t * 0.4 + i * 0.16, 1.0)
		var yy := y - life * 42.0 * s
		var xx := x + sin(t * 1.2 + i) * 4.0 * s * life
		var r := (1.4 + life * 5.0) * s
		var a := 0.11 * (1.0 - life)
		f.glow_radial(xx, yy, r, Color(210.0 / 255.0, 214.0 / 255.0, 224.0 / 255.0), a)


static func fedora(f: NoirFrame, cx: float, cy: float, r: float, rim: int) -> void:
	f.save()
	f.translate(cx, cy)
	f.ellipse_fill(0, r * 0.06, r * 1.62, r * 0.32, Palette.INK)
	var p := NoirPath.new()
	p.move_to(-r * 0.8, -r * 0.04)
	p.quad_to(-r * 0.86, -r * 0.82, -r * 0.4, -r * 0.9)
	p.quad_to(-r * 0.16, -r * 1.0, 0, -r * 0.82)
	p.quad_to(r * 0.16, -r * 1.0, r * 0.4, -r * 0.9)
	p.quad_to(r * 0.86, -r * 0.82, r * 0.8, -r * 0.04)
	f.fill_poly(p.points(), Palette.INK)
	f.fill_rect(-r * 0.8, -r * 0.16, r * 1.6, r * 0.16, Color8(16, 18, 26))
	var hl := NoirPath.new()
	hl.move_to(rim * r * 0.7, -r * 0.86)
	hl.quad_to(rim * r * 0.86, -r * 0.5, rim * r * 0.78, -r * 0.08)
	f.stroke_poly(hl.points(), Color(200.0 / 255.0, 210.0 / 255.0, 230.0 / 255.0, 0.28), 1.0)
	f.restore()


static func pistol(f: NoirFrame, x: float, y: float, s: float) -> void:
	f.save()
	f.translate(x, y)
	var dark := Color8(16, 18, 22)
	f.fill_rect(0, -3 * s, 17 * s, 5 * s, dark)
	f.fill_rect(-2 * s, -3 * s, 5 * s, 12 * s, dark)
	f.fill_rect(2 * s, 2 * s, 4 * s, 5 * s, Color8(26, 29, 34))
	f.line(Vector2(0, -3 * s), Vector2(17 * s, -3 * s), Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.55), 1.0)
	f.restore()


static func muzzle_flash(f: NoirFrame, x: float, y: float, s: float, fl: float) -> void:
	f.save()
	f.translate(x, y)
	var pts := PackedVector2Array()
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var r := (6.0 if i % 2 else 18.0) * s * (0.6 + fl)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	f.fill_poly(pts, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, fl))
	f.circle(0, 0, 5 * s * fl, Color(1, 1, 1, fl))
	f.glow_radial(0, 0, 24.0 * s * (0.5 + fl), Color(1.0, 48.0 / 255.0, 0.0), 0.7 * fl)
	f.restore()
