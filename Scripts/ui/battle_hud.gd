class_name BattleHud
extends Control

signal card_selected(index: int)
signal end_turn_pressed

const CURRENT_TURN_COLOR := Color(1.0, 0.82, 0.3)
const ACTED_COLOR := Color(0.5, 0.5, 0.5)
const MELEE_CARD_COLOR := Color(0.85, 0.4, 0.35)
const RANGED_CARD_COLOR := Color(0.4, 0.6, 0.95)
const OUTLINED_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]

@onready var _turn_label: RichTextLabel = %TurnLabel
@onready var _sp_panel: PanelContainer = %SpPanel
@onready var _sp_label: Label = %SpLabel
@onready var _hand_box: HBoxContainer = %HandBox
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _log: RichTextLabel = %BattleLog
@onready var _banner: Label = %Banner

var _melee_card_boxes: Dictionary = {}
var _ranged_card_boxes: Dictionary = {}
var _actor: Unit
var _selected_card: int = -1
var _interactive: bool = false


func _ready() -> void:
	_melee_card_boxes = _make_outline_boxes(MELEE_CARD_COLOR)
	_ranged_card_boxes = _make_outline_boxes(RANGED_CARD_COLOR)
	_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	_refresh_sp(null)
	_apply_interactive()


func sync_from_state(state: BattleState, selected_card: int) -> void:
	_actor = null if state.finished else state.current_unit()
	_selected_card = selected_card
	_refresh_sp(_actor)
	_refresh_hand()
	if state.finished:
		_turn_label.text = "승리!" if state.ally_won else "패배..."
		return
	var alive: Array[bool] = []
	for member in state.initiative:
		alive.append(member.is_alive())
	_turn_label.text = turn_bar_text(state.round_index, state.initiative, alive, state.turn_index)


func show_turn(event: BattleEvent) -> void:
	_turn_label.text = turn_bar_text(event.round_index, event.order, event.alive, event.turn_index)
	if not event.unit.is_ally():
		_actor = null
		_selected_card = -1
		_refresh_sp(null)
		_refresh_hand()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	if not enabled:
		_selected_card = -1
		for child in _hand_box.get_children():
			(child as Button).set_pressed_no_signal(false)
	_apply_interactive()


func append_log(text: String) -> void:
	_log.append_text(text + "\n")


func show_banner(ally_won: bool) -> void:
	_banner.text = "승리!" if ally_won else "패배..."
	_banner.visible = true


func hand_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _hand_box.get_children():
		buttons.append(child as Button)
	return buttons


func sp_text() -> String:
	return _sp_label.text if _sp_panel.visible else ""


func turn_text() -> String:
	return _turn_label.text


func log_text() -> String:
	return _log.get_parsed_text()


func end_turn_enabled() -> bool:
	return not _end_turn_button.disabled


func banner_visible() -> bool:
	return _banner.visible


func banner_text() -> String:
	return _banner.text


static func turn_bar_text(round_index: int, order: Array[Unit], alive: Array[bool], turn_index: int) -> String:
	var parts: PackedStringArray = []
	for i in order.size():
		if not alive[i]:
			continue
		var unit_name: String = order[i].data.display_name
		if i < turn_index:
			parts.append("[color=#%s]%s[/color]" % [ACTED_COLOR.to_html(false), unit_name])
		elif i == turn_index:
			parts.append("[b][color=#%s]▶%s[/color][/b]" % [CURRENT_TURN_COLOR.to_html(false), unit_name])
		else:
			parts.append(unit_name)
	return "R%d  %s" % [round_index, " → ".join(parts)]


func _refresh_sp(actor: Unit) -> void:
	_sp_panel.visible = actor != null and actor.is_ally()
	if not _sp_panel.visible:
		return
	var max_sp: int = (actor.data as AllyData).max_sp
	var pips: String = "●".repeat(actor.sp) + "○".repeat(maxi(max_sp - actor.sp, 0))
	_sp_label.text = "SP\n%s\n%d / %d" % [pips, actor.sp, max_sp]


func _refresh_hand() -> void:
	# queue_free 만 하면 이번 프레임 동안 자식으로 남아 hand_buttons() 가 옛 버튼을 돌려준다.
	for child in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()
	if _actor == null or not _actor.is_ally():
		return
	for i in _actor.hand.size():
		var card: CardData = _actor.hand[i]
		var button := Button.new()
		var melee: bool = card.attack_type == CardData.AttackType.MELEE
		button.text = "%s  [%s]\nSP %d · %d뎀 · 사거리 %d" % [card.display_name, "근접" if melee else "원거리", card.sp_cost, card.damage, card.attack_range]
		_set_outline(button, _melee_card_boxes if melee else _ranged_card_boxes)
		button.toggle_mode = true
		button.button_pressed = i == _selected_card
		button.pressed.connect(_on_card_pressed.bind(i))
		_hand_box.add_child(button)
	_apply_interactive()


func _apply_interactive() -> void:
	_end_turn_button.disabled = not _interactive
	for i in _hand_box.get_child_count():
		var button: Button = _hand_box.get_child(i)
		var affordable: bool = _actor != null and i < _actor.hand.size() and _actor.hand[i].sp_cost <= _actor.sp
		button.disabled = not _interactive or not affordable


func _on_card_pressed(index: int) -> void:
	_selected_card = -1 if _selected_card == index else index
	for i in _hand_box.get_child_count():
		(_hand_box.get_child(i) as Button).set_pressed_no_signal(i == _selected_card)
	card_selected.emit(_selected_card)


func _on_end_turn_button_pressed() -> void:
	end_turn_pressed.emit()


func _make_outline_boxes(color: Color) -> Dictionary:
	var boxes: Dictionary = {}
	for state in OUTLINED_STATES:
		# 기본 테마에는 hover_pressed 가 없다 (2026-09-13 확인).
		if not has_theme_stylebox(state, &"Button"):
			continue
		var box: StyleBox = get_theme_stylebox(state, &"Button").duplicate()
		var flat := box as StyleBoxFlat
		if flat != null:
			flat.border_color = color
			flat.set_border_width_all(3)
		boxes[state] = box
	return boxes


func _set_outline(button: Button, boxes: Dictionary) -> void:
	for state in OUTLINED_STATES:
		if boxes.has(state):
			button.add_theme_stylebox_override(state, boxes[state])
		else:
			button.remove_theme_stylebox_override(state)
