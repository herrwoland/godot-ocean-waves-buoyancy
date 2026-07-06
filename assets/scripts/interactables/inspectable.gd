extends Area3D
## An item that can be picked up and inspected (RE-style hold-to-inspect).
## Text lives ON the item (Label3D children) — no HUD. Mission-relevant items
## advance the day phase the first time they are inspected.

enum MissionRole { NONE, LETTER, PACKAGE }

@export var item_name: String = ""
@export var mission_role: MissionRole = MissionRole.NONE
@export var carry_on_inspect: bool = true

var _inspected_once := false

func interact(_player: Node) -> void:
	get_tree().get_first_node_in_group(&'inspection_controller').begin_inspect(self)

## Called by the InspectionController the moment inspection starts.
func notify_inspected() -> void:
	if _inspected_once:
		return
	_inspected_once = true
	match mission_role:
		MissionRole.LETTER:
			if GameState.phase == GameState.Phase.WAKE:
				GameState.set_phase(GameState.Phase.HAS_LETTER)
				EventBus.letter_read.emit()
		MissionRole.PACKAGE:
			if GameState.phase <= GameState.Phase.HAS_LETTER:
				GameState.set_phase(GameState.Phase.PICKED_UP)
				EventBus.package_picked_up.emit()

func set_label_text(text: String) -> void:
	if has_node(^'ItemLabel'):
		get_node(^'ItemLabel').text = text

func set_collision_active(active: bool) -> void:
	set_deferred(&'monitorable', active)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred(&'disabled', not active)

## Puts the item back into the world for a new morning.
func restage(world_parent: Node, world_position: Vector3) -> void:
	_inspected_once = false
	if get_parent() != world_parent:
		reparent(world_parent)
	global_transform = Transform3D(Basis.IDENTITY, world_position)
	visible = true
	set_collision_active(true)
