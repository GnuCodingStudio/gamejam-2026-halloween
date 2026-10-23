class_name Knight
extends Node3D

const BLEND_TIME := 0.15
const MOVING_SPEED := 0.1

@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _was_on_floor := true
var _jump_animation := &"jump_static"
var _current_animation := &""


func animate(on_floor: bool, horizontal_speed: float) -> void:
	var is_moving := horizontal_speed > MOVING_SPEED
	if on_floor:
		_play(&"run" if is_moving else &"idle")
	else:
		if _was_on_floor:
			_jump_animation = &"jump_forward" if is_moving else &"jump_static"
		_play(_jump_animation)
	_was_on_floor = on_floor


func _play(animation: StringName) -> void:
	if animation == _current_animation:
		return
	_current_animation = animation
	_animation_player.play(animation, BLEND_TIME)
