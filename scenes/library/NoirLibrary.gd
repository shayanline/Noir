class_name NoirLibrary
extends RefCounted
## Registering this populates the registry with every backdrop, light, actor, mover, prop and
## effect, the native equal of Inkfall's library/index.js side effect imports. Add a type to its
## group; from then on every story can place it by name.


static func register_all(reg: NoirRegistry) -> void:
	NoirBackdrops.register(reg)
	NoirLights.register(reg)
	NoirActors.register(reg)
	NoirProps.register(reg)
	NoirEffects.register(reg)
