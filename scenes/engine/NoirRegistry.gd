class_name NoirRegistry
extends RefCounted
## name to class map for every library object and backdrop. A story names a `type`; the scene
## asks the registry to build the matching NoirObject (or NoirBackdrop) with the story params.
## Population is done once by NoirLibrary.register_all, so adding a type touches one place.

var _objects := {}     # name -> GDScript (NoirObject subclass)
var _backdrops := {}   # name -> GDScript (NoirBackdrop subclass)


func register_object(name: String, cls: GDScript) -> void:
	_objects[name] = cls


func register_backdrop(name: String, cls: GDScript) -> void:
	_backdrops[name] = cls


func has_object(name: String) -> bool:
	return _objects.has(name)


func create(type_name: String, params: Dictionary) -> NoirObject:
	if not _objects.has(type_name):
		push_warning("Noir: unknown object type " + type_name)
		return null
	var obj: NoirObject = (_objects[type_name] as GDScript).new()
	obj.type = type_name
	obj.apply_params(params)
	return obj


func create_backdrop(type_name: String, scene_data: Dictionary) -> NoirBackdrop:
	if not _backdrops.has(type_name):
		push_warning("Noir: unknown backdrop " + type_name)
		return null
	var bd: NoirBackdrop = (_backdrops[type_name] as GDScript).new()
	bd.data = scene_data
	return bd
