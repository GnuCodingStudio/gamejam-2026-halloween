class_name LobbyCandyHud
extends CanvasLayer


@onready var candy_label: Label = %CandyLabel
@onready var worlds_label: Label = %WorldsLabel
@onready var finale_overlay: Control = %FinaleOverlay
@onready var finale_card: Control = %FinaleCard
@onready var finale_stats: Control = %FinaleStats
@onready var final_score_label: Label = %FinalScoreLabel
@onready var final_worlds_label: Label = %FinalWorldsLabel
@onready var continue_button: Button = %ContinueButton
@onready var finale_audio: AudioStreamPlayer = %FinaleAudio

var _finale_closing: bool = false
var _paused_for_finale: bool = false


func _ready() -> void:
    ProgressionService.total_candy_changed.connect(_update_candy_label)
    ProgressionService.world_progress_changed.connect(_update_worlds_label)
    continue_button.pressed.connect(_dismiss_finale)
    _update_candy_label(ProgressionService.get_total_candy())
    _update_worlds_label(
        ProgressionService.get_completed_world_count(),
        ProgressionService.get_available_world_count()
    )
    finale_overlay.hide()
    if ProgressionService.should_show_finale():
        _queue_finale.call_deferred()
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if finale_overlay.visible and event.is_action_pressed(&"exit"):
        get_viewport().set_input_as_handled()
        _dismiss_finale()


func _exit_tree() -> void:
    if _paused_for_finale:
        get_tree().paused = false


func _update_candy_label(total_candy: int) -> void:
    candy_label.text = "CANDY : %d" % total_candy


func _update_worlds_label(completed_worlds: int, available_worlds: int) -> void:
    worlds_label.text = "MONDES : %d / %d" % [completed_worlds, available_worlds]


func _queue_finale() -> void:
    if SceneTransition.is_transition_active():
        await SceneTransition.transition_finished
    await get_tree().create_timer(0.45).timeout
    if not ProgressionService.should_show_finale():
        return
    SceneTransition.run_fade(_prepare_finale, _reveal_finale)


func _prepare_finale() -> void:
    finale_overlay.show()
    if not ProgressionService.mark_finale_seen():
        finale_overlay.hide()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        return

    _update_finale_summary()
    _prepare_finale_animation()
    _paused_for_finale = true
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _reveal_finale() -> void:
    if not finale_overlay.visible or _finale_closing:
        return

    finale_audio.play()

    var entrance: Tween = create_tween().set_parallel(true)
    entrance.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    entrance.tween_property(finale_card, "scale", Vector2.ONE, 0.65)
    entrance.tween_property(finale_card, "modulate:a", 1.0, 0.40)
    await entrance.finished
    if _finale_closing or not finale_overlay.visible:
        return

    var reveal: Tween = create_tween().set_parallel(true)
    reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    reveal.tween_property(finale_stats, "modulate:a", 1.0, 0.40)
    reveal.tween_property(final_score_label, "scale", Vector2.ONE, 0.40)
    reveal.tween_property(final_worlds_label, "scale", Vector2.ONE, 0.40)
    await reveal.finished
    if _finale_closing or not finale_overlay.visible:
        return
    continue_button.grab_focus()


func _update_finale_summary() -> void:
    final_score_label.text = str(ProgressionService.get_total_candy())
    final_worlds_label.text = "%d / %d" % [
        ProgressionService.get_completed_world_count(),
        ProgressionService.get_available_world_count(),
    ]


func _prepare_finale_animation() -> void:
    finale_overlay.modulate = Color.WHITE
    finale_card.pivot_offset = finale_card.size * 0.5
    finale_card.scale = Vector2.ONE * 0.86
    finale_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
    finale_stats.modulate = Color(1.0, 1.0, 1.0, 0.0)
    final_score_label.pivot_offset = final_score_label.size * 0.5
    final_score_label.scale = Vector2.ONE * 0.78
    final_worlds_label.pivot_offset = final_worlds_label.size * 0.5
    final_worlds_label.scale = Vector2.ONE * 0.78
    finale_audio.volume_db = -6.0
    _finale_closing = false


func _dismiss_finale() -> void:
    if _finale_closing or not finale_overlay.visible:
        return

    _finale_closing = true
    continue_button.disabled = true
    var exit_tween: Tween = create_tween().set_parallel(true)
    exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    exit_tween.tween_property(finale_overlay, "modulate:a", 0.0, 0.30)
    exit_tween.tween_property(finale_card, "scale", Vector2.ONE * 0.96, 0.30)
    exit_tween.tween_property(finale_audio, "volume_db", -30.0, 0.30)
    await exit_tween.finished

    finale_audio.stop()
    finale_overlay.hide()
    continue_button.disabled = false
    _paused_for_finale = false
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
