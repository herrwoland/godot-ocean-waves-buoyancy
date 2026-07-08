extends Node3D
## Spawns the giant swimming creatures. Most drift in slow orbits around the
## player's area of the sea; when the player dives past hunt_depth, the
## nearest few turn hunter and close in. Contact kills (player_died).
## Bodies come from creature_scene (creatures/hunter_fish.tscn placeholder) —
## edit that scene or point creature_scene at another to change their look.

const HUNTER_SCENE := preload("res://assets/models/creatures/hunter_fish.tscn")

@export var creature_scene: PackedScene
@export var player: Node3D
@export var water: Node
@export var creature_count: int = 6
@export var hunter_count: int = 2
@export var hunt_depth: float = 3.0 # player depth (m below surface) that triggers hunting
@export var hunt_speed: float = 4.0 # fallback when the creature scene has no hunt_speed of its own
@export var kill_distance: float = 2.2
@export var orbit_speed: float = 0.06
## No hunting inside this zone (the Isle of the Dead — the eel rules there).
@export var hunt_exclusion_center: Vector3 = Vector3(260, 0, -260)
@export var hunt_exclusion_radius: float = 60.0

const SHORE_X_LIMIT := -85.0 # keep creatures out of the cove's shallows

var _creatures: Array[Node3D] = []
var _orbit_radius: Array[float] = []
var _orbit_depth: Array[float] = []
var _orbit_phase: Array[float] = []
var _kill_cooldown := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var scene := creature_scene if creature_scene else HUNTER_SCENE
	for i in creature_count:
		var creature: Node3D = scene.instantiate()
		add_child(creature)
		_creatures.append(creature)
		_orbit_radius.append(rng.randf_range(40.0, 130.0))
		_orbit_depth.append(rng.randf_range(-22.0, -7.0))
		_orbit_phase.append(rng.randf_range(0.0, TAU))
	EventBus.day_started.connect(func(_d: int) -> void: _kill_cooldown = 3.0)

func _physics_process(delta: float) -> void:
	_kill_cooldown = maxf(_kill_cooldown - delta, 0.0)
	var surface_y: float = water.get_wave_height(player.global_position)
	var player_depth: float = surface_y - player.global_position.y
	var in_exclusion := Vector2(player.global_position.x - hunt_exclusion_center.x,
		player.global_position.z - hunt_exclusion_center.z).length() < hunt_exclusion_radius
	var hunting: bool = player_depth > hunt_depth and not in_exclusion

	var time := Time.get_ticks_msec() / 1000.0
	for i in _creatures.size():
		var creature := _creatures[i]
		if hunting and i < hunter_count:
			var speed: float = creature.hunt_speed if &'hunt_speed' in creature else hunt_speed
			var to_player := player.global_position - creature.global_position
			if to_player.length() > 0.5:
				creature.global_position += to_player.normalized() * speed * delta
				if absf(to_player.normalized().dot(Vector3.UP)) < 0.98:
					creature.look_at(player.global_position, Vector3.UP)
			if to_player.length() < kill_distance and _kill_cooldown <= 0.0:
				_kill_cooldown = 5.0
				EventBus.player_died.emit()
		else:
			# Slow orbit around the player's patch of sea, always below the waves.
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
				creature.look_at(creature.global_position + step, Vector3.UP)
