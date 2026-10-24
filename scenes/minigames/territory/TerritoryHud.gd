class_name TerritoryHud
extends CanvasLayer

signal unit_requested(stats: UnitStats)

const UNIT_BUTTON_SCENE := preload("res://scenes/minigames/territory/UnitButton.tscn")

@onready var _buttons: HBoxContainer = %Buttons


func setup(all_stats: Array[UnitStats], spawner: UnitSpawner) -> void:
	for stats in all_stats:
		var button: UnitButton = UNIT_BUTTON_SCENE.instantiate()
		_buttons.add_child(button)
		button.setup(stats, spawner)
		button.unit_requested.connect(unit_requested.emit)
