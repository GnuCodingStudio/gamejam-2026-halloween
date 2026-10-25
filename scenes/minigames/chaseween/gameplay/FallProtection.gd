class_name FactionFightFallProtection
extends Node

const FALL_HEIGHT: float = -5.0
const MINIMUM_STABLE_HEIGHT: float = -1.5
const RECOVERY_OFFSET: Vector3 = Vector3(0.0, 0.2, 0.0)
const RECOVERY_COOLDOWN: float = 0.8
const STABLE_SAMPLE_INTERVAL: float = 0.35

var recovery_count: int = 0

var _player: CharacterBody3D
var _last_safe_position: Vector3 = Vector3.ZERO
var _fallback_position: Vector3 = Vector3.ZERO
var _cooldown: float = 0.0
var _sample_time: float = 0.0
var _awaiting_stable_ground: bool = false
var _active: bool = true


func configure(player: CharacterBody3D) -> void:
	_player = player
	_last_safe_position = player.global_position
	_fallback_position = player.global_position
	set_physics_process(true)


func set_active(enabled: bool) -> void:
	_active = enabled
	set_physics_process(enabled)


func get_last_safe_position() -> Vector3:
	return _last_safe_position


func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_player):
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_sample_time = maxf(_sample_time - delta, 0.0)
	if _player.global_position.y < FALL_HEIGHT:
		_recover_player()
		return
	if _sample_time <= 0.0 and _can_record_position():
		_last_safe_position = _player.global_position
		_sample_time = STABLE_SAMPLE_INTERVAL
		_awaiting_stable_ground = false


func _can_record_position() -> bool:
	return (
		_cooldown <= 0.0
		and _player.global_position.y >= MINIMUM_STABLE_HEIGHT
		and _player.is_on_floor()
		and absf(_player.velocity.y) < 0.5
	)


func _recover_player() -> void:
	if _cooldown > 0.0:
		return
	var recovery_position := _fallback_position if _awaiting_stable_ground else _last_safe_position
	_player.global_position = recovery_position + RECOVERY_OFFSET
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_cooldown = RECOVERY_COOLDOWN
	_awaiting_stable_ground = true
	recovery_count += 1
