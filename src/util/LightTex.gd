class_name LightTex
extends RefCounted
## Shared light texture for the native 2D lights. The soft radial falloff that gives a PointLight2D
## the round, feathered pool the noir look expects is authored as light_radial.tres; this loads it
## once and reuses it, so code-driven lights and authored scenes share the one texture.

const RADIAL := preload("res://src/util/light_radial.tres")

static var _cone: ImageTexture


static func radial() -> GradientTexture2D:
	return RADIAL


## A downward gobo cone for spot-style fixtures (the street lamp). The apex sits at the texture
## centre and the cone fans down through the lower half, bright along the axis and fading to the
## sides and toward the floor. Used as a PointLight2D texture so the lamp projects a real cone of
## light, the noir 'gobo', not a flat round pool. Baked once and shared.
static func cone() -> ImageTexture:
	if _cone:
		return _cone
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var v := float(y) / float(n - 1)         # 0 top, 1 bottom
		for x in n:
			var a := 0.0
			if v >= 0.5:
				var depth := (v - 0.5) * 2.0       # 0 at the apex (centre), 1 at the bottom
				var d := absf(float(x) / float(n - 1) - 0.5)
				var hw := 0.34 * depth             # cone half-width grows with depth
				if hw > 0.001 and d < hw:
					var hf := 1.0 - d / hw         # 1 on the axis, 0 at the cone edge
					var vf := clampf(1.0 - depth * 0.55, 0.0, 1.0)   # fade toward the floor
					a = hf * hf * vf
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cone = ImageTexture.create_from_image(img)
	return _cone
