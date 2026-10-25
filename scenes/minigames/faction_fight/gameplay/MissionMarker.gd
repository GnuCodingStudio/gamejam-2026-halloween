extends Node3D

const ACCENT := Color(1.0, 0.58, 0.16)
const SPECTRAL := Color(0.48, 0.88, 1.0)

var _outer_ring: MeshInstance3D
var _inner_ring: MeshInstance3D
var _sigil: Node3D
var _beams: Node3D
var _time: float = 0.0


func _ready() -> void:
	_build_ground_sigil()
	_build_beams()
	_build_motes()
	_build_title()


func _process(delta: float) -> void:
	_time += delta
	_outer_ring.rotation.y = _time * 0.32
	_inner_ring.rotation.y = -_time * 0.48
	_sigil.position.y = 0.08 + sin(_time * 1.8) * 0.025
	_beams.scale.x = 0.96 + sin(_time * 1.35) * 0.04
	_beams.scale.z = _beams.scale.x


func _build_ground_sigil() -> void:
	_sigil = Node3D.new()
	_sigil.name = "GroundSigil"
	add_child(_sigil)
	_outer_ring = _create_ring(1.34, 1.43, ACCENT, 0.52)
	_outer_ring.name = "OuterRuneRing"
	_sigil.add_child(_outer_ring)
	_inner_ring = _create_ring(0.82, 0.89, SPECTRAL, 0.34)
	_inner_ring.name = "InnerSpectralRing"
	_sigil.add_child(_inner_ring)
	for index: int in 8:
		var angle := TAU * float(index) / 8.0
		var rune := MeshInstance3D.new()
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.24, 0.018, 0.045)
		rune_mesh.material = _glow_material(SPECTRAL, 0.38, 1.8)
		rune.mesh = rune_mesh
		rune.position = Vector3(cos(angle) * 1.10, 0.01, sin(angle) * 1.10)
		rune.rotation.y = -angle
		rune.visibility_range_end = 90.0
		rune.visibility_range_end_margin = 12.0
		_sigil.add_child(rune)


func _build_beams() -> void:
	_beams = Node3D.new()
	_beams.name = "SpectralBeacon"
	add_child(_beams)
	for index: int in 3:
		var beam := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05 + float(index) * 0.025
		mesh.bottom_radius = 0.23 + float(index) * 0.05
		mesh.height = 8.5 - float(index) * 0.65
		mesh.radial_segments = 20
		var color := ACCENT if index == 0 else SPECTRAL
		mesh.material = _glow_material(color, 0.10 - float(index) * 0.018, 1.25)
		beam.mesh = mesh
		beam.position = Vector3(float(index - 1) * 0.16, mesh.height * 0.5, float(index % 2) * 0.08)
		beam.visibility_range_end = 150.0
		beam.visibility_range_end_margin = 20.0
		_beams.add_child(beam)


func _build_motes() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "RisingSugarMotes"
	particles.amount = 22
	particles.lifetime = 3.2
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3.0, 8.5, 3.0))
	particles.visibility_range_end = 110.0
	particles.visibility_range_end_margin = 15.0
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.9
	process_material.direction = Vector3.UP
	process_material.spread = 14.0
	process_material.initial_velocity_min = 0.65
	process_material.initial_velocity_max = 1.45
	process_material.gravity = Vector3(0.0, 0.08, 0.0)
	process_material.color = Color(0.72, 0.88, 1.0, 0.55)
	particles.process_material = process_material
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.025
	mote_mesh.height = 0.05
	mote_mesh.material = _glow_material(SPECTRAL, 0.58, 2.0)
	particles.draw_pass_1 = mote_mesh
	particles.position.y = 0.2
	add_child(particles)


func _build_title() -> void:
	var title_root := Node3D.new()
	title_root.name = "ObjectiveTitle"
	title_root.position.y = 3.15
	add_child(title_root)
	var backdrop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.65, 0.54)
	quad.material = _billboard_material(Color(0.035, 0.012, 0.08, 0.78))
	backdrop.mesh = quad
	backdrop.visibility_range_end = 90.0
	backdrop.visibility_range_end_margin = 14.0
	title_root.add_child(backdrop)
	var label := Label3D.new()
	label.text = tr("CHASE_HUD_MARKER_ACTIVE")
	label.position.z = 0.012
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(1.0, 0.88, 0.62)
	label.outline_modulate = Color(0.08, 0.01, 0.12, 0.96)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 90.0
	label.visibility_range_end_margin = 14.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	title_root.add_child(label)


func _create_ring(inner_radius: float, outer_radius: float, color: Color, alpha: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 6
	mesh.material = _glow_material(color, alpha, 1.65)
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.visibility_range_end = 100.0
	ring.visibility_range_end_margin = 15.0
	return ring


func _glow_material(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _billboard_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	return material
