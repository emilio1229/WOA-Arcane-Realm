@tool
extends Node

enum AudioType { OMNI, TWO_D, THREE_D }

@export var audio_library: AudioLibrary = null
@export var audio_setting_library: AudioSettingLibrary = null

@export var audio_bus: Array[StringName] = [&"Music", &"SFX"]

@export_group("Omni")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var omni_enabled: bool = true
@export_range(0, 10, 1, "or_greater") var max_omni: int = 10

@export_group("2D")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var audio_2d_enabled: bool = false
@export_range(0, 10, 1, "or_greater") var max_2d: int = 10

@export_group("3D")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var audio_3d_enabled: bool = false
@export_range(0, 10, 1, "or_greater") var max_3d: int = 10

var _library_cache: Dictionary = {}
var _active_players: Dictionary = {}
var _current_music_key: StringName = &""
var _current_music_player: Node = null

var _pool_omni: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_initialize_resources()

func _initialize_resources() -> void:
	if not audio_library:
		push_error("Initialization failed: AudioLibrary is missing.")
		return
	
	_cache_library_entries()
	_initialize_pools()

func _cache_library_entries() -> void:
	for entry in audio_library.entries:
		if not entry.key: continue
		_library_cache[entry.key] = entry

func _initialize_pools() -> void:
	if omni_enabled: _build_pool(AudioStreamPlayer, _pool_omni, max_omni)
	if audio_2d_enabled: _build_pool(AudioStreamPlayer2D, _pool_2d, max_2d)
	if audio_3d_enabled: _build_pool(AudioStreamPlayer3D, _pool_3d, max_3d)

func _build_pool(type: Variant, pool: Array, count: int) -> void:
	for i in count:
		var player = type.new()
		add_child(player)
		pool.append(player)

func is_playing(key: StringName) -> bool:
	var instances = _active_players.get(key, [])
	
	if instances.is_empty():
		return false

	for player in instances:
		if is_instance_valid(player) and player.is_playing():
			return true
			
	return false

func play_sfx_once(key: StringName, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	if is_playing(key):
		return
	_execute_play(key, AudioType.OMNI, audio_bus[1], null, volume, pitch, false, audio_setting_index)

func play_sfx(key: StringName, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.OMNI, audio_bus[1], null, volume, pitch, false, audio_setting_index)

func play_sfx_2d(key: StringName, pos: Vector2, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.TWO_D, audio_bus[1], pos, volume, pitch, false, audio_setting_index)

func play_sfx_3d(key: StringName, pos: Vector3, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.THREE_D, audio_bus[1], pos, volume, pitch, false, audio_setting_index)

func play_music(key: StringName, loop: bool = true, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.OMNI, audio_bus[0], null, volume, pitch, loop, audio_setting_index)

func play_music_2d(key: StringName, pos: Vector2, loop: bool = true, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.TWO_D, audio_bus[0], pos, volume, pitch, loop, audio_setting_index)

func play_music_3d(key: StringName, pos: Vector3, loop: bool = true, volume: float = 0.0, pitch: float = 1.0, audio_setting_index: int = -1) -> void:
	_execute_play(key, AudioType.THREE_D, audio_bus[0], pos, volume, pitch, loop, audio_setting_index)

func _execute_play(key: StringName, type: AudioType, bus: StringName, pos: Variant, volume: float = 0.0, pitch: float = 1.0, loop: bool = false, audio_setting_index: int = -1) -> void:
	if bus == audio_bus[0] and _current_music_key == key:
		#print("Music already playing: ", key)
		return

	var entry = _library_cache.get(key)
	if not entry:
		push_error("Audio key not found: %s" % key)
		return

	var stream_data = _load_stream_from_entry(entry)
	if stream_data == null:
		push_error("Failed to load audio for key: %s" % key)
		return

	if bus == audio_bus[0]:
		stop_music()

	var player = _request_available_player(type)
	if not player:
		push_error("No player found for AudioType: %s" % type)
		return

	_setup_player_properties(player, stream_data, volume, pitch, bus)
	_apply_optional_settings(player, audio_setting_index)
	_apply_stream_settings(player, loop, pos)
	_track_active_instance(key, player)

	if bus == audio_bus[0]:
		_current_music_key = key
		_current_music_player = player

	player.play()

func _load_stream_from_entry(entry: Resource) -> AudioStream:
	if not entry.path:
		push_error("No path for audio entry")
		return null
		
	var stream = ResourceLoader.load(entry.path)
	if not stream:
		push_error("Failed to load audio at: %s" % entry.path)
		return null
		
	return stream

func _setup_player_properties(player: Node, stream: AudioStream, volume: float, pitch: float, bus: StringName) -> void:
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.bus = bus

func _apply_optional_settings(player: Node, setting_index: int) -> void:
	if setting_index < 0: return
	if not audio_setting_library: return
	if audio_setting_library.entries.is_empty(): return
	
	var settings = audio_setting_library.entries[setting_index]
	_apply_audio_settings(player, settings)

func _apply_audio_settings(player: Node, settings: AudioSetting) -> void:
	if player.has_meta("mix_target"):
		player.mix_target = settings.mix_target

	if player.has_meta("max_polyphony"):
		player.max_polyphony = settings.max_polyphony

	if player.has_meta("playback_type"):
		player.playback_type = settings.playback_type

	if player.has_meta("panning_strength"):
		player.panning_strength = settings.panning_strength

	if player is AudioStreamPlayer2D:
		player.attenuation = settings.attenuation
		player.max_distance = settings.max_distance_2d
		player.area_mask = settings.area_mask_2d

	if player is AudioStreamPlayer3D:
		player.attenuation_model = settings.attenuation_model
		player.unit_size = settings.unit_size
		player.max_db = settings.max_db
		player.max_distance = settings.max_distance_3d
		player.area_mask = settings.area_mask_3d
		player.emission_angle_enabled = settings.emission_angle_enabled
		player.emission_angle_degrees = settings.emission_angle_degrees
		player.emission_angle_filter_attenuation_db = settings.emission_angle_filter_attenuation_db
		player.attenuation_filter_cutoff_hz = settings.attenuation_filter_cutoff_hz
		player.attenuation_filter_db = settings.attenuation_filter_db
		player.doppler_tracking = settings.doppler_tracking

func _apply_stream_settings(player: Node, loop: bool, pos: Variant) -> void:
	var s = player.stream
	if s is AudioStreamWAV:
		s.loop_mode = loop
	elif s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = loop

	if player is AudioStreamPlayer2D:
		player.global_position = pos
	elif player is AudioStreamPlayer3D:
		player.global_position = pos

func _request_available_player(type: AudioType) -> Node:
	var pool = _get_pool_by_type(type)
	if pool.is_empty():
		#print("Pool is empty for type: ", type)
		return null

	for i in pool.size():
		if not pool[i].is_playing():
			var p = pool.pop_at(i)
			pool.append(p)
			return p

	var oldest = pool.pop_front()
	#print("Pool full, stopping oldest player.")
	oldest.stop()
	pool.append(oldest)
	return oldest

func _get_pool_by_type(type: AudioType) -> Array:
	if type == AudioType.TWO_D: return _pool_2d
	if type == AudioType.THREE_D: return _pool_3d
	return _pool_omni

func _track_active_instance(key: StringName, player: Node) -> void:
	var list = _active_players.get(key, [])
	if player not in list:
		list.append(player)
		_active_players[key] = list

func stop_music() -> void:
	if _current_music_player and is_instance_valid(_current_music_player):
		_current_music_player.stop()
		#print("Stopped music: ", _current_music_key)
	_current_music_key = &""
	_current_music_player = null

func stop_by_key(key: StringName) -> void:
	var instances = _active_players.get(key, [])
	for player in instances:
		if is_instance_valid(player):
			player.stop()
	_active_players.erase(key)
	
	if key == _current_music_key:
		_current_music_key = &""
		_current_music_player = null

func stop_all_active() -> void:
	for pool in [_pool_omni, _pool_2d, _pool_3d]:
		for player in pool:
			if is_instance_valid(player):
				player.stop()
	_active_players.clear()
	_current_music_key = &""
	_current_music_player = null
	#print("Stopped all active audio.")
