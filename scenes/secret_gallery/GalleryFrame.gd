@tool
class_name GalleryFrame
extends Node3D


const BORDER_THICKNESS: float = 0.08
const SURFACE_MARGIN: float = 0.28

@export var frame_size: Vector2 = Vector2(3.2, 2.2):
	set(value):
		frame_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_configuration()
@export var archive_texture: Texture2D:
	set(value):
		archive_texture = value
		_apply_configuration()
@export_range(0.0, 3.0, 0.05) var highlight_energy: float = 1.0:
	set(value):
		highlight_energy = maxf(value, 0.0)
		_apply_configuration()

@onready var backing: MeshInstance3D = %Backing
@onready var archive_surface: MeshInstance3D = %ArchiveSurface
@onready var top_border: MeshInstance3D = %TopBorder
@onready var bottom_border: MeshInstance3D = %BottomBorder
@onready var left_border: MeshInstance3D = %LeftBorder
@onready var right_border: MeshInstance3D = %RightBorder
@onready var highlight: OmniLight3D = %Highlight

var _placeholder_material: StandardMaterial3D


func _ready() -> void:
	_placeholder_material = archive_surface.material_override as StandardMaterial3D
	_apply_configuration()


func _apply_configuration() -> void:
	if not is_node_ready():
		return

	var inner_size: Vector2 = frame_size - Vector2.ONE * SURFACE_MARGIN
	backing.scale = Vector3(frame_size.x, frame_size.y, 0.12)
	archive_surface.scale = Vector3(inner_size.x, inner_size.y, 0.04)
	top_border.position.y = frame_size.y * 0.5
	bottom_border.position.y = -frame_size.y * 0.5
	left_border.position.x = -frame_size.x * 0.5
	right_border.position.x = frame_size.x * 0.5
	top_border.scale = Vector3(frame_size.x + BORDER_THICKNESS, BORDER_THICKNESS, 0.16)
	bottom_border.scale = top_border.scale
	left_border.scale = Vector3(BORDER_THICKNESS, frame_size.y, 0.16)
	right_border.scale = left_border.scale
	highlight.position = Vector3(0.0, frame_size.y * 0.55, 1.15)
	highlight.light_energy = highlight_energy
	_apply_archive_texture(inner_size)


func _apply_archive_texture(inner_size: Vector2) -> void:
	if archive_texture == null:
		archive_surface.material_override = _placeholder_material
		return

	if _placeholder_material == null:
		return
	var local_material: StandardMaterial3D = _placeholder_material.duplicate() as StandardMaterial3D
	local_material.albedo_color = Color.WHITE
	local_material.albedo_texture = archive_texture
	local_material.metallic = 0.0
	local_material.roughness = 1.0
	archive_surface.material_override = local_material

	var texture_size: Vector2 = archive_texture.get_size()
	if texture_size.y <= 0.0:
		return
	var texture_ratio: float = texture_size.x / texture_size.y
	var display_size: Vector2 = inner_size
	if inner_size.x / inner_size.y > texture_ratio:
		display_size.x = inner_size.y * texture_ratio
	else:
		display_size.y = inner_size.x / texture_ratio
	archive_surface.scale = Vector3(display_size.x, display_size.y, 0.04)
