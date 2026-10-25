class_name FactionFightPickup
extends Node3D

signal candy_collected(pickup: FactionFightPickup)

const CRYSTALBERRY_SCENE: PackedScene = preload("res://objects/candy_crystalberry.tscn")
const PUMPKIN_SCENE: PackedScene = preload("res://objects/candy_pumpkin.tscn")
const PresentationScript := preload("res://scenes/minigames/chaseween/gameplay/ChaseweenItemPresentation.gd")

enum Kind {
	CANDY,
	ITEM,
	CHEST,
	KEY_ITEM,
	DEVICE,
}

var kind: int = Kind.CANDY
var display_name: String = "CHASE_HUD_PICKUP_DEFAULT"
var candy_value: int = 0
var item_id: StringName = &""
var item_charges: int = 0
var auto_collect: bool = false
var collected: bool = false
var shared_candy_scene_path: String = ""
var required_item_id: StringName = &""
var reward_id: StringName = &""
var mission_id: StringName = &""

var _shared_candy: Candy
var _presentation: PresentationScript


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
	candy_value = value
	item_id = new_item_id
	item_charges = charges
	required_item_id = new_required_item_id
	reward_id = new_reward_id
	mission_id = new_mission_id
	auto_collect = kind == Kind.CANDY
	_build_visual(candy_variant)
	set_process(false)


func collect_once() -> bool:
	if collected or kind == Kind.CANDY:
		return false
	collected = true
	set_process(false)
	if kind == Kind.CHEST:
		_open_chest()
		return true
	if is_instance_valid(_presentation):
		_presentation.play_activation()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.35, 0.12)
	tween.tween_property(self, "position:y", position.y + 0.8, 0.22)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.16)
	tween.finished.connect(queue_free)
	return true


func stop_gameplay() -> void:
	set_process(false)
	if is_instance_valid(_presentation):
		_presentation.set_active(false)
	if is_instance_valid(_shared_candy):
		_shared_candy.set_deferred(&"monitoring", false)


func get_interaction_position() -> Vector3:
	if is_instance_valid(_presentation):
		return _presentation.to_global(_presentation.get_effect_center())
	return global_position


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
	if kind == Kind.CHEST or kind == Kind.DEVICE:
		_build_physical_collision()
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
	_add_presentation(item_id)


func _build_chest() -> void:
	_add_presentation(&"candy_chest")


func _open_chest() -> void:
	var tween := create_tween()
	if is_instance_valid(_presentation):
		_presentation.play_activation()
	tween.tween_interval(0.85)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 1.18, 0.2)
	tween.tween_property(self, "position:y", position.y + 0.35, 0.2)
	tween.chain().tween_property(self, "scale", Vector3.ZERO, 0.18)
	tween.finished.connect(queue_free)


func _build_key_item() -> void:
	_add_presentation(item_id)


func _build_device() -> void:
	_add_presentation(_device_presentation_id())


func _add_presentation(presentation_id: StringName) -> void:
	_presentation = PresentationScript.new() as PresentationScript
	_presentation.name = "Presentation"
	add_child(_presentation)
	_presentation.configure(presentation_id)


func _device_presentation_id() -> StringName:
	match reward_id:
		&"ghost_lamp":
			return &"haunted_locker"
		&"spray_refill":
			return &"magic_dispenser"
		_:
			return &"magic_altar"


func _build_physical_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "PhysicalCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	if is_instance_valid(_presentation):
		var center := _presentation.get_effect_center()
		body.position = Vector3(center.x, 0.0, center.z)
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	body.add_child(collision)
	if kind == Kind.CHEST:
		_configure_box_collision(collision, Vector3(1.35, 1.05, 0.88))
		return
	match _device_presentation_id():
		&"haunted_locker":
			_configure_box_collision(collision, Vector3(1.65, 2.35, 0.88))
		&"magic_dispenser":
			_configure_box_collision(collision, Vector3(1.72, 2.25, 1.62))
		&"magic_altar":
			var shape := CylinderShape3D.new()
			shape.radius = 0.92
			shape.height = 1.55
			collision.shape = shape
			collision.position.y = 0.78
		_:
			push_warning("FactionFight: collision inconnue pour %s" % display_name)


func _configure_box_collision(collision: CollisionShape3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5


func _create_label() -> void:
	var title_root := Node3D.new()
	title_root.name = "WorldTitle"
	match kind:
		Kind.DEVICE:
			title_root.position.y = 3.05
		Kind.CHEST:
			title_root.position.y = 1.75
		_:
			title_root.position.y = 1.55
	if is_instance_valid(_presentation):
		var center := _presentation.get_effect_center()
		title_root.position.x = center.x
		title_root.position.z = center.z
	add_child(title_root)
	var accent := _label_accent_color()
	_add_title_backdrop(title_root, accent)
	var category := Label3D.new()
	category.name = "Category"
	category.text = _label_category()
	category.position = Vector3(0.0, 0.19, 0.012)
	category.font_size = 18
	category.outline_size = 5
	category.modulate = Color(accent.r, accent.g, accent.b, 0.88)
	_configure_world_label(category, 14.0)
	title_root.add_child(category)
	var title := Label3D.new()
	title.name = "Title"
	title.text = tr(display_name)
	title.position = Vector3(0.0, -0.055, 0.014)
	title.font_size = 30
	title.outline_size = 7
	title.modulate = Color(1.0, 0.94, 0.84, 0.96)
	_configure_world_label(title, 14.0)
	title_root.add_child(title)


func _add_title_backdrop(parent: Node3D, accent: Color) -> void:
	var width := clampf(float(tr(display_name).length()) * 0.105 + 0.75, 2.0, 4.4)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "TitleBackdrop"
	var backdrop_mesh := QuadMesh.new()
	backdrop_mesh.size = Vector2(width, 0.58)
	backdrop_mesh.material = _billboard_material(Color(0.025, 0.008, 0.055, 0.78))
	backdrop.mesh = backdrop_mesh
	_configure_world_geometry(backdrop, 14.0)
	parent.add_child(backdrop)
	var accent_line := MeshInstance3D.new()
	accent_line.name = "AccentLine"
	var accent_mesh := QuadMesh.new()
	accent_mesh.size = Vector2(width * 0.72, 0.026)
	accent_mesh.material = _billboard_material(Color(accent.r, accent.g, accent.b, 0.82))
	accent_line.mesh = accent_mesh
	accent_line.position = Vector3(0.0, -0.275, 0.018)
	_configure_world_geometry(accent_line, 14.0)
	parent.add_child(accent_line)


func _configure_world_label(label: Label3D, range_end: float) -> void:
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_modulate = Color(0.025, 0.0, 0.055, 0.98)
	label.visibility_range_end = range_end
	label.visibility_range_end_margin = 5.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _configure_world_geometry(geometry: GeometryInstance3D, range_end: float) -> void:
	geometry.visibility_range_end = range_end
	geometry.visibility_range_end_margin = 5.0
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _billboard_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color
	return material


func _label_accent_color() -> Color:
	match kind:
		Kind.ITEM:
			return Color(1.0, 0.38, 0.68)
		Kind.KEY_ITEM:
			return Color(0.42, 0.90, 1.0)
		Kind.CHEST:
			return Color(1.0, 0.62, 0.18)
		Kind.DEVICE:
			return Color(0.72, 0.34, 1.0)
		_:
			return Color.WHITE


func _label_category() -> String:
	match kind:
		Kind.ITEM:
			return tr("CHASE_HUD_CATEGORY_ITEM")
		Kind.KEY_ITEM:
			return tr("CHASE_HUD_CATEGORY_KEY_ITEM")
		Kind.CHEST:
			return tr("CHASE_HUD_CATEGORY_CHEST")
		Kind.DEVICE:
			return tr("CHASE_HUD_CATEGORY_DEVICE")
		_:
			return ""
