class_name FactionFightMonster
extends Node3D

signal player_bumped(monster: FactionFightMonster, direction: Vector3, strength: float)

enum State {
	IDLE,
	PATROL,
	ALERT,
	CHASE,
	REPELLED,
	RECOVERING,
	STUNNED,
	RETURN,
}

var display_name: String = "Monstre"
var model_resource_path: String = ""
var monster_type: StringName = &"goblin"
var patrol_speed: float = 1.2
var chase_speed: float = 2.4
var detection_radius: float = 8.0
var chase_limit: float = 11.0

var _state: int = State.IDLE
var _player: Node3D
var _home: Vector3
var _patrol_offset: Vector3
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _state_time: float = 0.0
var _contact_cooldown: float = 0.0
var _repel_velocity: Vector3 = Vector3.ZERO
var _model: Node3D
var _model_pivot: Node3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary = {}
var _alert_marker: MeshInstance3D
var _update_accumulator: float = 0.0
var _enrage_time: float = 0.0
var _slow_time: float = 0.0
var _slow_multiplier: float = 1.0
var _corruption_detection_multiplier: float = 1.0
var _aim_label: Label3D
var _aim_aura: MeshInstance3D
var _model_yaw_offset: float = PI
var _random := RandomNumberGenerator.new()
var _patrol_burst_time: float = 0.0
var _idle_target_yaw: float = 0.0

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
	monster_type = StringName(settings.get("monster_type", monster_type))
	_model_yaw_offset = float(settings.get("model_yaw_offset", PI))
	_random.randomize()
	_build_patrol_points()
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


func apply_slow(duration: float, multiplier: float = 0.55) -> void:
	_slow_time = maxf(_slow_time, duration)
	_slow_multiplier = clampf(multiplier, 0.25, 0.9)


func apply_enrage(duration: float = 5.0) -> void:
	_enrage_time = maxf(_enrage_time, duration)
	_set_state(State.ALERT, 0.2)


func set_corruption_level(progress: float) -> void:
	_corruption_detection_multiplier = lerpf(1.0, 1.15, clampf(progress, 0.0, 1.0))


func show_reaction(text: String, color: Color) -> void:
	var reaction_label := Label3D.new()
	reaction_label.text = text
	reaction_label.font_size = 42
	reaction_label.outline_size = 12
	reaction_label.modulate = color
	reaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reaction_label.position = Vector3(0.0, 3.15, 0.0)
	add_child(reaction_label)
	var tween := reaction_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(reaction_label, "position:y", 3.8, 0.8)
	tween.tween_property(reaction_label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(reaction_label.queue_free)


func show_aim_feedback(text: String, color: Color) -> void:
	if _aim_label == null or _aim_aura == null:
		return
	_aim_label.text = text
	_aim_label.modulate = color
	_aim_label.visible = true
	var material := _aim_aura.get_active_material(0) as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(color.r, color.g, color.b, 0.2)
		material.emission = color
	_aim_aura.visible = true


func clear_aim_feedback() -> void:
	if _aim_label != null:
		_aim_label.visible = false
	if _aim_aura != null:
		_aim_aura.visible = false


func get_state_name() -> String:
	return State.keys()[_state]


func can_steal_candy() -> bool:
	return _state != State.REPELLED and _state != State.RECOVERING and _state != State.STUNNED


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
	_enrage_time = maxf(_enrage_time - update_delta, 0.0)
	_slow_time = maxf(_slow_time - update_delta, 0.0)
	_patrol_burst_time = maxf(_patrol_burst_time - update_delta, 0.0)
	_update_state(update_delta)


func _update_state(delta: float) -> void:
	match _state:
		State.IDLE:
			rotation.y = lerp_angle(rotation.y, _idle_target_yaw, minf(delta * _idle_turn_speed(), 1.0))
			if _can_detect_player():
				_set_state(State.ALERT, 0.55)
			elif _state_time <= 0.0:
				if monster_type == &"goblin":
					_patrol_burst_time = _random.randf_range(0.45, 0.9)
				elif monster_type == &"conqueror" and _random.randf() < 0.55:
					_patrol_burst_time = _random.randf_range(0.35, 0.7)
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
				_set_state(State.RECOVERING, 0.65)
		State.RECOVERING:
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
				var return_speed := _effective_speed(chase_speed)
				_set_locomotion_animation_speed(return_speed, chase_speed)
				_move_toward(_home, return_speed, delta)


func _patrol(delta: float) -> void:
	if _patrol_points.is_empty():
		_set_state(State.IDLE, 1.0)
		return
	var target := _patrol_points[_patrol_index]
	if global_position.distance_to(target) < 0.35:
		_patrol_index = _next_patrol_index()
		_set_state(State.IDLE, _patrol_pause())
		return
	var burst_multiplier := 1.32 if _patrol_burst_time > 0.0 else 1.0
	var current_speed := _effective_speed(patrol_speed) * burst_multiplier
	_set_locomotion_animation_speed(current_speed, patrol_speed)
	_move_toward(target, current_speed, delta)


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
	var current_speed := _effective_speed(chase_speed)
	_set_locomotion_animation_speed(current_speed, chase_speed)
	_move_toward(_player.global_position, current_speed, delta)


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var desired_direction := target - global_position
	desired_direction.y = 0.0
	if desired_direction.is_zero_approx():
		return
	desired_direction = _clear_movement_direction(desired_direction.normalized(), speed * delta)
	if desired_direction.is_zero_approx():
		return
	_face_direction(desired_direction, delta)
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var alignment := clampf(forward.dot(desired_direction), 0.0, 1.0)
	if alignment < 0.2:
		return
	var distance := speed * delta * alignment
	if not _has_obstacle(forward, distance + OBSTACLE_CLEARANCE):
		global_position += forward * distance


func _move_in_direction(direction: Vector3, distance: float) -> void:
	if direction.is_zero_approx() or distance <= 0.0:
		return
	var normalized_direction := direction.normalized()
	if not _has_obstacle(normalized_direction, distance + 0.15):
		global_position += normalized_direction * distance


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
	_face_direction(direction.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 5.5, 1.0))


func _can_detect_player() -> bool:
	var current_detection_radius := detection_radius * _corruption_detection_multiplier * (1.35 if _enrage_time > 0.0 else 1.0)
	return (
		global_position.distance_squared_to(_player.global_position) <= current_detection_radius * current_detection_radius
		and global_position.distance_squared_to(_home) <= chase_limit * chase_limit
	)


func _effective_speed(base_speed: float) -> float:
	var multiplier := 1.65 if _enrage_time > 0.0 else 1.0
	if _slow_time > 0.0:
		multiplier *= _slow_multiplier
	return base_speed * multiplier


func _set_state(next_state: int, duration: float = 0.0) -> void:
	if _state == next_state and duration <= 0.0:
		return
	_state = next_state
	_state_time = duration
	if _state == State.IDLE:
		var look_range := 0.65 if monster_type == &"goblin" else 0.28
		_idle_target_yaw = rotation.y + _random.randf_range(-look_range, look_range)
	if _model_pivot != null and _state != State.REPELLED and _state != State.RECOVERING and _state != State.STUNNED:
		_model_pivot.rotation.z = 0.0
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
		State.REPELLED, State.RECOVERING, State.STUNNED:
			key = "stunned"
	var animation_name := StringName(_animation_names.get(key, _animation_names.get("idle", "")))
	if animation_name != &"" and _animation_player.has_animation(animation_name):
		_animation_player.speed_scale = 1.0
		_animation_player.play(animation_name, 0.18)


func _create_model(model_path: String, model_scale: float) -> void:
	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		push_error("FactionFight: impossible de charger " + model_path)
		return
	_model_pivot = Node3D.new()
	_model_pivot.name = "ModelPivot"
	_model_pivot.rotation.y = _model_yaw_offset
	add_child(_model_pivot)
	_model = packed_scene.instantiate() as Node3D
	if _model == null:
		push_error("FactionFight: racine 3D invalide pour " + model_path)
		return
	_model_pivot.add_child(_model)
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

	_aim_aura = MeshInstance3D.new()
	var aura_mesh := CylinderMesh.new()
	aura_mesh.top_radius = 0.85
	aura_mesh.bottom_radius = 0.85
	aura_mesh.height = 0.05
	var aura_material := StandardMaterial3D.new()
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.emission_enabled = true
	aura_mesh.material = aura_material
	_aim_aura.mesh = aura_mesh
	_aim_aura.position = Vector3(0.0, 0.06, 0.0)
	_aim_aura.visible = false
	add_child(_aim_aura)

	_aim_label = Label3D.new()
	_aim_label.position = Vector3(0.0, 2.82, 0.0)
	_aim_label.font_size = 32
	_aim_label.outline_size = 9
	_aim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aim_label.visible = false
	add_child(_aim_label)


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
	if _model_pivot != null:
		_model_pivot.rotation.z = sin(Time.get_ticks_msec() * 0.001 * speed) * 0.16


func _build_patrol_points() -> void:
	_patrol_points.clear()
	var base_offset := _patrol_offset
	if base_offset.length_squared() < 1.0:
		base_offset = Vector3(3.0, 0.0, 0.0)
	var angles: Array[float]
	match monster_type:
		&"paladin":
			angles = [-0.55, 0.25, 1.15]
		&"conqueror":
			angles = [-1.25, -0.35, 0.5, 1.35, 2.35]
		_:
			angles = [-0.85, 0.15, 1.15, 2.25]
	for index: int in angles.size():
		var scale_factor := 0.72 + float(index % 3) * 0.14
		_patrol_points.append(_home + base_offset.rotated(Vector3.UP, angles[index]) * scale_factor)
	_patrol_index = _random.randi_range(0, _patrol_points.size() - 1)


func _next_patrol_index() -> int:
	if monster_type == &"conqueror" and _patrol_points.size() > 2:
		var next_index := _random.randi_range(0, _patrol_points.size() - 1)
		return (next_index + 1) % _patrol_points.size() if next_index == _patrol_index else next_index
	return (_patrol_index + 1) % _patrol_points.size()


func _patrol_pause() -> float:
	match monster_type:
		&"paladin":
			return _random.randf_range(1.3, 2.2)
		&"conqueror":
			return _random.randf_range(0.45, 1.0)
		_:
			return _random.randf_range(0.25, 0.8)


func _idle_turn_speed() -> float:
	match monster_type:
		&"paladin":
			return 1.2
		&"conqueror":
			return 2.2
		_:
			return 3.8


func _set_locomotion_animation_speed(world_speed: float, reference_speed: float) -> void:
	if _animation_player == null or reference_speed <= 0.0:
		return
	_animation_player.speed_scale = clampf(world_speed / reference_speed, 0.8, 1.55)
