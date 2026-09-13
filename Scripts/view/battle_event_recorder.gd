class_name BattleEventRecorder
extends RefCounted

var _events: Array[BattleEvent] = []
# 레코더는 상태를 관찰만 할 뿐 생명 주기를 책임지지 않는다 (소유자인 BattleRoot 가 살려 둔다).
var _state_ref: WeakRef


func _init(state: BattleState) -> void:
	_state_ref = weakref(state)
	state.turn_started.connect(_on_turn_started)
	state.card_played.connect(_on_card_played)
	state.enemy_acted.connect(_on_enemy_acted)
	state.unit_damaged.connect(_on_unit_damaged)
	state.unit_healed.connect(_on_unit_healed)
	state.block_gained.connect(_on_block_gained)
	state.unit_died.connect(_on_unit_died)
	state.log_message.connect(_on_log_message)
	state.battle_ended.connect(_on_battle_ended)


func take_events() -> Array[BattleEvent]:
	var taken: Array[BattleEvent] = _events
	_events = []
	return taken


func _on_turn_started(unit: Unit) -> void:
	var state: BattleState = _state_ref.get_ref()
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.unit = unit
	event.hp = unit.hp
	event.block = unit.block
	event.round_index = state.round_index
	event.turn_index = state.turn_index
	event.order = state.initiative.duplicate()
	for member in state.initiative:
		event.alive.append(member.is_alive())
	_events.append(event)


func _on_card_played(actor: Unit, card: CardData, primary: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	event.unit = actor
	event.card = card
	event.target = primary
	_events.append(event)


func _on_enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.ENEMY_ACTED)
	event.unit = actor
	event.action = action
	event.target = target
	_events.append(event)


func _on_unit_damaged(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DAMAGED)
	event.unit = unit
	event.amount = amount
	event.hp = unit.hp
	event.block = unit.block
	_events.append(event)


func _on_unit_healed(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.HEALED)
	event.unit = unit
	event.amount = amount
	event.hp = unit.hp
	_events.append(event)


func _on_block_gained(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.BLOCK_GAINED)
	event.unit = unit
	event.amount = amount
	event.block = unit.block
	_events.append(event)


func _on_unit_died(unit: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DIED)
	event.unit = unit
	_events.append(event)


func _on_log_message(text: String) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.LOG)
	event.text = text
	_events.append(event)


func _on_battle_ended(ally_won: bool) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.BATTLE_ENDED)
	event.ally_won = ally_won
	_events.append(event)
