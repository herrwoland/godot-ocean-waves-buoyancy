extends Area3D
## Debug pickup/delivery point (Milestone 1). Later the pickup becomes an
## underwater package and the delivery a staged hand-off.

enum Kind { PICKUP, DELIVERY }

@export var kind: Kind = Kind.PICKUP

func set_active(active: bool) -> void:
	visible = active
	set_deferred(&'monitorable', active)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred(&'disabled', not active)

func interact(_player: Node) -> void:
	var note_view: CanvasLayer = get_tree().get_first_node_in_group(&'note_view')
	if kind == Kind.PICKUP:
		if GameState.phase == GameState.Phase.HAS_LETTER:
			note_view.show_note("The marker groans against its chain.\n\nWhatever it marks is below.\nDive.")
		elif GameState.phase == GameState.Phase.WAKE:
			note_view.show_note("A rusted marker bobs in the swell.\n\nWithout instructions it means nothing.\n(Read the letter first.)")
	else:
		if GameState.phase == GameState.Phase.PICKED_UP:
			note_view.show_note("This is the place.\n\nBring the package here and set it down.")
		#else:
			#note_view.show_note("There is nothing to leave here yet.")
