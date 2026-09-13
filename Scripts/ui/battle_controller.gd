extends Control

const CURRENT_TURN_COLOR := Color(1.0, 0.82, 0.3)
const VALID_TARGET_COLOR := Color(0.45, 0.85, 0.45)
const MELEE_CARD_COLOR := Color(0.85, 0.4, 0.35)
const RANGED_CARD_COLOR := Color(0.4, 0.6, 0.95)
const ACTED_COLOR := Color(0.5, 0.5, 0.5)
const UNAVAILABLE_MODULATE := Color(1, 1, 1, 0.45)
const OUTLINED_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]

@export var encounter: EncounterData

var _state: BattleState
var _selected_card: int = -1

@onready var _ally_grid: GridContainer = %AllyGrid
@onready var _enemy_grid: GridContainer = %EnemyGrid
@onready var _hand_box: HBoxContainer = %HandBox
@onready var _turn_label: RichTextLabel = %TurnLabel
@onready var _sp_panel: PanelContainer = %SpPanel
@onready var _sp_label: Label = %SpLabel
@onready var _log: RichTextLabel = %BattleLog
@onready var _end_turn_button: Button = %EndTurnButton

var _cells: Dictionary = {}
var _current_turn_boxes: Dictionary = {}
var _valid_target_boxes: Dictionary = {}
var _melee_card_boxes: Dictionary = {}
var _ranged_card_boxes: Dictionary = {}


func _ready() -> void:
	_current_turn_boxes = _make_outline_boxes(CURRENT_TURN_COLOR)
	_valid_target_boxes = _make_outline_boxes(VALID_TARGET_COLOR)
	_melee_card_boxes = _make_outline_boxes(MELEE_CARD_COLOR)
	_ranged_card_boxes = _make_outline_boxes(RANGED_CARD_COLOR)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	_state = BattleState.new(encounter, rng)
	_state.turn_started.connect(_on_turn_started)
	_state.unit_damaged.connect(_on_unit_damaged)
	_state.battle_ended.connect(_on_battle_ended)
	_state.log_message.connect(_append_log)

	_end_turn_button.pressed.connect(_on_end_turn_pressed)

	_build_grid(_ally_grid, encounter.ally_grid, Unit.Team.ALLY)
	_build_grid(_enemy_grid, encounter.enemy_grid, Unit.Team.ENEMY)

	_state.start_battle()
	_refresh()


# 아군은 화면 왼쪽이라 col 0(최전열)이 오른쪽 끝에 와야 한다.
func _build_grid(container: GridContainer, size: Vector2i, team: Unit.Team) -> void:
	container.columns = size.x
	for row in size.y:
		for screen_col in size.x:
			var col: int = (size.x - 1 - screen_col) if team == Unit.Team.ALLY else screen_col
			var button := Button.new()
			button.custom_minimum_size = Vector2(120, 72)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD
			button.pressed.connect(_on_cell_pressed.bind(team, Vector2i(col, row)))
			container.add_child(button)
			# 키를 Vector3i(team, col, row) 로 두는 이유: 배열을 Dictionary 키로 쓰면
			# 해시가 내용 기준이라 동작은 하지만 의도가 드러나지 않는다.
			_cells[Vector3i(team, col, row)] = button


func _unit_at(team: Unit.Team, cell: Vector2i) -> Unit:
	for unit in _state.units:
		if unit.team == team and unit.cell == cell and unit.is_alive():
			return unit
	return null


func _refresh() -> void:
	var actor: Unit = _state.current_unit()
	if _state.finished:
		actor = null
	var card: CardData = _selected_card_data(actor)

	for key in _cells:
		var button: Button = _cells[key]
		var unit: Unit = _unit_at(key.x, Vector2i(key.y, key.z))
		_set_outline(button, {})
		button.modulate = Color.WHITE
		if unit == null:
			button.text = "-"
			button.disabled = true
			continue
		var line: String = "%s\nHP %d/%d" % [unit.data.display_name, unit.hp, unit.data.max_hp]
		if unit.block > 0:
			line += "  방%d" % unit.block
		if card != null and not unit.is_ally():
			var valid: bool = _state.resolver.is_valid_target(actor, unit, card.attack_type, card.attack_range, _state.units)
			line += "\n" + _target_hint(actor, unit, card, valid)
			if valid:
				_set_outline(button, _valid_target_boxes)
			else:
				button.modulate = UNAVAILABLE_MODULATE
		if unit == actor:
			_set_outline(button, _current_turn_boxes)
		button.text = line
		button.disabled = false

	_refresh_hand()
	_refresh_sp(actor)
	_refresh_turn_bar()
	_end_turn_button.disabled = _state.finished


func _selected_card_data(actor: Unit) -> CardData:
	if actor == null or not actor.is_ally():
		return null
	if _selected_card < 0 or _selected_card >= actor.hand.size():
		return null
	return actor.hand[_selected_card]


# 칠 수 있는지는 is_valid_target 이 정하고, 여기서는 못 치는 이유만 고른다.
# 살아 있는 적만 넘어오므로 사거리 안인데 무효라면 근접 블로킹뿐이다.
func _target_hint(actor: Unit, target: Unit, card: CardData, valid: bool) -> String:
	var distance: int = _state.resolver.reach(actor, target)
	if valid:
		return "✓ 거리 %d" % distance
	if distance > card.attack_range:
		return "거리 %d" % distance
	return "막힘"


func _make_outline_boxes(color: Color) -> Dictionary:
	var boxes: Dictionary = {}
	for state in OUTLINED_STATES:
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


func _refresh_sp(actor: Unit) -> void:
	_sp_panel.visible = actor != null and actor.is_ally()
	if not _sp_panel.visible:
		return
	var max_sp: int = (actor.data as AllyData).max_sp
	var pips: String = "●".repeat(actor.sp) + "○".repeat(maxi(max_sp - actor.sp, 0))
	_sp_label.text = "SP\n%s\n%d / %d" % [pips, actor.sp, max_sp]


func _refresh_turn_bar() -> void:
	if _state.finished:
		_turn_label.text = "승리!" if _state.ally_won else "패배..."
		return

	var parts: PackedStringArray = []
	for i in _state.initiative.size():
		var unit: Unit = _state.initiative[i]
		if not unit.is_alive():
			continue
		var unit_name: String = unit.data.display_name
		if i < _state.turn_index:
			parts.append("[color=#%s]%s[/color]" % [ACTED_COLOR.to_html(false), unit_name])
		elif i == _state.turn_index:
			parts.append("[b][color=#%s]▶%s[/color][/b]" % [CURRENT_TURN_COLOR.to_html(false), unit_name])
		else:
			parts.append(unit_name)
	_turn_label.text = "R%d  %s" % [_state.round_index, " → ".join(parts)]


func _refresh_hand() -> void:
	for child in _hand_box.get_children():
		child.queue_free()

	var actor: Unit = _state.current_unit()
	if actor == null or not actor.is_ally() or _state.finished:
		return

	for i in actor.hand.size():
		var card: CardData = actor.hand[i]
		var button := Button.new()
		var melee: bool = card.attack_type == CardData.AttackType.MELEE
		button.text = "%s  [%s]\nSP %d · %d뎀 · 사거리 %d" % [card.display_name, "근접" if melee else "원거리", card.sp_cost, card.damage, card.attack_range]
		_set_outline(button, _melee_card_boxes if melee else _ranged_card_boxes)
		button.toggle_mode = true
		button.button_pressed = (i == _selected_card)
		button.disabled = card.sp_cost > actor.sp
		button.pressed.connect(_on_card_pressed.bind(i))
		_hand_box.add_child(button)


func _on_card_pressed(index: int) -> void:
	_selected_card = -1 if _selected_card == index else index
	_refresh()


func _on_cell_pressed(team: Unit.Team, cell: Vector2i) -> void:
	if _selected_card < 0 or team == Unit.Team.ALLY:
		return
	var target: Unit = _unit_at(team, cell)
	if target == null:
		return
	if _state.play_card(_selected_card, target):
		_selected_card = -1
	else:
		_append_log("사용할 수 없는 대상")
	_refresh()


func _on_end_turn_pressed() -> void:
	_selected_card = -1
	_state.end_turn()
	_refresh()


func _on_turn_started(unit: Unit) -> void:
	_append_log("― %s 차례" % unit.data.display_name)


func _on_unit_damaged(unit: Unit, amount: int) -> void:
	_append_log("%s 에게 %d 피해" % [unit.data.display_name, amount])


func _on_battle_ended(ally_won: bool) -> void:
	_append_log("전투 종료 — %s" % ("승리" if ally_won else "패배"))


func _append_log(text: String) -> void:
	_log.append_text(text + "\n")
