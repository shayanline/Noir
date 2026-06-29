class_name TrenchMan
extends BoardObject
## The detective. A near black trench coat silhouette in a fedora, drawn in the resting pose and
## lit by the shared rim. He reacts to two story fx with real bursts of light: the struck lighter
## that warms his face from below, and the muzzle flash when the gun goes off.


func on_fx(event: String) -> void:
	super(event)
	match event:
		"lighter":
			# A small warm spark at the cigarette, under-lighting the face the noir way.
			emit_flash(Vector2(4, -100), LightKit.SPARK, 1.8, 95.0)
		"muzzle":
			# The shot lights his hand and the wet street white for an instant.
			emit_flash(Vector2(18, -50), LightKit.MUZZLE, 3.4, 250.0)
