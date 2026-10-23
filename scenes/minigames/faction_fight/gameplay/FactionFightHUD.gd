class_name FactionFightHUD
extends CanvasLayer

signal summary_closed

var summary_visible: bool = false

var _candy_label: Label
var _zones_label: Label
var _item_label: Label
var _shield_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _summary_overlay: ColorRect
var _summary_candy: Label


func _ready() -> void:
	layer = 20
	_build_status_panel()
	_build_prompt()
	_build_toast()
	_build_summary()


func update_status(candy: int, zones: int, item_name: String, charges: int, shield_seconds: float) -> void:
	_candy_label.text = "CANDY  %d" % candy
	_zones_label.text = "ZONES  %d / 4" % zones
	_item_label.text = "OBJET  %s  ×%d" % [item_name, charges] if not item_name.is_empty() else "OBJET  —"
	_shield_label.visible = shield_seconds > 0.0
	_shield_label.text = "BOUCLIER CARAMEL  %.1f s" % shield_seconds


func set_prompt(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = text


func show_toast(text: String, color: Color = Color(1.0, 0.86, 0.38)) -> void:
	_toast_label.text = text
	_toast_label.modulate = color
	_toast_panel.modulate.a = 1.0
	_toast_panel.visible = true
	var tween := create_tween()
	tween.tween_interval(1.65)
	tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func() -> void: _toast_panel.visible = false)


func show_summary(candy: int, guarantee_added: int = 0) -> void:
	summary_visible = true
	_summary_candy.text = "CANDY RÉCOLTÉS : %d\nZONES TRAVERSÉES : 4 / 4" % candy
	if guarantee_added > 0:
		_summary_candy.text += "\nGARANTIE DE SORTIE : +%d CANDY" % guarantee_added
	_summary_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	var title := _label("FACTION FIGHT", 24, Color(1.0, 0.66, 0.2))
	box.add_child(title)
	_candy_label = _label("CANDY  0", 22, Color.WHITE)
	_zones_label = _label("ZONES  0 / 4", 18, Color(0.8, 0.85, 1.0))
	_item_label = _label("OBJET  —", 18, Color(0.5, 1.0, 0.8))
	_shield_label = _label("", 17, Color(1.0, 0.66, 0.22))
	box.add_child(_candy_label)
	box.add_child(_zones_label)
	box.add_child(_item_label)
	box.add_child(_shield_label)
	var help := _label("E : interagir     F : utiliser l’objet", 14, Color(0.76, 0.7, 0.84))
	box.add_child(help)


func _build_prompt() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_bottom = -30.0
	center.offset_top = -100.0
	add_child(center)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.02, 0.07, 0.92), Color(1.0, 0.68, 0.22)))
	center.add_child(_prompt_panel)
	_prompt_label = _label("", 22, Color.WHITE)
	_prompt_panel.add_child(_prompt_label)
	_prompt_panel.visible = false


func _build_toast() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 24.0
	center.offset_bottom = 100.0
	add_child(center)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.02, 0.13, 0.94), Color(0.55, 1.0, 0.72)))
	center.add_child(_toast_panel)
	_toast_label = _label("", 22, Color.WHITE)
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false


func _build_summary() -> void:
	_summary_overlay = ColorRect.new()
	_summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary_overlay.color = Color(0.01, 0.0, 0.03, 0.86)
	_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_summary_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 300.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.025, 0.16, 0.98), Color(1.0, 0.58, 0.18), 4))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var title := _label("FACTION FIGHT TERMINÉ", 34, Color(1.0, 0.68, 0.18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_summary_candy = _label("", 24, Color.WHITE)
	_summary_candy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_summary_candy)
	var close_button := Button.new()
	close_button.text = "FERMER LE RÉSUMÉ"
	close_button.custom_minimum_size = Vector2(300.0, 54.0)
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.pressed.connect(_close_summary)
	box.add_child(close_button)
	_summary_overlay.visible = false


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
