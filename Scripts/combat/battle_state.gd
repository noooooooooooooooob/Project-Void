class_name BattleState
extends RefCounted

signal turn_started(unit: Unit)
signal unit_damaged(unit: Unit, amount: int)
signal unit_died(unit: Unit)
signal battle_ended(ally_won: bool)
signal log_message(text: String)

const DRAW_PER_TURN: int = 4

var units: Array[Unit] = []
var resolver: TargetResolver
var rng: RandomNumberGenerator
var round_index: int = 0
var initiative: Array[Unit] = []
var turn_index: int = -1
var finished: bool = false
var ally_won: bool = false


func _init(encounter: EncounterData, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	resolver = TargetResolver.new(encounter.ally_grid, encounter.enemy_grid)

	var next_id: int = 0
	for placement in encounter.ally_units:
		var ally := Unit.new(next_id, placement.unit_data, Unit.Team.ALLY, placement.cell)
		ally.shuffle_deck(rng)
		units.append(ally)
		next_id += 1

	for placement in encounter.enemy_units:
		units.append(Unit.new(next_id, placement.unit_data, Unit.Team.ENEMY, placement.cell))
		next_id += 1


func living_units(team: Unit.Team) -> Array[Unit]:
	var alive: Array[Unit] = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			alive.append(unit)
	return alive


func current_unit() -> Unit:
	if turn_index < 0 or turn_index >= initiative.size():
		return null
	return initiative[turn_index]


# 시그널을 밖에서 직접 emit 하지 않도록 통로를 하나로 둔다.
# `log` 은 GDScript 전역 함수(자연로그)라 이름으로 쓸 수 없다.
func write_log(text: String) -> void:
	log_message.emit(text)


func apply_damage(target: Unit, amount: int) -> void:
	target.take_damage(amount)
	unit_damaged.emit(target, amount)
	if not target.is_alive():
		unit_died.emit(target)
		write_log("%s 쓰러짐" % target.data.display_name)


func check_end() -> void:
	if finished:
		return
	var allies_alive: bool = not living_units(Unit.Team.ALLY).is_empty()
	var enemies_alive: bool = not living_units(Unit.Team.ENEMY).is_empty()
	if allies_alive and enemies_alive:
		return
	finished = true
	ally_won = allies_alive
	battle_ended.emit(ally_won)


func play_card(hand_index: int, primary: Unit) -> bool:
	if finished:
		return false

	var actor: Unit = current_unit()
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	if hand_index < 0 or hand_index >= actor.hand.size():
		return false

	var card: CardData = actor.hand[hand_index]
	if card.sp_cost > actor.sp:
		return false
	if not resolver.is_valid_target(actor, primary, card.attack_type, card.attack_range, units):
		return false

	actor.sp -= card.sp_cost
	actor.hand.remove_at(hand_index)
	actor.discard.append(card)
	write_log("%s → %s (%s)" % [actor.data.display_name, primary.data.display_name, card.display_name])

	for victim in resolver.expand_shape(primary, card.shape, units):
		apply_damage(victim, card.damage)

	check_end()
	return true
