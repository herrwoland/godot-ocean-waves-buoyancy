extends "res://assets/scripts/mass_calculation.gd"
## Root of the standalone ferry scene. The physics rig — buoyant cells, the
## hull drag volume and the collider — is invisible and must never be touched
## when changing the ship's look. Swap models by replacing the placeholders
## under the three visual sockets instead: ShipModel, WheelModel and the
## StairsModel node inside each ladder.
## The water node lives in the main scene, so it cannot be referenced from
## inside this scene file: the instance passes it in and we hand it to every
## buoyant cell here before the physics starts.

@export var water: Node

func _ready() -> void:
	for cell in buoyant_cells:
		cell.water = water
	super._ready()
