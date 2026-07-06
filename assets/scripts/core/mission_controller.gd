extends Node
## Stages each day: resets player/ship, positions the mission points from the
## current DayConfig and reacts to mission events. Milestone 1 uses in-code
## placeholder day data; real content moves to DayConfig .tres files later.

const DayConfig := preload("res://assets/scripts/core/day_config.gd")
const CoordinateSystem := preload("res://assets/scripts/core/coordinate_system.gd")

@export var player: Node3D
@export var ferry: RigidBody3D
@export var player_spawn: Node3D
@export var letter_point: Node3D
@export var pickup_point: Node3D
@export var delivery_point: Node3D
@export var package: Node3D
@export var note_view: CanvasLayer
@export var sleep_fade: ColorRect

const PACKAGE_DEPTH := 6.0 # how far below the surface packages rest
const LETTER_HOME := Vector3(-129.4, 3.3, 10)

var days: Array[DayConfig] = []
var _ferry_start: Transform3D

func _ready() -> void:
	add_to_group(&'mission_controller')
	_build_placeholder_days()
	_ferry_start = ferry.global_transform
	EventBus.package_picked_up.connect(_on_package_picked_up)
	EventBus.package_delivered.connect(_on_package_delivered)
	EventBus.day_started.connect(_on_day_started)
	GameState.start_day.call_deferred()

func _config() -> DayConfig:
	return days[clampi(GameState.current_day, 1, days.size()) - 1]

func _on_day_started(_day: int) -> void:
	var cfg := _config()

	# Reset actors to their morning positions.
	player.global_position = player_spawn.global_position
	player.velocity = Vector3.ZERO
	player.state = 0 # State.WALK
	ferry.global_transform = _ferry_start
	ferry.linear_velocity = Vector3.ZERO
	ferry.angular_velocity = Vector3.ZERO

	# Nothing is carried on a new morning.
	get_tree().get_first_node_in_group(&'inspection_controller').reset_day()

	# Stage the mission props. The letter carries the pickup coordinates; the
	# package rests below the surface marker and carries the delivery ones.
	letter_point.restage(get_parent(), LETTER_HOME)
	letter_point.set_label_text("%s\n\nPickup:\n%s" % [cfg.letter_text, CoordinateSystem.format_position(cfg.pickup_position)])
	package.restage(get_parent(), cfg.pickup_position + Vector3.DOWN * PACKAGE_DEPTH)
	package.set_label_text("DELIVER TO:\n%s" % CoordinateSystem.format_position(cfg.delivery_position))
	pickup_point.global_position = cfg.pickup_position
	pickup_point.set_active(true)
	delivery_point.global_position = cfg.delivery_position
	delivery_point.set_active(true)

func _on_package_picked_up() -> void:
	pickup_point.set_active(false)

func _on_package_delivered() -> void:
	delivery_point.set_active(false)
	get_tree().get_first_node_in_group(&'inspection_controller').consume(package)
	note_view.show_note("It is out of your hands now.\n\nGo home.")

## Called by the bed. Fades out, advances the day (final day: placeholder end),
## saves, then fades back into the next morning.
func do_sleep() -> void:
	var tween := create_tween()
	tween.tween_property(sleep_fade, "modulate:a", 1.0, 1.2)
	tween.tween_callback(_advance_after_fade)
	tween.tween_interval(0.6)
	tween.tween_property(sleep_fade, "modulate:a", 0.0, 1.2)

func _advance_after_fade() -> void:
	if GameState.current_day >= GameState.FINAL_DAY:
		note_view.show_note("The fifth night.\n\nSomething is waiting on the shore.\n\n(End of the skeleton loop — the ending arrives in Milestone 7. Day 5 repeats.)")
	else:
		GameState.sleep_advance()
	GameState.start_day()

func _build_placeholder_days() -> void:
	var texts: Array[String] = [
		"A letter, damp at the corners.\n\n\"The first one is close. Bring it before dark.\"",
		"The handwriting is worse today.\n\n\"They are waiting. Do not open the crate.\"",
		"No greeting this time.\n\n\"You were seen. Deliver it anyway.\"",
		"The paper smells of low tide.\n\n\"The island. The well. Bring what sleeps at the bottom.\"",
		"The letter is addressed to you.\n\n\"Come home.\"",
	]
	var pickups: Array[Vector3] = [
		Vector3(150, 0, 60),
		Vector3(220, 0, -120),
		Vector3(320, 0, 180),
		Vector3(260, 0, -260),
		Vector3(180, 0, 20),
	]
	var deliveries: Array[Vector3] = [
		Vector3(40, 0, -160),
		Vector3(-40, 0, 240),
		Vector3(400, 0, -40),
		Vector3(60, 0, 320),
		Vector3(-112, 1, 12), # day 5: home
	]
	for i in 5:
		var cfg := DayConfig.new()
		cfg.day = i + 1
		cfg.letter_text = texts[i]
		cfg.pickup_position = pickups[i]
		cfg.delivery_position = deliveries[i]
		days.append(cfg)
