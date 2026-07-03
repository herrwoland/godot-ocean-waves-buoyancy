extends Area3D
## Placed on a ship's deck. Pressing the interact key while looking at this
## area hands helm control (throttle/rudder) to `ship`, and moves the player
## camera to `helm_marker` for the duration.

@export var ship: Node
@export var helm_marker: Node3D
@export var highlight_mesh: MeshInstance3D # visual (eg. the wheel) to outline when targeted

var highlight_material := preload("res://assets/scripts/interact_highlight_material.tres")

func interact(player: Node) -> void:
	if player.has_method(&'enter_pilot'):
		player.enter_pilot(ship, helm_marker)

func set_highlighted(on: bool) -> void:
	if highlight_mesh:
		highlight_mesh.material_overlay = highlight_material if on else null
