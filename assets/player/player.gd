extends CharacterBody3D
## First person player controller with three states: walking, swimming and
## piloting a ship's helm. Swim state is driven by comparing the player's feet
## height against the wave height sampled from `water`.

enum State { WALK, SWIM, PILOT }

@export var water: Node
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var swim_speed: float = 3.5
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var interact_distance: float = 3.0
@export var swim_enter_depth: float = 0.6 # how deep water must be over the feet before we start swimming
@export var swim_exit_margin: float = 0.15 # how far above water the feet must be, while grounded, to exit swimming

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var collider: CollisionShape3D = $Collider

var state: State = State.WALK
var piloted_ship: Node = null
var helm_marker: Node3D = null

const GRAVITY: float = 9.8

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PILOT and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotation.y -= event.relative.x * mouse_sensitivity
		camera.rotation.x -= event.relative.y * mouse_sensitivity
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)
	elif event.is_action_pressed(&'interact'):
		_try_interact()

func _physics_process(delta: float) -> void:
	match state:
		State.WALK:
			_process_walk(delta)
			_check_enter_swim()
		State.SWIM:
			_process_swim(delta)
			_check_exit_swim()
		State.PILOT:
			_process_pilot(delta)

func _process_walk(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed(&'jump'):
		velocity.y = jump_velocity

	var speed := sprint_speed if Input.is_action_pressed(&'sprint') else walk_speed
	var input_dir := Vector2(
		Input.get_action_strength(&'move_right') - Input.get_action_strength(&'move_left'),
		Input.get_action_strength(&'move_back') - Input.get_action_strength(&'move_forward')
	).normalized()
	var move_dir := (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	move_and_slide()

func _process_swim(delta: float) -> void:
	var surface_y: float = water.get_wave_height(global_position)
	var target_y: float = surface_y - 0.4 # swim with head roughly at the surface

	var input_dir := Vector2(
		Input.get_action_strength(&'move_right') - Input.get_action_strength(&'move_left'),
		Input.get_action_strength(&'move_back') - Input.get_action_strength(&'move_forward')
	).normalized()
	var move_dir := head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()

	var vertical := Input.get_action_strength(&'swim_up') - Input.get_action_strength(&'swim_down')

	velocity.x = move_dir.x * swim_speed
	velocity.z = move_dir.z * swim_speed
	# Gentle spring back toward the surface, plus manual vertical control.
	velocity.y = clampf((target_y - global_position.y) * 2.0, -swim_speed, swim_speed) + vertical * swim_speed

	move_and_slide()

func _process_pilot(delta: float) -> void:
	if not is_instance_valid(helm_marker):
		exit_pilot()
		return

	global_position = helm_marker.global_position
	velocity = Vector3.ZERO

	var throttle := Input.get_action_strength(&'move_forward') - Input.get_action_strength(&'move_back')
	var rudder := Input.get_action_strength(&'move_right') - Input.get_action_strength(&'move_left')
	if piloted_ship and piloted_ship.has_method(&'set_helm_input'):
		piloted_ship.set_helm_input(throttle, rudder)

	if Input.is_action_just_pressed(&'interact'):
		exit_pilot()

func _check_enter_swim() -> void:
	if not water:
		return
	var surface_y: float = water.get_wave_height(global_position)
	if surface_y - global_position.y > swim_enter_depth:
		state = State.SWIM
		collider.disabled = false

func _check_exit_swim() -> void:
	if not water:
		return
	var surface_y: float = water.get_wave_height(global_position)
	if is_on_floor() and surface_y - global_position.y < -swim_exit_margin:
		state = State.WALK

func _try_interact() -> void:
	if state == State.PILOT:
		exit_pilot()
		return
	if not interact_ray.is_colliding():
		return
	var target := interact_ray.get_collider()
	if target and target.has_method(&'interact'):
		target.interact(self)

func enter_pilot(ship: Node, marker: Node3D) -> void:
	state = State.PILOT
	piloted_ship = ship
	helm_marker = marker
	collider.disabled = true
	velocity = Vector3.ZERO
	if ship.has_method(&'set_piloted'):
		ship.set_piloted(true)

func exit_pilot() -> void:
	if piloted_ship and piloted_ship.has_method(&'set_piloted'):
		piloted_ship.set_piloted(false)
	if is_instance_valid(helm_marker):
		global_position = helm_marker.global_position + helm_marker.global_transform.basis.y * 0.1
	state = State.WALK
	piloted_ship = null
	helm_marker = null
	collider.disabled = false
