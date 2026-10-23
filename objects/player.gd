class_name Player
extends CharacterBody3D

signal started_moving

@onready var model: Knight = %Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 10.0

var _has_started_moving := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var camera := get_viewport().get_camera_3d().global_transform
	var direction := transform.basis * camera.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0.0
	direction = direction.normalized()

	if direction:
		_notify_first_move()
		_turn_model_toward(direction, delta)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	model.animate(is_on_floor(), Vector2(velocity.x, velocity.z).length())


func _notify_first_move() -> void:
	if not _has_started_moving:
		_has_started_moving = true
		started_moving.emit()


func _turn_model_toward(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(direction.x, direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, TURN_SPEED * delta)
