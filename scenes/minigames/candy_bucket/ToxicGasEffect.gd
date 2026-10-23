class_name CandyBucketToxicGasEffect
extends Node2D


const EFFECT_DURATION: float = 0.72
const PUFF_DIRECTIONS: Array[Vector2] = [
    Vector2(-0.95, -0.30),
    Vector2(-0.55, -0.85),
    Vector2(0.05, -1.00),
    Vector2(0.60, -0.75),
    Vector2(1.00, -0.20),
    Vector2(0.35, -0.35),
]
const PUFF_RADII: Array[float] = [15.0, 12.0, 14.0, 11.0, 13.0, 9.0]
const PUFF_COLORS: Array[Color] = [
    Color("9bdb45"),
    Color("d0dc4d"),
    Color("72c94b"),
]

var _elapsed: float = EFFECT_DURATION


func _ready() -> void:
    hide()
    set_process(false)


func play() -> void:
    _elapsed = 0.0
    show()
    set_process(true)
    queue_redraw()


func stop() -> void:
    _elapsed = EFFECT_DURATION
    hide()
    set_process(false)


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= EFFECT_DURATION:
        stop()
        return

    queue_redraw()


func _draw() -> void:
    var progress: float = clampf(_elapsed / EFFECT_DURATION, 0.0, 1.0)
    var appearance: float = minf(progress / 0.16, 1.0)
    var opacity: float = (1.0 - smoothstep(0.30, 1.0, progress)) * appearance

    for index: int in PUFF_DIRECTIONS.size():
        var direction: Vector2 = PUFF_DIRECTIONS[index]
        var travel: float = 12.0 + 42.0 * progress
        var wobble := Vector2(sin(progress * TAU + index) * 5.0, 0.0)
        var puff_position: Vector2 = direction * travel + wobble
        var radius: float = lerpf(4.0, PUFF_RADII[index], appearance)
        var color: Color = PUFF_COLORS[index % PUFF_COLORS.size()]
        color.a = opacity * (0.72 if index % 2 == 0 else 0.55)
        draw_circle(puff_position, radius, color)
        draw_arc(puff_position, radius, 0.0, TAU, 20, color.lightened(0.22), 2.0)
