extends RigidBody3D
## A physical item the player can pick up, carry in front of the camera and
## drop anywhere (Amnesia-style). Reading happens by simply holding it close
## (Firewatch-style) — no inspection mode. Pairs with the player's
## CarryController; the one interaction rule lives there.
##
## While carried the body is frozen (kinematic) and its collision disabled,
## following the CarrySocket. Dropping restores physics and inherits the
## player's motion, so a letter left on the deck sails with the ship.

enum MissionRole { NONE, LETTER }

@export var item_name: String = ""
@export var mission_role: MissionRole = MissionRole.NONE

var carried := false
var _picked_once := false
var _highlight_material: StandardMaterial3D

func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Give the mesh its own material copy so highlighting never leaks to others.
	var mesh_instance: MeshInstance3D = get_node_or_null(^'Mesh')
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		_highlight_material = mesh_instance.get_surface_override_material(0).duplicate()
		mesh_instance.set_surface_override_material(0, _highlight_material)

## Crosshair hover feedback (called by the player's hover system).
func set_highlighted(on: bool) -> void:
	if _highlight_material:
		_highlight_material.emission_enabled = on
		_highlight_material.emission = Color(1.0, 0.95, 0.7)
		_highlight_material.emission_energy_multiplier = 0.4

func interact(_player: Node) -> void:
	get_tree().get_first_node_in_group(&'carry_controller').pick_up(self)

func on_picked_up() -> void:
	carried = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	set_highlighted(false)
	if not _picked_once:
		_picked_once = true
		if mission_role == MissionRole.LETTER and GameState.phase == GameState.Phase.WAKE:
			GameState.set_phase(GameState.Phase.HAS_LETTER)
			EventBus.letter_read.emit()

func on_dropped(inherited_velocity: Vector3) -> void:
	carried = false
	freeze = false
	collision_layer = 0b101 # world + interactable
	collision_mask = 0b1 # collide with the world (shore, deck)
	linear_velocity = inherited_velocity
	angular_velocity = Vector3.ZERO
	sleeping = false

## Puts the item back into the world for a new morning.
func restage(world_parent: Node, world_position: Vector3) -> void:
	var controller: Node = get_tree().get_first_node_in_group(&'carry_controller')
	if controller and controller.carried == self:
		controller.carried = null
	on_dropped(Vector3.ZERO)
	_picked_once = false
	if get_parent() != world_parent:
		reparent(world_parent)
	global_transform = Transform3D(Basis.IDENTITY, world_position)
	visible = true

func set_label_text(text: String) -> void:
	if has_node(^'ItemLabel'):
		get_node(^'ItemLabel').text = text
