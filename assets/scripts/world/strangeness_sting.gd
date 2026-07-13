extends Node
## Plays a short, dissonant generated sting whenever the world transforms
## (EventBus.strangeness_triggered). Two detuned low tones beating against
## each other, decaying — barely music, mostly wrongness.

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = _make_sting_stream()
	_player.volume_db = -10.0
	add_child(_player)
	EventBus.strangeness_triggered.connect(_on_strangeness)

func _on_strangeness(_tier: int) -> void:
	_player.play()

func _make_sting_stream() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 3.0
	var frames := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var envelope := exp(-t * 1.6) * minf(t * 30.0, 1.0)
		var sample := sin(TAU * 138.0 * t) * 0.5 + sin(TAU * 143.5 * t) * 0.5
		sample += sin(TAU * 69.0 * t) * 0.3
		data.encode_s16(i * 2, int(clampf(sample * envelope, -1.0, 1.0) * 16000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
