class_name FactionFightEnvironment
extends Node3D

const STORM_AUDIO: AudioStream = preload("res://assets/audio/orage.mp3")

@export_range(3.0, 40.0, 0.5) var lightning_delay_min: float = 22.0
@export_range(3.0, 45.0, 0.5) var lightning_delay_max: float = 32.0
@export_range(-30.0, 0.0, 1.0) var music_volume_db: float = -12.0

@onready var lightning: DirectionalLight3D = %Lightning
@onready var music: AudioStreamPlayer = get_node_or_null("ChaseweenMusic") as AudioStreamPlayer
@onready var storm_audio: AudioStreamPlayer = get_node_or_null("ChaseweenStormAudio") as AudioStreamPlayer
@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var _random := RandomNumberGenerator.new()
var _storm_phase: int = 0
var _storm_intensity: float = 0.0
var _storm_volume_db: float = -80.0
var _lightning_visuals: Node3D
var _flash_tween: Tween
var _storm_volume_tween: Tween
var _lightning_timer: Timer
var _thunder_timer: Timer


func _ready() -> void:
	_random.randomize()
	_ensure_storm_audio()
	_create_storm_timers()
	_create_lightning_visuals()
	_start_music()
	set_storm_phase(0)


func _exit_tree() -> void:
	stop_storm()
	if is_instance_valid(music):
		music.stop()


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


func _ensure_storm_audio() -> void:
	if is_instance_valid(storm_audio):
		return
	storm_audio = AudioStreamPlayer.new()
	storm_audio.name = "ChaseweenStormAudio"
	storm_audio.stream = STORM_AUDIO
	storm_audio.volume_db = -80.0
	storm_audio.bus = &"SFX"
	add_child(storm_audio)


func _create_storm_timers() -> void:
	_lightning_timer = Timer.new()
	_lightning_timer.name = "LightningTimer"
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_on_lightning_timeout)
	add_child(_lightning_timer)
	_thunder_timer = Timer.new()
	_thunder_timer.name = "ThunderTimer"
	_thunder_timer.one_shot = true
	_thunder_timer.timeout.connect(_on_thunder_timeout)
	add_child(_thunder_timer)


func set_storm_phase(phase: int) -> void:
	_storm_phase = clampi(phase, 0, 3)
	match _storm_phase:
		0:
			_configure_storm(0.0, 22.0, 32.0, -80.0)
		1:
			_configure_storm(0.34, 13.0, 21.0, -22.0)
		2:
			_configure_storm(0.68, 7.0, 12.0, -15.0)
		3:
			_configure_storm(1.0, 3.8, 7.0, -11.0)
		_:
			push_warning("FactionFight: phase d’orage inconnue %d" % phase)


func _configure_storm(intensity: float, delay_min: float, delay_max: float, volume_db: float) -> void:
	_storm_intensity = intensity
	lightning_delay_min = delay_min
	lightning_delay_max = delay_max
	_storm_volume_db = volume_db
	if not is_instance_valid(storm_audio):
		return
	if _storm_volume_tween != null and _storm_volume_tween.is_valid():
		_storm_volume_tween.kill()
	if is_instance_valid(_lightning_timer):
		_lightning_timer.stop()
	if is_instance_valid(_thunder_timer):
		_thunder_timer.stop()
	if _storm_phase == 0:
		storm_audio.stop()
		storm_audio.volume_db = -80.0
		return
	_schedule_next_lightning()
	_storm_volume_tween = create_tween()
	_storm_volume_tween.tween_property(storm_audio, "volume_db", _storm_volume_db, 1.2)


func stop_storm() -> void:
	_storm_phase = 0
	_storm_intensity = 0.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _storm_volume_tween != null and _storm_volume_tween.is_valid():
		_storm_volume_tween.kill()
	if is_instance_valid(_lightning_timer):
		_lightning_timer.stop()
	if is_instance_valid(_thunder_timer):
		_thunder_timer.stop()
	if is_instance_valid(lightning):
		lightning.light_energy = 0.0
	_hide_lightning_visuals()
	if is_instance_valid(storm_audio):
		storm_audio.stop()
		storm_audio.volume_db = -80.0


func _schedule_next_lightning() -> void:
	if not is_instance_valid(_lightning_timer):
		return
	_lightning_timer.start(_random.randf_range(lightning_delay_min, lightning_delay_max))


func _on_lightning_timeout() -> void:
	if _storm_phase > 0:
		_flash_lightning()
	_schedule_next_lightning()


func _flash_lightning() -> void:
	if _storm_intensity <= 0.0 or not is_instance_valid(lightning):
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	lightning.light_color = Color(0.53, 0.46, 1.0).lerp(Color(0.38, 0.68, 1.0), _random.randf_range(0.15, 0.55))
	_position_lightning_visuals()
	_show_lightning_visuals()
	var first_energy := lerpf(4.2, 7.2, _storm_intensity)
	var second_energy := first_energy * 0.52
	_flash_tween = create_tween()
	_flash_tween.tween_property(lightning, "light_energy", first_energy, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(lightning, "light_energy", 0.35, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash_tween.tween_callback(_hide_lightning_visuals)
	_flash_tween.tween_interval(0.12)
	_flash_tween.tween_callback(_show_lightning_visuals)
	_flash_tween.tween_property(lightning, "light_energy", second_energy, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(lightning, "light_energy", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash_tween.tween_callback(_hide_lightning_visuals)
	_schedule_thunder()


func _schedule_thunder() -> void:
	if not is_instance_valid(storm_audio) or storm_audio.stream == null or storm_audio.playing or not is_instance_valid(_thunder_timer):
		return
	var delay := lerpf(1.0, 0.25, _storm_intensity) + _random.randf_range(0.08, 0.38)
	_thunder_timer.start(delay)


func _on_thunder_timeout() -> void:
	if _storm_phase == 0 or not is_instance_valid(storm_audio) or storm_audio.playing:
		return
	storm_audio.volume_db = _storm_volume_db
	storm_audio.pitch_scale = _random.randf_range(0.96, 1.03)
	storm_audio.play()


func _create_lightning_visuals() -> void:
	_lightning_visuals = Node3D.new()
	_lightning_visuals.name = "StormLightningVisuals"
	add_child(_lightning_visuals)
	_lightning_visuals.add_child(_create_lightning_bolt("VioletBolt", Color(0.68, 0.36, 1.0, 0.94), 0.34))
	_lightning_visuals.add_child(_create_lightning_bolt("ElectricBlueBolt", Color(0.28, 0.68, 1.0, 0.82), 0.23))
	_hide_lightning_visuals()


func _create_lightning_bolt(bolt_name: String, color: Color, width: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 4.2
	var mesh := ImmediateMesh.new()
	var points: Array[Vector2] = [
		Vector2(0.0, 7.2),
		Vector2(-0.42, 5.9),
		Vector2(0.18, 4.75),
		Vector2(-0.5, 3.45),
		Vector2(0.12, 2.3),
		Vector2(-0.3, 1.15),
		Vector2(0.0, 0.0),
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index: int in points.size() - 1:
		_add_bolt_segment(mesh, points[index], points[index + 1], width * (1.0 - float(index) * 0.09))
	mesh.surface_end()
	var bolt := MeshInstance3D.new()
	bolt.name = bolt_name
	bolt.mesh = mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bolt


func _add_bolt_segment(mesh: ImmediateMesh, start: Vector2, end: Vector2, width: float) -> void:
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x) * width
	var a := Vector3(start.x + normal.x, start.y + normal.y, 0.0)
	var b := Vector3(start.x - normal.x, start.y - normal.y, 0.0)
	var c := Vector3(end.x + normal.x, end.y + normal.y, 0.0)
	var d := Vector3(end.x - normal.x, end.y - normal.y, 0.0)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(d)


func _position_lightning_visuals() -> void:
	if not is_instance_valid(_lightning_visuals):
		return
	var origin := global_position + Vector3.UP * 12.0
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if is_instance_valid(player):
		forward = -player.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		right = player.global_basis.x
		right.y = 0.0
		right = right.normalized()
		origin = player.global_position + forward * 18.0 + Vector3.UP * 9.0
	_lightning_visuals.global_position = origin + right * _random.randf_range(-9.0, 9.0)
	var bolts := _lightning_visuals.get_children()
	for index: int in bolts.size():
		var bolt := bolts[index] as MeshInstance3D
		bolt.position = Vector3(float(index) * 4.5 - 2.25, _random.randf_range(-1.0, 2.5), float(index) * -0.5)
		var scale_factor := _random.randf_range(0.82, 1.18) * lerpf(0.86, 1.12, _storm_intensity)
		bolt.scale = Vector3.ONE * scale_factor


func _show_lightning_visuals() -> void:
	if is_instance_valid(_lightning_visuals):
		_lightning_visuals.visible = true


func _hide_lightning_visuals() -> void:
	if is_instance_valid(_lightning_visuals):
		_lightning_visuals.visible = false
