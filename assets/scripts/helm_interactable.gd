extends Area3D
## Placed on a ship's deck. Interacting hands helm control (throttle/rudder) to
## `ship`, and moves the player camera to `helm_marker` for the duration.

@export var ship: Node
@export var helm_marker: Node3D

func interact(player: Node) -> void:
	if player.has_method(&'enter_pilot'):
		player.enter_pilot(ship, helm_marker)
		print("entering ship control")


func _on_body_entered(body: Node3D) -> void:
	print("entered")
