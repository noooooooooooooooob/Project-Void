class_name BattleState
extends RefCounted

signal turn_started(unit: Unit)
signal unit_damaged(unit: Unit, amount: int)
signal unit_died(unit: Unit)
signal battle_ended(ally_won: bool)
signal log_message(text: String)
signal card_played(actor: Unit, card: CardData, primary: Unit)
signal enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit)
signal unit_healed(unit: Unit, amount: int)
signal block_gained(unit: Unit, amount: int)
signal deck_reshuffled(unit: Unit, count: int)
signal card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int)
signal hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)

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


func apply_heal(target: Unit, amount: int) -> void:
	var before: int = target.hp
	target.heal(amount)
	unit_healed.emit(target, target.hp - before)


func apply_block(target: Unit, amount: int) -> void:
	target.gain_block(amount)
	block_gained.emit(target, amount)


func report_enemy_action(actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
	enemy_acted.emit(actor, action, target)


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
	card_played.emit(actor, card, primary)
	write_log("%s → %s (%s)" % [actor.data.display_name, primary.data.display_name, card.display_name])

	for victim in resolver.expand_shape(primary, card.shape, units):
		apply_damage(victim, card.damage)

	check_end()
	return true


func start_battle() -> void:
	# 유닛이 전혀 없는(또는 이미 결판난) 인카운터라면 여기서 즉시 끝내야 한다.
	# 그렇지 않으면 _run_until_player_input() 이 매 라운드 빈 initiative 만
	# 반복 계산하며 멈추지 않는다.
	check_end()
	_start_round()
	_run_until_player_input()


func end_turn() -> void:
	var actor: Unit = current_unit()
	if actor != null and actor.is_ally():
		_discard_hand(actor)
	_run_until_player_input()


func _start_round() -> void:
	round_index += 1
	initiative = _compute_initiative()
	turn_index = -1


func _compute_initiative() -> Array[Unit]:
	var alive: Array[Unit] = []
	for unit in units:
		if unit.is_alive():
			alive.append(unit)
	alive.sort_custom(_initiative_sorter)
	return alive


func _initiative_sorter(a: Unit, b: Unit) -> bool:
	if a.data.speed != b.data.speed:
		return a.data.speed > b.data.speed
	return a.unit_id < b.unit_id


# 다음 아군 차례에서 멈춘다. 적 차례는 그 자리에서 해결하고 지나간다.
func _run_until_player_input() -> void:
	while not finished:
		turn_index += 1
		if turn_index >= initiative.size():
			_start_round()
			continue

		var actor: Unit = initiative[turn_index]
		if not actor.is_alive():
			continue

		actor.block = 0
		turn_started.emit(actor)

		if actor.is_ally():
			actor.sp = (actor.data as AllyData).max_sp
			_draw_cards(actor, DRAW_PER_TURN)
			return

		_take_enemy_turn(actor)
		check_end()


# Unit.draw 와 같은 순서로 한 장씩 진행하되, 화면이 순서대로 연출할 수 있게 매 단계 신호를 낸다.
func _draw_cards(actor: Unit, count: int) -> void:
	for _i in count:
		if actor.deck.is_empty():
			if actor.discard.is_empty():
				return
			deck_reshuffled.emit(actor, actor.reshuffle_discard(rng))
		var card: CardData = actor.draw_one()
		card_drawn.emit(actor, card, actor.deck.size(), actor.discard.size())


func _discard_hand(actor: Unit) -> void:
	var cards: Array[CardData] = actor.hand.duplicate()
	actor.discard_hand()
	hand_discarded.emit(actor, cards, actor.discard.size())


func _take_enemy_turn(actor: Unit) -> void:
	EnemyBrain.take_turn(self, actor)
