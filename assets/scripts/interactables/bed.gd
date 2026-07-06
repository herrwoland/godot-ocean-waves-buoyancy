extends Area3D
## Sleeping is the only save point, and only allowed once the day's delivery
## is done and the player has returned home.

func interact(_player: Node) -> void:
	if GameState.phase == GameState.Phase.CAN_SLEEP:
		get_tree().get_first_node_in_group(&'mission_controller').do_sleep()
	else:
		var note_view: CanvasLayer = get_tree().get_first_node_in_group(&'note_view')
		note_view.show_note("I can't sleep.\n\nThe delivery isn't finished.")
