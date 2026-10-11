@tool
extends Resource
class_name AudioSetting

@export var mix_target: AudioStreamPlayer.MixTarget = AudioStreamPlayer.MIX_TARGET_STEREO
@export_range(1, 10, 1, "or_greater") var max_polyphony: int = 1

@export_group("2D")
@export_exp_easing("attenuation", "positive_only") var attenuation: float = 1.0
@export_range(1, 4096, 1, "or_greater", "suffix:px") var max_distance_2d: int = 2000
@export_flags_2d_physics() var area_mask_2d: int = 1

@export_group("3D")
@export var attenuation_model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.AttenuationModel.ATTENUATION_INVERSE_DISTANCE
@export_range(0.1, 100, 0.1, "or_greater") var unit_size: float = 10.0
@export_range(-24.0, 6.0, 0.1, "suffix:db") var max_db: float = 3.0
@export_range(0.0, 4096, 0.01, "or_greater", "suffix:m") var max_distance_3d: float = 0.0
@export_flags_3d_physics() var area_mask_3d: int = 1

@export_subgroup("Emission Angle")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var emission_angle_enabled: bool = false
@export_range(0.1, 90.0, 0.01, "suffix:°") var emission_angle_degrees: float = 45.0
@export_range(-80.0, 0.0, 0.01, "suffix:db") var emission_angle_filter_attenuation_db: float = -12.0

@export_subgroup("Attenuation Filter")
@export_range(1, 20500, 1, "prefer_slider", "suffix:hz") var attenuation_filter_cutoff_hz: int = 5000
@export_range(-80.0, 0.0, 0.1, "suffix:db") var attenuation_filter_db: float = -24.0

@export_subgroup("Doppler")
@export var doppler_tracking: AudioStreamPlayer3D.DopplerTracking = AudioStreamPlayer3D.DopplerTracking.DOPPLER_TRACKING_DISABLED

@export_group("2D & 3D")
@export_range(0.0, 3.0, 0.01, "or_greater") var panning_strength: float = 1.0

@export_group("")
@export var playback_type: AudioServer.PlaybackType = AudioServer.PlaybackType.PLAYBACK_TYPE_DEFAULT
