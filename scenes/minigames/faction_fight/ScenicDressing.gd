extends Node3D

# Visual-only dressing. The walkable surfaces and their collision shapes stay in the scene.
const REGIONS: Array[Vector4] = [
	Vector4(-22.0, 22.0, -49.0, 13.0),
	Vector4(-18.0, 34.0, -113.0, -47.0),
	Vector4(-24.0, 14.0, -141.0, -113.0),
	Vector4(-24.0, 14.0, -195.0, -167.0),
	Vector4(-21.0, 37.0, -258.0, -194.0),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 10312026
	_add_terrain_shoulders()
	_add_distant_spires()
	_add_ground_details()


func _add_terrain_shoulders() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	for region_index: int in REGIONS.size():
		var region: Vector4 = REGIONS[region_index]
		for side: int in [-1, 1]:
			var terrain := MeshInstance3D.new()
			terrain.name = "Cliff_%d_%d" % [region_index, side]
			terrain.mesh = _make_shoulder(region, side, material)
			terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(terrain)


func _make_shoulder(region: Vector4, side: int, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: float = region.x if side == -1 else region.y
	var start_x: float = edge - 38.0 if side == -1 else edge - 3.0
	var step_x: float = 41.0 / 8.0
	var step_z: float = (region.w - region.z) / 20.0
	for row: int in 20:
		for column: int in 8:
			var x0: float = start_x + column * step_x
			var x1: float = x0 + step_x
			var z0: float = region.z + row * step_z
			var z1: float = z0 + step_z
			var a := _shoulder_point(x0, z0, edge)
			var b := _shoulder_point(x1, z0, edge)
			var c := _shoulder_point(x0, z1, edge)
			var d := _shoulder_point(x1, z1, edge)
			_add_terrain_triangle(surface, a, c, b, edge)
			_add_terrain_triangle(surface, b, c, d, edge)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _shoulder_point(x: float, z: float, edge: float) -> Vector3:
	var distance: float = maxf(0.0, absf(x - edge) - 3.0)
	var rise: float = pow(distance / 35.0, 1.7)
	var ridge: float = 9.0 + 3.5 * sin(z * 0.16 + x * 0.27)
	var ripples: float = sin(x * 0.54 + z * 0.37) * 0.42
	return Vector3(x, -0.09 + rise * (ridge + ripples), z)


func _add_terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, edge: float) -> void:
	for point: Vector3 in [a, b, c]:
		var distance: float = clampf((absf(point.x - edge) - 3.0) / 35.0, 0.0, 1.0)
		var color: Color = Color(0.18, 0.15, 0.22).lerp(Color(0.22, 0.16, 0.31), pow(distance, 1.3))
		surface.set_color(color)
		surface.add_vertex(point)


func _add_distant_spires() -> void:
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.12
	spire_mesh.bottom_radius = 1.6
	spire_mesh.height = 9.0
	spire_mesh.radial_segments = 6
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for region: Vector4 in REGIONS:
		for side: int in [-1, 1]:
			var edge: float = region.x if side == -1 else region.y
			for index: int in 5:
				var offset: float = _rng.randf_range(13.0, 29.0)
				var x: float = edge + side * offset
				var z: float = lerpf(region.z, region.w, (index + _rng.randf_range(0.05, 0.95)) / 5.0)
				var height: float = _rng.randf_range(0.7, 2.0)
				var base_y: float = _shoulder_point(x, z, edge).y
				var width: float = _rng.randf_range(0.8, 2.0)
				transforms.append(_detail_transform(Vector3(x, base_y + height * 4.2, z), _rng.randf_range(0.0, TAU), Vector3(width, height, width)))
				colors.append(Color(0.13, 0.14, 0.21))
	_add_batch("DistantRockSpire", spire_mesh, transforms, colors, false)


func _add_ground_details() -> void:
	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 0.5
	pebble_mesh.height = 0.65
	pebble_mesh.radial_segments = 7
	pebble_mesh.rings = 4
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.55
	cap_mesh.height = 0.42
	cap_mesh.radial_segments = 9
	cap_mesh.rings = 4
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.0
	crystal_mesh.bottom_radius = 0.36
	crystal_mesh.height = 1.8
	crystal_mesh.radial_segments = 5
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.07
	stem_mesh.bottom_radius = 0.12
	stem_mesh.height = 0.65
	stem_mesh.radial_segments = 5

	var pebbles: Array[Transform3D] = []
	var pebble_colors: Array[Color] = []
	var crystals: Array[Transform3D] = []
	var crystal_colors: Array[Color] = []
	var caps: Array[Transform3D] = []
	var cap_colors: Array[Color] = []
	var stems: Array[Transform3D] = []
	var stem_colors: Array[Color] = []
	for region_index: int in REGIONS.size():
		var region: Vector4 = REGIONS[region_index]
		var count: int = 68 if region_index == 1 else 42
		for item: int in count:
			var x: float = _rng.randf_range(region.x + 2.0, region.y - 2.0)
			var z: float = _rng.randf_range(region.z + 2.0, region.w - 2.0)
			if _near_path(x, z, region_index):
				continue
			var angle: float = _rng.randf_range(0.0, TAU)
			var size: float = _rng.randf_range(0.55, 1.4)
			match item % 5:
				0, 1:
					pebbles.append(_detail_transform(Vector3(x, 0.18, z), angle, Vector3(size, size, size)))
					pebble_colors.append(Color(0.29, 0.24, 0.34) if region_index < 2 else Color(0.23, 0.19, 0.32))
				2:
					crystals.append(_detail_transform(Vector3(x, size * 0.68, z), angle, Vector3(size, size, size)))
					crystal_colors.append(Color(0.27, 0.75, 0.74) if region_index < 2 else Color(0.68, 0.27, 0.70))
				3, 4:
					stems.append(_detail_transform(Vector3(x, size * 0.31, z), angle, Vector3(size, size, size)))
					stem_colors.append(Color(0.31, 0.54, 0.52))
					caps.append(_detail_transform(Vector3(x, size * 0.65, z), angle, Vector3(size, size, size)))
					cap_colors.append(Color(0.80, 0.38, 0.54) if region_index == 0 else Color(0.55, 0.38, 0.70))
	_add_batch("StoneScatter", pebble_mesh, pebbles, pebble_colors, false)
	_add_batch("SugarCrystals", crystal_mesh, crystals, crystal_colors, true)
	_add_batch("MushroomStems", stem_mesh, stems, stem_colors, false)
	_add_batch("MushroomCaps", cap_mesh, caps, cap_colors, false)


func _near_path(x: float, z: float, region_index: int) -> bool:
	if region_index == 0:
		return absf(x) < 5.8
	if region_index == 1:
		return absf(x - 7.0) < 6.5 or (z < -78.0 and absf(x + 7.0) < 3.0)
	if region_index == 2 or region_index == 3:
		return absf(x + 5.0) < 6.5
	return absf(x - 8.0) < 8.0


func _detail_transform(origin: Vector3, angle: float, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, angle, 0.0)).scaled(size), origin)


func _add_batch(label: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], luminous: bool) -> void:
	if transforms.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	if luminous:
		material.emission_enabled = true
		material.emission = Color(0.10, 0.18, 0.19)
		material.emission_energy_multiplier = 0.45
	mesh.surface_set_material(0, material)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index: int in transforms.size():
		batch.set_instance_transform(index, transforms[index])
		batch.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
