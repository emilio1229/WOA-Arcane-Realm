@tool
extends Resource
class_name AudioSettingLibrary

var _entries_data: Array = []

@export_custom(PROPERTY_HINT_ARRAY_TYPE, "AudioSetting")
var entries: Array:
	get:
		return _entries_data
	set(value):
		_on_entries_set(value)

func _on_entries_set(value: Array) -> void:
	var new_array: Array = []

	for item in value:
		if item is AudioSetting:
			new_array.append(item)

		else:
			new_array.append(AudioSetting.new())

	_entries_data = new_array
