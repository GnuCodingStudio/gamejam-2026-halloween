class_name FactionFightPickup
extends Node3D

enum Kind {
	CANDY,
	ITEM,
	CHEST,
}

var kind: int = Kind.CANDY
var display_name: String = "CANDY"
var candy_value: int = 0
var item_id: StringName = &""
var item_charges: int = 0
var auto_collect: bool = false
var collected: bool = false

var _base_y: float
var _time: float = 0.0


func configure(
	pickup_kind: int,
	pickup_name: String,
	position_3d: Vector3,
	value: int = 0,
	new_item_id: StringName = &"",
	charges: int = 0
) -> void:
	kind = pickup_kind
	display_name = pickup_name
	global_position = position_3d
	_base_y = position_3d.y
	candy_value = value
	item_id = new_item_id
	item_charges = charges
	auto_collect = kind == Kind.CANDY
	_build_visual()


func collect_once() -> bool:
	if collected:
		return false
	collected = true
	set_process(false)
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


func _build_visual() -> void:
	match kind:
		Kind.CANDY:
			_build_candy()
		Kind.ITEM:
			_build_item()
		Kind.CHEST:
			_build_chest()
	_create_label()


func _build_candy() -> void:
	var colors: Array[Color] = [Color(1.0, 0.22, 0.54), Color(0.32, 1.0, 0.77), Color(1.0, 0.78, 0.16)]
	for index: int in 3:
		var candy := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		mesh.material = _make_material(colors[index], 2.1)
		candy.mesh = mesh
		candy.position = Vector3((index - 1) * 0.3, absf(index - 1) * 0.05, 0.0)
		add_child(candy)


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
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.22, 0.22, 0.84)
	lid_mesh.material = _make_material(Color(0.95, 0.58, 0.08), 1.0)
	lid.mesh = lid_mesh
	lid.position.y = 0.79
	add_child(lid)


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
