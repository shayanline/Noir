class_name RotationGate
extends Control
## The landscape prompt. On a touch device held in portrait, starting a story raises a full screen
## gate that offers ROTATE TO LANDSCAPE (fullscreen plus orientation lock where possible) or STAY IN
## PORTRAIT (plays letterboxed). Turning the phone by hand while the prompt is up clears it at once.
## On desktop or when already landscape the gate never appears. After the gate has been passed once,
## returning to portrait mid story is non blocking (it just letterboxes), matching the legacy
## Inkfall behaviour.

## Emitted when the gate unblocks (landscape reached or portrait accepted), so the flow can start.
signal unblocked

const SKIP_DELAY := 4.0  ## seconds before STAY IN PORTRAIT appears on no fullscreen devices

@onready var _bg: ColorRect = $BG
@onready var _center: CenterContainer = $Center
@onready var _phone: Control = $Center/VBox/PhoneIcon
@onready var _msg_fs: Label = $Center/VBox/MessageFS
@onready var _msg_nofs: Label = $Center/VBox/MessageNoFS
@onready var _btn_rotate: Button = $Center/VBox/BtnRotate
@onready var _btn_skip: Button = $Center/VBox/BtnSkip

var _is_touch := false
var _gate_passed := false
var _gate_blocked := false
var _skip_timer: SceneTreeTimer


func _ready() -> void:
	_is_touch = DisplayServer.is_touchscreen_available()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_rotate.pressed.connect(_on_rotate_pressed)
	_btn_skip.pressed.connect(_on_skip_pressed)
	get_viewport().size_changed.connect(_schedule_evaluate)


## Called when a story begins. If the device is in landscape already and can fullscreen, slip into
## fullscreen silently. Otherwise evaluate whether the gate should block.
func begin_story() -> void:
	_gate_passed = false
	_gate_blocked = false
	if _is_touch and _can_fullscreen() and _is_landscape():
		_enter_fullscreen()
		_evaluate()
	else:
		_evaluate()


## Reset all flags when returning to the start screen so the gate runs fresh on the next story.
func reset() -> void:
	_gate_passed = false
	_gate_blocked = false
	_clear_skip_timer()
	_hide_overlay()


## Whether the gate is currently blocking the story.
func is_blocked() -> bool:
	return _gate_blocked


# --- detection helpers -----------------------------------------------------------------

func _is_landscape() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.x >= s.y


func _can_fullscreen() -> bool:
	# Godot can enter fullscreen on any platform via DisplayServer. On iOS (where the legacy project
	# could not fullscreen the canvas) the orientation lock and fullscreen still work natively, so
	# we always allow it on touch devices. The no fullscreen path is kept for web exports where the
	# API may be unavailable.
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("!!(document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen)", true)
	return true


# --- flow ------------------------------------------------------------------------------

func _schedule_evaluate() -> void:
	# Defer one frame so the viewport size is settled after a resize.
	_evaluate.call_deferred()


func _evaluate() -> void:
	if _is_landscape():
		_gate_passed = true
	_gate_blocked = _is_touch and not _gate_passed and not _is_landscape()
	if _gate_blocked:
		_show_overlay()
	else:
		_hide_overlay()


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
		# On devices that cannot fullscreen (web on iOS), delay the skip button so the viewer is
		# nudged to rotate first.
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
	unblocked.emit()


func _clear_skip_timer() -> void:
	if _skip_timer and _skip_timer.time_left > 0:
		# SceneTreeTimers cannot be cancelled, but disconnecting the callback is enough.
		if _skip_timer.timeout.get_connections().size() > 0:
			for c in _skip_timer.timeout.get_connections():
				_skip_timer.timeout.disconnect(c.callable)
	_skip_timer = null


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
