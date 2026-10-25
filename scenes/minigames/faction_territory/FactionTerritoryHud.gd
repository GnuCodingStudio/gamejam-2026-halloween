class_name FactionTerritoryHud
extends CanvasLayer

signal unit_requested(stats: UnitStats)

const UNIT_BUTTON_SCENE := preload("res://scenes/minigames/faction_territory/UnitButton.tscn")
const GAIN_DURATION := 1.5
const GAIN_FADE_DURATION := 0.5
const GAIN_SCROLL_DISTANCE := 35.0

var _gain_tween: Tween
var _gain_rest_y: float
var _spawner: UnitSpawner

@onready var _buttons: HBoxContainer = %Buttons
@onready var _candy_label: Label = %CandyLabel
@onready var _sites_label: Label = %SitesLabel
@onready var _time_label: Label = %TimeLabel
@onready var _gain_label: Label = %GainLabel
@onready var _units_label: Label = %UnitsLabel


func _ready() -> void:
	await get_tree().process_frame
	_gain_rest_y = _gain_label.position.y


func _process(_delta: float) -> void:
	if _spawner:
		_units_label.text = tr("CREDITS_TERRITORY_UNITS_FIGHTING") % [_spawner.alive_count, _spawner.max_alive]


func setup(all_stats: Array[UnitStats], spawner: UnitSpawner) -> void:
	_spawner = spawner
	for stats in all_stats:
		var button: UnitButton = UNIT_BUTTON_SCENE.instantiate()
		_buttons.add_child(button)
		button.setup(stats, spawner)
		button.unit_requested.connect(unit_requested.emit)


func set_candies(total: int) -> void:
	_candy_label.text = tr("CREDITS_CANDIES_COUNT") % total


func set_time(seconds: float) -> void:
	var whole_seconds := ceili(seconds)
	var minutes := floori(whole_seconds / 60.0)
	_time_label.text = "%d:%02d" % [minutes, whole_seconds % 60]


func set_sites(owned: int, total: int) -> void:
	_sites_label.text = tr("CREDITS_TERRITORY_SITES") % [owned, total]


func show_gain(amount: int) -> void:
	if _gain_tween:
		_gain_tween.kill()
	_gain_label.text = tr("CREDITS_TERRITORY_GAIN") % amount
	_gain_label.modulate.a = 0.0
	_gain_label.position.y = _gain_rest_y + GAIN_SCROLL_DISTANCE
	_gain_label.visible = true
	_gain_tween = create_tween()
	_gain_tween.set_parallel()
	_gain_tween.tween_property(_gain_label, "modulate:a", 1.0, GAIN_FADE_DURATION)
	_gain_tween.tween_property(_gain_label, "position:y", _gain_rest_y, GAIN_FADE_DURATION) \
		.set_ease(Tween.EASE_OUT)
	_gain_tween.chain().tween_interval(GAIN_DURATION)
	_gain_tween.chain().tween_property(_gain_label, "modulate:a", 0.0, GAIN_FADE_DURATION)
	_gain_tween.tween_property(_gain_label, "position:y", _gain_rest_y - GAIN_SCROLL_DISTANCE, GAIN_FADE_DURATION) \
		.set_ease(Tween.EASE_IN)
	_gain_tween.chain().tween_callback(_gain_label.hide)
