class_name RotationGate
extends Control
## The landscape prompt, a faithful port of the legacy Inkfall viewport.js gate.
##
## On a touch device held in portrait, pressing ENTER raises a full screen prompt that offers
## ROTATE TO LANDSCAPE (fullscreen plus orientation lock where possible) or STAY IN PORTRAIT
## (plays letterboxed). Turning the phone by hand while the prompt is up clears it at once.
## On desktop or when already landscape the gate never appears. After the gate has been passed
## once, returning to portrait mid story is non blocking (it just letterboxes), matching the
## legacy Inkfall behaviour.
##
## Key differences from a naive implementation:
##   - experienceStarted guard: resize and orientation events are ignored until begin_story().
##   - storyStarted flag: the started signal fires exactly once per story, never on later resizes.
##   - 220ms settle debounce: orientation and fullscreen changes fire event bursts, so we wait
##     220ms after the last event before judging, matching the legacy scheduleEvaluate.

## Emitted once when the gate clears and the story should begin playing (the opening sequence).
## Fires exactly once per story, never again on later orientation changes.
signal started

const SKIP_DELAY := 3.0  ## seconds before STAY IN PORTRAIT appears on no fullscreen devices
const SETTLE_MS := 220   ## debounce: wait this long after the last resize before judging

@onready var _msg_fs: Label = $Center/VBox/MessageFS
@onready var _msg_nofs: Label = $Center/VBox/MessageNoFS
@onready var _btn_rotate: Button = $Center/VBox/BtnRotate
@onready var _btn_skip: Button = $Center/VBox/BtnSkip
@onready var _phone_icon: Control = $Center/VBox/PhoneIcon
@onready var _vbox: VBoxContainer = $Center/VBox

var _is_touch := false
var _experience_started := false  ## ENTER pressed, a story is on its way in
var _story_started := false       ## started signal has fired (the play clock is live)
var _gate_passed := false         ## landscape reached (button or by hand), or portrait accepted
var _gate_blocked := false        ## the landscape prompt is up right now
var _skip_timer: SceneTreeTimer
var _settle_timer: SceneTreeTimer


func _ready() -> void:
	_is_touch = DisplayServer.is_touchscreen_available()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_rotate.pressed.connect(_on_rotate_pressed)
	_btn_skip.pressed.connect(_on_skip_pressed)
	get_viewport().size_changed.connect(_schedule_evaluate)
	UIScale.scale_changed.connect(_rescale)
	_rescale()


## Called when a story begins (ENTER pressed). If the device is in landscape already and can
## fullscreen, slip into fullscreen silently. Otherwise evaluate() raises the landscape prompt
## and the viewer chooses ROTATE TO LANDSCAPE or STAY IN PORTRAIT.
func begin_story() -> void:
	_experience_started = true
	_story_started = false
	_gate_passed = false
	_gate_blocked = false
	if _is_touch and _can_fullscreen() and _is_landscape():
		_enter_fullscreen()
	_evaluate()


## Back to the start screen: reset the gate so it runs fresh on the next story.
func reset() -> void:
	_experience_started = false
	_story_started = false
	_gate_passed = false
	_gate_blocked = false
	_clear_skip_timer()
	_clear_settle_timer()
	_hide_overlay()


## Whether the gate is currently blocking the story.
func is_blocked() -> bool:
	return _gate_blocked


# --- detection helpers -----------------------------------------------------------------

func _is_landscape() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.x >= s.y


func _can_fullscreen() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("!!(document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen)", true)
	return true


# --- flow ------------------------------------------------------------------------------

## Orientation and fullscreen changes can fire a burst of events, so settle briefly before
## judging. This matches the legacy's scheduleEvaluate (220ms setTimeout).
func _schedule_evaluate() -> void:
	if not _experience_started:
		return
	_clear_settle_timer()
	_settle_timer = get_tree().create_timer(SETTLE_MS / 1000.0, true, false, true)
	_settle_timer.timeout.connect(_evaluate)


func _evaluate() -> void:
	if not _experience_started:
		return
	if _is_landscape():
		_gate_passed = true
	_gate_blocked = _is_touch and not _gate_passed and not _is_landscape()
	if _gate_blocked:
		_show_overlay()
	else:
		_hide_overlay()
		if not _story_started:
			_story_started = true
			started.emit()
	_clear_settle_timer()


func _show_overlay() -> void:
	var no_fs := not _can_fullscreen()
	_msg_fs.visible = not no_fs
	_msg_nofs.visible = no_fs
	_btn_rotate.visible = not no_fs
	if visible:
		return
	visible = true
	_btn_skip.visible = false
	_clear_skip_timer()
	if no_fs:
		_skip_timer = get_tree().create_timer(SKIP_DELAY, true, false, true)
		_skip_timer.timeout.connect(func(): _btn_skip.visible = true)
	else:
		_btn_skip.visible = true
	_apply_pause(true)


func _hide_overlay() -> void:
	if not visible:
		return
	visible = false
	_clear_skip_timer()
	_apply_pause(false)


func _clear_skip_timer() -> void:
	if _skip_timer and _skip_timer.time_left > 0:
		for c in _skip_timer.timeout.get_connections():
			_skip_timer.timeout.disconnect(c.callable)
	_skip_timer = null


func _clear_settle_timer() -> void:
	if _settle_timer and _settle_timer.time_left > 0:
		for c in _settle_timer.timeout.get_connections():
			_settle_timer.timeout.disconnect(c.callable)
	_settle_timer = null


func _apply_pause(p: bool) -> void:
	get_tree().paused = p
	AudioDirector.set_suspended(p)


# --- button handlers -------------------------------------------------------------------

func _on_rotate_pressed() -> void:
	_enter_fullscreen()
	_gate_passed = true
	_evaluate()


func _on_skip_pressed() -> void:
	_gate_passed = true
	_evaluate()


func _enter_fullscreen() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(()=>{}) } catch(e) {}", true)


## Apply responsive font and layout sizes from UIScale.
func _rescale() -> void:
	_msg_fs.add_theme_font_size_override("font_size", UIScale.fs_sub)
	_msg_nofs.add_theme_font_size_override("font_size", UIScale.fs_body)
	_btn_rotate.add_theme_font_size_override("font_size", UIScale.fs_menu)
	_btn_skip.add_theme_font_size_override("font_size", UIScale.fs_menu)
	# scale the phone icon proportionally
	var icon_sz := clampf(UIScale.vmin * 0.12, 64.0 * UIScale.dpr, 118.0 * UIScale.dpr)
	_phone_icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
	_vbox.add_theme_constant_override("separation", roundi(UIScale.vmin * 0.03))
	# gate button padding. Duplicate from the theme base (not the resolved stylebox, which is our
	# own override after the first pass) so the dpr scaled border width and corner radius stay current.
	for btn in [_btn_rotate, _btn_skip]:
		for state in ["normal", "hover", "pressed"]:
			var sb: StyleBox = ThemeDB.get_project_theme().get_stylebox(state, btn.theme_type_variation)
			if sb is StyleBoxFlat:
				var dup := sb.duplicate() as StyleBoxFlat
				dup.content_margin_left = UIScale.gate_pad_h
				dup.content_margin_right = UIScale.gate_pad_h
				dup.content_margin_top = UIScale.gate_pad_v
				dup.content_margin_bottom = UIScale.gate_pad_v
				btn.add_theme_stylebox_override(state, dup)
