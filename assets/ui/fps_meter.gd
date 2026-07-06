extends Label
## Tiny FPS readout, updated once per frame.

func _process(_delta: float) -> void:
	text = "%d FPS" % Engine.get_frames_per_second()
