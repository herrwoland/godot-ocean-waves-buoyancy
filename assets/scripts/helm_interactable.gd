extends Area3D
## Placed on a ship's deck. Pressing the interact key while looking at this
## area hands helm control (throttle/rudder) to `ship`, and moves the player
## camera to `helm_marker` for the duration.

@export var ship: Node
@export var helm_marker: Node3D
@export var highlight_mesh: Node3D # visual (eg. the wheel) to outline when targeted; every mesh under it glows

var highlight_material := preload("res://assets/scripts/interact_highlight_material.tres")

func interact(player: Node) -> void:
	if player.has_method(&'enter_pilot'):
		player.enter_pilot(ship, helm_marker)

## Overlays every MeshInstance3D at or below highlight_mesh, so it works both
## on a single mesh and on an imported model with its own subtree.
func set_highlighted(on: bool) -> void:
	if highlight_mesh == null:
		return
	var meshes := highlight_mesh.find_children("*", "MeshInstance3D", true, false)
	if highlight_mesh is MeshInstance3D:
		meshes.append(highlight_mesh)
	for m in meshes:
		m.material_overlay = highlight_material if on else null
