extends Area3D
## Boarding ladder on the ship's hull: interacting (usually while swimming)
## climbs the player up onto the deck at `deck_point`.

@export var deck_point: Node3D

func interact(player: Node) -> void:
	player.global_position = deck_point.global_position
	player.velocity = Vector3.ZERO
	player.state = 0 # State.WALK
