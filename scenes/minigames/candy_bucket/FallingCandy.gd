class_name CandyBucketFallingCandy
extends Area2D


var is_poison: bool = false
var size_factor: float = 1.0
var fall_speed: float = 220.0
var oscillation_amplitude: float = 0.0
var oscillation_frequency: float = 0.0

var _consumed: bool = false
var _falling: bool = false
var _oscillation_direction: float = 1.0
var _oscillation_origin_x: float = 0.0
var _oscillation_time: float = 0.0
var _horizontal_limits: Vector2 = Vector2.ZERO

@onready var visual: CandyBucketCandyVisual = %Visual
@onready var collision_shape: CollisionShape2D = %CollisionShape


const COLLISION_SIZES: Array[Vector2] = [
    Vector2(66.0, 50.0),
    Vector2(56.0, 52.0),
    Vector2(48.0, 66.0),
    Vector2(88.0, 44.0),
    Vector2(88.0, 44.0),
]


func _ready() -> void:
    add_to_group(&"candy_bucket_falling_candies")


func _physics_process(delta: float) -> void:
    if not _falling:
        return

    global_position.y += fall_speed * delta
    _update_horizontal_oscillation(delta)
    if global_position.y > get_viewport_rect().size.y + 48.0:
        queue_free()


func configure(
    appearance_index: int,
    new_fall_speed: float,
    new_size_factor: float,
    horizontal_limits: Vector2,
    new_oscillation_amplitude: float = 0.0,
    new_oscillation_frequency: float = 0.0,
    oscillation_direction: float = 1.0
) -> void:
    is_poison = appearance_index == CandyBucketCandyVisual.TOXIC_APPEARANCE_INDEX
    fall_speed = new_fall_speed
    size_factor = new_size_factor
    oscillation_amplitude = new_oscillation_amplitude if is_poison else 0.0
    oscillation_frequency = new_oscillation_frequency if is_poison else 0.0
    _oscillation_direction = signf(oscillation_direction)
    _oscillation_origin_x = global_position.x
    _horizontal_limits = horizontal_limits
    visual.configure(appearance_index, size_factor)
    _configure_collision(appearance_index, size_factor)
    _falling = true


func collect() -> bool:
    if _consumed:
        return false

    _consumed = true
    _falling = false
    set_deferred("monitoring", false)
    queue_free()
    return true


func freeze() -> void:
    _falling = false
    set_physics_process(false)


func _configure_collision(appearance_index: int, collision_scale: float) -> void:
    var index: int = posmod(appearance_index, COLLISION_SIZES.size())
    var rectangle := RectangleShape2D.new()
    rectangle.size = COLLISION_SIZES[index] * collision_scale
    collision_shape.shape = rectangle


func _update_horizontal_oscillation(delta: float) -> void:
    if not is_poison or is_zero_approx(oscillation_amplitude):
        return

    _oscillation_time += delta
    var offset := sin(_oscillation_time * TAU * oscillation_frequency)
    var target_x := _oscillation_origin_x + offset * oscillation_amplitude * _oscillation_direction
    global_position.x = clampf(target_x, _horizontal_limits.x, _horizontal_limits.y)
