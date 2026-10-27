class_name TouchControls
extends CanvasLayer
## On-screen controls for tablets: floating joystick, plus action buttons.
## Only shown on touch devices. They press the same input actions as the keyboard.

@export var show_jump: bool = true
@export var show_interact: bool = true
@export var show_combat: bool = false
@export var force_visible: bool = false

@onready var _controls: Control = %Controls
@onready var _jump_button: TouchActionButton = %JumpButton
@onready var _interact_button: TouchActionButton = %InteractButton
@onready var _attack_button: TouchActionButton = %AttackButton
@onready var _switch_tool_button: TouchActionButton = %SwitchToolButton
@onready var _journal_button: TouchActionButton = %JournalButton


func _ready() -> void:
	if not force_visible and not DisplayServer.is_touchscreen_available():
		queue_free()
		return
	_jump_button.visible = show_jump
	_interact_button.visible = show_interact
	_attack_button.visible = show_combat
	_switch_tool_button.visible = show_combat
	_journal_button.visible = show_combat


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		if _controls != null:
			_controls.visible = can_process()
