class_name CandyBucketCandyVisual
extends Node2D


const TEXTURES: Array[Texture2D] = [
    preload("res://assets/2D/pumpkin_hard_candy.png"),
    preload("res://assets/2D/sparling_gumdrop.png"),
    preload("res://assets/2D/swirl_lollipop.png"),
    preload("res://assets/2D/toxyc_candy.png"),
    preload("res://assets/2D/triped_chewy_candy.png"),
    preload("res://assets/2D/magic_candy.png"),
]
const TOXIC_APPEARANCE_INDEX: int = 3
const MAGIC_APPEARANCE_INDEX: int = 5
const HEALTHY_APPEARANCE_INDICES: Array[int] = [0, 1, 2, 4]

# Textures are uniformly scaled inside these boxes. This preserves their source
# proportions while keeping every candy below a common 104 x 82 px limit.
const MAX_DISPLAY_SIZES: Array[Vector2] = [
    Vector2(82.0, 82.0),
    Vector2(78.0, 76.0),
    Vector2(82.0, 82.0),
    Vector2(104.0, 72.0),
    Vector2(104.0, 72.0),
    Vector2(108.0, 72.0),
]


@onready var sprite: Sprite2D = %Sprite
@onready var glow: Sprite2D = %Glow

var _is_magic: bool = false
var _base_scale: Vector2 = Vector2.ONE
var _animation_time: float = 0.0


func _process(delta: float) -> void:
    if not _is_magic:
        return

    _animation_time += delta
    var pulse: float = 1.0 + sin(_animation_time * TAU * 1.8) * 0.07
    sprite.scale = _base_scale * pulse
    sprite.rotation = sin(_animation_time * TAU * 0.8) * 0.10
    glow.scale = _base_scale * (1.20 + sin(_animation_time * TAU * 1.8) * 0.08)
    glow.modulate.a = 0.22 + sin(_animation_time * TAU * 1.8) * 0.07


func configure(appearance_index: int, size_factor: float) -> void:
    var index: int = posmod(appearance_index, TEXTURES.size())
    var texture: Texture2D = TEXTURES[index]
    var texture_size: Vector2 = texture.get_size()
    var max_size: Vector2 = MAX_DISPLAY_SIZES[index]
    var scale_factor: float = minf(
        max_size.x / texture_size.x,
        max_size.y / texture_size.y
    )

    sprite.texture = texture
    _base_scale = Vector2.ONE * scale_factor * size_factor
    sprite.scale = _base_scale
    _is_magic = index == MAGIC_APPEARANCE_INDEX
    set_process(_is_magic)
    glow.visible = _is_magic
    if _is_magic:
        glow.texture = texture
        glow.scale = _base_scale * 1.20
