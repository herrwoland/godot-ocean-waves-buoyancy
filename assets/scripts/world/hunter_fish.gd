extends Node3D
## A deep-water stalker. Idle drifting is driven by the CreatureDirector; when
## told to hunt it sneaks into the player's blind spot from behind and below,
## then hangs there, creeping closer while unseen. The instant the player's
## camera catches any part of it — or they back into the teeth — the jaw swings
## open and it lunges at several times its sneaking speed. A miss peels away
## and re-stalks; a catch is dragged into the deep for carry_time seconds
## before player_died fires and the day restages.
## All tuning lives here as exports so each instance can be balanced in the
## inspector. The model is ~150 m long: distances are mouth-relative.

enum State { LURK, SNEAK, ATTACK, CARRY }

@export_group("Speeds")
@export var cruise_speed := 10.0 # m/s closing in on the stalk point from far away
@export var sneak_speed := 3.0 # m/s for the final quiet approach
@export var attack_speed := 14.0 # m/s lunge — 4-5x the sneak
@export var carry_speed := 8.0 # m/s dragging the catch down
@export var sneak_turn_speed := 25.0 # deg/s — a body this size does not whip around
@export var attack_turn_speed := 55.0 # deg/s while homing on the lunge
@export var snatch_pull_time := 0.5 # seconds from the grab until the player sits in the mouth

@export_group("Stalking")
@export var stalk_behind_distance := 50.0 # first hold point this far behind the player
@export var stalk_below_depth := 30.0 # and this far beneath them
@export var creep_rate := 1.5 # m/s the hold distance shrinks while unseen
@export var min_stalk_distance := 18.0 # as close as it dares to hover
@export var arrive_radius := 10.0 # counts as "in position" at the stalk point

@export_group("Attack")
@export var seen_distance := 60.0 # farther than this the murk hides it: no trigger
@export var kill_distance := 12.0 # fallback bite range, used only if no mouth_area is set
@export var jaw_open_angle := 95.0 # degrees the jaw swings to when open (rest pose = closed)
@export var jaw_open_time := 0.35 # seconds for the jaw to swing open on the lunge
@export var jaw_open_distance := 22.0 # the jaw only gapes this close to the prey — the snatch itself
@export var attack_give_up_time := 8.0 # a missed lunge lasts this long before re-stalking
@export var carry_time := 10.0 # seconds the catch is dragged down before the day resets

@export_group("Body")
@export var jaw: Node3D # opens for the attack; found in the model if left unset
@export var mouth: Node3D # marker at the mouth; kills and carrying anchor here
@export var mouth_area: Area3D # the actual mouth volume; overlap with the player = caught

var state := State.LURK
var player: Node3D = null

var _jaw_closed_x := 0.0
var _jaw_tween: Tween
var _head_minus_z := true # which way the model's snout points along local Z
var _stalk_distance := 0.0
var _behind_dir := Vector3.FORWARD # last known horizontal "behind the player's view"
var _attack_left := 0.0
var _jaw_opened := false # gape already triggered during this attack
var _carry_left := 0.0
var _pull_left := 0.0 # remaining seconds of the reel-in at carry start
var _died_emitted := false
var _player_in_mouth := false # kept current by the mouth_area overlap signals

func _ready() -> void:
	if jaw == null:
		jaw = get_node_or_null(^'fish_01/jaw')
	if jaw:
		_jaw_closed_x = jaw.rotation.x # the authored rest pose is the closed jaw
	if mouth == null:
		for candidate: NodePath in [^'Mouth', ^'mouth', ^'MouthMarker', ^'fish_01/Mouth']:
			mouth = get_node_or_null(candidate)
			if mouth:
				break
	_head_minus_z = to_local(mouth_position()).z <= 0.0
	if mouth_area == null:
		mouth_area = get_node_or_null(^'Area3D')
	if mouth_area:
		mouth_area.set_collision_mask_value(2, true) # the player body lives on layer 2
		mouth_area.body_entered.connect(_on_mouth_body_entered)
		mouth_area.body_exited.connect(_on_mouth_body_exited)

func _on_mouth_body_entered(body: Node3D) -> void:
	if body.is_in_group(&'player'):
		_player_in_mouth = true

func _on_mouth_body_exited(body: Node3D) -> void:
	if body.is_in_group(&'player'):
		_player_in_mouth = false

## True while the player is physically inside the mouth volume. Falls back to
## a distance check for instances without a mouth_area.
func _player_caught() -> bool:
	if mouth_area:
		return _player_in_mouth
	return _mouth_to_player() < kill_distance

## ---- API for the CreatureDirector ------------------------------------------

func begin_hunt(target: Node3D) -> void:
	if state != State.LURK:
		return
	player = target
	_stalk_distance = stalk_behind_distance
	state = State.SNEAK

## Prey escaped (surfaced, climbed out, reached safe water). Ignored while
## carrying: the drag into the deep always ends in the day reset.
func end_hunt() -> void:
	if state == State.CARRY or state == State.LURK:
		return
	set_jaw_open(false)
	state = State.LURK

## Hard reset for the morning restage: drop everything, close the jaw.
func abort_hunt() -> void:
	set_jaw_open(false)
	state = State.LURK
	player = null

func is_busy() -> bool:
	return state != State.LURK

func is_carrying() -> bool:
	return state == State.CARRY

## Lets the director orient the idle orbit with the same sluggish turning.
func face_along(dir: Vector3, delta: float) -> void:
	_steer_toward(dir, sneak_turn_speed, delta)

## ---- behaviour ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.LURK or player == null:
		return
	match state:
		State.SNEAK: _process_sneak(delta)
		State.ATTACK: _process_attack(delta)
		State.CARRY: _process_carry(delta)

## Slip into the blind spot behind the player's view, well below, then hover
## there facing them and edge closer while they are not looking. Stalk
## distances position the MOUTH, not the origin: the snout reaches ~46 m
## ahead of the body's center, so measuring from the origin would park the
## teeth on top of the player.
func _process_sneak(delta: float) -> void:
	var cam := _player_camera()
	if cam:
		var back: Vector3 = cam.global_transform.basis.z # camera backward
		back.y = 0.0
		if back.length() > 0.1:
			_behind_dir = back.normalized()
	var stalk_point := player.global_position + _behind_dir * _stalk_distance \
		+ Vector3.DOWN * stalk_below_depth
	var root_target := stalk_point - (mouth_position() - global_position)

	var to_point := root_target - global_position
	if to_point.length() > arrive_radius:
		_steer_toward(to_point, sneak_turn_speed, delta)
		var speed := cruise_speed if to_point.length() > 80.0 else sneak_speed
		global_position += _heading() * speed * delta
	else:
		# In position: hang in the dark, face the prey, dare a little closer.
		_steer_toward(player.global_position - global_position, sneak_turn_speed, delta)
		_stalk_distance = maxf(_stalk_distance - creep_rate * delta, min_stalk_distance)

	if _is_seen() or _player_caught():
		_begin_attack() # spotted — or the prey backed straight into the teeth

func _begin_attack() -> void:
	state = State.ATTACK
	_attack_left = attack_give_up_time
	_jaw_opened = false # the gape waits for the last jaw_open_distance meters

func _process_attack(delta: float) -> void:
	_steer_toward(player.global_position - mouth_position(), attack_turn_speed, delta)
	global_position += _heading() * attack_speed * delta
	if not _jaw_opened and _mouth_to_player() < jaw_open_distance:
		_jaw_opened = true
		set_jaw_open(true) # the last-moment gape right before the snatch
	# The bite only lands once the jaw has visibly swung open — a point-blank
	# trigger must still show the mouth opening before the grab.
	if _player_caught() and _jaw_open_fraction() > 0.7:
		_begin_carry()
		return
	_attack_left -= delta
	if _attack_left <= 0.0:
		# Missed. Peel away and start the stalk again from a respectful distance.
		set_jaw_open(false)
		_stalk_distance = stalk_behind_distance
		state = State.SNEAK

## The bite does not kill outright: the jaws clamp shut and the catch rides in
## the mouth, dragged down and away while the light fades above.
func _begin_carry() -> void:
	state = State.CARRY
	_carry_left = carry_time
	_pull_left = snatch_pull_time
	_died_emitted = false
	set_jaw_open(false)
	if player.has_method(&'set_captured'):
		player.set_captured(true)

func _process_carry(delta: float) -> void:
	var horiz := _heading()
	horiz.y = 0.0
	horiz = horiz.normalized() if horiz.length() > 0.05 else Vector3.RIGHT
	if global_position.x < -45.0:
		horiz = Vector3.RIGHT # never drag the catch back toward the cove
	var dive := (horiz * 0.5 + Vector3.DOWN).normalized()
	_steer_toward(dive, attack_turn_speed, delta)
	global_position += _heading() * carry_speed * delta
	# Reel the catch into the (moving) mouth over exactly snatch_pull_time
	# seconds, then keep it glued there for the rest of the dive.
	if _pull_left > delta:
		player.global_position = player.global_position.lerp(
			mouth_position(), clampf(delta / _pull_left, 0.0, 1.0))
		_pull_left -= delta
	else:
		player.global_position = mouth_position()

	_carry_left -= delta
	if _carry_left <= 0.0 and not _died_emitted:
		_died_emitted = true
		EventBus.player_died.emit() # the mission controller fades out and restages

## ---- helpers -----------------------------------------------------------------

## The jaw swings open to jaw_open_angle for the attack and clamps back to
## its rest pose on the bite or when the prey escapes.
func set_jaw_open(open: bool) -> void:
	if jaw == null:
		return
	if _jaw_tween:
		_jaw_tween.kill()
	_jaw_tween = create_tween()
	_jaw_tween.tween_property(jaw, "rotation:x",
		deg_to_rad(jaw_open_angle) if open else _jaw_closed_x, jaw_open_time if open else 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 0 = clenched at the rest pose, 1 = fully open at jaw_open_angle.
func _jaw_open_fraction() -> float:
	var open_x := deg_to_rad(jaw_open_angle)
	if jaw == null or absf(open_x - _jaw_closed_x) < 0.001:
		return 1.0
	return clampf((jaw.rotation.x - _jaw_closed_x) / (open_x - _jaw_closed_x), 0.0, 1.0)

## World position of the mouth — kills and carrying anchor here, because the
## body's origin sits a long way behind the snout on this model.
func mouth_position() -> Vector3:
	if mouth:
		return mouth.global_position
	if jaw:
		return jaw.global_position
	return global_position

func _mouth_to_player() -> float:
	return mouth_position().distance_to(player.global_position)

func _player_camera() -> Camera3D:
	return player.camera if &'camera' in player else null

## Seen = any part of it (mouth or mid-body) inside the camera frustum and near
## enough that the murk does not cover it.
func _is_seen() -> bool:
	var cam := _player_camera()
	if cam == null:
		return false
	for point: Vector3 in [mouth_position(), global_position]:
		if cam.global_position.distance_to(point) < seen_distance \
				and cam.is_position_in_frustum(point):
			return true
	return false

## Current mouth-first travel direction.
func _heading() -> Vector3:
	var fwd := -global_basis.z if _head_minus_z else global_basis.z
	return fwd.normalized()

## Angle-limited steering: rotates the whole body toward dir at most turn_deg
## degrees per second, so the bulk carves wide arcs instead of snapping.
func _steer_toward(dir: Vector3, turn_deg: float, delta: float) -> void:
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var look_dir := dir if _head_minus_z else -dir
	var up := Vector3.UP if absf(look_dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var desired := Basis.looking_at(look_dir, up).get_rotation_quaternion()
	var current := global_basis.get_rotation_quaternion()
	var angle := current.angle_to(desired)
	if angle < 0.001:
		return
	global_basis = Basis(current.slerp(desired, minf(1.0, deg_to_rad(turn_deg) * delta / angle)))
