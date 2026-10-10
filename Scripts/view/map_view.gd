## 지도 화면. 노드마다 버튼을 놓고 연결선을 그리며, 빈 곳을 끌어 지도를 움직일 수 있다.
## 진행 상태는 들고 있지 않는다 — GameRoot 가 sync_from_state 로 넘겨 주는 MapRunState 를 보고 색만 바꾼다.
class_name MapView
# Control: 화면 전체를 덮는 UI 노드.
extends Control

## 들어갈 수 있는 노드 버튼을 눌렀을 때.
signal node_selected(node_id: int)
## 파티·인벤토리 버튼을 눌렀을 때.
signal party_requested

## 노드 버튼 크기.
const NODE_SIZE: Vector2 = Vector2(48.0, 48.0)
## 아직 갈 수 없는 노드 색.
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
## 이미 깬 노드 색.
const CLEARED_COLOR := Color(0.35, 0.55, 0.35)
## 지금 들어갈 수 있는 이야기·보스 노드 색.
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
## 마지막으로 깬 (지금 서 있는) 노드 색.
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
## 지금 들어갈 수 있는 파밍 노드 색.
const FARM_COLOR := Color(0.3, 0.75, 0.7)
## 파밍 노드로 가는 점선 색.
const LINE_COLOR := Color(0.5, 0.5, 0.55)
## 이야기 길을 잇는 실선 색.
const STORY_LINE_COLOR := Color(0.85, 0.75, 0.3)
## 클릭과 드래그를 가르는 최소 이동 거리(px).
const DRAG_THRESHOLD: float = 6.0
## 지도를 끌어도 이만큼은 화면에 남도록 막는 여백(px).
const PAN_MARGIN: float = 120.0

## 그리고 있는 지도.
var _graph: MapGraph
## 노드 id -> 버튼.
var _buttons: Dictionary = {}
## 전투 결과 문구 (승리·패배·도망).
var _result_label: Label
## 파티·인벤토리 화면을 여는 버튼.
var _party_button: Button

## 지도 경계 상자를 화면 중앙에 두기 위한 기준점. 뷰포트 크기가 바뀌면 다시 계산한다.
var _base_origin: Vector2 = Vector2.ZERO
## 드래그로 옮긴 만큼의 오프셋.
var _pan_offset: Vector2 = Vector2.ZERO
## 모든 노드 위치를 감싸는 상자의 왼쪽 위 (지도 기준 좌표).
var _bounds_min: Vector2 = Vector2.ZERO
## 모든 노드 위치를 감싸는 상자의 오른쪽 아래 (지도 기준 좌표).
var _bounds_max: Vector2 = Vector2.ZERO

## 왼쪽 버튼을 누른 화면 위치 (드래그 시작 판정용).
var _press_position: Vector2 = Vector2.ZERO
## 지금 지도를 끌고 있으면 true.
var _dragging: bool = false


## 그릴 지도를 받는다. 버튼은 트리에 들어간 뒤(_ready) 만든다.
func _init(graph: MapGraph) -> void:
	# 지도를 기억한다.
	_graph = graph


## 화면을 구성한다.
func _ready() -> void:
	# 화면 전체를 덮는다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 이 노드 자체는 마우스를 받지 않는다 (버튼만 받는다. 드래그는 _input 에서 따로 본다).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 노드 버튼을 만든다.
	_build_buttons()
	# 결과 문구 글자를 만든다.
	_result_label = _make_result_label()
	# 붙인다.
	add_child(_result_label)
	# 파티 버튼을 만든다.
	_party_button = _make_party_button()
	# 붙인다.
	add_child(_party_button)
	# 창 크기가 바뀌면 지도를 다시 가운데로 맞춘다.
	get_viewport().size_changed.connect(_on_viewport_resized)


## run_state 가 새 그래프로 넘어갔을 때(보스 클리어나 패배로 런이 새로 시작될 때) 버튼을 새로 만든다.
func rebuild(graph: MapGraph) -> void:
	# 기존 버튼을 모두 지운다.
	for id in _buttons:
		(_buttons[id] as Button).queue_free()
	# 목록을 비운다.
	_buttons.clear()
	# 새 지도를 기억한다.
	_graph = graph
	# 새 버튼을 만든다.
	_build_buttons()


## 진행 상태에 맞춰 버튼마다 눌림 가능 여부와 색을 바꾼다.
func sync_from_state(run_state: MapRunState) -> void:
	# 노드마다.
	for node in _graph.nodes:
		# 그 노드의 버튼.
		var button: Button = _buttons[node.id]
		# 깼는지.
		var cleared: bool = run_state.cleared.has(node.id)
		# 지금 서 있는 노드인지.
		var current: bool = node.id == run_state.current_node_id
		# 지금 들어갈 수 있는지.
		var selectable: bool = run_state.is_selectable(node.id)
		# 들어갈 수 없으면 버튼을 막는다.
		button.disabled = not selectable
		# 상태에 맞는 색을 입힌다.
		button.modulate = _color_for(node, current, cleared, selectable)
	# 연결선을 다시 그린다.
	queue_redraw()


## 전투 결과 문구를 띄운다.
func show_result(text: String) -> void:
	# 문구를 넣는다.
	_result_label.text = text
	# 보이게 한다.
	_result_label.visible = true


## 전투 결과 문구를 숨긴다.
func hide_result() -> void:
	# 숨긴다.
	_result_label.visible = false


## 그 노드의 버튼 (테스트용 접근자).
func button_for(node_id: int) -> Button:
	# 버튼을 돌려준다.
	return _buttons[node_id]


## 버튼 개수 (테스트용 접근자).
func button_count() -> int:
	# 목록 크기를 돌려준다.
	return _buttons.size()


## 결과 문구가 보이면 true (테스트용 접근자).
func result_visible() -> bool:
	# 보이는지 돌려준다.
	return _result_label.visible


## 결과 문구 내용 (테스트용 접근자).
func result_text() -> String:
	# 문구를 돌려준다.
	return _result_label.text


## 노드 상태에 맞는 버튼 색. 우선순위: 지금 위치 > 들어갈 수 있음 > 깸 > 잠김.
func _color_for(node: MapNode, current: bool, cleared: bool, selectable: bool) -> Color:
	# 지금 서 있는 노드.
	if current:
		return CURRENT_COLOR
	# 들어갈 수 있는 노드 (파밍은 다른 색).
	if selectable:
		return FARM_COLOR if node.kind == MapNode.Kind.FARM else SELECTABLE_COLOR
	# 깬 노드.
	if cleared:
		return CLEARED_COLOR
	# 나머지는 잠김.
	return LOCKED_COLOR


## 노드의 지도 기준 좌표. 시작이 아래, 보스가 위에 오도록 y 를 뒤집는다.
func _local_position(node: MapNode) -> Vector2:
	# 행·열을 픽셀로 바꾼다 (행이 커질수록 아래).
	var layout: Vector2 = MapLayout.node_position(node)
	# y 를 뒤집어 위로 올라가게 한다.
	return Vector2(layout.x, -layout.y)


## 노드의 화면 좌표 = 가운데 기준점 + 드래그 오프셋 + 지도 기준 좌표.
func _screen_position(node: MapNode) -> Vector2:
	# 세 값을 더한다.
	return _base_origin + _pan_offset + _local_position(node)


## 노드마다 버튼을 만들고 지도를 화면 가운데에 둔다.
func _build_buttons() -> void:
	# 노드마다 버튼을 만들어 기억한다.
	for node in _graph.nodes:
		_buttons[node.id] = _make_button(node)
	# 지도 경계 상자를 계산한다.
	_compute_bounds()
	# 가운데로 맞추고 버튼을 배치한다.
	_recenter()


## 노드 버튼 하나를 만든다. 처음에는 잠김 상태다 (sync_from_state 가 풀어 준다).
func _make_button(node: MapNode) -> Button:
	# 버튼을 만든다.
	var button := Button.new()
	# 크기.
	button.custom_minimum_size = NODE_SIZE
	# 글자 (번호·보스·파밍·시작).
	button.text = _label_for(node)
	# 처음에는 누를 수 없다.
	button.disabled = true
	# 잠김 색.
	button.modulate = LOCKED_COLOR
	# 누르면 노드 id 와 함께 처리한다.
	button.pressed.connect(_on_button_pressed.bind(node.id))
	# 붙인다.
	add_child(button)
	# 만든 버튼을 돌려준다.
	return button


## 버튼에 쓸 글자.
func _label_for(node: MapNode) -> String:
	# 종류별로 고른다.
	match node.kind:
		# 보스.
		MapNode.Kind.BOSS:
			return "보스"
		# 파밍.
		MapNode.Kind.FARM:
			return "파밍"
		# 시작.
		MapNode.Kind.START:
			return "시작"
		# 이야기 노드는 1 부터 세는 번호.
		_:
			return str(node.row + 1)


## 오른쪽 위 구석의 파티·인벤토리 버튼을 만든다.
func _make_party_button() -> Button:
	# 버튼을 만든다.
	var button := Button.new()
	# 글자.
	button.text = "파티 · 인벤토리"
	# 왼쪽 앵커를 화면 오른쪽 끝에 붙인다.
	button.anchor_left = 1.0
	# 오른쪽 앵커도 화면 오른쪽 끝에 붙인다.
	button.anchor_right = 1.0
	# 오른쪽 끝에서 220 픽셀 안쪽부터.
	button.offset_left = -220.0
	# 오른쪽 끝에서 20 픽셀 안쪽까지 (너비 200).
	button.offset_right = -20.0
	# 위에서 20 픽셀.
	button.offset_top = 20.0
	# 위에서 64 픽셀까지 (높이 44).
	button.offset_bottom = 64.0
	# 누르면 파티 화면 요청 신호를 낸다.
	button.pressed.connect(func() -> void: party_requested.emit())
	# 만든 버튼을 돌려준다.
	return button


## 파티 버튼 (테스트용 접근자).
func party_button() -> Button:
	# 버튼을 돌려준다.
	return _party_button


## 화면 위쪽 가운데의 결과 문구 글자를 만든다.
func _make_result_label() -> Label:
	# 글자를 만든다.
	var label := Label.new()
	# 처음에는 숨긴다.
	label.visible = false
	# 가운데 정렬.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 화면 너비 전체를 쓴다.
	label.anchor_right = 1.0
	# 위에서 40 픽셀.
	label.position = Vector2(0.0, 40.0)
	# 크게.
	label.add_theme_font_size_override("font_size", 32)
	# 만든 글자를 돌려준다.
	return label


## 노드 버튼을 눌렀다.
func _on_button_pressed(node_id: int) -> void:
	# 어느 노드인지 알린다.
	node_selected.emit(node_id)


## 노드 사이 연결선을 그린다. 이야기 길은 실선, 파밍 노드로 가는 길은 점선.
func _draw() -> void:
	# 노드마다.
	for node in _graph.nodes:
		# 선의 시작점.
		var from: Vector2 = _screen_position(node)
		# 이어진 노드마다.
		for next_id in node.connections:
			# 이어진 노드.
			var next: MapNode = _graph.get_node(next_id)
			# 선의 끝점.
			var to: Vector2 = _screen_position(next)
			# 파밍 노드로 가는 길은 회색 점선.
			if next.kind == MapNode.Kind.FARM:
				draw_dashed_line(from, to, LINE_COLOR, 2.0, 8.0)
			# 이야기 길은 굵은 금색 실선.
			else:
				draw_line(from, to, STORY_LINE_COLOR, 3.0)


## 모든 노드를 감싸는 경계 상자를 구한다 (가운데 맞추기·드래그 제한용).
func _compute_bounds() -> void:
	# 첫 노드 위치에서 시작한다.
	var first: Vector2 = _local_position(_graph.nodes[0])
	# 최솟값을 첫 위치로.
	_bounds_min = first
	# 최댓값도 첫 위치로.
	_bounds_max = first
	# 나머지 노드로 상자를 넓힌다.
	for i in range(1, _graph.nodes.size()):
		# 그 노드의 위치.
		var local: Vector2 = _local_position(_graph.nodes[i])
		# 왼쪽 끝.
		_bounds_min.x = minf(_bounds_min.x, local.x)
		# 위쪽 끝.
		_bounds_min.y = minf(_bounds_min.y, local.y)
		# 오른쪽 끝.
		_bounds_max.x = maxf(_bounds_max.x, local.x)
		# 아래쪽 끝.
		_bounds_max.y = maxf(_bounds_max.y, local.y)


## 경계 상자의 가운데가 화면 가운데에 오도록 기준점을 다시 정한다.
func _recenter() -> void:
	# 화면 크기.
	var viewport_size: Vector2 = get_viewport_rect().size
	# 경계 상자의 가운데.
	var bounds_center: Vector2 = (_bounds_min + _bounds_max) / 2.0
	# 둘을 맞추는 기준점.
	_base_origin = viewport_size / 2.0 - bounds_center
	# 버튼을 새 위치로 옮긴다.
	_reposition_all()


## 창 크기가 바뀌었다.
func _on_viewport_resized() -> void:
	# 다시 가운데로 맞춘다.
	_recenter()


## 모든 버튼을 지금 화면 좌표로 옮기고 선을 다시 그린다.
func _reposition_all() -> void:
	# 노드마다.
	for node in _graph.nodes:
		# 그 노드의 버튼.
		var button: Button = _buttons[node.id]
		# 버튼 위치는 왼쪽 위 기준이라 크기의 절반만큼 빼서 가운데를 맞춘다.
		button.position = _screen_position(node) - NODE_SIZE / 2.0
	# 연결선을 다시 그린다.
	queue_redraw()


## 뷰 전역 입력을 직접 받는다 — mouse_filter 를 IGNORE 로 둔 채로도 빈 공간 드래그를 감지하려면
## gui_input 이 아니라 _input 을 써야 한다. 눌림이 버튼 위에서 시작했다면 그 버튼이 먼저 처리하므로
## 여기서 오프셋이 조금 흔들려도 클릭 판정과 충돌하지 않는다.
func _input(event: InputEvent) -> void:
	# 숨겨져 있으면 (전투·파티 화면 중) 무시한다.
	if not visible:
		return
	# 마우스 버튼 누름·뗌.
	if event is InputEventMouseButton:
		# 마우스 버튼 이벤트로 꺼낸다.
		var mb := event as InputEventMouseButton
		# 왼쪽 버튼만 본다.
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		# 눌렀을 때: 위치를 기억하고 아직 드래그가 아니다.
		if mb.pressed:
			_press_position = mb.position
			_dragging = false
		# 뗐을 때: 드래그 끝.
		else:
			_dragging = false
	# 마우스 움직임.
	elif event is InputEventMouseMotion:
		# 왼쪽 버튼을 누른 채가 아니면 무시한다.
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		# 움직임 이벤트로 꺼낸다.
		var mm := event as InputEventMouseMotion
		# 아직 조금밖에 안 움직였으면 클릭일 수 있으니 드래그로 치지 않는다.
		if not _dragging and mm.position.distance_to(_press_position) < DRAG_THRESHOLD:
			return
		# 이제부터 드래그다.
		_dragging = true
		# 움직인 만큼 지도를 옮기되 너무 멀리 가지 않게 막는다.
		_pan_offset = _clamp_pan(_pan_offset + mm.relative)
		# 버튼과 선을 다시 배치한다.
		_reposition_all()


## 드래그 오프셋을 제한한다. 지도가 화면 밖으로 완전히 나가지 않고 PAN_MARGIN 만큼은 남게 한다.
func _clamp_pan(offset: Vector2) -> Vector2:
	# 화면 크기.
	var viewport_size: Vector2 = get_viewport_rect().size
	# 지도 크기의 절반.
	var half_map: Vector2 = (_bounds_max - _bounds_min) / 2.0
	# 가로로 옮길 수 있는 한계 (음수가 되지 않게).
	var limit_x: float = maxf(half_map.x + viewport_size.x / 2.0 - PAN_MARGIN, 0.0)
	# 세로로 옮길 수 있는 한계 (음수가 되지 않게).
	var limit_y: float = maxf(half_map.y + viewport_size.y / 2.0 - PAN_MARGIN, 0.0)
	# 두 축을 각각 한계 안으로 자른다.
	return Vector2(clampf(offset.x, -limit_x, limit_x), clampf(offset.y, -limit_y, limit_y))
