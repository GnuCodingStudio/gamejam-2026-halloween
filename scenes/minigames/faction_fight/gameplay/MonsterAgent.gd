class_name FactionFightMonster
extends Node3D

signal player_bumped(monster: FactionFightMonster, direction: Vector3, strength: float)

enum State {
	IDLE,
	PATROL,
	ALERT,
	CHASE,
	REPELLED,
	STUNNED,
	RETURN,
}

var display_name: String = "Monstre"
var model_resource_path: String = ""
var patrol_speed: float = 1.2
var chase_speed: float = 2.4
var detection_radius: float = 8.0
var chase_limit: float = 11.0

var _state: int = State.IDLE
var _player: Node3D
var _home: Vector3
var _patrol_offset: Vector3
var _patrol_direction: float = 1.0
var _state_time: float = 0.0
var _contact_cooldown: float = 0.0
var _repel_velocity: Vector3 = Vector3.ZERO
var _model: Node3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary = {}
var _alert_marker: MeshInstance3D
var _update_accumulator: float = 0.0

const FAR_UPDATE_DISTANCE_SQUARED: float = 2025.0
const FAR_UPDATE_INTERVAL: float = 0.2
const OBSTACLE_COLLISION_MASK: int = 12
const OBSTACLE_PROBE_HEIGHT: float = 0.7
const OBSTACLE_CLEARANCE: float = 0.65
const AVOIDANCE_ANGLES: Array[float] = [0.0, PI / 3.0, -PI / 3.0, PI * 0.55, -PI * 0.55]


func configure(
	monster_name: String,
	model_path: String,
	player: Node3D,
	spawn_position: Vector3,
	patrol_offset: Vector3,
	settings: Dictionary,
	animations: Dictionary
) -> void:
	display_name = monster_name
	model_resource_path = model_path
	_player = player
	global_position = spawn_position
	_home = spawn_position
	_patrol_offset = patrol_offset
	patrol_speed = float(settings.get("patrol_speed", patrol_speed))
	chase_speed = float(settings.get("chase_speed", chase_speed))
	detection_radius = float(settings.get("detection_radius", detection_radius))
	chase_limit = float(settings.get("chase_limit", chase_limit))
	_animation_names = animations
	_create_model(model_path, float(settings.get("scale", 1.0)))
	_create_feedback()
	_set_state(State.IDLE, 0.8)


func apply_repel(source_position: Vector3, duration: float = 1.4, force: float = 5.0) -> void:
	var direction := global_position - source_position
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	_repel_velocity = direction.normalized() * force
	_set_state(State.REPELLED, duration)


func apply_stun(duration: float = 2.2) -> void:
	_repel_velocity = Vector3.ZERO
	_set_state(State.STUNNED, duration)


func get_state_name() -> String:
	return State.keys()[_state]


func can_steal_candy() -> bool:
	return _state != State.REPELLED and _state != State.STUNNED


func stop_gameplay() -> void:
	set_physics_process(false)
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_update_accumulator += delta
	var is_far := global_position.distance_squared_to(_player.global_position) > FAR_UPDATE_DISTANCE_SQUARED
	if is_far and _update_accumulator < FAR_UPDATE_INTERVAL:
		return
	var update_delta := _update_accumulator
	_update_accumulator = 0.0
	_state_time = maxf(_state_time - update_delta, 0.0)
	_contact_cooldown = maxf(_contact_cooldown - update_delta, 0.0)
	_update_state(update_delta)


func _update_state(delta: float) -> void:
	match _state:
		State.IDLE:
			if _can_detect_player():
				_set_state(State.ALERT, 0.55)
			elif _state_time <= 0.0:
				_set_state(State.PATROL)
		State.PATROL:
			if _can_detect_player():
				_set_state(State.ALERT, 0.55)
			else:
				_patrol(delta)
		State.ALERT:
			_face_position(_player.global_position, delta)
			if _state_time <= 0.0:
				_set_state(State.CHASE)
		State.CHASE:
			_chase(delta)
		State.REPELLED:
			_move_in_direction(_repel_velocity.normalized(), _repel_velocity.length() * delta)
			_repel_velocity = _repel_velocity.move_toward(Vector3.ZERO, 5.0 * delta)
			_spin_model(delta, 8.0)
			if _state_time <= 0.0:
				_set_state(State.RETURN)
		State.STUNNED:
			_spin_model(delta, 4.0)
			if _state_time <= 0.0:
				_set_state(State.RETURN)
		State.RETURN:
			if global_position.distance_to(_home) < 0.35:
				global_position = _home
				_set_state(State.IDLE, 0.75)
			else:
				_move_toward(_home, chase_speed, delta)


func _patrol(delta: float) -> void:
	var target := _home + _patrol_offset * _patrol_direction
	if global_position.distance_to(target) < 0.35:
		_patrol_direction *= -1.0
		_set_state(State.IDLE, 0.7)
		return
	_move_toward(target, patrol_speed, delta)


func _chase(delta: float) -> void:
	var player_distance := global_position.distance_to(_player.global_position)
	if global_position.distance_to(_home) > chase_limit or player_distance > detection_radius * 1.65:
		_set_state(State.RETURN)
		return
	if player_distance < 1.45 and _contact_cooldown <= 0.0:
		var direction := _player.global_position - global_position
		direction.y = 0.0
		player_bumped.emit(self, direction.normalized(), 0.8)
		_contact_cooldown = 3.0
		if _state == State.CHASE:
			_set_state(State.RETURN)
		return
	_move_toward(_player.global_position, chase_speed, delta)


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = _clear_movement_direction(direction.normalized(), speed * delta)
	if direction.is_zero_approx():
		return
	global_position += direction * speed * delta
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 6.0, 1.0))


func _move_in_direction(direction: Vector3, distance: float) -> void:
	if direction.is_zero_approx() or distance <= 0.0:
		return
	var clear_direction := _clear_movement_direction(direction, distance)
	if not clear_direction.is_zero_approx():
		global_position += clear_direction * distance


func _clear_movement_direction(direction: Vector3, distance: float) -> Vector3:
	if not is_inside_tree():
		return direction
	for angle: float in AVOIDANCE_ANGLES:
		var candidate := direction.rotated(Vector3.UP, angle)
		if not _has_obstacle(candidate, distance + OBSTACLE_CLEARANCE):
			return candidate
	return Vector3.ZERO


func _has_obstacle(direction: Vector3, probe_distance: float) -> bool:
	var from := global_position + Vector3.UP * OBSTACLE_PROBE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		from,
		from + direction * probe_distance,
		OBSTACLE_COLLISION_MASK
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face_position(target: Vector3, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var target_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 7.0, 1.0))


func _can_detect_player() -> bool:
	return (
		global_position.distance_squared_to(_player.global_position) <= detection_radius * detection_radius
		and global_position.distance_squared_to(_home) <= chase_limit * chase_limit
	)


func _set_state(next_state: int, duration: float = 0.0) -> void:
	if _state == next_state and duration <= 0.0:
		return
	_state = next_state
	_state_time = duration
	if _alert_marker != null:
		_alert_marker.visible = _state == State.ALERT
	_play_state_animation()


func _play_state_animation() -> void:
	if _animation_player == null:
		return
	var key := "idle"
	match _state:
		State.PATROL, State.RETURN:
			key = "walk"
		State.ALERT:
			key = "alert"
		State.CHASE:
			key = "run"
		State.REPELLED, State.STUNNED:
			key = "stunned"
	var animation_name := StringName(_animation_names.get(key, _animation_names.get("idle", "")))
	if animation_name != &"" and _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name, 0.18)


func _create_model(model_path: String, model_scale: float) -> void:
	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		push_error("FactionFight: impossible de charger " + model_path)
		return
	_model = packed_scene.instantiate() as Node3D
	if _model == null:
		push_error("FactionFight: racine 3D invalide pour " + model_path)
		return
	add_child(_model)
	_model.scale = Vector3.ONE * model_scale
	_animation_player = _find_animation_player(_model)
	if _animation_player != null:
		_animation_player.animation_finished.connect(_on_animation_finished)


func _create_feedback() -> void:
	var label := Label3D.new()
	label.text = display_name
	label.position = Vector3(0.0, 2.25, 0.0)
	label.font_size = 36
	label.outline_size = 10
	label.modulate = Color(1.0, 0.86, 0.48)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	_alert_marker = MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.13
	marker_mesh.height = 0.26
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.23, 0.12)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.05, 0.01)
	marker_material.emission_energy_multiplier = 4.0
	marker_mesh.material = marker_material
	_alert_marker.mesh = marker_mesh
	_alert_marker.position = Vector3(0.0, 2.75, 0.0)
	_alert_marker.visible = false
	add_child(_alert_marker)


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _on_animation_finished(_animation_name: StringName) -> void:
	_play_state_animation()


func _spin_model(delta: float, speed: float) -> void:
	if _model != null:
		_model.rotation.y += delta * speed
