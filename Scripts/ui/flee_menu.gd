## 전투 중 Esc 로 여는 메뉴: 계속하기 / 도망가기. 씬 파일 없이 코드로 구성한다.
## 이 위젯은 어떤 선택을 했는지 신호로만 알리고, 전투를 실제로 끝내는 일은 BattleRoot 가 한다.
class_name FleeMenu
extends Control

## 계속하기를 눌렀다.
signal resume_requested
## 도망가기를 눌렀다.
signal flee_requested

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const WARNING_TEXT: String = "도망치면 보상과 진행도 없이 지도로 돌아갑니다."

var _resume_button: Button
var _flee_button: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# 화면 전체를 덮어 메뉴가 열려 있는 동안 아래 전투 화면의 마우스 입력을 막는다.
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360.0, 0.0)
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	_resume_button = _make_button("계속하기")
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	column.add_child(_resume_button)

	_flee_button = _make_button("도망가기")
	_flee_button.pressed.connect(func() -> void: flee_requested.emit())
	column.add_child(_flee_button)

	var warning := Label.new()
	warning.text = WARNING_TEXT
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 14)
	column.add_child(warning)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func resume_button() -> Button:
	return _resume_button


func flee_button() -> Button:
	return _flee_button


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 56.0)
	return button
