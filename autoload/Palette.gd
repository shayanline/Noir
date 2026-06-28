extends Node
## The fixed art direction: grayscale plus the colours that bleed, and the global
## timing knobs. Change a value here and the whole look shifts. Mirrors the idea of
## Inkfall's palette.js + ANIM, but native to Godot.

# --- colours ---
const INK := Color("020203")
const NEAR_INK := Color("050506")
const MID_INK := Color("070809")
const FAR_INK := Color("0c0e13")
const BG := Color("050505")

const PAPER := Color("f5f2e8")
const BONE := Color("d8d4c8")
const STEEL := Color("aab4c8")

const RED := Color("c8000f")
const RED_HOT := Color("e10010")
const EMBER := Color("ff2010")
const AMBER := Color("ffd400")

const MOON := Color("e8edf6")
const SKY_TOP := Color("04050a")
const SKY_MID := Color("0a0c12")
const SKY_LOW := Color("16181f")

const WARM_WIN := Color(1.0, 0.925, 0.769, 0.9)
const COOL_WIN := Color(0.792, 0.863, 1.0, 0.72)

# --- timing + intensities ---
const SWAY_SPEED := 1.1
const WALK_SPEED := 2.2
const EMBER_SPEED := 6.0
const FLICKER_SPEED := 9.0

const RAIN_ALPHA := 0.35
const GRAIN_ALPHA := 0.05
const VIGNETTE := 0.7
const PARALLAX_LERP := 0.08

const TRANS_IN := 0.7        # ink wipe close duration (s)
const TRANS_OUT := 0.8       # ink wipe open duration (s)
const CARD_FADE := 0.3       # title card fade in and fade out duration (s), same both ways
const CARD_OVERLAP := 0.0    # how much the outgoing and incoming card fades overlap (0 = sequential, 1 = fully simultaneous)
const CARD_HOLD := 2.0       # act-card dwell (s)
const OPEN_CARD_HOLD := 2.0  # the first act card (right after the story title)
const TITLE_HOLD := 2.5      # opening story-title card dwell (s)
const BEAT_FADE := 0.7       # caption beat crossfade (s)
