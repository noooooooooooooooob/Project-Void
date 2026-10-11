## 의뢰 화면 (1층 격자). 칸마다 버튼을 놓고 연결선을 그리며, 아래에 파티 체력을 보여 준다.
## 진행 상태는 들고 있지 않는다 — GameRoot 가 sync_from_run 으로 넘겨 주는 CommissionRun 을 보고 색만 바꾼다.
class_name StageView
# Control: 화면 전체를 덮는 UI 노드.
extends Control

## 갈 수 있는 칸 버튼을 눌렀을 때.
signal node_selected(id: int)

## 칸 버튼 크기.
const NODE_SIZE: Vector2 = Vector2(56.0, 56.0)
## 아직 갈 수 없는 칸 색.
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
## 지금 갈 수 있는 칸 색.
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
## 지금 서 있는 칸 색.
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
## 지나온 칸 색.
const VISITED_COLOR := Color(0.9, 0.55, 0.2)
## 연결선 기본 색.
const LINE_COLOR := Color(0.45, 0.45, 0.5)
## 지나온 길 연결선 색.
const PATH_LINE_COLOR := Color(0.9, 0.55, 0.2)
## 제목 문구.
const TITLE_TEXT: String = "1층 탐사 중"

## 그리고 있는 의뢰.
var _run: CommissionRun
## 칸 id -> 버튼.
var _buttons: Dictionary = {}
## 제목 글자.
var _title_label: Label
## 결과 문구 (빈 칸·승리).
var _result_label: Label
## 파티 체력 줄을 담는 상자.
var _hp_box: HBoxContainer
## 파티원별 체력 글자.
var _hp_labels: Array[Label] = []
## 격자를 화면 가운데에 두기 위한 기준점.
var _origin: Vector2 = Vector2.ZERO


## 그릴 의뢰를 받는다. 버튼은 트리에 들어간 뒤(_ready) 만든다.
func _init(run: CommissionRun) -> void:
	# 의뢰를 기억한다.
	_run = run


## 화면을 구성한다.
func _ready() -> void:
	# 화면 전체를 덮는다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 이 노드 자체는 마우스를 받지 않는다 (버튼만 받는다).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 제목.
	_title_label = _make_top_label(TITLE_TEXT, 20.0, 28)
	add_child(_title_label)
	# 결과 문구 (처음엔 숨김).
	_result_label = _make_top_label("", 70.0, 26)
	_result_label.visible = false
	add_child(_result_label)
	# 파티 체력 상자.
	_hp_box = _make_hp_box()
	add_child(_hp_box)
	# 칸 버튼.
	for node in _run.graph.nodes:
		_buttons[node.id] = _make_button(node)
	# 가운데로 맞춘다.
	_recenter()
	# 창 크기가 바뀌면 다시 맞춘다.
	get_viewport().size_changed.connect(_recenter)


## 진행 상태에 맞춰 버튼 눌림·색과 체력 줄을 바꾼다.
func sync_from_run(run: CommissionRun, party: PartyState) -> void:
	# 의뢰를 기억한다 (선 그리기용).
	_run = run
	# 칸마다.
	for node in run.graph.nodes:
		# 버튼.
		var button: Button = _buttons[node.id]
		# 갈 수 있는지.
		var selectable: bool = run.is_selectable(node.id)
		# 갈 수 없으면 막는다.
		button.disabled = not selectable
		# 색.
		button.modulate = _color_for(node.id, selectable)
	# 체력 줄을 다시 만든다.
	_rebuild_hp_lines(run, party)
	# 선을 다시 그린다.
	queue_redraw()


## 결과 문구를 띄운다.
func show_result(text: String) -> void:
	# 문구.
	_result_label.text = text
	# 보이기.
	_result_label.visible = true


## 결과 문구를 숨긴다.
func hide_result() -> void:
	# 숨긴다.
	_result_label.visible = false


## 그 칸의 버튼 (테스트용 접근자).
func button_for(id: int) -> Button:
	# 돌려준다.
	return _buttons[id]


## 버튼 개수 (테스트용 접근자).
func button_count() -> int:
	# 돌려준다.
	return _buttons.size()


## 파티원 체력 줄 글자 (테스트용 접근자).
func hp_text(index: int) -> String:
	# 돌려준다.
	return _hp_labels[index].text


## 제목 글자 (테스트용 접근자).
func title_text() -> String:
	# 돌려준다.
	return _title_label.text


## 결과 문구가 보이면 true (테스트용 접근자).
func result_visible() -> bool:
	# 돌려준다.
	return _result_label.visible


## 결과 문구 내용 (테스트용 접근자).
func result_text() -> String:
	# 돌려준다.
	return _result_label.text


## 칸 상태에 맞는 색. 우선순위: 지금 칸 > 갈 수 있음 > 지나옴 > 잠김.
func _color_for(id: int, selectable: bool) -> Color:
	# 지금 칸.
	if id == _run.current_id:
		return CURRENT_COLOR
	# 갈 수 있는 칸.
	if selectable:
		return SELECTABLE_COLOR
	# 지나온 칸.
	if _run.visited.has(id):
		return VISITED_COLOR
	# 잠김.
	return LOCKED_COLOR


## 칸 버튼 하나를 만든다. 처음엔 잠김 (sync_from_run 이 풀어 준다).
func _make_button(node: StageNode) -> Button:
	# 버튼.
	var button := Button.new()
	# 크기.
	button.custom_minimum_size = NODE_SIZE
	# 종류 글자.
	button.text = _label_for(node.kind)
	# 처음엔 막는다.
	button.disabled = true
	# 잠김 색.
	button.modulate = LOCKED_COLOR
	# 누르면 칸 id 를 알린다.
	button.pressed.connect(func() -> void: node_selected.emit(node.id))
	# 붙인다.
	add_child(button)
	# 돌려준다.
	return button


## 칸 종류 글자.
func _label_for(kind: StageNode.Kind) -> String:
	# 종류별.
	match kind:
		StageNode.Kind.START:
			return "시작"
		StageNode.Kind.BATTLE:
			return "전투"
		StageNode.Kind.EVENT:
			return "?"
		StageNode.Kind.SHOP:
			return "상점"
		StageNode.Kind.REST:
			return "휴식"
		_:
			return "보스"


## 화면 위쪽 가운데 글자를 만든다.
func _make_top_label(text: String, top: float, font_size: int) -> Label:
	# 글자.
	var label := Label.new()
	# 내용.
	label.text = text
	# 가운데 정렬.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 화면 너비 전체.
	label.anchor_right = 1.0
	# 위치.
	label.position = Vector2(0.0, top)
	# 크기.
	label.add_theme_font_size_override("font_size", font_size)
	# 돌려준다.
	return label


## 화면 아래쪽 파티 체력 상자를 만든다.
func _make_hp_box() -> HBoxContainer:
	# 가로 상자.
	var box := HBoxContainer.new()
	# 화면 아래 가로 전체.
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.anchor_right = 1.0
	# 아래에서 70 ~ 20 픽셀.
	box.offset_top = -70.0
	box.offset_bottom = -20.0
	# 가운데 정렬.
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	# 사이 간격.
	box.add_theme_constant_override("separation", 40)
	# 돌려준다.
	return box


## 파티원마다 "이름  현재 / 최대" (쓰러졌으면 "이름  쓰러짐") 글자를 다시 만든다.
func _rebuild_hp_lines(run: CommissionRun, party: PartyState) -> void:
	# 기존 글자를 지운다.
	for label in _hp_labels:
		label.free()
	# 목록을 비운다.
	_hp_labels.clear()
	# 파티원마다.
	for i in party.member_count():
		# 글자.
		var label := Label.new()
		# 이름.
		var member_name: String = party.member_data(i).display_name
		# 쓰러졌는지에 따라.
		if run.member_hp[i] <= 0:
			label.text = "%s  쓰러짐" % member_name
		else:
			label.text = "%s  %d / %d" % [member_name, run.member_hp[i], run.member_max_hp[i]]
		# 붙인다.
		_hp_box.add_child(label)
		# 기억한다.
		_hp_labels.append(label)


## 격자 경계의 가운데가 화면 가운데에 오도록 기준점을 정하고 버튼을 옮긴다.
func _recenter() -> void:
	# 경계 상자.
	var min_pos: Vector2 = StageLayout.node_position(_run.graph.nodes[0])
	var max_pos: Vector2 = min_pos
	for node in _run.graph.nodes:
		var local: Vector2 = StageLayout.node_position(node)
		min_pos = min_pos.min(local)
		max_pos = max_pos.max(local)
	# 화면 가운데에 맞춘다.
	_origin = get_viewport_rect().size / 2.0 - (min_pos + max_pos) / 2.0
	# 버튼을 옮긴다 (가운데 기준이라 크기 절반을 뺀다).
	for node in _run.graph.nodes:
		(_buttons[node.id] as Button).position = _origin + StageLayout.node_position(node) - NODE_SIZE / 2.0
	# 선을 다시 그린다.
	queue_redraw()


## 연결선을 그린다. 지나온 길(연속한 두 칸)은 굵은 주황, 나머지는 얇은 회색.
func _draw() -> void:
	# 칸마다.
	for node in _run.graph.nodes:
		# 시작점.
		var from: Vector2 = _origin + StageLayout.node_position(node)
		# 이어진 칸마다.
		for next_id in node.connections:
			# 끝점.
			var to: Vector2 = _origin + StageLayout.node_position(_run.graph.get_node(next_id))
			# 지나온 길인지: 두 칸이 길에서 바로 이어져 있다.
			var index: int = _run.visited.find(node.id)
			var on_path: bool = index >= 0 and index + 1 < _run.visited.size() and _run.visited[index + 1] == next_id
			# 그린다.
			if on_path:
				draw_line(from, to, PATH_LINE_COLOR, 4.0)
			else:
				draw_line(from, to, LINE_COLOR, 2.0)
