extends Node
## Persistent campaign state (autoload). The game saves ONLY when the player
## sleeps (DESIGN.md §4). Death re-enters the saved morning.

enum Phase { WAKE, HAS_LETTER, PICKED_UP, DELIVERED, CAN_SLEEP }

const SAVE_PATH := "user://save.cfg"
const FINAL_DAY := 5

var current_day: int = 1
var phase: Phase = Phase.WAKE

func _ready() -> void:
	load_game()

func set_phase(new_phase: Phase) -> void:
	phase = new_phase

## Emits day_started so the mission controller (re)stages the world.
func start_day() -> void:
	phase = Phase.WAKE
	EventBus.day_started.emit(current_day)

## Advance to the next morning and persist. Called from the bed, via sleep.
func sleep_advance() -> void:
	current_day = mini(current_day + 1, FINAL_DAY)
	save_game()

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "day", current_day)
	config.save(SAVE_PATH)

func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # first run
	current_day = clampi(config.get_value("progress", "day", 1), 1, FINAL_DAY)
