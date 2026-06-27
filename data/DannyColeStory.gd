class_name DannyColeStory
extends RefCounted
## "The Last Deal of Danny Cole", ported from Inkfall's stories/danny-cole as pure data. A small
## man with a big debt goes looking for easy money in the underground casinos of Basin City.


static func get_story() -> Dictionary:
	return {
		"title": "INKFALL",
		"subtitle": "THE LAST DEAL OF DANNY COLE",
		"blurb": "A small man with a big debt goes looking for easy money in the underground casinos of Basin City. The house always wins. Tap through his last bad night.",
		"music": "sad_jazz",
		"music_vol": 0.5,
		"scenes": [
			{
				"title": "THE ITCH", "ground": 0.8, "key_light": {"x": 0.3, "y": 0.5}, "ambience": "street", "ambience_vol": 0.4, "rain_vol": 0.16,
				"backdrop": {
					"type": "skyline", "seed": 19880420,
					"layers": [
						{"depth": 0.25, "top": 0.18, "shade": "#0c0e13", "min_w": 60, "max_w": 130, "min_h": 0.34, "max_h": 0.62, "win": 0.10},
						{"depth": 0.55, "top": 0.28, "shade": "#070809", "min_w": 80, "max_w": 170, "min_h": 0.40, "max_h": 0.74, "win": 0.16},
						{"depth": 1.00, "top": 0.40, "shade": "#020203", "min_w": 110, "max_w": 240, "min_h": 0.46, "max_h": 0.92, "win": 0.22},
					],
				},
				"lights": [
					{"type": "lamp", "x": 0.30, "intensity": 1, "flicker": true, "par": 0.5},
					{"type": "neon", "x": 0.10, "y": 0.40, "w": 130, "h": 34, "color": Color("ff0018"), "label": "CASINO", "seed": 1.3},
					{"type": "neon", "x": 0.70, "y": 0.28, "w": 44, "h": 118, "color": Color("ffd400"), "label": "LUCK", "seed": 4.1},
				],
				"cast": [
					{"type": "steam", "x": 0.52, "seed": 0.3},
					{"type": "barrelFire", "x": 0.07, "scale": 0.85, "par": 0.5},
					{"type": "cat", "x": 0.92, "flip": true, "par": 0.5},
					{"type": "redCar", "x": 0.86, "scale": 0.7, "par": 0.5},
					{"type": "womanInRed", "x": 0.62, "scale": 0.8, "par": 0.4},
					{"type": "trenchMan", "x": 0.34, "scale": 1, "dy": 4, "par": 0.5},
				],
				"script": [
					{"text": "Danny Cole had two suits, one good lung, and a dream the size of a debt."},
					{"text": "Get rich or get gone. In Basin City that's the same bus."},
					{"text": "The neon promised him everything. Neon's a liar with a pretty mouth."},
					{"text": "Tonight he'd play the deep tables, the ones <b>under</b> the city."},
				],
			},
			{
				"title": "THE TABLE", "ground": 0.82, "key_light": {"x": 0.5, "y": 0.3}, "rain_vol": 0.16,
				"backdrop": {"type": "room", "wall": "#06070b", "wall_top": "#0b0d12", "door": 0.64},
				"lights": [
					{"type": "bulb", "x": 0.45, "y": 0.30, "intensity": 1, "flicker": true, "par": 0.2},
					{"type": "neon", "x": 0.14, "y": 0.20, "w": 120, "h": 30, "color": Color("ff0018"), "label": "FORTUNE", "seed": 2.2, "par": 0.2},
				],
				"cast": [
					{"type": "rouletteWheel", "x": 0.20, "y": 0.74, "scale": 0.8, "par": 0.2},
					{"type": "slotMachine", "x": 0.07, "scale": 0.85, "par": 0.2},
					{"type": "slotMachine", "x": 0.93, "scale": 0.85, "par": 0.2},
					{"type": "dealer", "x": 0.45, "scale": 0.95},
					{"type": "cardTable", "x": 0.45, "scale": 1.05},
					{"type": "cash", "x": 0.52, "y": 0.79, "scale": 0.85},
					{"type": "drink", "x": 0.63, "y": 0.80, "kind": "whiskey", "scale": 0.9},
					{"type": "trenchMan", "x": 0.76, "scale": 1, "par": 0.2},
				],
				"script": [
					{"text": "Down past the meat locker, the air goes blue with smoke and worse."},
					{"text": "Green felt. <b>Red</b> chips. A dealer who smiles like a closing door."},
					{"text": "He bets the rent. Then the car. Then his father's watch."},
					{"text": "The cards turn cold. The house just breathes in, slow."},
				],
			},
			{
				"title": "THE LOSS", "ground": 0.82, "key_light": {"x": 0.5, "y": 0.3}, "rain_vol": 0.16,
				"backdrop": {"type": "room", "wall": "#05060a", "wall_top": "#090b10", "door": 0.62},
				"lights": [
					{"type": "bulb", "x": 0.45, "y": 0.30, "intensity": 0.8, "flicker": true, "par": 0.2},
				],
				"cast": [
					{"type": "slotMachine", "x": 0.08, "scale": 0.85, "par": 0.2},
					{"type": "dealer", "x": 0.45, "scale": 0.95},
					{"type": "cardTable", "x": 0.45, "scale": 1.05, "glow": false},
					{"type": "trenchMan", "x": 0.74, "scale": 0.97, "par": 0.2},
					{"type": "boss", "x": 0.92, "scale": 0.95, "par": 0.2},
				],
				"script": [
					{"text": "Cleaned out. Pockets full of lint and a marker he can't cover."},
					{"text": "The boss gives him till dawn. The boss is being <b>generous</b>."},
					{"text": "No system beats a debt with your name carved in it."},
					{"text": "Danny walks out owing more than he's worth. Which isn't much."},
				],
			},
			{
				"title": "THE ACCIDENT", "ground": 0.8, "key_light": {"x": 0.5, "y": 0.3}, "rain_vol": 0.16,
				"backdrop": {"type": "alley", "seed": 44021},
				"lights": [
					{"type": "bulb", "x": 0.5, "y": 0.3, "intensity": 1, "flicker": true, "par": 0.3},
					{"type": "neon", "x": 0.47, "y": 0.42, "w": 52, "h": 22, "color": Color("ff0018"), "label": "EAT", "seed": 3.3, "par": 0.3},
				],
				"cast": [
					{"type": "steam", "x": 0.40, "seed": 0.9},
					{"type": "barrelFire", "x": 0.88, "scale": 0.85, "par": 0.5},
					{"type": "fireHydrant", "x": 0.06, "par": 0.5},
					{"type": "cat", "x": 0.14, "par": 0.5},
					{"type": "newspaper", "x": 0, "seed": 2.1},
					{"type": "gunman", "x": 0.34, "scale": 1, "par": 0.5, "hide_on_flag": "blood"},
					{"type": "knife", "x": 0.40, "y": 0.84, "angle": 0.2, "bloody": true, "on_flag": "blood"},
					{"type": "bodyOnGround", "x": 0.34, "scale": 1, "par": 0.5, "on_flag": "blood"},
					{"type": "bloodSplat", "x": 0.40, "on_flag": "blood", "seed": 7},
					{"type": "trenchMan", "x": 0.72, "scale": 1, "par": 0.5},
				],
				"script": [
					{"text": "A collector trails him into the alley. Knuckles, bad teeth, worse intentions."},
					{"text": "They go for the same gun. It only answers to one of them.", "fx": ["muzzle", "blood", "lightning"]},
					{"text": "The collector folds like a cheap hand. Danny didn't mean it. Doesn't matter."},
					{"text": "He's not a gambler anymore. He's a <b>killer</b> with nowhere left to run."},
				],
			},
			{
				"title": "THE RECKONING", "ground": 0.8, "key_light": {"x": 0.7, "y": 0.4}, "rain_vol": 0.16,
				"backdrop": {
					"type": "skyline", "seed": 90218,
					"layers": [
						{"depth": 0.3, "top": 0.20, "shade": "#0c0e13", "min_w": 60, "max_w": 140, "min_h": 0.34, "max_h": 0.66, "win": 0.10},
						{"depth": 0.6, "top": 0.30, "shade": "#070809", "min_w": 90, "max_w": 180, "min_h": 0.40, "max_h": 0.78, "win": 0.14},
						{"depth": 1.0, "top": 0.42, "shade": "#020203", "min_w": 120, "max_w": 250, "min_h": 0.46, "max_h": 0.94, "win": 0.18},
					],
				},
				"lights": [
					{"type": "lamp", "x": 0.50, "intensity": 1, "flicker": true, "par": 0.5},
					{"type": "neon", "x": 0.78, "y": 0.30, "w": 90, "h": 30, "color": Color("ff0018"), "label": "DEAD END", "seed": 5.5},
				],
				"cast": [
					{"type": "steam", "x": 0.55, "seed": 1.1},
					{"type": "gunman", "x": 0.66, "scale": 1, "par": 0.5},
					{"type": "thug", "x": 0.84, "scale": 1, "par": 0.5},
					{"type": "boss", "x": 0.97, "scale": 0.92, "par": 0.5},
					{"type": "trenchMan", "x": 0.30, "scale": 1, "par": 0.5, "hide_on_flag": "blood"},
					{"type": "bodyOnGround", "x": 0.30, "scale": 1, "par": 0.5, "flip": true, "on_flag": "blood"},
					{"type": "bloodSplat", "x": 0.34, "on_flag": "blood", "seed": 13},
				],
				"script": [
					{"text": "Word travels fast when a made man stops breathing."},
					{"text": "They find him where the rain pools deepest. Three coats, three guns."},
					{"text": "He opens his mouth to deal one last time.", "fx": ["muzzle"]},
					{"text": "The guns answer first. The gutter drinks him down.", "fx": ["muzzle", "blood", "lightning"]},
					{"text": "Basin City balances its books by morning. Danny Cole doesn't even leave a stain."},
				],
			},
		],
	}
