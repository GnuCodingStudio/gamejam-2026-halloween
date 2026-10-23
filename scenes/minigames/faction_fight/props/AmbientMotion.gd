class_name ChaseweenAmbientMotion
extends Node3D


enum MotionMode {
    SWAY,
    SPIN,
    BOB,
}

@export var mode: MotionMode = MotionMode.SWAY
@export_range(0.0, 2.0, 0.05) var amplitude: float = 0.12
@export_range(0.0, 4.0, 0.05) var speed: float = 1.0
@export var phase: float = 0.0

var _base_position: Vector3
var _base_rotation: Vector3


func _ready() -> void:
    _base_position = position
    _base_rotation = rotation


func _process(_delta: float) -> void:
    var wave: float = sin(Time.get_ticks_msec() * 0.001 * speed + phase)
    match mode:
        MotionMode.SWAY:
            rotation.z = _base_rotation.z + wave * amplitude
        MotionMode.SPIN:
            rotation.y = _base_rotation.y + Time.get_ticks_msec() * 0.001 * speed
        MotionMode.BOB:
            position.y = _base_position.y + wave * amplitude
        _:
            pass

