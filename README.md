# Noir

Noir is a noir crime motion comic, a storytelling board where rain soaked stories are
staged and played one beat at a time. You tap through the night, the captions fall like
narration, and the only colour is the colour that bleeds.

It is built natively in [Godot 4.7](https://godotengine.org). Stories are pure data and the
look is shared, so telling a new tale is writing data, not engine code.

## The idea

This is a board for telling noir stories, not a general purpose engine. Every tale is a
plain dictionary: a title, some music, and a list of acts. Each act names a backdrop, the
lights, the cast, and the lines that play over them. The board reads that data and stages
it with real Godot 2D: a global wash, lights and shadows, rain and fog, neon that blooms,
and the colour red where the story bleeds.

Behaviour is data too. A character walks, a sign ignites, a gun fires, blood crawls to the
drain, all expressed as parameters and per line effects rather than new code.

## Stories on the board

- **A Hallucination of Sin City**, three acts: the street, the alley, the rooftop.
- **The Last Deal of Danny Cole**, five acts through the underground casinos of Basin City.

Pick a tale on the start screen, then tap or click to advance. Press `L` for lightning.

## Run it

Open the project in Godot 4.7 (the Mono build) and press play, or from a terminal:

```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . 
```

First open reimports the assets into the local `.godot` folder.

## How a tale is shaped

A story is a dictionary (see `data/HallucinationStory.gd` for a worked example):

```gdscript
{
    "title": ..., "subtitle": ..., "blurb": ...,
    "music": "piano_noir", "music_vol": 0.62,
    "scenes": [
        {
            "title": "THE STREET", "ground": 0.8, "ambience": "street",
            "backdrop": { "type": "skyline", "seed": 1977, "layers": [ ... ] },
            "lights":  [ { "type": "neon", "x": 0.10, "label": "BAR", ... } ],
            "cast":    [ { "type": "trenchMan", "x": 0.34, "light_at": 3 }, ... ],
            "script":  [ { "text": "The night is wet ...", "fx": ["lighter"] }, ... ],
        },
    ],
}
```

`text` accepts simple emphasis, and the words wrapped in `<b>..</b>` print in blood red. A
line's `fx` fires events for that beat (`muzzle`, `blood`, `lightning`, `hammer`, `lighter`).
A cast member can be revealed or hidden by an event with `on_flag` and `hide_on_flag`.

To add a tale, write a data class under `data/`, then list it in `data/StoryLibrary.gd`. No
board changes needed.

## Layout

```
data/                   the tales (pure data) + the story picker list
scenes/
  core/Main.*           the view controller: world, camera, post, flow
  panels/NoirPanel.gd   the board: world layer, additive light buffer, weather
  engine/               the staging model: frame facade, lighting, scene runtime, registry
  library/              the cast, props, lights, backdrops and effects (the art)
  ui/                   start screen, captions and act picker, rotation gate
  fx/                   shared texture helpers
autoload/               Palette, SceneDirector, AudioDirector, Transitions
shaders/                grain, vignette, ink wipe
audio/ fonts/           sound and type
```

## Credits

The stories and the noir look began life in
[Inkfall](https://github.com/masoudqashqai/Inkfall), an HTML canvas storytelling prototype
(see the [live build](https://masoudqashqai.github.io/Inkfall/)), and were rebuilt here as a
native Godot board.
