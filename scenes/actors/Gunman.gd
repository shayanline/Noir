class_name Gunman
extends BoardObject
## The shooter. A near black fedora silhouette with one arm that swings up a pistol at raise_at.

const REST_ANG := 1.366
const RAISE_ANG := 0.142

var _raise_at := -1


func on_object_params(p: Dictionary) -> void:
	super(p)
	if p.has("raise_at") and p["raise_at"] != null:
		_raise_at = int(p["raise_at"])


func on_line(idx: int) -> void:
	super(idx)
	var arm := $ArmPivot as Node2D
	if _raise_at < 0:
		arm.rotation = RAISE_ANG
		return
	if idx < _raise_at:
		arm.rotation = REST_ANG
	elif idx == _raise_at:
		var tw := create_tween()
		tw.tween_property(arm, "rotation", RAISE_ANG, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		arm.rotation = RAISE_ANG


func on_fx(event: String) -> void:
	super(event)
	if event == "muzzle":
		# A real white-gold flash at the barrel tip; it lights the shooter and the wall for an instant.
		var muzzle := to_local(($ArmPivot/Gun as Node2D).to_global(Vector2(18, 0)))
		emit_flash(muzzle, LightKit.MUZZLE, 3.6, 260.0)
