@tool
extends Resource
class_name AudioEntry

@export var key: StringName = "":
	set(value):
		key = value
		resource_name = value

@export_file("*.wav", "*.ogg", "*.mp3", "*.flac", "*.opus") var path: String = "":
	set(value):
		path = value
		if key == "" and path:
			if path != "":
				if path.begins_with("uid://"):
					path = ResourceUID.ensure_path(path)
				key = path.get_file().get_basename()
		notify_property_list_changed()
