extends Area3D
## The morning letter. First read advances WAKE -> HAS_LETTER; it stays
## readable all day (it is the paper you carry, until Milestone 2's
## inspection system replaces this).

var note_text: String = ""

func interact(_player: Node) -> void:
	if GameState.phase == GameState.Phase.WAKE:
		GameState.set_phase(GameState.Phase.HAS_LETTER)
		EventBus.letter_read.emit()
	var note_view: CanvasLayer = get_tree().get_first_node_in_group(&'note_view')
	note_view.show_note(note_text)
