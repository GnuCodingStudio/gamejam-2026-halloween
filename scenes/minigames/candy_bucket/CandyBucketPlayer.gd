class_name CandyBucketPlayer
extends CharacterBody2D


signal candy_entered(candy: Area2D)


const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"


var _base_speed: float = 520.0
var _speed_multiplier: float = 1.0
var _movement_enabled: bool = false
var _left_limit: float = 72.0
var _right_limit: float = 1208.0


func _physics_process(_delta: float) -> void:
    if not _movement_enabled:
        velocity = Vector2.ZERO
        return

    var direction: float = Input.get_axis(MOVE_LEFT, MOVE_RIGHT)
    velocity = Vector2(direction * _base_speed * _speed_multiplier, 0.0)
    move_and_slide()
    global_position.x = clampf(global_position.x, _left_limit, _right_limit)


func configure(base_speed: float, left_limit: float, right_limit: float) -> void:
    _base_speed = base_speed
    set_horizontal_limits(left_limit, right_limit)


func set_horizontal_limits(left_limit: float, right_limit: float) -> void:
    _left_limit = left_limit
    _right_limit = maxf(left_limit, right_limit)
    global_position.x = clampf(global_position.x, _left_limit, _right_limit)


func set_movement_enabled(enabled: bool) -> void:
    _movement_enabled = enabled
    if not enabled:
        velocity = Vector2.ZERO


func set_poisoned(poisoned: bool) -> void:
    _speed_multiplier = 0.5 if poisoned else 1.0


func set_collection_enabled(enabled: bool) -> void:
    %BucketCollector.set_deferred("monitoring", enabled)


func reset_state(start_position: Vector2) -> void:
    global_position = start_position
    velocity = Vector2.ZERO
    set_poisoned(false)
    set_movement_enabled(false)
    set_collection_enabled(false)


func _on_bucket_collector_area_entered(area: Area2D) -> void:
    candy_entered.emit(area)
