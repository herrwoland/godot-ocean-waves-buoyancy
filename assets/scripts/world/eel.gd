extends Node3D
## The giant eel circling inside the island well (Mario 64 homage, DESIGN.md).
## Lethal only on touch — it never leaves its circle. Place at the well center.
## The visual lives in the Body child (see creatures/eel.tscn): Body is moved
## and steered by this script, so replacement models keep their own rotation.

@export var orbit_radius: float = 2.3
@export var orbit_speed: float = 0.9 # radians/sec
@export var top_y: float = -3.0
@export var bottom_y: float = -14.0
@export var rise_speed: float = 0.12 # how fast it drifts between depths
@export var kill_distance: float = 1.6

@onready var _body: Node3D = $Body

var _kill_cooldown := 0.0

func _physics_process(delta: float) -> void:
	_kill_cooldown = maxf(_kill_cooldown - delta, 0.0)
	var t := Time.get_ticks_msec() / 1000.0
	var angle := t * orbit_speed
	var depth: float = lerpf(bottom_y, top_y, 0.5 + 0.5 * sin(t * rise_speed * TAU))
	_body.position = Vector3(cos(angle) * orbit_radius, depth, sin(angle) * orbit_radius)
	# Face along the direction of travel (tangent to the circle).
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	_body.look_at(_body.global_position + tangent, Vector3.UP)

	var player: Node3D = get_tree().get_first_node_in_group(&'player')
	if player and _kill_cooldown <= 0.0:
		if player.global_position.distance_to(_body.global_position) < kill_distance:
			_kill_cooldown = 5.0
			EventBus.player_died.emit()
