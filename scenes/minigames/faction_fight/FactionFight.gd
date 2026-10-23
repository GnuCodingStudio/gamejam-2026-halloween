class_name FactionFightEnvironment
extends Node3D


@export_range(3.0, 20.0, 0.5) var lightning_delay_min: float = 6.0
@export_range(3.0, 25.0, 0.5) var lightning_delay_max: float = 13.0
@export_range(-30.0, 0.0, 1.0) var music_volume_db: float = -12.0

@onready var lightning: DirectionalLight3D = %Lightning
@onready var music: AudioStreamPlayer = get_node_or_null("ChaseweenMusic") as AudioStreamPlayer

var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_start_music()
	_run_lightning_loop()


func _start_music() -> void:
	if not is_instance_valid(music):
		push_error("FactionFight: ChaseweenMusic AudioStreamPlayer is missing.")
		return
	if music.stream == null:
		push_error("FactionFight: ChaseweenMusic has no audio stream.")
		return
	var local_stream: AudioStreamMP3 = music.stream.duplicate() as AudioStreamMP3
	if local_stream == null:
		push_error("FactionFight: ChaseweenMusic stream is not an MP3 resource.")
		return
	local_stream.loop = true
	music.stream = local_stream
	music.volume_db = music_volume_db
	music.play()


func _run_lightning_loop() -> void:
	while is_inside_tree():
		var delay: float = _random.randf_range(lightning_delay_min, lightning_delay_max)
		await get_tree().create_timer(delay).timeout
		_flash_lightning()


func _flash_lightning() -> void:
	var flash := create_tween()
	flash.tween_property(lightning, "light_energy", 2.8, 0.04)
	flash.tween_property(lightning, "light_energy", 0.0, 0.10)
	flash.tween_interval(0.08)
	flash.tween_property(lightning, "light_energy", 1.6, 0.04)
	flash.tween_property(lightning, "light_energy", 0.0, 0.18)
