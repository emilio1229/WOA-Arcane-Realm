# log_helper.gd
# Centralized logging utility with timestamp
@tool
class_name LogHelper
extends RefCounted

signal logged(message: String)

static var _instance: LogHelper = null
const LOG_PREFIX := "[Tripo Bridge]"

static func get_instance() -> LogHelper:
	if _instance == null:
		_instance = LogHelper.new()
	return _instance

static func release_instance() -> void:
	_instance = null

static func format_message(message: String) -> String:
	return "%s [%s] %s" % [LOG_PREFIX, Time.get_time_string_from_system(), message]

static func log(message: String, enabled: bool = true) -> void:
	if not enabled:
		return
	var formatted := format_message(message)
	get_instance().emit_signal("logged", formatted)
	print(formatted)

static func error(message: String, enabled: bool = true) -> void:
	LogHelper.log("ERROR: " + message, enabled)

static func warning(message: String, enabled: bool = true) -> void:
	LogHelper.log("WARNING: " + message, enabled)
