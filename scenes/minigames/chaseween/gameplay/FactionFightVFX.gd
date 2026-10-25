class_name FactionFightVFX
extends RefCounted

const GHOST_BEAM_SHADER: Shader = preload("res://scenes/minigames/chaseween/gameplay/ghost_lamp_beam.gdshader")
const GHOST_BEAM_DISTANCE: float = 8.0
const GHOST_BEAM_HALF_ANGLE: float = deg_to_rad(26.0)


static func create_preview(tool_id: StringName, parent: Node3D) -> Node3D:
	var preview := Node3D.new()
	preview.name = "ActionPreview"
	parent.add_child(preview)
	match tool_id:
		&"sugar_spray":
			_add_cone(preview, 7.0, deg_to_rad(30.0), Color(0.35, 0.85, 1.0, 0.18))
		&"ghost_lamp":
			_add_spectral_beam(preview, GHOST_BEAM_DISTANCE, GHOST_BEAM_HALF_ANGLE)
		&"caramel_shield":
			_add_dome(preview, 1.65, Color(1.0, 0.58, 0.14, 0.15))
		_:
			_add_sector(preview, 6.0, deg_to_rad(75.0), Color(1.0, 0.28, 0.18, 0.18))
			_add_arc(preview, 6.0, Color(1.0, 0.28, 0.18, 0.22))
	return preview


static func pulse_spectral_beam(preview: Node3D) -> void:
	if not is_instance_valid(preview):
		return
	var beam := preview.get_node_or_null("SpectralBeam") as MeshInstance3D
	if beam == null:
		return
	var material := beam.get_active_material(0) as ShaderMaterial
	if material == null:
		return
	var previous_tween: Tween
	if preview.has_meta(&"spectral_pulse_tween"):
		previous_tween = preview.get_meta(&"spectral_pulse_tween") as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	material.set_shader_parameter(&"impulse", 1.0)
	var tween := preview.create_tween()
	preview.set_meta(&"spectral_pulse_tween", tween)
	tween.tween_method(
		func(value: float) -> void: material.set_shader_parameter(&"impulse", value),
		1.0,
		0.0,
		0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func spawn_spectral_impact(parent: Node3D, position: Vector3) -> Node3D:
	var impact := Node3D.new()
	impact.name = "SpectralImpact"
	parent.add_child(impact)
	impact.global_position = position
	var pulse := MeshInstance3D.new()
	pulse.name = "ImpactPulse"
	var pulse_mesh := SphereMesh.new()
	pulse_mesh.radius = 0.18
	pulse_mesh.height = 0.36
	var pulse_material := _transparent_material(Color(0.38, 0.88, 1.0, 0.52))
	pulse_mesh.material = pulse_material
	pulse.mesh = pulse_mesh
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.add_child(pulse)
	var particles := _create_spectral_particles(true)
	particles.name = "ImpactFragments"
	particles.amount = 10
	particles.lifetime = 0.55
	particles.explosiveness = 0.92
	var process_material := particles.process_material as ParticleProcessMaterial
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.16
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.8
	process_material.initial_velocity_max = 1.8
	impact.add_child(particles)
	particles.restart()
	var tween := impact.create_tween().set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE * 3.2, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse_material, "albedo_color:a", 0.0, 0.42)
	parent.get_tree().create_timer(0.7).timeout.connect(impact.queue_free)
	return impact


static func spawn_cone(parent: Node3D, origin: Transform3D, distance: float, half_angle: float, color: Color) -> Node3D:
	var effect := Node3D.new()
	parent.add_child(effect)
	effect.global_transform = origin
	var cone := _add_cone(effect, distance, half_angle, color)
	_fade_and_free(effect, cone, 0.38)
	return effect


static func spawn_arc(parent: Node3D, origin: Transform3D, radius: float, color: Color) -> Node3D:
	var effect := Node3D.new()
	parent.add_child(effect)
	effect.global_transform = origin
	_add_arc(effect, radius, color)
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.12, 0.12)
	tween.tween_property(effect, "scale", Vector3.ZERO, 0.18)
	tween.finished.connect(effect.queue_free)
	return effect


static func _add_arc(parent: Node3D, radius: float, color: Color) -> void:
	for index: int in 7:
		var angle := lerpf(-1.15, 1.15, float(index) / 6.0)
		var streak := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.7
		mesh.material = _emissive_material(color)
		streak.mesh = mesh
		streak.position = Vector3(sin(angle), 0.65, -cos(angle)) * radius
		streak.rotation.z = -angle
		parent.add_child(streak)


static func spawn_dome(parent: Node3D, position: Vector3, radius: float, color: Color, duration: float) -> Node3D:
	var dome := MeshInstance3D.new()
	parent.add_child(dome)
	_add_dome_mesh(dome, radius, color)
	dome.global_position = position + Vector3.UP
	var tween := dome.create_tween()
	tween.set_loops(maxi(1, int(duration / 0.8)))
	tween.tween_property(dome, "scale", Vector3.ONE * 1.04, 0.4)
	tween.tween_property(dome, "scale", Vector3.ONE * 0.96, 0.4)
	parent.get_tree().create_timer(duration).timeout.connect(dome.queue_free)
	return dome


static func spawn_wave(parent: Node3D, position: Vector3) -> Node3D:
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.material = _transparent_material(Color(0.75, 0.2, 1.0, 0.65))
	wave.mesh = mesh
	parent.add_child(wave)
	wave.global_position = position + Vector3.UP * 0.2
	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * 24.0, 1.15)
	tween.tween_property(wave, "position:y", wave.position.y + 1.0, 1.15)
	tween.finished.connect(wave.queue_free)
	return wave


static func _add_cone(parent: Node3D, distance: float, half_angle: float, color: Color) -> MeshInstance3D:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = tan(half_angle) * distance
	mesh.height = distance
	mesh.radial_segments = 24
	mesh.material = _transparent_material(color)
	cone.mesh = mesh
	cone.rotation.x = -PI * 0.5
	cone.position = Vector3(0.0, 0.25, -distance * 0.5)
	parent.add_child(cone)
	return cone


static func _add_spectral_beam(parent: Node3D, distance: float, half_angle: float) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "SpectralBeam"
	var mesh := CylinderMesh.new()
	mesh.top_radius = tan(half_angle) * distance
	mesh.bottom_radius = 0.12
	mesh.height = distance
	mesh.radial_segments = 24
	mesh.rings = 6
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = GHOST_BEAM_SHADER
	material.set_shader_parameter(&"beam_length", distance)
	mesh.material = material
	beam.mesh = mesh
	beam.rotation.x = -PI * 0.5
	beam.position = Vector3(0.0, 0.92, -distance * 0.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	var source := MeshInstance3D.new()
	source.name = "SpectralSource"
	var source_mesh := SphereMesh.new()
	source_mesh.radius = 0.11
	source_mesh.height = 0.22
	source_mesh.material = _emissive_material(Color(0.42, 0.95, 1.0, 0.9))
	source.mesh = source_mesh
	source.position = Vector3(0.40, 1.02, -0.18)
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(source)
	var particles := _create_spectral_particles(false)
	particles.name = "SpectralMotes"
	particles.position = Vector3(0.36, 1.0, -0.22)
	particles.visibility_aabb = AABB(Vector3(-4.5, -1.5, -8.5), Vector3(9.0, 3.0, 9.0))
	parent.add_child(particles)
	var light := OmniLight3D.new()
	light.name = "SpectralSourceLight"
	light.position = source.position
	light.light_color = Color(0.36, 0.82, 1.0)
	light.light_energy = 0.32
	light.omni_range = 2.1
	light.shadow_enabled = false
	parent.add_child(light)


static func _create_spectral_particles(one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = 1.8
	particles.randomness = 0.55
	particles.one_shot = one_shot
	particles.fixed_fps = 24
	particles.local_coords = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.02, -1.0)
	process_material.spread = rad_to_deg(GHOST_BEAM_HALF_ANGLE)
	process_material.initial_velocity_min = 2.8
	process_material.initial_velocity_max = 4.2
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.55
	process_material.scale_max = 1.25
	process_material.color = Color(0.48, 0.88, 1.0, 0.72)
	particles.process_material = process_material
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.025
	mote_mesh.height = 0.05
	mote_mesh.material = _emissive_material(Color(0.45, 0.88, 1.0, 0.75))
	particles.draw_pass_1 = mote_mesh
	particles.emitting = true
	return particles


static func _add_dome(parent: Node3D, radius: float, color: Color) -> void:
	var dome := MeshInstance3D.new()
	_add_dome_mesh(dome, radius, color)
	dome.position = Vector3.UP
	parent.add_child(dome)


static func _add_dome_mesh(dome: MeshInstance3D, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _transparent_material(color)
	dome.mesh = mesh


static func _add_sector(parent: Node3D, radius: float, half_angle: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _transparent_material(color))
	var segments := 24
	for index: int in segments:
		var angle_a := lerpf(-half_angle, half_angle, float(index) / float(segments))
		var angle_b := lerpf(-half_angle, half_angle, float(index + 1) / float(segments))
		mesh.surface_add_vertex(Vector3(0.0, 0.08, 0.0))
		mesh.surface_add_vertex(Vector3(sin(angle_a) * radius, 0.08, -cos(angle_a) * radius))
		mesh.surface_add_vertex(Vector3(sin(angle_b) * radius, 0.08, -cos(angle_b) * radius))
	mesh.surface_end()
	visual.mesh = mesh
	parent.add_child(visual)


static func _fade_and_free(effect: Node3D, visual: MeshInstance3D, duration: float) -> void:
	var material := visual.get_active_material(0) as StandardMaterial3D
	var tween := effect.create_tween()
	if material != null:
		tween.tween_property(material, "albedo_color:a", 0.0, duration)
	else:
		tween.tween_interval(duration)
	tween.finished.connect(effect.queue_free)


static func _transparent_material(color: Color) -> StandardMaterial3D:
	var material := _emissive_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color.a = minf(color.a, 0.28)
	return material


static func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	return material
