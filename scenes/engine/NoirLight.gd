class_name NoirLight
extends RefCounted
## The one shared light + shadow model, ported from Inkfall's render/lighting.js. An object
## describes a light once with add_light({...}); the panel's light pass then paints a tight
## surface glow, a soft air glow and a wet floor reflection. rim, tint and ground shadow read
## the same records, which keeps the whole cast lit from the same sources.

const DEFAULT_COL := Color(1.0, 0.980, 0.882)   # 255,250,225


## register a light for this frame. Fields mirror Inkfall: x, y, col (Color), r, I, ew, eh,
## glow, surface, ring, glow_r, glow_i, refl, refl_w, refl_i, refl_len.
static func add_light(f: NoirFrame, rec: Dictionary) -> void:
	if not rec.has("col"): rec["col"] = DEFAULT_COL
	if not rec.has("r"): rec["r"] = 150.0
	if not rec.has("I"): rec["I"] = 0.5
	if not rec.has("ew"): rec["ew"] = rec["r"] * 0.10
	if not rec.has("eh"): rec["eh"] = rec["ew"]
	if not rec.has("glow"): rec["glow"] = true
	if not rec.has("surface"): rec["surface"] = true
	if not rec.has("ring"): rec["ring"] = false
	if not rec.has("glow_r"): rec["glow_r"] = rec["r"]
	if not rec.has("glow_i"): rec["glow_i"] = rec["I"]
	if not rec.has("refl"): rec["refl"] = true
	f.lights.append(rec)


## the strongest light reaching a point (rim side, shadow direction).
static func dominant_light(f: NoirFrame, wx: float):
	var best = null
	var bw := 0.12
	for L in f.lights:
		var w: float = L["I"] * (1.0 - absf(wx - L["x"]) / (L["r"] * 1.1))
		if w > bw:
			bw = w
			best = L
	return best


## ambient tint at a point: a smooth weighted blend of nearby lights, or null if too dark.
static func lit_tint(f: NoirFrame, wx: float):
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var wsum := 0.0
	for L in f.lights:
		var w: float = L["I"] * (1.0 - absf(wx - L["x"]) / (L["r"] * 1.1))
		if w > 0.0:
			var cc: Color = L["col"]
			r += cc.r * w
			g += cc.g * w
			b += cc.b * w
			wsum += w
	if wsum < 0.12:
		return null
	return Color(r / wsum, g / wsum, b / wsum)


## blended colour of every light reaching x (red + green to amber), else the fallback base.
static func lit_color(f: NoirFrame, x: float, base: Color) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var wsum := 0.0
	for L in f.lights:
		var w: float = L["I"] * (1.0 - absf(x - L["x"]) / (L["r"] * 0.6))
		if w > 0.0:
			var cc: Color = L["col"]
			r += cc.r * w
			g += cc.g * w
			b += cc.b * w
			wsum += w
	if wsum < 0.18:
		return base
	var m: float = minf(1.0, wsum * 0.9 + 0.2)
	return Color(
		NoirMath.lerp_f(base.r, r / wsum, m),
		NoirMath.lerp_f(base.g, g / wsum, m),
		NoirMath.lerp_f(base.b, b / wsum, m))


## directional ground shadow used by every grounded object, drawn to the world canvas.
static func ground_shadow(f: NoirFrame, wx: float, half_w: float, obj_h: float) -> void:
	var g := f.gy
	var black := Color(0, 0, 0)
	var cands := []
	for L in f.lights:
		var w: float = L["I"] * (1.0 - absf(wx - L["x"]) / (L["r"] * 1.2))
		if w > 0.06:
			cands.append({"L": L, "w": w})
	cands.sort_custom(func(a, b): return a["w"] > b["w"])
	if cands.is_empty():
		var r_x := half_w * 1.25
		var r_y := half_w * 0.3
		f.blit_world(NoirSoft.radial(), wx - r_x, g + 4.0 - r_y, r_x * 2.0, r_y * 2.0, black, 0.32)
		return
	for i in mini(2, cands.size()):
		var L: Dictionary = cands[i]["L"]
		var w: float = cands[i]["w"]
		var dir := 1.0 if wx >= L["x"] else -1.0
		var dist: float = absf(wx - L["x"])
		var vert: float = maxf(24.0, g - L["y"])
		var ln: float = minf(obj_h * 2.2, half_w + obj_h * (dist / vert) * 0.9 + obj_h * 0.2)
		var r_x := half_w * 0.7 + ln * 0.55
		var r_y := half_w * 0.3
		var a: float = minf(0.42, 0.32 * w)
		f.blit_world(NoirSoft.radial(), wx + dir * ln * 0.45 - r_x, g + 4.0 - r_y, r_x * 2.0, r_y * 2.0, black, a)


# --- the additive light layer (called by the panel during the light pass) -----------------

## a soft streak down the wet floor; also used for static off-screen signs and the moon.
static func streak(f: NoirFrame, x: float, col: Color, intensity: float, w: float, ln: float) -> void:
	if intensity < 0.02 or ln < 2.0:
		return
	f.blit_light(NoirSoft.column(), x - w, f.gy, w * 2.0, ln, col, 0.5 * intensity)


static func _surface_glow(f: NoirFrame, L: Dictionary) -> void:
	var rx: float = maxf(L["ew"] * 1.25, 8.0) + L["r"] * 0.10
	var ry: float = maxf(L["eh"] * 1.25, 8.0) + L["r"] * 0.10
	f.blit_light(NoirSoft.radial(), L["x"] - rx, L["y"] - ry, rx * 2.0, ry * 2.0, L["col"], 0.30 * L["glow_i"])


static func _air_glow(f: NoirFrame, L: Dictionary) -> void:
	var r: float = L["glow_r"]
	var tex: ImageTexture = NoirSoft.ring() if L["ring"] else NoirSoft.radial()
	f.blit_light(tex, L["x"] - r, L["y"] - r, r * 2.0, r * 2.0, L["col"], 0.15 * L["glow_i"])


static func _floor_refl(f: NoirFrame, L: Dictionary) -> void:
	var gy := f.gy
	var h: float = gy - L["y"]
	if h <= 2.0:
		return
	var intensity: float
	var w: float
	var ln: float
	if L.has("refl_i"):
		intensity = L["refl_i"]
		w = L["refl_w"] if L.has("refl_w") else 24.0
		ln = (f.H - gy) * (L["refl_len"] if L.has("refl_len") else 0.7)
	else:
		var reach: float = L["r"] / (L["r"] + h)
		intensity = L["I"] * reach * 0.7
		w = maxf(8.0, L["ew"] * 0.7 + L["r"] * 0.12)
		ln = minf(f.H - gy, h * 0.5 + L["r"] * 0.45)
	streak(f, L["x"], L["col"], intensity, w, ln)


## surface + air glow then the wet floor reflection, for every registered light.
static func draw_light_layer(f: NoirFrame) -> void:
	for L in f.lights:
		if L["glow"]:
			if L["surface"]:
				_surface_glow(f, L)
			_air_glow(f, L)
		if L["refl"]:
			_floor_refl(f, L)
