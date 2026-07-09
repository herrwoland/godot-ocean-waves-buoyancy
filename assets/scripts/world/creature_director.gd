extends Node3D
## Spawns the giant swimming creatures. Most drift in slow orbits far below the
## player's area of the sea; when the player dives past hunt_depth, the
## nearest few turn hunter: they stage directly beneath the player, then strike
## upward out of the dark, jaws open. A catch is not an instant death — the
## jaws clamp shut and the player is dragged into the deep for carry_time
## seconds before player_died fires and the day restages.
## Bodies come from creature_scene (creatures/hunter_fish.tscn placeholder) —
## edit that scene or point creature_scene at another to change their look.

const HUNTER_SCENE := preload("res://assets/models/creatures/hunter_fish.tscn")

@export var creature_scene: PackedScene
@export var player: Node3D
@export var water: Node
@export var creature_count: int = 6
@export var hunter_count: int = 2
@export var hunt_depth: float = 3.0 # player depth (m below surface) that triggers hunting
@export var hunt_speed: float = 9.0 # fallback when the creature scene has no hunt_speed of its own
@export var kill_distance: float = 12.0 # fallback when the creature scene has no kill_distance
@export var ambush_depth: float = 40.0 # hunters stage this far below the player before striking
@export var carry_time: float = 10.0 # seconds the catch is dragged down before the day resets
@export var orbit_speed: float = 0.06
## No hunting inside this zone (the Isle of the Dead — the eel rules there).
@export var hunt_exclusion_center: Vector3 = Vector3(260, 0, -260)
@export var hunt_exclusion_radius: float = 60.0

const SHORE_X_LIMIT := -85.0 # keep creatures out of the cove's shallows

var _creatures: Array[Node3D] = []
var _orbit_radius: Array[float] = []
var _orbit_depth: Array[float] = []
var _orbit_phase: Array[float] = []
var _staged: Array[bool] = [] # hunter has reached its ambush point below the player
var _was_hunting: Array[bool] = []
var _kill_cooldown := 0.0
var _carrier: Node3D = null # the creature currently dragging the player down
var _carry_left := 0.0
var _died_emitted := false

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var scene := creature_scene if creature_scene else HUNTER_SCENE
	for i in creature_count:
		var creature: Node3D = scene.instantiate()
		add_child(creature)
		_creatures.append(creature)
		_orbit_radius.append(rng.randf_range(40.0, 130.0))
		_orbit_depth.append(rng.randf_range(-75.0, -40.0)) # deep enough to hide a 160 m body
		_orbit_phase.append(rng.randf_range(0.0, TAU))
		_staged.append(false)
		_was_hunting.append(false)
	EventBus.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
	_kill_cooldown = 3.0
	_carrier = null # the fade has passed; the morning restage frees the player
	if player.has_method(&'set_captured'):
		player.set_captured(false)

func _physics_process(delta: float) -> void:
	_kill_cooldown = maxf(_kill_cooldown - delta, 0.0)
	var surface_y: float = water.get_wave_height(player.global_position)
	var player_depth: float = surface_y - player.global_position.y
	var in_exclusion := Vector2(player.global_position.x - hunt_exclusion_center.x,
		player.global_position.z - hunt_exclusion_center.z).length() < hunt_exclusion_radius
	var hunting: bool = player_depth > hunt_depth and not in_exclusion and _carrier == null

	var time := Time.get_ticks_msec() / 1000.0
	for i in _creatures.size():
		var creature := _creatures[i]
		if creature == _carrier:
			_process_carry(creature, delta)
			continue
		var is_hunter: bool = hunting and i < hunter_count
		if is_hunter != _was_hunting[i]:
			_was_hunting[i] = is_hunter
			_staged[i] = false
			if creature.has_method(&'set_jaw_open'):
				creature.set_jaw_open(is_hunter)
		if is_hunter:
			_process_hunt(creature, i, delta)
		else:
			# Slow orbit around the player's patch of sea, far below the waves.
			var angle := time * orbit_speed + _orbit_phase[i]
			var target := Vector3(
				player.global_position.x + cos(angle) * _orbit_radius[i],
				_orbit_depth[i],
				player.global_position.z + sin(angle) * _orbit_radius[i]
			)
			target.x = maxf(target.x, SHORE_X_LIMIT)
			var step := target - creature.global_position
			creature.global_position += step * minf(delta * 0.8, 1.0)
			if step.length() > 0.1:
				_face(creature, creature.global_position + step)

## Stage beneath the player first, then rise mouth-first out of the dark.
func _process_hunt(creature: Node3D, i: int, delta: float) -> void:
	var speed: float = creature.hunt_speed if &'hunt_speed' in creature else hunt_speed
	var target := player.global_position
	if not _staged[i]:
		target += Vector3.DOWN * ambush_depth
		if creature.global_position.distance_to(target) < 15.0:
			_staged[i] = true
	var to_target := target - creature.global_position
	if to_target.length() > 0.5:
		creature.global_position += to_target.normalized() * speed * delta
		_face(creature, target)

	var mouth: Vector3 = creature.mouth_position() if creature.has_method(&'mouth_position') else creature.global_position
	var kill_r: float = creature.kill_distance if &'kill_distance' in creature else kill_distance
	var caught: bool = mouth.distance_to(player.global_position) < kill_r \
		or creature.global_position.distance_to(player.global_position) < kill_r
	if caught and _kill_cooldown <= 0.0:
		_begin_carry(creature)

## The bite does not kill outright: the jaws clamp shut and the catch is
## carried down for carry_time seconds — the light fading above — before
## player_died triggers the usual fade and restage.
func _begin_carry(creature: Node3D) -> void:
	_carrier = creature
	_carry_left = carry_time
	_died_emitted = false
	if creature.has_method(&'set_jaw_open'):
		creature.set_jaw_open(false) # clamp down on the catch
	if player.has_method(&'set_captured'):
		player.set_captured(true)

func _process_carry(creature: Node3D, delta: float) -> void:
	# Dive steeply along the current heading, never back toward the shallows.
	var fwd := -creature.global_transform.basis.z
	var horiz := Vector3(fwd.x, 0.0, fwd.z)
	horiz = horiz.normalized() if horiz.length() > 0.05 else Vector3.RIGHT
	if creature.global_position.x < SHORE_X_LIMIT + 40.0:
		horiz = Vector3.RIGHT
	var dive := (horiz * 0.5 + Vector3.DOWN).normalized()
	var speed: float = creature.carry_speed if &'carry_speed' in creature else 8.0
	creature.global_position += dive * speed * delta
	_face(creature, creature.global_position + dive * 10.0)

	# The player rides in the mouth the whole way down.
	player.global_position = creature.mouth_position() if creature.has_method(&'mouth_position') else creature.global_position

	_carry_left -= delta
	if _carry_left <= 0.0 and not _died_emitted:
		_died_emitted = true
		EventBus.player_died.emit() # mission controller fades to black and restages

## look_at that survives near-vertical strikes, where UP is degenerate.
func _face(creature: Node3D, target: Vector3) -> void:
	var dir := (target - creature.global_position).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	creature.look_at(target, up)
