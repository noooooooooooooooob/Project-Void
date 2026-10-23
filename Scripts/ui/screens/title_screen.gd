## 타이틀: 키 아트 + 로고 + "아무 키나 누르세요". 아무 입력이나 받으면 started.
class_name TitleScreen
extends Control

signal started

var _prompt: Label
var _time: float = 0.0
var _done: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.backdrop(UiTheme.bg("title"), 0.15))
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.anchor_top = 0.62
	center.anchor_bottom = 0.62
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)
	var logo := UiTheme.title_label("공허 정화자", 96, Color(0.95, 0.9, 1.0))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_shadow_color", Color(0.35, 0.15, 0.55, 0.9))
	logo.add_theme_constant_override("shadow_offset_y", 4)
	center.add_child(logo)
	var sub := UiTheme.label("VOID PURIFIER  ·  PROTOTYPE", 22, UiTheme.LAVENDER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 60)
	center.add_child(gap)
	_prompt = UiTheme.label("아무 키나 누르세요", 26, UiTheme.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_prompt)


func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.45 + 0.55 * absf(sin(_time * 2.2))


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_done = true
		get_viewport().set_input_as_handled()
		started.emit()
