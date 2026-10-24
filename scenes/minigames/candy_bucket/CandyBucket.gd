class_name CandyBucketGame
extends Node2D


## Public integration point for a future global score system.
## Emitted once per completed round with the stable minigame id and candy count.
signal round_completed(minigame_id: StringName, collected_candies: int)
## Emitted when a future host scene calls [method abandon].
signal minigame_abandoned()


enum DifficultyPhase {
    ONE,
    TWO,
    THREE,
}


const FALLING_CANDY_SCENE: PackedScene = preload(
    "res://scenes/minigames/candy_bucket/FallingCandy.tscn"
)
const PLAYER_SIDE_MARGIN: float = 72.0
const SPAWN_SIDE_MARGIN: float = 42.0
const MIN_SPAWN_SEPARATION: float = 96.0
const MAX_SPAWN_POSITION_ATTEMPTS: int = 10
const CANDY_HORIZONTAL_HALF_EXTENT: float = 52.0
const ROUND_DURATION: float = 60.0
const MINIGAME_ID: StringName = &"candy_bucket"
const LOBBY_SCENE_PATH: String = "res://scenes/levels/main.tscn"
const LOBBY_RETURN_META: StringName = &"candy_bucket_return_to_door"
const MAGIC_APPEARANCES_PER_ROUND: int = 2
const MAGIC_BOOST_DURATION: float = 5.0
const MAGIC_FIRST_SPAWN_WINDOW: Vector2 = Vector2(8.0, 28.0)
const MAGIC_SECOND_SPAWN_WINDOW: Vector2 = Vector2(32.0, 52.0)
const MAGIC_OSCILLATION_AMPLITUDE: float = 28.0
const MAGIC_OSCILLATION_FREQUENCY: float = 0.55


@export_category("Round")
@export_range(1, 5, 1) var preparation_seconds: int = 3

@export_category("Player")
@export_range(100.0, 1000.0, 10.0) var player_speed: float = 520.0
@export_range(0.5, 10.0, 0.1) var poison_duration: float = 3.0

@export_category("Difficulty thresholds")
@export_range(1.0, 59.0, 1.0) var phase_two_starts_at: float = 40.0
@export_range(1.0, 39.0, 1.0) var phase_three_starts_at: float = 20.0

@export_category("Phase 1")
@export_range(0.1, 3.0, 0.05) var phase_one_spawn_interval: float = 0.90
@export_range(0.0, 1.0, 0.01) var phase_one_poison_chance: float = 0.10
@export_range(50.0, 600.0, 5.0) var phase_one_fall_speed: float = 225.0

@export_category("Phase 2")
@export_range(0.1, 3.0, 0.05) var phase_two_spawn_interval: float = 0.65
@export_range(0.0, 1.0, 0.01) var phase_two_poison_chance: float = 0.20
@export_range(50.0, 600.0, 5.0) var phase_two_fall_speed: float = 275.0

@export_category("Phase 3")
@export_range(0.1, 3.0, 0.05) var phase_three_spawn_interval: float = 0.45
@export_range(0.0, 1.0, 0.01) var phase_three_poison_chance: float = 0.25
@export_range(50.0, 600.0, 5.0) var phase_three_fall_speed: float = 335.0

@export_category("Spawn fairness")
@export_range(0.0, 0.45, 0.01) var spawn_interval_jitter: float = 0.16

@export_category("Candy size variation")
@export_range(0.5, 1.0, 0.01) var candy_scale_min: float = 0.85
@export_range(0.5, 1.0, 0.01) var candy_scale_max: float = 1.0

@export_category("Healthy candy movement")
@export_range(0.5, 1.5, 0.01) var healthy_speed_factor_min: float = 0.85
@export_range(0.5, 1.5, 0.01) var healthy_speed_factor_max: float = 1.15

@export_category("Toxic candy movement")
@export_range(0.25, 1.0, 0.01) var toxic_speed_factor_min: float = 0.55
@export_range(0.25, 1.0, 0.01) var toxic_speed_factor_max: float = 0.75
@export_range(0.0, 100.0, 1.0) var toxic_oscillation_amplitude_min: float = 20.0
@export_range(0.0, 100.0, 1.0) var toxic_oscillation_amplitude_max: float = 45.0
@export_range(0.05, 1.0, 0.01) var toxic_oscillation_frequency_min: float = 0.18
@export_range(0.05, 1.0, 0.01) var toxic_oscillation_frequency_max: float = 0.30

@export_category("Result audio")
@export var round_end_jingle: AudioStream


var _round_active: bool = false
var _round_generation: int = 0
var _remaining_time: float = 60.0
var _poison_remaining: float = 0.0
var _magic_boost_remaining: float = 0.0
var _collected_candies: int = 0
var _last_spawn_x: float = -1000.0
var _magic_spawn_times: Array[float] = []
var _next_magic_spawn_index: int = 0
var _return_transition_started: bool = false

@onready var player: CandyBucketPlayer = %Player
@onready var candies: Node2D = %Candies
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var result_audio_player: AudioStreamPlayer = %ResultAudioPlayer
@onready var toxic_sfx_player: AudioStreamPlayer = %ToxicSfxPlayer
@onready var toxic_gas_effect: CandyBucketToxicGasEffect = %ToxicGasEffect
@onready var spawn_timer: Timer = %SpawnTimer
@onready var time_label: Label = %TimeLabel
@onready var candy_label: Label = %CandyLabel
@onready var poison_label: Label = %PoisonLabel
@onready var magic_boost_label: Label = %MagicBoostLabel
@onready var instruction_panel: Control = %InstructionPanel
@onready var countdown_label: Label = %CountdownLabel
@onready var result_overlay: Control = %ResultOverlay
@onready var result_title: Label = %ResultTitle
@onready var result_details: Label = %ResultDetails
@onready var return_lobby_button: Button = %ReturnLobbyButton


func _ready() -> void:
    get_viewport().size_changed.connect(_update_layout)
    player.candy_entered.connect(_on_player_candy_entered)
    music_player.finished.connect(_on_music_finished)
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    return_lobby_button.pressed.connect(_on_return_lobby_button_pressed)
    _update_layout()
    _begin_preparation()


func _physics_process(delta: float) -> void:
    if not _round_active:
        return

    _update_status_effects(delta)
    _remaining_time = maxf(0.0, _remaining_time - delta)
    _update_hud()

    if is_zero_approx(_remaining_time):
        _finish_round()


## Stops the standalone round and notifies a future host scene.
func abandon() -> void:
    if not _round_active:
        return

    _stop_gameplay()
    minigame_abandoned.emit()


func _begin_preparation() -> void:
    _round_generation += 1
    _round_active = false
    music_player.stop()
    result_audio_player.stop()
    toxic_sfx_player.stop()
    toxic_gas_effect.stop()
    _remaining_time = ROUND_DURATION
    _poison_remaining = 0.0
    _magic_boost_remaining = 0.0
    _collected_candies = 0
    _last_spawn_x = -1000.0
    _prepare_magic_spawn_times()

    spawn_timer.stop()
    _clear_candies()
    result_overlay.hide()
    countdown_label.show()
    instruction_panel.show()
    _reset_player()
    _configure_hud()
    _run_preparation_countdown(_round_generation)


func _run_preparation_countdown(round_id: int) -> void:
    for count: int in range(preparation_seconds, 0, -1):
        if round_id != _round_generation:
            return
        countdown_label.text = str(count)
        await get_tree().create_timer(1.0).timeout

    if round_id != _round_generation:
        return

    countdown_label.text = "GO !"
    _start_round()
    await get_tree().create_timer(0.7).timeout

    if round_id == _round_generation and _round_active:
        countdown_label.hide()


func _start_round() -> void:
    _round_active = true
    instruction_panel.hide()
    player.set_movement_enabled(true)
    player.set_collection_enabled(true)
    music_player.play(0.0)
    _spawn_candy()
    _schedule_next_spawn()


func _reset_player() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var start_position: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y - 42.0)
    player.configure(player_speed, PLAYER_SIDE_MARGIN, viewport_size.x - PLAYER_SIDE_MARGIN)
    player.reset_state(start_position)


func _configure_hud() -> void:
    poison_label.modulate = Color("d8d2df")
    magic_boost_label.modulate = Color("ffd166")
    _update_hud()


func _update_hud() -> void:
    time_label.text = "Temps : %.2f s" % _remaining_time
    candy_label.text = "CANDY : %d" % _collected_candies

    if _poison_remaining > 0.0:
        poison_label.text = "Poison actif : %.1f s" % _poison_remaining
        poison_label.modulate = Color("a8ff7a")
    else:
        poison_label.text = "Poison : inactif"
        poison_label.modulate = Color("d8d2df")

    magic_boost_label.visible = _magic_boost_remaining > 0.0
    magic_boost_label.text = "Vitesse +50 %% : %.1f s" % _magic_boost_remaining


func _update_layout() -> void:
    if not is_instance_valid(player):
        return

    var viewport_size: Vector2 = get_viewport_rect().size
    player.set_horizontal_limits(PLAYER_SIDE_MARGIN, viewport_size.x - PLAYER_SIDE_MARGIN)
    player.global_position.y = viewport_size.y - 42.0


func _on_spawn_timer_timeout() -> void:
    if not _round_active:
        return

    _spawn_candy()
    _schedule_next_spawn()


func _spawn_candy() -> void:
    var phase: DifficultyPhase = _current_phase()
    var new_node: Node = FALLING_CANDY_SCENE.instantiate()
    assert(new_node is CandyBucketFallingCandy)
    var candy: CandyBucketFallingCandy = new_node as CandyBucketFallingCandy
    var magic: bool = _should_spawn_magic()
    var poisoned: bool = not magic and randf() < _poison_chance_for_phase(phase)
    var appearance_index: int = (
        CandyBucketCandyVisual.MAGIC_APPEARANCE_INDEX
        if magic
        else _pick_appearance_index(poisoned)
    )
    var size_factor: float = _random_between(candy_scale_min, candy_scale_max)
    var reference_speed: float = _fall_speed_for_phase(phase)
    var candy_fall_speed: float = _pick_fall_speed(reference_speed, poisoned)
    var oscillation_amplitude: float = _pick_oscillation_amplitude(poisoned, magic)
    var oscillation_frequency: float = _pick_oscillation_frequency(poisoned, magic)
    var spawn_x: float = _pick_spawn_x(oscillation_amplitude)
    var horizontal_limits := Vector2(
        CANDY_HORIZONTAL_HALF_EXTENT,
        get_viewport_rect().size.x - CANDY_HORIZONTAL_HALF_EXTENT
    )
    var oscillation_direction: float = -1.0 if randf() < 0.5 else 1.0

    candies.add_child(candy)
    candy.global_position = Vector2(spawn_x, -38.0)
    candy.configure(
        appearance_index,
        candy_fall_speed,
        size_factor,
        horizontal_limits,
        oscillation_amplitude,
        oscillation_frequency,
        oscillation_direction
    )
    _last_spawn_x = spawn_x


func _schedule_next_spawn() -> void:
    var mean_interval: float = _spawn_interval_for_phase(_current_phase())
    var jitter_multiplier: float = randf_range(
        1.0 - spawn_interval_jitter,
        1.0 + spawn_interval_jitter
    )
    spawn_timer.start(mean_interval * jitter_multiplier)


func _pick_spawn_x(horizontal_clearance: float = 0.0) -> float:
    var left_limit := maxf(
        SPAWN_SIDE_MARGIN,
        CANDY_HORIZONTAL_HALF_EXTENT + horizontal_clearance
    )
    var right_limit := get_viewport_rect().size.x - left_limit
    var candidate: float = randf_range(left_limit, right_limit)

    for _attempt: int in MAX_SPAWN_POSITION_ATTEMPTS:
        candidate = randf_range(left_limit, right_limit)
        if _is_spawn_position_clear(candidate):
            return candidate

    return candidate


func _is_spawn_position_clear(candidate_x: float) -> bool:
    if absf(candidate_x - _last_spawn_x) < MIN_SPAWN_SEPARATION:
        return false

    for node: Node in get_tree().get_nodes_in_group(&"candy_bucket_falling_candies"):
        if node is CandyBucketFallingCandy:
            var candy: CandyBucketFallingCandy = node as CandyBucketFallingCandy
            if candy.global_position.y < 120.0:
                if absf(candidate_x - candy.global_position.x) < MIN_SPAWN_SEPARATION:
                    return false
    return true


func _on_player_candy_entered(area: Area2D) -> void:
    if not _round_active or not area is CandyBucketFallingCandy:
        return

    var candy: CandyBucketFallingCandy = area as CandyBucketFallingCandy
    if not candy.collect():
        return

    if candy.is_poison:
        _apply_poison()
        return

    if candy.is_magic:
        _apply_magic_boost()

    _collected_candies += 1
    _update_hud()


func _apply_poison() -> void:
    _play_toxic_reaction()
    _poison_remaining = poison_duration
    player.set_poisoned(true)
    _update_hud()


func _play_toxic_reaction() -> void:
    toxic_sfx_player.play(0.0)
    toxic_gas_effect.global_position = player.global_position + Vector2(0.0, -28.0)
    toxic_gas_effect.play()


func _update_poison(delta: float) -> void:
    if _poison_remaining <= 0.0:
        return

    _poison_remaining = maxf(0.0, _poison_remaining - delta)
    if is_zero_approx(_poison_remaining):
        player.set_poisoned(false)


func _apply_magic_boost() -> void:
    _magic_boost_remaining = MAGIC_BOOST_DURATION
    player.set_magic_boosted(true)
    _update_hud()


func _update_status_effects(delta: float) -> void:
    _update_poison(delta)
    _update_magic_boost(delta)


func _update_magic_boost(delta: float) -> void:
    if _magic_boost_remaining <= 0.0:
        return

    _magic_boost_remaining = maxf(0.0, _magic_boost_remaining - delta)
    if is_zero_approx(_magic_boost_remaining):
        player.set_magic_boosted(false)


func _finish_round() -> void:
    if not _round_active:
        return

    _stop_gameplay()
    SceneTransition.run_fade(_prepare_round_result, _reveal_round_result)


func _prepare_round_result() -> void:
    result_title.text = "TEMPS ÉCOULÉ !"
    result_title.modulate = Color("ffd166")
    result_details.text = "BONBONS RÉCOLTÉS : %d" % _collected_candies
    return_lobby_button.show()
    _show_result(return_lobby_button)
    round_completed.emit(MINIGAME_ID, _collected_candies)


func _reveal_round_result() -> void:
    _play_result_sound(round_end_jingle)


func _stop_gameplay() -> void:
    _round_active = false
    music_player.stop()
    result_audio_player.stop()
    toxic_sfx_player.stop()
    toxic_gas_effect.stop()
    spawn_timer.stop()
    player.set_movement_enabled(false)
    player.set_collection_enabled(false)
    player.set_poisoned(false)
    player.set_magic_boosted(false)
    _poison_remaining = 0.0
    _magic_boost_remaining = 0.0
    countdown_label.hide()
    _freeze_candies()
    _update_hud()


func _show_result(focus_button: Button) -> void:
    result_overlay.show()
    focus_button.grab_focus()


func _on_return_lobby_button_pressed() -> void:
    if _return_transition_started:
        return

    _stop_gameplay()
    ProgressionService.complete_world(MINIGAME_ID, _collected_candies)
    if not SceneTransition.change_scene(LOBBY_SCENE_PATH, _mark_lobby_return):
        return

    _return_transition_started = true
    return_lobby_button.disabled = true


func _mark_lobby_return() -> void:
    get_tree().set_meta(LOBBY_RETURN_META, true)


func _on_music_finished() -> void:
    if _round_active:
        music_player.play(0.0)


func _play_result_sound(sound: AudioStream) -> void:
    if sound == null:
        return

    result_audio_player.stream = sound
    result_audio_player.play(0.0)


func _clear_candies() -> void:
    for child: Node in candies.get_children():
        child.queue_free()


func _freeze_candies() -> void:
    for child: Node in candies.get_children():
        if child is CandyBucketFallingCandy:
            var candy: CandyBucketFallingCandy = child as CandyBucketFallingCandy
            candy.freeze()


func _current_phase() -> DifficultyPhase:
    if _remaining_time > phase_two_starts_at:
        return DifficultyPhase.ONE
    if _remaining_time > phase_three_starts_at:
        return DifficultyPhase.TWO
    return DifficultyPhase.THREE


func _spawn_interval_for_phase(phase: DifficultyPhase) -> float:
    match phase:
        DifficultyPhase.ONE:
            return phase_one_spawn_interval
        DifficultyPhase.TWO:
            return phase_two_spawn_interval
        DifficultyPhase.THREE:
            return phase_three_spawn_interval
        _:
            return phase_one_spawn_interval


func _poison_chance_for_phase(phase: DifficultyPhase) -> float:
    match phase:
        DifficultyPhase.ONE:
            return phase_one_poison_chance
        DifficultyPhase.TWO:
            return phase_two_poison_chance
        DifficultyPhase.THREE:
            return phase_three_poison_chance
        _:
            return phase_one_poison_chance


func _fall_speed_for_phase(phase: DifficultyPhase) -> float:
    match phase:
        DifficultyPhase.ONE:
            return phase_one_fall_speed
        DifficultyPhase.TWO:
            return phase_two_fall_speed
        DifficultyPhase.THREE:
            return phase_three_fall_speed
        _:
            return phase_one_fall_speed


func _pick_appearance_index(poisoned: bool) -> int:
    if poisoned:
        return CandyBucketCandyVisual.TOXIC_APPEARANCE_INDEX
    return CandyBucketCandyVisual.HEALTHY_APPEARANCE_INDICES.pick_random()


func _prepare_magic_spawn_times() -> void:
    _magic_spawn_times = [
        randf_range(MAGIC_FIRST_SPAWN_WINDOW.x, MAGIC_FIRST_SPAWN_WINDOW.y),
        randf_range(MAGIC_SECOND_SPAWN_WINDOW.x, MAGIC_SECOND_SPAWN_WINDOW.y),
    ]
    _next_magic_spawn_index = 0


func _should_spawn_magic() -> bool:
    if _next_magic_spawn_index >= MAGIC_APPEARANCES_PER_ROUND:
        return false

    var elapsed_time: float = ROUND_DURATION - _remaining_time
    if elapsed_time < _magic_spawn_times[_next_magic_spawn_index]:
        return false

    _next_magic_spawn_index += 1
    return true


func _pick_fall_speed(reference_speed: float, poisoned: bool) -> float:
    var minimum_factor := toxic_speed_factor_min if poisoned else healthy_speed_factor_min
    var maximum_factor := toxic_speed_factor_max if poisoned else healthy_speed_factor_max
    return reference_speed * _random_between(minimum_factor, maximum_factor)


func _pick_oscillation_amplitude(poisoned: bool, magic: bool) -> float:
    if magic:
        return MAGIC_OSCILLATION_AMPLITUDE
    if not poisoned:
        return 0.0
    return _random_between(
        toxic_oscillation_amplitude_min,
        toxic_oscillation_amplitude_max
    )


func _pick_oscillation_frequency(poisoned: bool, magic: bool) -> float:
    if magic:
        return MAGIC_OSCILLATION_FREQUENCY
    if not poisoned:
        return 0.0
    return _random_between(
        toxic_oscillation_frequency_min,
        toxic_oscillation_frequency_max
    )


func _random_between(first_value: float, second_value: float) -> float:
    return randf_range(
        minf(first_value, second_value),
        maxf(first_value, second_value)
    )
