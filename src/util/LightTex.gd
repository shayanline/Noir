class_name LightTex
extends RefCounted
## Shared light textures for the native 2D lights. Each gobo is baked once as a 256x256 alpha map
## and cached. The radial falloff (light_radial.tres) gives the soft round pool, while the named
## gobos give each lamp style its own light distribution:
##   cone     the classic street lamp: a clean downward fan, bright on the axis, fading to the edges.
##   cobra    a modern highway lamp: a wide, flat spread with sharp horizontal cutoff and bat wing
##            lobes at roughly 60 degrees, the IES look of a real cobra head fixture.
##   globe    a frosted glass globe: nearly radial but weighted downward, with a gentle upward spill
##            through the top of the globe. Soft and even, no sharp edges.
##   pendant  a hanging shade: a tight downward pool (narrower than cone) with a hard cutoff at the
##            shade rim and a faint upward leak around the cord.
## Call gobo("name") to get the right texture, or use the convenience methods directly.

const RADIAL := preload("res://src/util/light_radial.tres")

static var _cache: Dictionary = {}


static func radial() -> GradientTexture2D:
	return RADIAL


## Look up a named gobo texture. Returns the classic cone for unknown names.
static func gobo(name: String) -> ImageTexture:
	match name:
		"cobra":
			return cobra()
		"globe":
			return globe()
		"pendant":
			return pendant()
		_:
			return cone()


## The classic street lamp cone: apex at the texture centre, fans down through the lower half,
## bright on the axis and fading to the sides and toward the floor. The noir gobo.
static func cone() -> ImageTexture:
	if _cache.has("cone"):
		return _cache["cone"]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var v := float(y) / float(n - 1)
		for x in n:
			var a := 0.0
			if v >= 0.5:
				var depth := (v - 0.5) * 2.0
				var d := absf(float(x) / float(n - 1) - 0.5)
				var hw := 0.34 * depth
				if hw > 0.001 and d < hw:
					var hf := 1.0 - d / hw
					var vf := clampf(1.0 - depth * 0.55, 0.0, 1.0)
					a = hf * hf * vf
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cache["cone"] = ImageTexture.create_from_image(img)
	return _cache["cone"]


## Cobra head: a wide, flat spread with a sharp horizontal cutoff above the lamp and two bat wing
## lobes at roughly 60 degrees from the vertical. The IES distribution of a modern highway fixture.
static func cobra() -> ImageTexture:
	if _cache.has("cobra"):
		return _cache["cobra"]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cx := float(n - 1) * 0.5
	var cy := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var a := 0.0
			if dy > 0.0:
				var dist := sqrt(dx * dx + dy * dy) / cx
				var angle := atan2(absf(dx), dy)
				# main lobe: broad, centred on vertical (angle 0)
				var main := exp(-angle * angle * 2.0)
				# bat wing lobes at roughly 55 degrees (0.96 rad)
				var wing_angle := absf(angle - 0.96)
				var wing := exp(-wing_angle * wing_angle * 12.0) * 0.6
				var lobe := maxf(main, wing)
				# radial falloff and sharp cutoff past 85% radius
				var rf := clampf(1.0 - dist * 0.8, 0.0, 1.0)
				a = lobe * rf * rf
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_cache["cobra"] = ImageTexture.create_from_image(img)
	return _cache["cobra"]


## Globe: a frosted glass globe, nearly radial but weighted downward. Light spills in all
## directions with a gentle bias toward the ground, no sharp edges anywhere.
static func globe() -> ImageTexture:
	if _cache.has("globe"):
		return _cache["globe"]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cx := float(n - 1) * 0.5
	var cy := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (float(x) - cx) / cx
			var dy := (float(y) - cy) / cy
			var dist := sqrt(dx * dx + dy * dy)
			# downward bias: lower hemisphere gets more light
			var bias := 1.0 + dy * 0.35
			var rf := clampf(1.0 - dist, 0.0, 1.0)
			var a := rf * rf * bias
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_cache["globe"] = ImageTexture.create_from_image(img)
	return _cache["globe"]


## Pendant: a hanging shade lamp. A tight downward pool (narrower than the cone) with a hard
## cutoff at the shade rim and a faint leak upward around the cord.
static func pendant() -> ImageTexture:
	if _cache.has("pendant"):
		return _cache["pendant"]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cx := float(n - 1) * 0.5
	var cy := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var a := 0.0
			if dy > 0.0:
				# tight cone, narrower than the standard
				var depth := dy / cy
				var spread := absf(dx) / cx
				var hw := 0.22 * depth
				if hw > 0.001 and spread < hw:
					var hf := 1.0 - spread / hw
					var vf := clampf(1.0 - depth * 0.45, 0.0, 1.0)
					a = hf * hf * hf * vf
			else:
				# faint upward leak: a very dim, tight glow above the shade
				var up_dist := sqrt(dx * dx + dy * dy) / cx
				a = clampf(0.06 * (1.0 - up_dist * 4.0), 0.0, 0.06)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_cache["pendant"] = ImageTexture.create_from_image(img)
	return _cache["pendant"]
