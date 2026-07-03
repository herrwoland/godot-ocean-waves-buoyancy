extends Area3D
## Placed on a ship's deck. Walking into this area hands helm control
## (throttle/rudder) to `ship`, and moves the player camera to `helm_marker`
## for the duration.

@export var ship: Node
@export var helm_marker: Node3D

func interact(player: Node) -> void:
	_enter(player)

func _on_body_entered(body: Node3D) -> void:
	_enter(body)

func _enter(body: Node) -> void:
	if body.has_method(&'enter_pilot'):
		body.enter_pilot(ship, helm_marker)
