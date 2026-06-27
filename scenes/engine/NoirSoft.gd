class_name NoirSoft
extends RefCounted
## Pre-built white soft sprites (radial, ring, column). Drawn additively and tinted by a colour
## modulate, they replace Inkfall's per-frame radial gradients and the costly canvas blur. White
## with an alpha falloff so a colour modulate gives a coloured glow on the additive light layer.

static var _radial: ImageTexture
static var _ring: ImageTexture
static var _column: ImageTexture


## soft round glow, peak alpha 1 at centre, matching softRadial (stops 0:1, 0.5:0.32, 1:0).
static func radial() -> ImageTexture:
	if _radial == null:
		var s := 128
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var c := Vector2(s * 0.5, s * 0.5)
		for y in s:
			for x in s:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
				var a := 0.0
				if d < 0.5:
					a = lerpf(1.0, 0.32, d / 0.5)
				elif d < 1.0:
					a = lerpf(0.32, 0.0, (d - 0.5) / 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_radial = ImageTexture.create_from_image(img)
	return _radial


## soft halo ring: transparent core, bright ring, fades out (softRing).
static func ring() -> ImageTexture:
	if _ring == null:
		var s := 128
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var c := Vector2(s * 0.5, s * 0.5)
		for y in s:
			for x in s:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (s * 0.5)
				var a := 0.0
				if d < 0.4:
					a = 0.0
				elif d < 0.52:
					a = lerpf(0.0, 1.0, (d - 0.4) / 0.12)
				elif d < 0.75:
					a = lerpf(1.0, 0.4, (d - 0.52) / 0.23)
				elif d < 1.0:
					a = lerpf(0.4, 0.0, (d - 0.75) / 0.25)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_ring = ImageTexture.create_from_image(img)
	return _ring


## soft vertical streak: bright at the top, feathered sides (softColumn), 64x256.
static func column() -> ImageTexture:
	if _column == null:
		var w := 64
		var h := 256
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var v := float(y) / float(h)
			var va := 0.0
			if v < 0.4:
				va = lerpf(1.0, 0.36, v / 0.4)
			else:
				va = lerpf(0.36, 0.0, (v - 0.4) / 0.6)
			for x in w:
				var u := float(x) / float(w)
				var ha := 1.0 - absf(u - 0.5) * 2.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(va * clampf(ha, 0.0, 1.0), 0.0, 1.0)))
		_column = ImageTexture.create_from_image(img)
	return _column
