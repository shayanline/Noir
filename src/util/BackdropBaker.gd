class_name BackdropBaker
extends RefCounted
## Bakes the procedural seeded skyline (buildings plus lit windows) into a single texture, so a
## backdrop shows it with one Sprite2D instead of hundreds of nodes. The seed reproduces the same
## skyline every run, the way the old canvas skyline did.


## a skyline layer config. top is a fraction of board height, shade is the building colour.
static func bake_skyline(vp: Vector2, ground_y: float, seed_value: int, layers_cfg: Array) -> ImageTexture:
	var img := Image.create(maxi(1, int(vp.x)), maxi(1, int(vp.y)), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cfg in layers_cfg:
		var shade: Color = cfg["shade"]
		var top_px: float = cfg["top"] * vp.y
		var x := -140.0
		while x < vp.x + 220.0:
			var w: float = cfg["min_w"] + rng.randf() * (cfg["max_w"] - cfg["min_w"])
			var h: float = (cfg["min_h"] + rng.randf() * (cfg["max_h"] - cfg["min_h"])) * (ground_y - top_px)
			var top := ground_y - h
			_rect(img, x, top, w, h + 6.0, shade)
			if rng.randf() < 0.25:
				var capx := x + w * (0.3 + rng.randf() * 0.4)
				if rng.randf() < 0.5:
					_rect(img, capx - 7.0, top - 14.0, 14.0, 14.0, shade)
					_rect(img, capx - 9.0, top - 2.0, 18.0, 3.0, shade)
				else:
					_rect(img, capx - 1.0, top - 22.0, 2.0, 22.0, shade)
			var cols: int = maxi(2, int(w / 16.0))
			var rows: int = maxi(3, int(h / 20.0))
			for r in rows:
				for ci in cols:
					if rng.randf() > cfg["win"]:
						continue
					var wx := x + 7.0 + ci * (w - 14.0) / cols
					var wy := top + 10.0 + r * (h - 16.0) / rows
					var warm: bool = rng.randf() > 0.8
					_rect(img, wx, wy, 4.0, 5.0, Palette.WARM_WIN if warm else Palette.COOL_WIN)
			x += w + 2.0 + rng.randf() * 16.0
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	var r := Rect2i(int(x), int(y), maxi(1, int(w)), maxi(1, int(h)))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col)
