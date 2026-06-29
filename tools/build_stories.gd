extends SceneTree
## One time generator: builds the typed Story / Act / Line / Placement resources from the source
## tale data and saves them as .tres under res://stories, plus the library.tres the start screen
## reads. Run headless with:
##   Godot --path . --headless --script res://tools/build_stories.gd
## The .tres files are the source of truth after this, so this tool is only for regenerating them.

const SCENES := {
	"skyline": "res://scenes/backdrops/Skyline.tscn",
	"alley": "res://scenes/backdrops/Alley.tscn",
	"rooftop": "res://scenes/backdrops/Rooftop.tscn",
	"room": "res://scenes/backdrops/Room.tscn",
	"lamp": "res://scenes/lights/Lamp.tscn",
	"neon": "res://scenes/lights/Neon.tscn",
	"bulb": "res://scenes/lights/Bulb.tscn",
	"trenchMan": "res://scenes/actors/TrenchMan.tscn",
	"gunman": "res://scenes/actors/Gunman.tscn",
	"boss": "res://scenes/actors/Boss.tscn",
	"thug": "res://scenes/actors/Thug.tscn",
	"dealer": "res://scenes/actors/Dealer.tscn",
	"womanInRed": "res://scenes/actors/WomanInRed.tscn",
	"cat": "res://scenes/actors/Cat.tscn",
	"crow": "res://scenes/actors/Crow.tscn",
	"steam": "res://scenes/effects/Steam.tscn",
	"searchlight": "res://scenes/effects/Searchlight.tscn",
	"newspaper": "res://scenes/effects/Newspaper.tscn",
	"bodyOnGround": "res://scenes/effects/BodyOnGround.tscn",
	"bloodSplat": "res://scenes/effects/BloodSplat.tscn",
	"bloodDrain": "res://scenes/effects/BloodDrain.tscn",
	"redCar": "res://scenes/props/RedCar.tscn",
	"trafficLight": "res://scenes/props/TrafficLight.tscn",
	"dumpster": "res://scenes/props/Dumpster.tscn",
	"manhole": "res://scenes/props/Manhole.tscn",
	"waterTower": "res://scenes/props/WaterTower.tscn",
	"barrelFire": "res://scenes/props/BarrelFire.tscn",
	"fireHydrant": "res://scenes/props/FireHydrant.tscn",
	"rouletteWheel": "res://scenes/props/RouletteWheel.tscn",
	"slotMachine": "res://scenes/props/SlotMachine.tscn",
	"cardTable": "res://scenes/props/CardTable.tscn",
	"cash": "res://scenes/props/Cash.tscn",
	"drink": "res://scenes/props/Drink.tscn",
	"knife": "res://scenes/props/Knife.tscn",
}


func _init() -> void:
	var hall := _to_story(_hallucination())
	var danny := _to_story(_danny())
	ResourceSaver.save(hall, "res://stories/hallucination.tres")
	ResourceSaver.save(danny, "res://stories/danny_cole.tres")
	var lib := StoryLibrary.new()
	lib.stories.append(hall)
	lib.stories.append(danny)
	ResourceSaver.save(lib, "res://stories/library.tres")
	print("Built stories: ", hall.acts.size(), " + ", danny.acts.size(), " acts")
	quit()


func _to_story(d: Dictionary) -> Story:
	var s := Story.new()
	s.title = d.get("title", "")
	s.subtitle = d.get("subtitle", "")
	s.blurb = d.get("blurb", "")
	s.picker_name = d.get("picker_name", "")
	s.picker_tagline = d.get("picker_tagline", "")
	s.music = d.get("music", "")
	s.music_vol = d.get("music_vol", 0.5)
	for sc in d.get("scenes", []):
		s.acts.append(_to_act(sc))
	return s


func _to_act(sc: Dictionary) -> Act:
	var a := Act.new()
	a.title = sc.get("title", "")
	a.ground = sc.get("ground", 0.8)
	var kl: Dictionary = sc.get("key_light", {"x": 0.3, "y": 0.3})
	a.key_light = Vector2(kl["x"], kl["y"])
	if sc.has("moon"):
		a.has_moon = true
		var m: Dictionary = sc["moon"]
		a.moon = Vector2(m["x"], m["y"])
	var bd = sc.get("backdrop", null)
	if bd:
		a.backdrop = _placement(bd)
	a.indoor = sc.get("indoor", bd != null and bd.get("type", "") == "room")
	a.blood_rain = sc.get("blood_rain", false)
	a.ambience = sc.get("ambience", "")
	a.ambience_vol = sc.get("ambience_vol", 0.4)
	a.rain_vol = sc.get("rain_vol", 0.16)
	for l in sc.get("lights", []):
		a.lights.append(_placement(l))
	for p in sc.get("cast", []):
		a.cast.append(_placement(p))
	for ln in sc.get("script", []):
		a.lines.append(_line(ln))
	return a


func _placement(d: Dictionary) -> Placement:
	var pl := Placement.new()
	pl.scene = load(SCENES[d["type"]])
	pl.params = d
	return pl


func _line(d: Dictionary) -> Line:
	var ln := Line.new()
	ln.text = d.get("text", "")
	ln.fx = PackedStringArray(d.get("fx", []))
	return ln


func _hallucination() -> Dictionary:
	return {
		"title": "INKFALL",
		"subtitle": "A HALLUCINATION OF SIN CITY",
		"blurb": "It always rains in Basin City. The whole town is black and white, except the things that bleed. Tap through the long, wet night.",
		"picker_name": "STORY 0",
		"picker_tagline": "A HALLUCINATION",
		"music": "piano_noir",
		"music_vol": 0.62,
		"scenes": [
			{
				"title": "THE STREET", "ground": 0.8, "key_light": {"x": 0.30, "y": 0.5}, "moon": {"x": 0.78, "y": 0.18},
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
					{"type": "neon", "x": 0.40, "y": 0.48, "w": 120, "h": 30, "color": Color("ff0018"), "label": "GIRLS", "seed": 2.7, "par": 0.4, "dropout": true},
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


func _danny() -> Dictionary:
	return {
		"title": "INKFALL",
		"subtitle": "THE LAST DEAL OF DANNY COLE",
		"blurb": "A small man with a big debt goes looking for easy money in the underground casinos of Basin City. The house always wins. Tap through his last bad night.",
		"picker_name": "STORY 1",
		"picker_tagline": "THE LAST DEAL OF DANNY COLE",
		"music": "sad_jazz",
		"music_vol": 0.5,
		"scenes": [
			{
				"title": "THE ITCH", "ground": 0.8, "key_light": {"x": 0.3, "y": 0.5}, "moon": {"x": 0.78, "y": 0.18}, "ambience": "street", "ambience_vol": 0.4, "rain_vol": 0.16,
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
				"title": "THE ACCIDENT", "ground": 0.8, "key_light": {"x": 0.5, "y": 0.3}, "moon": {"x": 0.78, "y": 0.18}, "rain_vol": 0.16,
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
				"title": "THE RECKONING", "ground": 0.8, "key_light": {"x": 0.7, "y": 0.4}, "moon": {"x": 0.78, "y": 0.18}, "rain_vol": 0.16,
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
