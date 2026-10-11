@tool
extends EditorPlugin

const AUTOLOAD_NAME = "AudioManager"
const AUTOLOAD_PATH = "res://addons/any_audio_manager/AudioManager.tscn"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
