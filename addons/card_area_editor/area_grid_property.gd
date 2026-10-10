# @tool: 에디터 인스펙터 안에서 실행된다.
@tool
## CardData.area 를 5×5 토글 버튼으로 편집하는 인스펙터 속성. 가운데(◎)가 기준점, 위가 행 −, 오른쪽이 열 +(뒤쪽).
## 값 변경은 emit_changed 로 알려 에디터의 Undo/Redo 에 자동으로 올라간다.
extends EditorProperty

# 격자 계산.
const AreaGridLogic := preload("res://addons/card_area_editor/area_grid_logic.gd")

## 칸 버튼들 (칸 번호 순서).
var _buttons: Array[Button] = []
## 버튼 상태를 코드로 맞추는 중이면 true (그동안 토글 신호를 무시한다).
var _updating: bool = false


## 격자 버튼을 만든다.
func _init() -> void:
	# 5열 격자.
	var grid := GridContainer.new()
	grid.columns = AreaGridLogic.SIZE
	# 칸마다 버튼.
	for index in AreaGridLogic.SIZE * AreaGridLogic.SIZE:
		# 눌림이 유지되는 버튼.
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(22, 22)
		# 가운데 칸은 기준점 표시.
		button.text = "◎" if AreaGridLogic.offset_for(index) == Vector2i.ZERO else ""
		# 누르면 그 칸을 토글한다.
		button.toggled.connect(_on_toggled.bind(index))
		grid.add_child(button)
		_buttons.append(button)
	# 속성 아래쪽에 붙인다.
	add_child(grid)
	set_bottom_editor(grid)


## 편집 중인 값으로 버튼 눌림을 맞춘다.
func _update_property() -> void:
	# 현재 값.
	var area: Array = get_edited_object()[get_edited_property()]
	# 신호를 막고 맞춘다.
	_updating = true
	for index in _buttons.size():
		_buttons[index].button_pressed = area.has(AreaGridLogic.offset_for(index))
	_updating = false


## 칸을 눌렀다: 그 오프셋을 켜거나 끈 새 배열을 알린다.
func _on_toggled(_pressed: bool, index: int) -> void:
	# 코드로 맞추는 중이면 무시.
	if _updating:
		return
	# 현재 값을 타입 있는 배열로.
	var current: Array[Vector2i] = []
	current.assign(get_edited_object()[get_edited_property()])
	# 새 값을 알린다.
	emit_changed(get_edited_property(), AreaGridLogic.toggled(current, AreaGridLogic.offset_for(index)))
