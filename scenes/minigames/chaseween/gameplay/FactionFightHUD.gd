class_name FactionFightHUD
extends CanvasLayer

signal summary_closed

const RESULT_OVERLAY_SCENE: PackedScene = preload(
	"res://scenes/minigames/labyrinth/ResultOverlay.tscn"
)

enum MessageCategory {
	OBJECTIVE,
	INFORMATION,
	SUCCESS,
	DANGER,
}

var summary_visible: bool = false

var _candy_label: Label
var _zones_label: Label
var _item_label: Label
var _second_item_label: Label
var _shield_label: Label
var _prompt_panel: PanelContainer
var _prompt_key_panel: PanelContainer
var _prompt_key_label: Label
var _prompt_action_label: Label
var _prompt_text: String = ""
var _prompt_tween: Tween
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _message_priority: int = -1
var _queued_message_text: String = ""
var _queued_message_category: int = MessageCategory.OBJECTIVE
var _help_label: Label
var _summary_overlay: ResultOverlay
var _summary_candy: Label
var _summary_button: Button
var _inventory_label: Label
var _corruption_bar: ProgressBar
var _phase_label: Label
var _journal_overlay: ColorRect
var _journal_text: Label
var _cinematic_overlay: ColorRect
var _objective_title: Label
var _objective_text: Label
var _objective_distance: Label


func _ready() -> void:
	layer = 20
	_build_status_panel()
	_build_objective_panel()
	_build_prompt()
	_build_toast()
	_build_corruption_panel()
	_build_journal()
	_build_cinematic_overlay()
	_build_summary()


func update_status(candy: int, zones: int, item_name: String, charges: int, shield_seconds: float) -> void:
	_candy_label.text = tr("CHASE_HUD_CANDY") % candy
	_zones_label.text = tr("CHASE_HUD_MISSIONS") % zones
	_item_label.text = tr("CHASE_HUD_ITEM") % [item_name, charges] if not item_name.is_empty() else tr("CHASE_HUD_ITEM_NONE")
	_shield_label.visible = shield_seconds > 0.0
	_shield_label.text = tr("CHASE_HUD_SHIELD") % shield_seconds


func update_inventory(text: String) -> void:
	_inventory_label.text = tr("CHASE_HUD_INVENTORY") % (text if not text.is_empty() else "—")


func update_tools(primary: String, primary_charges: int, secondary: String, secondary_charges: int) -> void:
	_item_label.text = tr("CHASE_HUD_TOOL") % [primary, primary_charges] if not primary.is_empty() else tr("CHASE_HUD_TOOL_NONE")
	_second_item_label.text = tr("CHASE_HUD_SECOND_TOOL") % [secondary, secondary_charges] if not secondary.is_empty() else tr("CHASE_HUD_SECOND_TOOL_NONE")


func set_objective(title: String, objective: String, distance: float, direction: String = "◆", hint: String = "") -> void:
	_objective_title.text = title
	_objective_text.text = objective
	_objective_distance.text = "%s  %.0f m" % [direction, distance]
	if not hint.is_empty():
		_objective_distance.text += "  •  " + hint


func pulse_candy(color: Color = Color(1.0, 0.76, 0.22)) -> void:
	_candy_label.pivot_offset = _candy_label.size * 0.5
	_candy_label.modulate = color
	var tween := create_tween()
	tween.tween_property(_candy_label, "scale", Vector2.ONE * 1.16, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_candy_label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(_candy_label, "modulate", Color.WHITE, 0.18)


func update_corruption(percent: float, phase_name: String) -> void:
	_corruption_bar.value = clampf(percent, 0.0, 100.0)
	_phase_label.text = phase_name


func set_journal(entries: Array[String]) -> void:
	_journal_text.text = tr("CHASE_HUD_JOURNAL_TITLE") + "\n\n" + "\n".join(entries) + "\n\n" + tr("CHASE_HUD_JOURNAL_CLOSE")


func toggle_journal() -> void:
	_journal_overlay.visible = not _journal_overlay.visible


func is_journal_visible() -> bool:
	return _journal_overlay.visible


func show_final_spell() -> void:
	_cinematic_overlay.visible = true
	var tween := create_tween()
	_cinematic_overlay.modulate.a = 0.0
	tween.tween_property(_cinematic_overlay, "modulate:a", 1.0, 0.55)


func set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if text.is_empty():
		_fade_prompt_out()
		return
	_set_prompt_content(text)
	_prompt_panel.visible = true
	_prompt_panel.modulate.a = 0.0
	_prompt_panel.scale = Vector2(0.96, 0.96)
	_prompt_panel.call_deferred("set_pivot_offset", _prompt_panel.size * 0.5)
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_prompt_tween.tween_property(_prompt_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_gameplay_message(text: String, category: int) -> void:
	var priority := _category_priority(category)
	if _toast_panel.visible and _toast_tween != null and _toast_tween.is_valid() and priority < _message_priority:
		_queued_message_text = text
		_queued_message_category = category
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_message_priority = priority
	_toast_label.text = text
	_toast_label.modulate = message_color(category)
	_toast_panel.modulate.a = 0.0
	_toast_panel.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(4.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_toast_tween.finished.connect(_finish_gameplay_message)


static func message_color(category: int) -> Color:
	match category:
		MessageCategory.INFORMATION:
			return Color8(72, 199, 188)
		MessageCategory.SUCCESS:
			return Color8(120, 205, 132)
		MessageCategory.DANGER:
			return Color8(240, 107, 112)
		_:
			return Color8(231, 184, 77)


func _category_priority(category: int) -> int:
	match category:
		MessageCategory.DANGER:
			return 3
		MessageCategory.SUCCESS:
			return 2
		MessageCategory.INFORMATION:
			return 1
		_:
			return 0


func _finish_gameplay_message() -> void:
	_toast_panel.visible = false
	_message_priority = -1
	if _queued_message_text.is_empty():
		return
	var next_text := _queued_message_text
	var next_category := _queued_message_category
	_queued_message_text = ""
	show_gameplay_message(next_text, next_category)


func show_summary(candy: int, guarantee_added: int, zones: int, discoveries: int, exit_mode: String) -> void:
	summary_visible = true
	_cinematic_overlay.visible = false
	var details := tr("CHASE_HUD_SUMMARY_MISSIONS") % zones + "\n" + tr("CHASE_HUD_SUMMARY_DISCOVERIES") % discoveries + "\n" + tr("CHASE_HUD_SUMMARY_EXIT") % exit_mode
	if guarantee_added > 0:
		details += "\n" + tr("CHASE_HUD_SUMMARY_BONUS") % guarantee_added
	_summary_overlay.show_result(tr("CHASE_HUD_SUMMARY_TITLE"), candy, details)


func _build_status_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.025, 0.13, 0.9), Color(0.86, 0.42, 1.0)))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title := _label("CHASEWEEN", 24, Color(1.0, 0.66, 0.2))
	box.add_child(title)
	_candy_label = _label(tr("CHASE_HUD_CANDY") % 0, 22, Color.WHITE)
	_zones_label = _label(tr("CHASE_HUD_MISSIONS") % 0, 18, Color(0.8, 0.85, 1.0))
	_item_label = _label(tr("CHASE_HUD_ITEM_NONE"), 18, Color(0.5, 1.0, 0.8))
	_second_item_label = _label(tr("CHASE_HUD_SECOND_TOOL_NONE"), 15, Color(0.66, 0.84, 0.78))
	_shield_label = _label("", 17, Color(1.0, 0.66, 0.22))
	box.add_child(_candy_label)
	box.add_child(_zones_label)
	box.add_child(_item_label)
	box.add_child(_second_item_label)
	box.add_child(_shield_label)
	_inventory_label = _label(tr("CHASE_HUD_INVENTORY") % "—", 15, Color(0.75, 0.92, 1.0))
	box.add_child(_inventory_label)
	_help_label = _label(tr("CHASE_HUD_HELP"), 14, Color(0.76, 0.7, 0.84))
	box.add_child(_help_label)


func _build_objective_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 112.0
	center.offset_bottom = 232.0
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590.0, 104.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.02, 0.07, 0.9), Color(1.0, 0.72, 0.2), 2))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	_objective_title = _label("MISSION 1", 19, Color(1.0, 0.72, 0.2))
	_objective_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_objective_title)
	_objective_text = _label("", 18, Color.WHITE)
	_objective_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_objective_text)
	_objective_distance = _label("", 15, Color(0.52, 0.94, 1.0))
	_objective_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_objective_distance)


func _build_prompt() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_bottom = -30.0
	center.offset_top = -100.0
	add_child(center)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.custom_minimum_size = Vector2(360.0, 66.0)
	_prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.008, 0.065, 0.94), Color(0.78, 0.30, 1.0), 1))
	center.add_child(_prompt_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_prompt_panel.add_child(row)
	_prompt_key_panel = PanelContainer.new()
	_prompt_key_panel.custom_minimum_size = Vector2(44.0, 40.0)
	_prompt_key_panel.add_theme_stylebox_override("panel", _key_style())
	row.add_child(_prompt_key_panel)
	_prompt_key_label = _label("E", 21, Color(1.0, 0.90, 0.64))
	_prompt_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key_panel.add_child(_prompt_key_label)
	_prompt_action_label = _label("", 20, Color(0.98, 0.96, 1.0))
	_prompt_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_prompt_action_label)
	_prompt_panel.visible = false


func _set_prompt_content(text: String) -> void:
	var parts: PackedStringArray = text.split("•", false, 1)
	var has_key := parts.size() > 1 and parts[0].strip_edges() == "E"
	_prompt_key_panel.visible = has_key
	_prompt_action_label.text = parts[1].strip_edges() if has_key else text


func _fade_prompt_out() -> void:
	if not _prompt_panel.visible:
		return
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prompt_tween.tween_property(_prompt_panel, "scale", Vector2(0.98, 0.98), 0.15)
	_prompt_tween.finished.connect(_finish_prompt_hide)


func _finish_prompt_hide() -> void:
	if _prompt_text.is_empty():
		_prompt_panel.visible = false


func _key_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.055, 0.25, 0.98)
	style.border_color = Color(1.0, 0.60, 0.20, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _build_toast() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 250.0
	center.offset_bottom = 330.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_toast_panel = PanelContainer.new()
	_toast_panel.custom_minimum_size = Vector2(900.0, 56.0)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(_toast_panel)
	_toast_label = _label("", 24, Color.WHITE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_constant_override("outline_size", 3)
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false


func _build_corruption_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -390.0
	margin.offset_right = -22.0
	margin.offset_top = 20.0
	margin.offset_bottom = 122.0
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.015, 0.1, 0.9), Color(0.72, 0.2, 1.0)))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label(tr("CHASE_HUD_CORRUPTION_TITLE"), 16, Color(0.92, 0.7, 1.0)))
	_corruption_bar = ProgressBar.new()
	_corruption_bar.max_value = 100.0
	_corruption_bar.show_percentage = true
	_corruption_bar.custom_minimum_size = Vector2(320.0, 18.0)
	box.add_child(_corruption_bar)
	_phase_label = _label(tr("CHASE_HUD_PHASE_DEFAULT"), 14, Color(0.72, 0.82, 1.0))
	box.add_child(_phase_label)


func _build_journal() -> void:
	_journal_overlay = ColorRect.new()
	_journal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_journal_overlay.color = Color(0.015, 0.0, 0.04, 0.86)
	_journal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_journal_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_journal_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 600.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.02, 0.14, 0.98), Color(0.4, 0.9, 1.0), 3))
	center.add_child(panel)
	_journal_text = _label("", 18, Color.WHITE)
	panel.add_child(_journal_text)
	_journal_overlay.visible = false


func _build_cinematic_overlay() -> void:
	_cinematic_overlay = ColorRect.new()
	_cinematic_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic_overlay.color = Color(0.08, 0.0, 0.14, 0.72)
	_cinematic_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cinematic_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic_overlay.add_child(center)
	var message := _label(tr("CHASE_HUD_FINAL_SPELL"), 36, Color(0.92, 0.72, 1.0))
	center.add_child(message)
	_cinematic_overlay.visible = false


func _build_summary() -> void:
	_summary_overlay = RESULT_OVERLAY_SCENE.instantiate() as ResultOverlay
	add_child(_summary_overlay)
	_summary_candy = _summary_overlay.details_label
	_summary_button = _summary_overlay.continue_button
	_summary_overlay.continue_pressed.connect(_close_summary)


func _close_summary() -> void:
	summary_visible = false
	_summary_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	summary_closed.emit()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.04))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _panel_style(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
