# NOIR, board operating guide

A noir crime motion comic told on a storytelling board, built natively in Godot 4.7. Stories are
pure data and the look is shared, so telling a new tale is writing data, not board code. This is a
board for staging noir stories, not a general purpose engine.

## Run

- Editor: open this folder in Godot 4.7 and press play. First open reimports assets into the
  gitignored `.godot/` folder.
- Play from a terminal: `Godot --path .` (use the Godot 4.7 binary on your machine).
- No test suite. A fast headless check that catches script parse and load errors without a window:
  `Godot --headless --quit-after 120` and read the output for errors. Headless skips rendering, so
  for anything visual run it windowed and look at it.

## Map

```
project.godot          config, display (1280x720, landscape), input actions, autoloads
data/                  the tales (pure data) + the picker list
  HallucinationStory.gd  "A Hallucination of Sin City" (a worked example of the story shape)
  DannyColeStory.gd      "The Last Deal of Danny Cole"
  StoryLibrary.gd        the tales shown on the start screen picker
autoload/              globals
  SceneDirector.gd       the flow + data model (loaded story, current act + line). Never draws.
  Palette.gd             the fixed art direction (grayscale plus the colours that bleed) + timing
  AudioDirector.gd       looping beds (music, ambience, rain) crossfade, pooled duckable one-shots
  Transitions.gd/.tscn   ink wipe, act title card, the end card
scenes/
  core/Main.*            the view controller: world, post FX, camera, UI, then drives the flow
  panels/NoirPanel.gd    the board: a world layer, an additive light buffer, weather, the update loop
  engine/                the staging model (the native equal of Inkfall's engine + render)
    NoirFrame.gd           per-frame facade: a canvas like draw API + coordinate/lighting helpers
    NoirLight.gd           the one shared light + shadow service (records, tint, reflections, shadow)
    NoirScene.gd           one act: flags, current line, timing, cast, shells, ripples, draw passes
    NoirObject.gd          base for everything placed in a scene (transform + params + hooks)
    NoirBackdrop.gd        base for a backdrop (build geometry once, paint each frame)
    NoirRegistry.gd        name to class map for objects and backdrops
    NoirMath.gd            seeded PRNG (mulberry32) + easings + curve sampling
    NoirPath.gd            a tiny move_to/line_to/quad_to path builder
    NoirSoft.gd            pre-built soft glow sprites (radial, ring, column)
    NoirShells.gd          ejected brass casings (scene owned)
    NoirRipples.gd         wet floor ripples on the light layer (scene owned)
  library/               the art, by category, registered through NoirLibrary
    NoirLibrary.gd         register_all: pulls every group into the registry
    NoirShared.gd          shared sub drawings + materials (ember, smoke, fedora, pistol, rim, body)
    NoirBackdrops.gd       skyline, alley, rooftop, room
    NoirLights.gd          lamp, neon, bulb, glow
    NoirActors.gd          trenchMan, thug, boss, gunman, womanInRed, dealer, singer, cat, crow
    NoirProps.gd           redCar, casino, street and weapon props
    NoirEffects.gd         steam, searchlight, newspaper, the blood set
  ui/                    StartScreen (title + tale picker), Hud (captions, scene tag, nav), RotationGate
  fx/FXUtil.gd          shared procedural texture helpers
shaders/                post (grain, vignette), ink_wipe (the transition)
audio/ fonts/           sound and type
```

## Render model (how a frame is drawn)

`NoirPanel` holds three stacked canvases and rebuilds the lights each frame, then repaints:

1. world layer (normal blend): sky + moon, the back layer, the backdrop, the light fixtures, then
   the cast in depth order, plus brass and ground shadows.
2. additive light buffer: every light's surface + air glow, the wet floor reflections, the deferred
   glow accents the cast emitted during the world pass, and the ripples.
3. weather (over the lit scene): rain coloured by the light each drop falls through, the lightning
   flash and bolt.

`NoirFrame` is the facade handed to every draw. Solid draws go to the world layer. Additive draws
(`glow_*`) are deferred during the world pass and replayed on the light buffer, so the look
composites like the original Inkfall additive buffer. Lighting, tint and shadow all read the same
light records, which keeps the whole cast lit from the same sources.

## Object + story contract

A library type is a small class extending `NoirObject` (or `NoirBackdrop`), registered by name in
its group. Inside the hooks `self` is the placed instance (its story params) and `f` is the frame:

- `emit_light(f)` registers lights with `f.add_light({...})`. Runs before any draw each frame.
- `draw(f)` paints to the world layer with `f.fill_poly`, `f.circle`, `f.ellipse_fill`,
  `f.fill_poly_grad`, the `glow_*` family, and so on. Use `f.x_of(self)`, `f.scale_of(self)`,
  `f.walk_x(self)`, `f.beat()`, `f.line_idx`, `f.flags`, `f.lit_tint(x)`, `f.ground_shadow(...)`.
- `update(dt, f)` advances any simulation state.
- Reveal or hide by event with `on_flag` / `hide_on_flag` (flags are set by a line's `fx`).

A story is a Dictionary: `title`, `subtitle`, `blurb`, `music`, `music_vol`, and `scenes`. Each
scene has `title`, `ground`, optional `key_light` / `moon` / `indoor` / `blood_rain`, audio
(`ambience`, `ambience_vol`, `rain_vol`), a `backdrop` (`{type, ...}`), `lights` and `cast` (each
names a `type` plus params), and a `script` of lines `{ "text": ..., "fx": [...] }`. `text` accepts
simple emphasis, `<b>..</b>` prints in blood red, and `fx` fires `muzzle`, `blood`, `lightning`,
`hammer` or `lighter` for that beat. See `data/HallucinationStory.gd` for a worked example.

## Extending

- New object: add a class to the matching `library/Noir*.gd`, register it in that group's
  `register`, and place it in a story by name. New behaviour is data (params + `fx` + flags), not
  board edits.
- New backdrop: add a `NoirBackdrop` subclass and register it in `NoirBackdrops.register`.
- New tale: write a data class under `data/`, then add it to `data/StoryLibrary.gd`. No board change.
- Restyle everything: `autoload/Palette.gd` (palette + timing), `engine/NoirLight.gd` (the light
  model), `shaders/post.gdshader` (the screen finish).

## Conventions

- GDScript style: tabs for indentation, typed vars and returns where the surrounding code already
  is, `##` doc comments on scripts and public methods, `_private` for internals. Read a neighbouring
  script before adding one.
- Stories are pure data, behaviour is data. Lighting, shadows and the global wash go through the
  shared `NoirFrame` + `NoirLight` + `Palette`. Do not hand roll per object lighting, that is what
  keeps the look uniform.
- The frame's transform stack mirrors canvas `save` / `translate` / `rotate` / `scale`. Use it
  rather than reaching for Godot transforms inside a draw.

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

- Work on a branch off `master`, in a dedicated git worktree, never directly in the shared
  checkout. Name branches by intent, for example `fix/mobile-flicker` or `feat/clip-system`.
- Open a pull request into `master` for review, then merge once it looks good. Keep each change
  focused so it is easy to review.
- Commits are authored under the maintainer's name only, with no AI or bot co-author trailers.
- Do not push or merge unless asked. Never force push or rewrite shared history, and never resolve a
  merge conflict without checking first.
