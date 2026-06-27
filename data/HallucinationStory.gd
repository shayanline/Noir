class_name HallucinationStory
extends RefCounted
## "A Hallucination of Sin City", ported from Inkfall's stories/hallucination as pure data. Cast
## entries name a library object by `type`; lights name a light by `type`. Reveal or hide a member
## with on_flag / hide_on_flag (set by a line's fx). <b>..</b> prints in blood red.


static func get_story() -> Dictionary:
	return {
		"title": "INKFALL",
		"subtitle": "A HALLUCINATION OF SIN CITY",
		"blurb": "It always rains in Basin City. The whole town is black and white, except the things that bleed. Tap through the long, wet night.",
		"music": "piano_noir",
		"music_vol": 0.62,
		"scenes": [
			{
				"title": "THE STREET", "ground": 0.8, "key_light": {"x": 0.30, "y": 0.5},
				"ambience": "street", "ambience_vol": 0.4, "rain_vol": 0.16,
				"backdrop": {
					"type": "skyline", "seed": 1977,
					"layers": [
						{"depth": 0.25, "top": 0.16, "shade": "#0c0e13", "min_w": 60, "max_w": 130, "min_h": 0.34, "max_h": 0.62, "win": 0.10},
						{"depth": 0.55, "top": 0.26, "shade": "#070809", "min_w": 80, "max_w": 170, "min_h": 0.40, "max_h": 0.74, "win": 0.16},
						{"depth": 1.00, "top": 0.38, "shade": "#020203", "min_w": 110, "max_w": 240, "min_h": 0.46, "max_h": 0.92, "win": 0.22},
					],
				},
				"lights": [
					{"type": "lamp", "x": 0.30, "intensity": 1, "flicker": true, "par": 0.5},
					{"type": "neon", "x": 0.10, "y": 0.52, "w": 92, "h": 34, "color": Color("ff0018"), "label": "BAR", "seed": 1.3},
					{"type": "neon", "x": 0.40, "y": 0.48, "w": 120, "h": 30, "color": Color("ff0018"), "label": "GIRLS", "seed": 2.7, "par": 0.4},
					{"type": "neon", "x": 0.66, "y": 0.40, "w": 44, "h": 120, "color": Color("ffd400"), "label": "XXX", "seed": 4.1},
				],
				"cast": [
					{"type": "steam", "x": 0.52, "seed": 0.3},
					{"type": "trafficLight", "x": 0.90, "scale": 0.9, "par": 0.6, "green_at": 2},
					{"type": "redCar", "x": 0.84, "scale": 0.7, "par": 0.5, "walk": [0.84, 0.84, 1.45, 1.7], "walk_dur": 3.2},
					{"type": "womanInRed", "x": 0.7, "scale": 0.8, "par": 0.4, "walk": [0.72, 0.52, 0.30, -0.3], "walk_dur": 11, "pass_x": 0.34},
					{"type": "trenchMan", "x": 0.34, "scale": 1, "dy": 4, "par": 0.5, "raise_at": 1, "light_at": 3},
				],
				"script": [
					{"text": "The night is wet and the city drinks it down."},
					{"text": "She walks past in a dress the colour of <b>fresh blood</b>."},
					{"text": "Neon hums a lullaby for the damned."},
					{"text": "I light a smoke and let the dark make the first move.", "fx": ["lighter"]},
				],
			},
			{
				"title": "THE ALLEY", "ground": 0.8, "key_light": {"x": 0.74, "y": 0.3}, "moon": {"x": 0.5, "y": 0.11}, "rain_vol": 0.16,
				"backdrop": {"type": "alley", "seed": 77123},
				"lights": [
					{"type": "neon", "x": 0.72, "y": 0.24, "w": 64, "h": 34, "color": Color("ff0018"), "label": "EAT", "seed": 5.2, "par": 0.3, "arrow": true, "ignite": true},
				],
				"cast": [
					{"type": "dumpster", "x": 0.11, "scale": 1, "par": 0.4},
					{"type": "manhole", "x": 0.6, "scale": 1.1, "par": 0.2},
					{"type": "steam", "x": 0.6, "seed": 0.9},
					{"type": "newspaper", "x": 0, "rest_x": 0.2, "seed": 2.1},
					{"type": "gunman", "x": 0.30, "scale": 1, "par": 0.5, "raise_at": 1},
					{"type": "bodyOnGround", "x": 0.5, "scale": 1, "par": 0.5, "on_flag": "blood"},
					{"type": "bloodSplat", "x": 0.5, "on_flag": "blood", "seed": 999},
					{"type": "bloodDrain", "x": 0.5, "drain_x": 0.6, "par": 0.2, "on_flag": "blood", "drain_at": 3},
				],
				"script": [
					{"text": "The alley stinks of rain and old sins."},
					{"text": "A shape in the doorway. A <b>gun</b> that means it.", "fx": ["hammer"]},
					{"text": "Two shots. The bricks wear a fresh coat of <b>red</b>.", "fx": ["muzzle", "blood", "lightning"]},
					{"text": "Nobody heard a thing. Nobody ever does here."},
				],
			},
			{
				"title": "THE ROOFTOP", "ground": 0.72, "key_light": {"x": 0.6, "y": 0.4}, "moon": {"x": 0.78, "y": 0.18},
				"blood_rain": true, "ambience": "rooftop", "ambience_vol": 0.45, "rain_vol": 0.16,
				"backdrop": {"type": "rooftop", "seed": 55512},
				"lights": [],
				"cast": [
					{"type": "searchlight", "x": 0.5},
					{"type": "waterTower", "x": 0.18, "scale": 1, "par": 0.4},
					{"type": "crow", "x": 0.18, "y": 0.43, "scale": 1.5, "par": 0.4, "fly_at": 3, "delay": 0.0},
					{"type": "crow", "x": 0.36, "y": 0.25, "scale": 1.1, "fly_at": 3, "delay": 0.14},
					{"type": "crow", "x": 0.67, "y": 0.22, "scale": 1.0, "fly_at": 3, "delay": 0.26},
					{"type": "steam", "x": 0.74, "seed": 0.5},
					{"type": "womanInRed", "x": 0.6, "scale": 0.85, "par": 0.4},
				],
				"script": [
					{"text": "Up here the city's just a field of dirty stars."},
					{"text": "Crows watch. They've seen worse. So have I."},
					{"text": "She stands on the ledge, between two kinds of falling."},
					{"text": "The rain'll wash it clean by morning. It always lies."},
				],
			},
		],
	}
