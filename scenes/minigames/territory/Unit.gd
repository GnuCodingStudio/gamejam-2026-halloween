class_name Unit
extends Node3D

signal died(unit: Unit)

const GROUP := &"units"
const BLEND_TIME := 0.15
const SITE_REACHED_DISTANCE := 1.0
const SITE_DEFENDED_DISTANCE := 2.5
const FIELD_HALF_LENGTH := 24.0
const TINT_ALPHA := 0.3
const PUNCH_SCALE := 1.15
const PUNCH_TIME := 0.08

@onready var _model_holder: Node3D = %Model
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

var faction: Faction.Side
var stats: UnitStats
var health: float

var _attack_cooldown := 0.0
var _current_animation := &""


func setup(unit_stats: UnitStats, side: Faction.Side) -> void:
	stats = unit_stats
	faction = side
	health = stats.max_health


func _ready() -> void:
	add_to_group(GROUP)
	_spawn_model()


func take_damage(amount: float) -> void:
	health -= amount
	if health > 0.0:
		return
	remove_from_group(GROUP)
	died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var target := _find_target_in_range()
	if target != null:
		_fight(target)
	else:
		_march(delta)


func _heading() -> float:
	return 1.0 if faction == Faction.Side.PLAYER else -1.0


func _spawn_model() -> void:
	var model := stats.model_scene.instantiate()
	_model_holder.add_child(model)
	_model_holder.rotation.y = _heading() * PI / 2.0
	_animation_player.root_node = _animation_player.get_path_to(model)
	_tint(model)
	_play(&"idle")


func _tint(model: Node) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Faction.color_of(faction)
	overlay.albedo_color.a = TINT_ALPHA
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = overlay


func _play(animation: StringName) -> void:
	if animation == _current_animation:
		return
	_current_animation = animation
	_animation_player.play(animation, BLEND_TIME)


func _find_target_in_range() -> Unit:
	var best: Unit = null
	var best_distance := INF
	for other in _enemy_units():
		var distance := absf(other.global_position.x - global_position.x)
		if distance <= stats.attack_range and distance < best_distance:
			best = other
			best_distance = distance
	return best


func _enemy_units() -> Array[Unit]:
	var enemies: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit
		if other != null and other.faction != faction:
			enemies.append(other)
	return enemies


func _fight(target: Unit) -> void:
	_play(&"idle")
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = stats.attack_interval
	target.take_damage(stats.damage)
	_punch()


func _punch() -> void:
	var tween := create_tween()
	tween.tween_property(_model_holder, "scale", Vector3.ONE * PUNCH_SCALE, PUNCH_TIME)
	tween.tween_property(_model_holder, "scale", Vector3.ONE, PUNCH_TIME)


func _march(delta: float) -> void:
	_play(&"run")
	global_position.x += _heading() * stats.move_speed * delta
	_try_capture_sites()
	if absf(global_position.x) > FIELD_HALF_LENGTH:
		queue_free()


func _try_capture_sites() -> void:
	for node in get_tree().get_nodes_in_group(Site.GROUP):
		var site := node as Site
		if site.faction == faction:
			continue
		if absf(site.global_position.x - global_position.x) > SITE_REACHED_DISTANCE:
			continue
		if not _is_defended(site):
			site.flip_to(faction)


func _is_defended(site: Site) -> bool:
	for other in _enemy_units():
		if absf(other.global_position.x - site.global_position.x) <= SITE_DEFENDED_DISTANCE:
			return true
	return false
