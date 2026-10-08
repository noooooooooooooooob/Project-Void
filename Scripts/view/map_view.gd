class_name MapView
extends Control

signal node_selected(node_id: int)
## 파티·인벤토리 버튼을 눌렀을 때.
signal party_requested

const NODE_SIZE: Vector2 = Vector2(48.0, 48.0)
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
const CLEARED_COLOR := Color(0.35, 0.55, 0.35)
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
const FARM_COLOR := Color(0.3, 0.75, 0.7)
const LINE_COLOR := Color(0.5, 0.5, 0.55)
const STORY_LINE_COLOR := Color(0.85, 0.75, 0.3)
## 클릭과 드래그를 가르는 최소 이동 거리(px).
const DRAG_THRESHOLD: float = 6.0
## 지도를 끌어도 이만큼은 화면에 남도록 막는 여백(px).
const PAN_MARGIN: float = 120.0

var _graph: MapGraph
var _buttons: Dictionary = {}
var _result_label: Label
var _party_button: Button

## 지도 경계 상자를 화면 중앙에 두기 위한 기준점. 뷰포트 크기가 바뀌면 다시 계산한다.
var _base_origin: Vector2 = Vector2.ZERO
## 드래그로 옮긴 만큼의 오프셋.
var _pan_offset: Vector2 = Vector2.ZERO
var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ZERO

var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _init(graph: MapGraph) -> void:
	_graph = graph


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_buttons()
	_result_label = _make_result_label()
	add_child(_result_label)
	_party_button = _make_party_button()
	add_child(_party_button)
	get_viewport().size_changed.connect(_on_viewport_resized)


## run_state 가 새 그래프로 넘어갔을 때(보스 클리어나 패배로 런이 새로 시작될 때) 버튼을 새로 만든다.
func rebuild(graph: MapGraph) -> void:
	for id in _buttons:
		(_buttons[id] as Button).queue_free()
	_buttons.clear()
	_graph = graph
	_build_buttons()


func sync_from_state(run_state: MapRunState) -> void:
	for node in _graph.nodes:
		var button: Button = _buttons[node.id]
		var cleared: bool = run_state.cleared.has(node.id)
		var current: bool = node.id == run_state.current_node_id
		var selectable: bool = run_state.is_selectable(node.id)
		button.disabled = not selectable
		button.modulate = _color_for(node, current, cleared, selectable)
	queue_redraw()


func show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true


func hide_result() -> void:
	_result_label.visible = false


func button_for(node_id: int) -> Button:
	return _buttons[node_id]


func button_count() -> int:
	return _buttons.size()


func result_visible() -> bool:
	return _result_label.visible


func result_text() -> String:
	return _result_label.text


func _color_for(node: MapNode, current: bool, cleared: bool, selectable: bool) -> Color:
	if current:
		return CURRENT_COLOR
	if selectable:
		return FARM_COLOR if node.kind == MapNode.Kind.FARM else SELECTABLE_COLOR
	if cleared:
		return CLEARED_COLOR
	return LOCKED_COLOR


func _local_position(node: MapNode) -> Vector2:
	var layout: Vector2 = MapLayout.node_position(node)
	return Vector2(layout.x, -layout.y)


func _screen_position(node: MapNode) -> Vector2:
	return _base_origin + _pan_offset + _local_position(node)


func _build_buttons() -> void:
	for node in _graph.nodes:
		_buttons[node.id] = _make_button(node)
	_compute_bounds()
	_recenter()


func _make_button(node: MapNode) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.text = _label_for(node)
	button.disabled = true
	button.modulate = LOCKED_COLOR
	button.pressed.connect(_on_button_pressed.bind(node.id))
	add_child(button)
	return button


func _label_for(node: MapNode) -> String:
	match node.kind:
		MapNode.Kind.BOSS:
			return "보스"
		MapNode.Kind.FARM:
			return "파밍"
		MapNode.Kind.START:
			return "시작"
		_:
			return str(node.row + 1)


func _make_party_button() -> Button:
	var button := Button.new()
	button.text = "파티 · 인벤토리"
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -220.0
	button.offset_right = -20.0
	button.offset_top = 20.0
	button.offset_bottom = 64.0
	button.pressed.connect(func() -> void: party_requested.emit())
	return button


func party_button() -> Button:
	return _party_button


func _make_result_label() -> Label:
	var label := Label.new()
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.position = Vector2(0.0, 40.0)
	label.add_theme_font_size_override("font_size", 32)
	return label


func _on_button_pressed(node_id: int) -> void:
	node_selected.emit(node_id)


func _draw() -> void:
	for node in _graph.nodes:
		var from: Vector2 = _screen_position(node)
		for next_id in node.connections:
			var next: MapNode = _graph.get_node(next_id)
			var to: Vector2 = _screen_position(next)
			if next.kind == MapNode.Kind.FARM:
				draw_dashed_line(from, to, LINE_COLOR, 2.0, 8.0)
			else:
				draw_line(from, to, STORY_LINE_COLOR, 3.0)


func _compute_bounds() -> void:
	var first: Vector2 = _local_position(_graph.nodes[0])
	_bounds_min = first
	_bounds_max = first
	for i in range(1, _graph.nodes.size()):
		var local: Vector2 = _local_position(_graph.nodes[i])
		_bounds_min.x = minf(_bounds_min.x, local.x)
		_bounds_min.y = minf(_bounds_min.y, local.y)
		_bounds_max.x = maxf(_bounds_max.x, local.x)
		_bounds_max.y = maxf(_bounds_max.y, local.y)


func _recenter() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var bounds_center: Vector2 = (_bounds_min + _bounds_max) / 2.0
	_base_origin = viewport_size / 2.0 - bounds_center
	_reposition_all()


func _on_viewport_resized() -> void:
	_recenter()


func _reposition_all() -> void:
	for node in _graph.nodes:
		var button: Button = _buttons[node.id]
		button.position = _screen_position(node) - NODE_SIZE / 2.0
	queue_redraw()


## 뷰 전역 입력을 직접 받는다 — mouse_filter 를 IGNORE 로 둔 채로도 빈 공간 드래그를 감지하려면
## gui_input 이 아니라 _input 을 써야 한다. 눌림이 버튼 위에서 시작했다면 그 버튼이 먼저 처리하므로
## 여기서 오프셋이 조금 흔들려도 클릭 판정과 충돌하지 않는다.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_position = mb.position
			_dragging = false
		else:
			_dragging = false
	elif event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_press_position) < DRAG_THRESHOLD:
			return
		_dragging = true
		_pan_offset = _clamp_pan(_pan_offset + mm.relative)
		_reposition_all()


func _clamp_pan(offset: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_map: Vector2 = (_bounds_max - _bounds_min) / 2.0
	var limit_x: float = maxf(half_map.x + viewport_size.x / 2.0 - PAN_MARGIN, 0.0)
	var limit_y: float = maxf(half_map.y + viewport_size.y / 2.0 - PAN_MARGIN, 0.0)
	return Vector2(clampf(offset.x, -limit_x, limit_x), clampf(offset.y, -limit_y, limit_y))
