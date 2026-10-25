class_name ChaseweenItemPresentation
extends Node3D

const MODELS: Dictionary = {
	&"candy_cane": preload("res://assets/chaseween/objets/Meshy_AI_Candy_Cane_Staff.glb"),
	&"sugar_spray": preload("res://assets/chaseween/objets/Meshy_AI_Candy_Spray.glb"),
	&"caramel_shield": preload("res://assets/chaseween/objets/Meshy_AI_Caramel_Shield.glb"),
	&"ghost_lamp": preload("res://assets/chaseween/objets/Meshy_AI_Ghost_Lantern.glb"),
	&"caramel_key": preload("res://assets/chaseween/objets/Meshy_AI_Caramel_Key.glb"),
	&"sugar_crystal": preload("res://assets/chaseween/objets/Meshy_AI_Sugar_Crystal.glb"),
	&"syrup_capsule": preload("res://assets/chaseween/objets/Meshy_AI_Syrup_Capsule.glb"),
	&"spectral_badge": preload("res://assets/chaseween/objets/Meshy_AI_Phantom_spectral_badge.glb"),
	&"candy_chest": preload("res://assets/chaseween/objets/Chaseween_Candy_Chest.glb"),
	&"haunted_locker": preload("res://assets/chaseween/objets/Chaseween_Haunted_Locker.glb"),
	&"magic_dispenser": preload("res://assets/chaseween/objets/Chaseween_Magic_Candy_Dispenser.glb"),
	&"magic_altar": preload("res://assets/chaseween/objets/Chaseween_Magic_Altar.glb"),
	&"chewingland_heart": preload("res://assets/chaseween/objets/Chaseween_Chewingland_Heart.glb"),
}

const PROFILES: Dictionary = {
	&"candy_cane": {"scale": 0.60, "model_y": 0.57, "bob": 0.10, "spin": 0.58, "halo": 0.78, "color": Color(1.0, 0.24, 0.10)},
	&"sugar_spray": {"scale": 0.55, "model_y": 0.52, "bob": 0.09, "spin": 0.50, "halo": 0.82, "color": Color(1.0, 0.18, 0.66)},
	&"caramel_shield": {"scale": 0.60, "model_y": 0.57, "bob": 0.08, "spin": 0.42, "halo": 0.90, "color": Color(1.0, 0.56, 0.12)},
	&"ghost_lamp": {"scale": 0.48, "model_y": 0.46, "bob": 0.08, "spin": 0.38, "halo": 0.78, "color": Color(0.40, 0.30, 1.0)},
	&"caramel_key": {"scale": 0.45, "model_y": 0.43, "bob": 0.12, "spin": 0.72, "halo": 0.68, "color": Color(1.0, 0.48, 0.08), "particles": true},
	&"sugar_crystal": {"scale": 0.45, "model_y": 0.43, "bob": 0.13, "spin": 0.48, "halo": 0.72, "color": Color(0.78, 0.24, 1.0), "particles": true},
	&"syrup_capsule": {"scale": 0.45, "model_y": 0.43, "bob": 0.11, "spin": 0.50, "halo": 0.70, "color": Color(1.0, 0.30, 0.08), "particles": true},
	&"spectral_badge": {"scale": 0.45, "model_y": 0.43, "bob": 0.12, "spin": 0.64, "halo": 0.72, "color": Color(0.46, 0.30, 1.0), "particles": true},
	&"candy_chest": {"scale": 0.75, "model_y": 0.64, "bob": 0.0, "spin": 0.0, "halo": 1.05, "color": Color(1.0, 0.64, 0.12), "light": 0.42},
	&"haunted_locker": {"scale": 1.35, "model_y": 1.29, "bob": 0.0, "spin": 0.0, "halo": 1.18, "color": Color(0.52, 0.26, 1.0), "light": 0.46},
	&"magic_dispenser": {"scale": 1.35, "model_y": 1.29, "bob": 0.0, "spin": 0.0, "halo": 1.22, "color": Color(1.0, 0.30, 0.10), "light": 0.48},
	&"magic_altar": {"scale": 1.15, "model_y": 0.95, "bob": 0.0, "spin": 0.0, "halo": 1.28, "color": Color(0.72, 0.28, 1.0), "light": 0.44},
	&"chewingland_heart": {"scale": 1.0, "model_y": 0.95, "bob": 0.16, "spin": 0.16, "halo": 1.35, "color": Color(1.0, 0.20, 0.74), "light": 0.72, "particles": true},
}

var _visual_pivot: Node3D
var _halo: MeshInstance3D
var _inner_halo: MeshInstance3D
var _rune_crown: Node3D
var _local_light: OmniLight3D
var _particles: GPUParticles3D
var _glow_material: StandardMaterial3D
var _particle_process_material: ParticleProcessMaterial
var _base_rotation: Vector3 = Vector3.ZERO
var _bob_height: float = 0.0
var _spin_speed: float = 0.0
var _base_light_energy: float = 0.0
var _effect_center: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _active: bool = true
var presentation_id: StringName = &""


func configure(presentation_id: StringName, held: bool = false) -> void:
	self.presentation_id = presentation_id
	var packed_scene: PackedScene = MODELS.get(presentation_id) as PackedScene
	var profile: Dictionary = PROFILES.get(presentation_id, {})
	if packed_scene == null or profile.is_empty():
		push_error("FactionFight: présentation inconnue %s" % presentation_id)
		return
	_build_model(packed_scene, profile, held)
	if held:
		set_process(false)
		return
	_build_halo(profile)
	_build_light(profile)
	_build_particles(profile)
	_bob_height = float(profile.get("bob", 0.0))
	_spin_speed = float(profile.get("spin", 0.0))
	set_process(_bob_height > 0.0 or _spin_speed > 0.0 or _halo != null or _local_light != null)


func set_active(enabled: bool) -> void:
	_active = enabled
	set_process(enabled)
	if is_instance_valid(_particles):
		_particles.emitting = enabled


func set_glow_color(color: Color) -> void:
	if is_instance_valid(_glow_material):
		_glow_material.albedo_color = Color(color.r, color.g, color.b, 0.38)
		_glow_material.emission = color
	if is_instance_valid(_local_light):
		_local_light.light_color = color
	if is_instance_valid(_particle_process_material):
		_particle_process_material.color = Color(color.r, color.g, color.b, 0.62)


func get_effect_center() -> Vector3:
	return _effect_center


func play_activation() -> void:
	if not is_instance_valid(_halo):
		return
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_halo, "scale", Vector3.ONE * 1.55, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_local_light):
		tween.tween_property(_local_light, "light_energy", _base_light_energy * 2.4, 0.12)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	if is_instance_valid(_visual_pivot):
		_visual_pivot.position.y = sin(_time * 2.0) * _bob_height
		_visual_pivot.rotation.y = _base_rotation.y + _time * _spin_speed
	var pulse: float = 1.0 + sin(_time * 2.4) * 0.07
	if is_instance_valid(_halo):
		_halo.scale = Vector3.ONE * pulse
		_halo.rotation.y = _time * 0.28
	if is_instance_valid(_inner_halo):
		_inner_halo.scale = Vector3.ONE * (1.0 - sin(_time * 2.1) * 0.035)
		_inner_halo.rotation.y = -_time * 0.42
	if is_instance_valid(_rune_crown):
		_rune_crown.rotation.y = _time * 0.18
	if is_instance_valid(_local_light):
		_local_light.light_energy = _base_light_energy * (0.92 + sin(_time * 2.0) * 0.08)


func _build_model(packed_scene: PackedScene, profile: Dictionary, held: bool) -> void:
	_visual_pivot = Node3D.new()
	_visual_pivot.name = "VisualPivot"
	add_child(_visual_pivot)
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		push_error("FactionFight: le GLB n'a pas de racine Node3D.")
		return
	model.name = "GLBInstance"
	var model_scale: float = float(profile.get("scale", 1.0))
	if held:
		model_scale *= 0.72
		model.position.y = 0.0
	else:
		model.position.y = float(profile.get("model_y", 0.0))
	model.scale = Vector3.ONE * model_scale
	_visual_pivot.add_child(model)
	_base_rotation = Vector3(0.0, deg_to_rad(float(profile.get("yaw", 0.0))), 0.0)
	_visual_pivot.rotation = _base_rotation
	_configure_meshes(model)
	_effect_center = _calculate_visible_center(model)


func _calculate_visible_center(root: Node3D) -> Vector3:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found_geometry := false
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.get_aabb()
		var to_presentation := global_transform.affine_inverse() * mesh_instance.global_transform
		for corner: Vector3 in _aabb_corners(bounds):
			var point := to_presentation * corner
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			found_geometry = true
	if not found_geometry:
		return Vector3.ZERO
	var center := (minimum + maximum) * 0.5
	return Vector3(center.x, 0.0, center.z)


func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var start := bounds.position
	var end := bounds.end
	return [
		Vector3(start.x, start.y, start.z),
		Vector3(end.x, start.y, start.z),
		Vector3(start.x, end.y, start.z),
		Vector3(end.x, end.y, start.z),
		Vector3(start.x, start.y, end.z),
		Vector3(end.x, start.y, end.z),
		Vector3(start.x, end.y, end.z),
		Vector3(end.x, end.y, end.z),
	]


func _configure_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = 55.0
		geometry.visibility_range_end_margin = 5.0
	for child: Node in node.get_children():
		_configure_meshes(child)


func _build_halo(profile: Dictionary) -> void:
	var color: Color = profile.get("color", Color.WHITE)
	_glow_material = _create_glow_material(color, 0.34, 1.5)
	var halo_radius: float = float(profile.get("halo", 0.8))
	_halo = _create_ring(halo_radius * 0.88, halo_radius, _glow_material)
	_halo.name = "PresentationHalo"
	_halo.position = _effect_center + Vector3.UP * 0.025
	add_child(_halo)
	var inner_material := _create_glow_material(color.lightened(0.24), 0.20, 1.25)
	_inner_halo = _create_ring(halo_radius * 0.59, halo_radius * 0.65, inner_material)
	_inner_halo.name = "InnerHalo"
	_inner_halo.position = _effect_center + Vector3.UP * 0.032
	add_child(_inner_halo)
	_build_rune_crown(halo_radius, color)
	_build_ground_glow(halo_radius, color)


func _create_ring(inner_radius: float, outer_radius: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 40
	mesh.ring_segments = 6
	mesh.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.visibility_range_end = 45.0
	ring.visibility_range_end_margin = 7.0
	ring.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return ring


func _build_rune_crown(radius: float, color: Color) -> void:
	_rune_crown = Node3D.new()
	_rune_crown.name = "RuneCrown"
	_rune_crown.position = _effect_center + Vector3.UP * 0.042
	add_child(_rune_crown)
	var rune_material := _create_glow_material(color.lightened(0.28), 0.30, 1.8)
	for index: int in 6:
		var angle := TAU * float(index) / 6.0
		var rune := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(radius * 0.18, 0.012, radius * 0.035)
		mesh.material = rune_material
		rune.mesh = mesh
		rune.position = Vector3(cos(angle) * radius * 0.80, 0.0, sin(angle) * radius * 0.80)
		rune.rotation.y = -angle
		rune.visibility_range_end = 38.0
		rune.visibility_range_end_margin = 6.0
		_rune_crown.add_child(rune)


func _build_ground_glow(radius: float, color: Color) -> void:
	var glow := MeshInstance3D.new()
	glow.name = "GroundGlow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.62
	mesh.bottom_radius = radius * 0.66
	mesh.height = 0.008
	mesh.radial_segments = 32
	mesh.material = _create_glow_material(color, 0.055, 0.55)
	glow.mesh = mesh
	glow.position = _effect_center + Vector3.UP * 0.012
	glow.visibility_range_end = 32.0
	glow.visibility_range_end_margin = 7.0
	add_child(glow)


func _create_glow_material(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _build_light(profile: Dictionary) -> void:
	_base_light_energy = float(profile.get("light", 0.0))
	if _base_light_energy <= 0.0:
		return
	_local_light = OmniLight3D.new()
	_local_light.name = "PresentationLight"
	_local_light.light_color = profile.get("color", Color.WHITE)
	_local_light.light_energy = _base_light_energy
	_local_light.omni_range = 3.2
	_local_light.shadow_enabled = false
	_local_light.position = _effect_center + Vector3.UP * minf(float(profile.get("model_y", 0.8)), 1.25)
	add_child(_local_light)


func _build_particles(profile: Dictionary) -> void:
	if not bool(profile.get("particles", false)):
		return
	_particles = GPUParticles3D.new()
	_particles.name = "MagicMotes"
	_particles.amount = 10
	_particles.lifetime = 2.4
	_particles.randomness = 0.65
	_particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 3.5, 3.0))
	_particle_process_material = ParticleProcessMaterial.new()
	_particle_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_particle_process_material.emission_sphere_radius = 0.55
	_particle_process_material.direction = Vector3.UP
	_particle_process_material.spread = 35.0
	_particle_process_material.initial_velocity_min = 0.08
	_particle_process_material.initial_velocity_max = 0.22
	_particle_process_material.gravity = Vector3(0.0, 0.08, 0.0)
	var color: Color = profile.get("color", Color.WHITE)
	_particle_process_material.color = Color(color.r, color.g, color.b, 0.62)
	_particles.process_material = _particle_process_material
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.025
	mote_mesh.height = 0.05
	mote_mesh.material = _glow_material
	_particles.draw_pass_1 = mote_mesh
	_particles.position = _effect_center + Vector3.UP * 0.45
	_particles.visibility_range_end = 35.0
	_particles.visibility_range_end_margin = 5.0
	add_child(_particles)
