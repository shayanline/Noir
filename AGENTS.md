# INKFALL, board operating guide

A noir crime motion comic told on a storytelling board, built natively in Godot 4.7. Stories are
typed data and the look is shared, so telling a new tale is writing a resource, not board code. This
is a board for staging noir stories, not a general purpose engine.

The board is a real Godot scene tree: every placed object (a backdrop, a light, a cast member) is a
node scene built from Polygon2D, Line2D, Sprite2D and Label, lit by native 2D lights (PointLight2D
and DirectionalLight2D) over a global CanvasModulate wash, with WorldEnvironment bloom. The nodes
draw themselves and animate themselves with AnimationPlayer (and Tween for data driven motion), so
there is no per frame repaint. The flow is signal driven, and the UI look comes from a shared Theme.

## Run

- Editor: open this folder in Godot 4.7 and press play. First open reimports assets into the
  gitignored `.godot/` folder. The project is pure GDScript, the Mono build runs it fine.
- Play from a terminal: `Godot --path .` (use the Godot 4.7 binary on your machine).
- Headless parse and load check (no window): `Godot --path . --editor --headless --quit` once to build
  the class cache, then `Godot --path . --headless --quit-after 120` and read the output for errors.
- Headless smoke test: `Godot --path . --headless tools/SmokeTest.tscn` builds every act, sets every
  line and fires every fx, printing one OK line per act. Use it to catch runtime errors after a change.
- Headless skips rendering, so for anything visual run it windowed and look at it.

## Map

```
project.godot          config, display (1920x1080 base, canvas_items + expand, landscape),
                       input actions, autoloads
stories/               the tales as resources
  hallucination.tres     "A Hallucination of Sin City" (a worked example of the story shape)
  danny_cole.tres        "The Last Deal of Danny Cole"
  library.tres           the StoryLibrary the start screen picker reads
src/
  resources/             the data types (Resource subclasses)
    Story.gd               title, subtitle, blurb, music, acts
    Act.gd                 look and audio knobs, backdrop, lights, cast, lines
    Line.gd                one beat: text plus fx
    Placement.gd           a scene plus its params (a backdrop, light or cast entry)
    StoryLibrary.gd        the picker list
  util/
    light_radial.tres      shared radial falloff texture for the 2D lights and warm fixtures
    soft_glow.tres         shared soft glow texture for the steam particles
    LightTex.gd            loads and hands out light_radial.tres
    BackdropBaker.gd       bakes the seeded skyline (buildings plus windows) to a texture
themes/
  inkfall_theme.tres     the shared UI theme (fonts, colours, styleboxes, type variations),
                         set as the project default theme in project.godot
autoload/              globals (Transitions.tscn is also registered as an autoload scene)
  GameState.gd           the flow and data model, and the signal source: emits line_changed and
                         fx_fired as the story advances. Never draws.
  Palette.gd             the fixed art direction (grayscale plus the colours that bleed) and timing
  AudioDirector.gd       looping beds (music, ambience, rain) crossfade, pooled duckable one shots
scenes/
  core/Main.*            the view controller. The global look (CanvasModulate wash, WorldEnvironment
                         bloom via Environment.tres, post FX via post_material.tres, Camera2D) is
                         authored in Main.tscn; the script only advances GameState and swaps the Board.
  board/
    Board.gd               the act host: builds the backdrop, lights, cast and weather as nodes and
                           sets up the key and moon lights. Reacts to GameState.line_changed and
                           fx_fired, and fans them out to its objects by signal (plus the
                           board_object group).
    BoardObject.gd         base for everything placed on the board (placement, params, hooks)
  backdrops/            Skyline, Alley, Rooftop, Room (BoardBackdrop) + BoardBackdrop.gd
  lights/              Lamp, Neon, Bulb (BoardLight) + BoardLight.gd (drives a PointLight2D)
  actors/             trenchMan, gunman, boss, thug, dealer, womanInRed, cat, crow
  props/              redCar, trafficLight, dumpster, manhole, waterTower, barrelFire, fireHydrant,
                      rouletteWheel, slotMachine, cardTable, cash, drink, knife
  effects/            steam and searchlight (particles and 2D lights), newspaper, the blood set
                      (bodyOnGround, bloodSplat, bloodDrain), RainField, Lightning
  ui/                 StartScreen (title and tale picker), Hud (captions, scene tag, nav), RotationGate
  transitions/        Transitions (the act flow) + InkWipe (the drawn panel wipe), act card, end card
tools/                build_stories.gd (regenerates the .tres tales), SmokeTest.*
shaders/              post (grain, vignette)
audio/ fonts/         sound and type
```

## Render model (how an act is staged)

`Main` owns the global look, authored in `Main.tscn`: a CanvasModulate wash darkens the whole 2D
canvas, a WorldEnvironment adds additive bloom (Environment.tres), and a post shader lays grain and a
vignette over everything (post_material.tres). For each act it swaps in a `Board`.

`Board` builds the act as a scene tree: it instances the backdrop, the light fixtures and the cast
(each a `Placement.scene`), positions and scales each one, creates the key light and the moon as
PointLight2D nodes from the act, and adds the rain and lightning when the act is outdoor. From then
on the nodes draw, light and animate themselves (AnimationPlayer and Tween), there is no manual
repaint. Lights brighten the grayscale world out of the wash, and the colours that bleed (red, neon,
fire) read where the light reaches.

The flow is signal driven. `GameState` holds the model and emits `line_changed` and `fx_fired`.
`Board` and `Hud` react to those, and `Board` re forwards each beat to its spawned objects through its
own `line_changed` and `fx` signals (every object also joins the `board_object` group). `Main` only
advances `GameState` and orchestrates the transitions and audio.

## Object and story contract

A placed object is a scene whose root script extends `BoardObject` (a Node2D), or `BoardLight` /
`BoardBackdrop` for those families. `Board` calls `setup(params, board)` then `place()` before the
object enters its first frame:

- Art is authored in DESIGN UNITS: y = 0 is the object's base on the ground, up is negative y, x is
  centred on 0. The board scales those units to pixels (about 3x at the 1920x1080 base), so a scene never
  premultiplies by a scale factor.
- `BoardObject` handles placement (`nx`, `ny_units`, `par`, `obj_scale`, `flip`, `depth`, and the
  `anchor` for screen placed signs), the optional walk path (`walk` plus `walk_dur`), and reveal by
  flag (`on_flag` / `hide_on_flag`). A param named `y` screen anchors the object at that height.
- Override `on_object_params(p)` to read any extra params (call `super` first). Override `on_line(idx)`
  and `on_fx(event)` (call `super`) to react to story beats and events, reading `board.line_index`
  and `board.flags`. `Board` fans these to every object by signal.
- Authored motion lives in an `AnimationPlayer` in the scene: a looping animation that autoplays (the
  cat tail, the roulette spin, the searchlight sweep, the barrel flicker) or a triggered one the
  script plays by name (the crow `fly`, the blood drain `grow` driving a normalized `progress`). Use a
  `Tween` for data driven motion (the walk path tweens to each line's target). Keep `on_tick()` only
  for genuinely procedural, random motion that cannot be keyframed (the light flicker, the lightning
  bolt path).
- A light scene is a `BoardLight` containing a `PointLight2D` child, which the base colours, energises
  and flickers from the params.

A story is a `Story` resource: `title`, `subtitle`, `blurb`, `music`, `music_vol`, and `acts`. Each
`Act` has the look knobs (`ground`, `key_light`, `moon`, `indoor`, `blood_rain`), the audio knobs, a
`backdrop` and arrays of `lights` and `cast` (each a `Placement` with a `scene` and a `params`
dictionary), and an array of `lines`. A `Line` has `text` (simple emphasis, `<b>..</b>` prints in
blood red) and `fx` (`muzzle`, `blood`, `lightning`, `hammer`, `lighter`).

## Extending

- New object: add a scene under the matching `scenes/` folder whose root extends `BoardObject` (or
  `BoardLight` / `BoardBackdrop`), then place it in a tale by pointing a `Placement` at it. New
  behaviour is params, fx and flags, not board edits.
- New tale: author a `Story` resource (in the inspector, or extend `tools/build_stories.gd`), then add
  it to `stories/library.tres`. No board change.
- Restyle everything: `autoload/Palette.gd` (palette and timing), the CanvasModulate wash and lights
  in `scenes/core/Main.gd` and `scenes/board/Board.gd`, and `shaders/post.gdshader` (the screen finish).

## Conventions

- GDScript style: tabs for indentation, typed vars and returns where the surrounding code already is,
  `##` doc comments on scripts and public methods, `_private` for internals. Read a neighbouring
  script before adding one.
- Stories are data, behaviour is data. Keep the look centralised: lighting goes through native 2D
  lights over the shared wash, colours come from `Palette`, and the UI look comes from the shared
  `themes/inkfall_theme.tres` (use its type variations, do not add per control theme overrides).
- Do it the Godot way: author geometry as scene nodes, author motion as `AnimationPlayer` animations
  or `Tween`s, and communicate by signal. Do not hand code per frame `sin()` animation, do not push
  state into nodes that could react to a signal, and do not hand roll a lighting model per object.
- Author art in design units in the scene, and let the board place and scale it. Do not bake the
  board scale into coordinates.

## Output rules (apply to ALL written output)

These apply to everything you write in this project: docs, code comments, commit messages, the in
app copy, and the story captions, subtitles and blurbs you write, including the prose inside any
examples. The only place they do not apply is code itself.

1. Never use the em dash or en dash. Use a comma, colon, parentheses, or a full stop. Rewrite the
   sentence if needed.
2. Never hyphenate compound modifiers (write "rain soaked", "read only", "black and white"). Genuine
   identifiers stay as is: code symbols, file names, package names.
3. Never use the semicolon in prose. Use a full stop or a comma, or rewrite. This does not apply to
   code.
4. No bare URLs where links render. Hyperlink a short descriptive phrase, for example
   [the Inkfall prototype](https://github.com/masoudqashqai/Inkfall).

## Git

- Work on a branch off `master`, in a dedicated git worktree, never directly in the shared checkout.
  Name branches by intent, for example `fix/mobile-flicker` or `feat/clip-system`.
- Open a pull request into `master` for review, then merge once it looks good. Keep each change
  focused so it is easy to review.
- Commits are authored under the maintainer's name only, with no AI or bot co-author trailers.
- Do not push or merge unless asked. Never force push or rewrite shared history, and never resolve a
  merge conflict without checking first.
