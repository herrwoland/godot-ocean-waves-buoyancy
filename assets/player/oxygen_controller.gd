extends Node
## Breath management with no HUD: running out of air desaturates the screen,
## closes a vignette (oxygen_overlay.gdshader) and raises a heartbeat that
## quickens as things get dire. Hitting zero emits player_died — the mission
## controller restages the same morning.

@export var player: CharacterBody3D
@export var overlay_rect: ColorRect
@export var heartbeat_player: AudioStreamPlayer
@export var max_breath: float = 40.0 # seconds of air — tune survival time here
@export var recover_rate: float = 12.0 # breath regained per second at the surface
@export var flash_start_intensity: float = 0.4 # spent-breath fraction where the red flash begins

var breath: float
var _died := false

func _ready() -> void:
	breath = max_breath
	heartbeat_player.stream = _make_heartbeat_stream()
	EventBus.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
	breath = max_breath
	_died = false

func _process(delta: float) -> void:
	if player._ears_underwater:
		breath = maxf(breath - delta, 0.0)
	else:
		breath = minf(breath + recover_rate * delta, max_breath)

	var intensity := 1.0 - breath / max_breath
	overlay_rect.material.set_shader_parameter(&'intensity', intensity)

	# Drowning flash: kicks in past flash_start_intensity, pulsing 1/s and
	# accelerating to 3/s as the last breath approaches.
	var flash_t := clampf((intensity - flash_start_intensity) / (1.0 - flash_start_intensity), 0.0, 1.0)
	overlay_rect.material.set_shader_parameter(&'flash_amount', flash_t)
	overlay_rect.material.set_shader_parameter(&'flash_rate', lerpf(1.0, 3.0, flash_t))

	# Heartbeat fades in past one third spent breath and quickens toward the end.
	if intensity > 0.3:
		if not heartbeat_player.playing:
			heartbeat_player.play()
		heartbeat_player.volume_db = lerpf(-40.0, -4.0, (intensity - 0.3) / 0.7)
		heartbeat_player.pitch_scale = lerpf(0.85, 1.7, intensity)
	elif heartbeat_player.playing:
		heartbeat_player.stop()

	if breath <= 0.0 and not _died:
		_died = true
		EventBus.player_died.emit()

## Generates a looping two-thump heartbeat entirely in code (no asset needed).
func _make_heartbeat_stream() -> AudioStreamWAV:
	var rate := 22050
	var frames := rate # one second loop
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var envelope := exp(-t * 22.0)
		if t >= 0.24:
			envelope += 0.65 * exp(-(t - 0.24) * 22.0)
		var sample := sin(TAU * 52.0 * t) * envelope
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = frames
	wav.data = data
	return wav
