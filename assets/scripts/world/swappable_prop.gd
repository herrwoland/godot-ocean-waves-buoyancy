extends Node3D
## A prop that can transform as the player's mind goes (DESIGN.md §2).
## Each direct child is one variant (child 0 = normal, child 1+ = strange
## tiers); apply_variant shows exactly one. Drop replacement models in as
## additional children — no code changes needed.

@export var prop_id: StringName = &""

func _ready() -> void:
	add_to_group(&'swappable_prop')
	apply_variant(0)

func apply_variant(tier: int) -> void:
	var index := clampi(tier, 0, get_child_count() - 1)
	for i in get_child_count():
		var variant := get_child(i)
		variant.visible = i == index
		_set_collision_enabled(variant, i == index)

func _set_collision_enabled(node: Node, enabled: bool) -> void:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		child.set_deferred(&'disabled', not enabled)
