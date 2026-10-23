class_name LobbyCandyHud
extends CanvasLayer


@onready var candy_label: Label = %CandyLabel


func _ready() -> void:
    ProgressionService.total_candy_changed.connect(_update_candy_label)
    _update_candy_label(ProgressionService.get_total_candy())


func _update_candy_label(total_candy: int) -> void:
    candy_label.text = "CANDY : %d" % total_candy
