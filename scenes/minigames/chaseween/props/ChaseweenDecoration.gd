class_name ChaseweenDecoration
extends Node3D

@export var asset_key: StringName
@export_range(20.0, 150.0, 1.0) var visibility_distance: float = 72.0
@export var emission_color: Color = Color.WHITE
@export_range(0.0, 2.0, 0.01) var emission_energy: float = 0.0

static var _shared_emissive_materials: Dictionary[StringName, StandardMaterial3D] = {}


func _ready() -> void:
	_configure_collision()
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		_configure_mesh(child as MeshInstance3D)


func _configure_collision() -> void:
	var body := get_node_or_null("Collision") as StaticBody3D
	var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D if body != null else null
	if collision == null:
		collision = body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
	if body == null or collision == null or collision.shape == null:
		push_warning("ChaseweenDecoration: collision manquante pour %s" % name)
		return
	var instance_scale := global_basis.get_scale().abs()
	collision.shape = _scaled_collision_shape(collision.shape, instance_scale)
	collision.position *= instance_scale
	body.top_level = true
	body.global_transform = Transform3D(global_basis.orthonormalized(), global_position)


func _scaled_collision_shape(source: Shape3D, instance_scale: Vector3) -> Shape3D:
	var scaled := source.duplicate() as Shape3D
	if scaled is CylinderShape3D:
		var cylinder := scaled as CylinderShape3D
		cylinder.radius *= maxf(instance_scale.x, instance_scale.z)
		cylinder.height *= instance_scale.y
	elif scaled is BoxShape3D:
		var box := scaled as BoxShape3D
		box.size *= instance_scale
	elif scaled is CapsuleShape3D:
		var capsule := scaled as CapsuleShape3D
		capsule.radius *= maxf(instance_scale.x, instance_scale.z)
		capsule.height *= instance_scale.y
	return scaled


func _configure_mesh(mesh_instance: MeshInstance3D) -> void:
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = visibility_distance
	mesh_instance.visibility_range_end_margin = 10.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if emission_energy <= 0.0 or mesh_instance.mesh == null:
		return
	for surface_index: int in mesh_instance.mesh.get_surface_count():
		var material := _shared_emissive_material(mesh_instance, surface_index)
		if material != null:
			mesh_instance.set_surface_override_material(surface_index, material)


func _shared_emissive_material(mesh_instance: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var cache_key := StringName("%s:%d" % [asset_key, surface_index])
	if _shared_emissive_materials.has(cache_key):
		return _shared_emissive_materials[cache_key]
	var source := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
	if source == null:
		return null
	var material := source.duplicate() as StandardMaterial3D
	material.resource_name = "%s_DecorationEmission" % asset_key
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	material.emission_texture = material.albedo_texture
	_shared_emissive_materials[cache_key] = material
	return material
