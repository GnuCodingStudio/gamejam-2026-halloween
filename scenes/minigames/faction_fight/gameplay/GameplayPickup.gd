class_name FactionFightPickup
extends Node3D

signal candy_collected(pickup: FactionFightPickup)

const CRYSTALBERRY_SCENE: PackedScene = preload("res://objects/candy_crystalberry.tscn")
const PUMPKIN_SCENE: PackedScene = preload("res://objects/candy_pumpkin.tscn")

enum Kind {
	CANDY,
	ITEM,
	CHEST,
	KEY_ITEM,
	DEVICE,
}

var kind: int = Kind.CANDY
var display_name: String = "CANDY"
var candy_value: int = 0
var item_id: StringName = &""
var item_charges: int = 0
var auto_collect: bool = false
var collected: bool = false
var shared_candy_scene_path: String = ""
var required_item_id: StringName = &""
var reward_id: StringName = &""
var mission_id: StringName = &""

var _base_y: float
var _time: float = 0.0
var _shared_candy: Candy
var _chest_lid_pivot: Node3D


func configure(
	pickup_kind: int,
	pickup_name: String,
	position_3d: Vector3,
	value: int = 0,
	new_item_id: StringName = &"",
	charges: int = 0,
	candy_variant: int = 0,
	new_required_item_id: StringName = &"",
	new_reward_id: StringName = &"",
	new_mission_id: StringName = &""
) -> void:
	kind = pickup_kind
	display_name = pickup_name
	global_position = position_3d
	_base_y = position_3d.y
	candy_value = value
	item_id = new_item_id
	item_charges = charges
	required_item_id = new_required_item_id
	reward_id = new_reward_id
	mission_id = new_mission_id
	auto_collect = kind == Kind.CANDY
	_build_visual(candy_variant)
	set_process(kind != Kind.CANDY)


func collect_once() -> bool:
	if collected or kind == Kind.CANDY:
		return false
	collected = true
	set_process(false)
	if kind == Kind.CHEST:
		_open_chest()
		return true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.35, 0.12)
	tween.tween_property(self, "position:y", position.y + 0.8, 0.22)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.16)
	tween.finished.connect(queue_free)
	return true


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.5) * 0.12
	rotation.y += delta * 0.75


func stop_gameplay() -> void:
	set_process(false)
	if is_instance_valid(_shared_candy):
		_shared_candy.set_deferred(&"monitoring", false)


func _build_visual(candy_variant: int) -> void:
	match kind:
		Kind.CANDY:
			_build_candy(candy_variant)
		Kind.ITEM:
			_build_item()
		Kind.CHEST:
			_build_chest()
		Kind.KEY_ITEM:
			_build_key_item()
		Kind.DEVICE:
			_build_device()
	if kind != Kind.CANDY:
		_create_label()


func _build_candy(candy_variant: int) -> void:
	var candy_scene := CRYSTALBERRY_SCENE if candy_variant % 2 == 0 else PUMPKIN_SCENE
	_shared_candy = candy_scene.instantiate() as Candy
	if _shared_candy == null:
		push_error("FactionFight: impossible d’instancier le CANDY partagé.")
		return
	shared_candy_scene_path = candy_scene.resource_path
	add_child(_shared_candy)
	_shared_candy.collected.connect(_on_shared_candy_collected)


func _on_shared_candy_collected() -> void:
	if collected:
		return
	collected = true
	set_process(false)
	candy_collected.emit(self)
	get_tree().create_timer(0.8).timeout.connect(queue_free)


func _build_item() -> void:
	match item_id:
		&"candy_cane":
			_add_capsule(Vector3(0.0, 0.5, 0.0), Vector3(0.18, 0.65, 0.18), Color(1.0, 0.18, 0.24))
			_add_capsule(Vector3(0.0, 1.05, 0.0), Vector3(0.28, 0.3, 0.18), Color.WHITE, Vector3(0.0, 0.0, 0.55))
		&"sugar_spray":
			_add_cylinder(Vector3(0.0, 0.42, 0.0), Vector3(0.52, 0.84, 0.52), Color(0.25, 0.92, 1.0))
			_add_cylinder(Vector3(0.0, 0.95, 0.0), Vector3(0.2, 0.28, 0.2), Color(1.0, 0.42, 0.75))
		&"caramel_shield":
			var shield := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.72
			mesh.bottom_radius = 0.72
			mesh.height = 0.16
			mesh.material = _make_material(Color(0.88, 0.42, 0.08), 1.8)
			shield.mesh = mesh
			shield.rotation.x = PI * 0.5
			shield.position.y = 0.72
			add_child(shield)


func _build_chest() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.15, 0.65, 0.78)
	base_mesh.material = _make_material(Color(0.42, 0.17, 0.05), 0.2)
	base.mesh = base_mesh
	base.position.y = 0.36
	add_child(base)
	_chest_lid_pivot = Node3D.new()
	_chest_lid_pivot.position = Vector3(0.0, 0.69, 0.35)
	add_child(_chest_lid_pivot)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.22, 0.22, 0.84)
	lid_mesh.material = _make_material(Color(0.95, 0.58, 0.08), 1.0)
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.1, -0.35)
	_chest_lid_pivot.add_child(lid)


func _open_chest() -> void:
	var tween := create_tween()
	if _chest_lid_pivot != null:
		tween.tween_property(_chest_lid_pivot, "rotation:x", -1.25, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.85)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.18, 0.2)
	tween.tween_property(self, "position:y", position.y + 0.35, 0.2)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.18)
	tween.finished.connect(queue_free)


func _build_key_item() -> void:
	var core := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.42
	mesh.height = 0.95
	mesh.radial_segments = 8
	mesh.material = _make_material(_key_item_color(), 2.0)
	core.mesh = mesh
	core.position.y = 0.55
	core.rotation.z = PI * 0.5 if item_id == &"caramel_key" else 0.0
	add_child(core)
	var halo := OmniLight3D.new()
	halo.light_color = _key_item_color()
	halo.light_energy = 0.65
	halo.omni_range = 2.2
	halo.position.y = 0.7
	add_child(halo)


func _build_device() -> void:
	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.35, 1.5, 0.75)
	mesh.material = _make_material(Color(0.18, 0.08, 0.28), 0.35)
	base.mesh = mesh
	base.position.y = 0.75
	add_child(base)
	var rune := MeshInstance3D.new()
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 0.2
	rune_mesh.outer_radius = 0.38
	rune_mesh.material = _make_material(Color(0.72, 0.25, 1.0), 2.4)
	rune.mesh = rune_mesh
	rune.position = Vector3(0.0, 0.85, -0.42)
	rune.rotation.x = PI * 0.5
	add_child(rune)


func _key_item_color() -> Color:
	match item_id:
		&"caramel_key":
			return Color(1.0, 0.48, 0.08)
		&"sugar_crystal":
			return Color(0.65, 0.28, 1.0)
		&"syrup_capsule":
			return Color(1.0, 0.18, 0.55)
		&"spectral_badge":
			return Color(0.2, 0.85, 1.0)
		_:
			return Color.WHITE


func _create_label() -> void:
	var label := Label3D.new()
	label.text = display_name
	label.position.y = 1.45 if kind != Kind.CANDY else 0.75
	label.font_size = 34
	label.outline_size = 9
	label.modulate = Color(1.0, 0.92, 0.64)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _add_capsule(position_3d: Vector3, item_scale: Vector3, color: Color, rotation_3d: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 2.0
	mesh.material = _make_material(color, 1.2)
	part.mesh = mesh
	part.position = position_3d
	part.scale = item_scale
	part.rotation = rotation_3d
	add_child(part)


func _add_cylinder(position_3d: Vector3, item_scale: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.material = _make_material(color, 1.0)
	part.mesh = mesh
	part.position = position_3d
	part.scale = item_scale
	add_child(part)


func _make_material(color: Color, emission_strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_strength
	return material
