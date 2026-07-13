extends Node
## Carries one Carryable at the CarrySocket marker in front of the camera.
## The single rule (enforced in player._try_interact): interacting with a
## carryable picks it up; interacting while holding anything drops it.
## Move/tilt the CarrySocket marker in the editor to adjust where held items
## sit — bring it closer to make paper readable.

@export var player: CharacterBody3D
@export var socket: Node3D

const FOLLOW_STIFFNESS := 18.0 # higher = snappier follow

var carried: RigidBody3D = null

func _ready() -> void:
	add_to_group(&'carry_controller')

func is_carrying() -> bool:
	return carried != null

func pick_up(item: RigidBody3D) -> void:
	if carried:
		drop()
	carried = item
	item.on_picked_up()

func drop() -> void:
	if not carried:
		return
	carried.on_dropped(player.velocity * 0.8)
	carried = null

func reset_day() -> void:
	carried = null # items themselves are restaged by the mission controller

func _physics_process(delta: float) -> void:
	if not carried:
		return
	# Smoothly chase the socket; exponential decay keeps it framerate-stable.
	var weight := 1.0 - exp(-FOLLOW_STIFFNESS * delta)
	carried.global_transform = carried.global_transform.interpolate_with(socket.global_transform, weight)
