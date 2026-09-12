extends Control

@export var encounter: EncounterData

var _state: BattleState
var _selected_card: int = -1

@onready var _ally_grid: GridContainer = %AllyGrid
@onready var _enemy_grid: GridContainer = %EnemyGrid
@onready var _hand_box: HBoxContainer = %HandBox
@onready var _turn_label: Label = %TurnLabel
@onready var _log: RichTextLabel = %BattleLog
@onready var _end_turn_button: Button = %EndTurnButton

var _cells: Dictionary = {}


func _ready() -> void:
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
	for key in _cells:
		var button: Button = _cells[key]
		var unit: Unit = _unit_at(key.x, Vector2i(key.y, key.z))
		if unit == null:
			button.text = "-"
			button.disabled = true
			continue
		var line: String = "%s\nHP %d/%d" % [unit.data.display_name, unit.hp, unit.data.max_hp]
		if unit.block > 0:
			line += "  방%d" % unit.block
		if unit.is_ally():
			line += "\nSP %d" % unit.sp
		button.text = line
		button.disabled = false

	_refresh_hand()

	var actor: Unit = _state.current_unit()
	if _state.finished:
		_turn_label.text = "승리!" if _state.ally_won else "패배..."
	elif actor != null:
		_turn_label.text = "R%d  %s 차례" % [_state.round_index, actor.data.display_name]
	_end_turn_button.disabled = _state.finished


func _refresh_hand() -> void:
	for child in _hand_box.get_children():
		child.queue_free()

	var actor: Unit = _state.current_unit()
	if actor == null or not actor.is_ally() or _state.finished:
		return

	for i in actor.hand.size():
		var card: CardData = actor.hand[i]
		var button := Button.new()
		button.text = "%s\nSP %d / %d뎀" % [card.display_name, card.sp_cost, card.damage]
		button.toggle_mode = true
		button.button_pressed = (i == _selected_card)
		button.disabled = card.sp_cost > actor.sp
		button.pressed.connect(_on_card_pressed.bind(i))
		_hand_box.add_child(button)


func _on_card_pressed(index: int) -> void:
	_selected_card = -1 if _selected_card == index else index
	_refresh_hand()


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
