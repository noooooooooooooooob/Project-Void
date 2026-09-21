## 맵 화면. 점마다 버튼 하나를 두고, 점 사이 길은 직접 선으로 그린다.
## 진행 상황은 들고 있지 않다 — MapRunState 를 받아 버튼 상태만 그때그때 맞춘다.
## 버튼을 누르면 어느 점인지만 알리고, 전투를 띄우는 일은 GameRoot 가 한다.
class_name MapView
# Control: 2D UI 노드. 길을 직접 그려야 해서 _draw 를 쓴다.
extends Control

## 갈 수 있는 점을 눌렀을 때 그 점 번호와 함께 난다.
signal node_selected(node_id: int)

## 시작점을 놓을 화면 위치. 맵이 여기서 위로 뻗어 올라간다.
const ORIGIN: Vector2 = Vector2(640.0, 560.0)
## 점 버튼 한 개의 크기.
const NODE_SIZE: Vector2 = Vector2(48.0, 48.0)
## 아직 갈 수 없는 점의 색.
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
## 이미 깬 점의 색.
const CLEARED_COLOR := Color(0.35, 0.55, 0.35)
## 지금 고를 수 있는 점의 색.
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
## 지금 서 있는 점의 색.
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
## 점을 잇는 길의 색.
const LINE_COLOR := Color(0.5, 0.5, 0.55)

## 화면에 그릴 맵 생김새. 버튼과 길을 만들 때만 쓴다.
var _graph: MapGraph
## 점 번호 → 그 점의 버튼.
var _buttons: Dictionary = {}
## 런이 끝났을 때 띄우는 안내 문구.
var _result_label: Label


## 버튼과 안내 문구를 한 번 만들어 둔다. 색과 활성 상태는 sync_from_state 가 맞춘다.
func _ready() -> void:
	# 이 Control 자체는 화면 전체를 덮으므로 마우스를 가로채지 않게 둔다 (자식 버튼은 그대로 받는다).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 생김새는 런이 바뀌어도 같으므로 여기서 한 번만 만든다.
	_graph = MapGraph.new()
	# 점마다 버튼을 하나씩 만든다.
	for node in _graph.nodes:
		_buttons[node.id] = _make_button(node)
	# 안내 문구를 만든다 (처음에는 숨어 있다).
	_result_label = _make_result_label()
	# 버튼 위에 오도록 마지막에 붙인다.
	add_child(_result_label)


## 진행 상황을 보고 버튼의 색과 누를 수 있는지를 다시 맞춘다.
func sync_from_state(run_state: MapRunState) -> void:
	# 점을 하나씩 본다.
	for node in _graph.nodes:
		# 그 점의 버튼.
		var button: Button = _buttons[node.id]
		# 이미 깼는지.
		var cleared: bool = run_state.cleared.has(node.id)
		# 지금 서 있는 점인지.
		var current: bool = node.id == run_state.current_node_id
		# 지금 갈 수 있는지.
		var selectable: bool = run_state.is_selectable(node.id)
		# 갈 수 있는 점만 누를 수 있다.
		button.disabled = not selectable
		# 상태에 맞는 색으로 칠한다.
		button.modulate = _color_for(current, cleared, selectable)
	# 길은 바뀌지 않지만 버튼 색이 바뀌었으므로 같이 다시 그린다.
	queue_redraw()


## 런이 끝났을 때 안내 문구를 띄운다.
func show_result(text: String) -> void:
	# 문구를 바꾼다.
	_result_label.text = text
	# 보이게 한다.
	_result_label.visible = true


## 안내 문구를 숨긴다.
func hide_result() -> void:
	# 안 보이게 한다.
	_result_label.visible = false


## 점 번호로 버튼을 꺼낸다 (테스트에서 버튼을 눌러 보기 위한 통로).
func button_for(node_id: int) -> Button:
	# 만들어 둔 버튼을 그대로 준다.
	return _buttons[node_id]


## 만들어진 버튼 수 (테스트용).
func button_count() -> int:
	# 점마다 하나씩이므로 점 수와 같다.
	return _buttons.size()


## 안내 문구가 보이는지 (테스트용).
func result_visible() -> bool:
	# 라벨이 보이는지 그대로 알린다.
	return _result_label.visible


## 안내 문구의 내용 (테스트용).
func result_text() -> String:
	# 라벨 문구를 그대로 알린다.
	return _result_label.text


## 점 상태에 맞는 색을 고른다. 겹칠 때는 "지금 자리 > 갈 수 있음 > 깬 곳" 순으로 앞선 것이 이긴다.
func _color_for(current: bool, cleared: bool, selectable: bool) -> Color:
	# 지금 서 있는 곳이 가장 눈에 띄어야 한다.
	if current:
		return CURRENT_COLOR
	# 다음으로 지금 고를 수 있는 곳.
	if selectable:
		return SELECTABLE_COLOR
	# 지나온 곳.
	if cleared:
		return CLEARED_COLOR
	# 나머지는 아직 못 가는 곳.
	return LOCKED_COLOR


## 점의 배치 좌표를 화면 좌표로 바꾼다.
func _screen_position(node: MapNode) -> Vector2:
	# 배치 계산은 MapLayout 에 맡긴다.
	var layout: Vector2 = MapLayout.node_position(node)
	# 화면 y 는 아래로 늘어나므로, 위로 뻗는 맵을 그리려면 y 를 뒤집어 더한다.
	return ORIGIN + Vector2(layout.x, -layout.y)


## 점 하나의 버튼을 만들어 붙인다.
func _make_button(node: MapNode) -> Button:
	# 빈 버튼.
	var button := Button.new()
	# 점 크기.
	button.custom_minimum_size = NODE_SIZE
	# position 은 왼쪽 위 모서리이므로 절반을 빼야 점 자리가 버튼 가운데에 온다.
	button.position = _screen_position(node) - NODE_SIZE / 2.0
	# 보스만 따로 표시하고 나머지는 번호를 그대로 쓴다.
	button.text = "보스" if node.is_boss else str(node.id)
	# 처음에는 모두 못 누르는 상태 (sync_from_state 가 풀어 준다).
	button.disabled = true
	# 처음에는 모두 잠긴 색.
	button.modulate = LOCKED_COLOR
	# 눌리면 어느 점인지 함께 알리도록 번호를 미리 묶어 둔다.
	button.pressed.connect(_on_button_pressed.bind(node.id))
	# 화면에 붙인다.
	add_child(button)
	# 나중에 찾아 쓸 수 있게 돌려준다.
	return button


## 런 결과 안내 문구를 만든다 (붙이는 일은 부른 쪽이 한다).
func _make_result_label() -> Label:
	# 빈 라벨.
	var label := Label.new()
	# 알릴 일이 있을 때만 보인다.
	label.visible = false
	# 가운데 정렬.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 가로로 화면을 꽉 채워야 가운데 정렬이 화면 가운데가 된다.
	label.anchor_right = 1.0
	# 화면 위쪽에 띄운다.
	label.position = Vector2(0.0, 40.0)
	# 맵 위에서도 읽히도록 크게.
	label.add_theme_font_size_override("font_size", 32)
	# 만든 라벨을 돌려준다.
	return label


## 버튼이 눌렸을 때. 묶어 둔 점 번호를 그대로 바깥에 알린다.
func _on_button_pressed(node_id: int) -> void:
	# 어느 점을 골랐는지 알린다.
	node_selected.emit(node_id)


## 점 사이를 잇는 길을 그린다. Control 이 다시 그려질 때 엔진이 부른다.
func _draw() -> void:
	# 점을 하나씩 본다.
	for node in _graph.nodes:
		# 선이 시작할 자리.
		var from: Vector2 = _screen_position(node)
		# 이 점에서 갈 수 있는 곳마다 선을 긋는다.
		for next_id in node.connections:
			draw_line(from, _screen_position(_graph.get_node(next_id)), LINE_COLOR, 2.0)
