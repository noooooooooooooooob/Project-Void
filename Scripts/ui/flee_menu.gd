## 전투 중 Esc 로 여는 메뉴: 계속하기 / 도망가기. 씬 파일 없이 코드로 구성한다.
## 이 위젯은 어떤 선택을 했는지 신호로만 알리고, 전투를 실제로 끝내는 일은 BattleRoot 가 한다.
class_name FleeMenu
extends Control

## 계속하기를 눌렀다.
signal resume_requested
## 도망가기를 눌렀다.
signal flee_requested

## 메뉴 뒤로 전투 화면을 어둡게 가리는 색.
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)
## 도망가기 버튼 아래에 보이는 안내 문구.
const WARNING_TEXT: String = "도망치면 보상과 진행도 없이 지도로 돌아갑니다."

## 계속하기 버튼.
var _resume_button: Button
## 도망가기 버튼.
var _flee_button: Button


## 메뉴 화면을 코드로 짠다. 처음에는 숨겨 둔다.
func _init() -> void:
	# 화면 전체를 덮도록 앵커를 맞춘다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 열기 전까지는 보이지 않는다.
	visible = false

	# 화면 전체를 덮어 메뉴가 열려 있는 동안 아래 전투 화면의 마우스 입력을 막는다.
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	# 마우스 입력을 여기서 멈춘다.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 패널을 화면 가운데에 놓기 위한 컨테이너.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 컨테이너 자체는 마우스를 받지 않는다 (버튼만 받으면 된다).
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	# 가운데 컨테이너 안에 넣는다.
	center.add_child(panel)

	var margin := MarginContainer.new()
	# 네 방향 모두 32 픽셀.
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	panel.add_child(margin)

	# 제목·버튼·안내를 세로로 쌓는 상자.
	var column := VBoxContainer.new()
	# 최소 너비 360 픽셀.
	column.custom_minimum_size = Vector2(360.0, 0.0)
	# 항목 사이 간격 16 픽셀.
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	_resume_button = _make_button("계속하기")
	# 누르면 계속하기 신호를 낸다.
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	column.add_child(_resume_button)

	_flee_button = _make_button("도망가기")
	# 누르면 도망가기 신호를 낸다.
	_flee_button.pressed.connect(func() -> void: flee_requested.emit())
	column.add_child(_flee_button)

	# 도망치면 어떻게 되는지 알려 주는 안내 글자.
	var warning := Label.new()
	warning.text = WARNING_TEXT
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 너비를 넘으면 단어 단위로 줄을 바꾼다.
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 14)
	column.add_child(warning)


## 메뉴를 연다.
func open() -> void:
	visible = true


## 메뉴를 닫는다.
func close() -> void:
	visible = false


## 메뉴가 열려 있으면 true.
func is_open() -> bool:
	# 보이는지가 곧 열려 있는지다.
	return visible


## 계속하기 버튼 (테스트용 접근자).
func resume_button() -> Button:
	return _resume_button


## 도망가기 버튼 (테스트용 접근자).
func flee_button() -> Button:
	return _flee_button


## 메뉴용 버튼 하나를 만든다.
func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# 높이 56 픽셀 (누르기 쉽게).
	button.custom_minimum_size = Vector2(0.0, 56.0)
	return button
