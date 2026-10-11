@tool
extends Resource
class_name AudioLibrary

var _entries_data: Array = []

@export_dir var audio_dir: String = "":
	set(value):
		audio_dir = value
		_on_audio_dir_set()
		notify_property_list_changed()

@export_custom(PROPERTY_HINT_ARRAY_TYPE, "AudioEntry, AudioStream")
var entries: Array:
	get:
		return _entries_data
	set(value):
		_on_entries_set(value)

func _on_entries_set(value: Array) -> void:
	var new_array: Array = []

	for item in value:
		if item is AudioStream:
			var audio_entry := AudioEntry.new()
			audio_entry.path = item.resource_path
			new_array.append(audio_entry)

		elif item is AudioEntry:
			item.resource_name = item.key
			new_array.append(item)

		else:
			new_array.append(AudioEntry.new())

	_entries_data = new_array

func _on_audio_dir_set() -> void:
	if audio_dir == "" or audio_dir == null:
		return

	var base_path := audio_dir
	if not base_path.begins_with("res://") and not base_path.begins_with("user://"):
		base_path = "res://" + base_path

	if base_path.ends_with("/"):
		base_path = base_path.substr(0, base_path.length() - 1)

	entries.clear()
	_scan_directory_recursive(base_path)

func _scan_directory_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := "%s/%s" % [path, file_name]

		if dir.current_is_dir():
			_scan_directory_recursive(full_path)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in ["wav", "ogg", "mp3", "flac", "opus"]:
				var audio_entry := AudioEntry.new()
				audio_entry.path = full_path
				audio_entry.key = file_name.get_basename()
				audio_entry.resource_name = audio_entry.key
				entries.append(audio_entry)

		file_name = dir.get_next()
	dir.list_dir_end()
