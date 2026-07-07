extends Node3D
## The day-2 scripted scare (DESIGN.md §2): once, and only once, something
## enormous passes beneath the ship — silhouette only, never again. Triggers
## while the player is piloting far from shore, with a low generated rumble.

const HUNTER_SCENE := preload("res://assets/models/creatures/hunter_fish.tscn")

@export var player: Node3D
@export var trigger_x: float = 60.0 # how far out at sea before it can happen
@export var scale_factor: float = 6.0
@export var pass_depth: float = -9.0
@export var pass_duration: float = 12.0

var _armed := false
var _spent := false
var _rumble: AudioStreamPlayer

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = _make_rumble_stream()
	_rumble.volume_db = -8.0
	add_child(_rumble)

func _on_day_started(day: int) -> void:
	_armed = day == 2 and not _spent

func _physics_process(_delta: float) -> void:
	if not _armed or _spent:
		return
	if player.state != 2: # State.PILOT — only while at the helm, eyes on the sea
		return
	if player.global_position.x < trigger_x:
		return
	_spent = true
	_armed = false
	_run_passing()

func _run_passing() -> void:
	var shape: Node3D = HUNTER_SCENE.instantiate()
	shape.scale = Vector3.ONE * scale_factor
	add_child(shape)

	# Cross beneath the ship, port to starboard, unhurried.
	var ship_pos: Vector3 = player.global_position
	var start := ship_pos + Vector3(0, pass_depth, -70)
	var end := ship_pos + Vector3(25, pass_depth - 4.0, 80)
	shape.global_position = start
	shape.look_at(end, Vector3.UP)

	_rumble.play()
	var tween := create_tween()
	tween.tween_property(shape, "global_position", end, pass_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(shape.queue_free)

## A low sub-rumble swelling and dying, generated in code (no asset).
func _make_rumble_stream() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 6.0
	var frames := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var envelope := sin(PI * t / seconds) # swell in, swell out
		var freq := 34.0 - 6.0 * (t / seconds) # sinking pitch
		var sample := sin(TAU * freq * t) * envelope * 0.9
		sample += sin(TAU * freq * 0.503 * t) * envelope * 0.4
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 18000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
