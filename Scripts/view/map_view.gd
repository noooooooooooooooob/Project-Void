class_name MapView
extends Control

signal node_selected(node_id: int)

const ORIGIN: Vector2 = Vector2(640.0, 560.0)
const NODE_SIZE: Vector2 = Vector2(48.0, 48.0)
const LOCKED_COLOR := Color(0.3, 0.3, 0.32)
const CLEARED_COLOR := Color(0.35, 0.55, 0.35)
const SELECTABLE_COLOR := Color(0.85, 0.75, 0.3)
const CURRENT_COLOR := Color(0.3, 0.6, 0.9)
const LINE_COLOR := Color(0.5, 0.5, 0.55)

var _graph: MapGraph
var _buttons: Dictionary = {}
var _result_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph = MapGraph.new()
	for node in _graph.nodes:
		_buttons[node.id] = _make_button(node)
	_result_label = _make_result_label()
	add_child(_result_label)


func sync_from_state(run_state: MapRunState) -> void:
	for node in _graph.nodes:
		var button: Button = _buttons[node.id]
		var cleared: bool = run_state.cleared.has(node.id)
		var current: bool = node.id == run_state.current_node_id
		var selectable: bool = run_state.is_selectable(node.id)
		button.disabled = not selectable
		button.modulate = _color_for(current, cleared, selectable)
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


func _color_for(current: bool, cleared: bool, selectable: bool) -> Color:
	if current:
		return CURRENT_COLOR
	if selectable:
		return SELECTABLE_COLOR
	if cleared:
		return CLEARED_COLOR
	return LOCKED_COLOR


func _screen_position(node: MapNode) -> Vector2:
	var layout: Vector2 = MapLayout.node_position(node)
	return ORIGIN + Vector2(layout.x, -layout.y)


func _make_button(node: MapNode) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.position = _screen_position(node) - NODE_SIZE / 2.0
	button.text = "보스" if node.is_boss else str(node.id)
	button.disabled = true
	button.modulate = LOCKED_COLOR
	button.pressed.connect(_on_button_pressed.bind(node.id))
	add_child(button)
	return button


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
			draw_line(from, _screen_position(_graph.get_node(next_id)), LINE_COLOR, 2.0)
