extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_initiative_sorted_by_speed()
	_test_initiative_ties_broken_by_id()
	_test_turn_start_refills_sp_and_draws()
	_test_end_turn_discards_hand()
	_test_dead_units_are_skipped()
	_test_new_round_after_everyone_acted()
	_test_empty_encounter_finishes_without_hanging()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	return rng


func _ally(id: StringName, speed: int, deck_size: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 30
	data.speed = speed
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		var card: CardData = CardDataScript.new()
		card.id = StringName("%s_c%d" % [id, i])
		deck.append(card)
	data.deck = deck
	return data


func _enemy(id: StringName, speed: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 10
	data.speed = speed
	return data


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _state(allies: Array, enemies: Array) -> BattleState:
	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	var ally_placements: Array[UnitPlacement] = []
	var row: int = 0
	for data in allies:
		ally_placements.append(_placement(data, Vector2i(0, row)))
		row += 1
	var enemy_placements: Array[UnitPlacement] = []
	row = 0
	for data in enemies:
		enemy_placements.append(_placement(data, Vector2i(0, row)))
		row += 1
	encounter.ally_units = ally_placements
	encounter.enemy_units = enemy_placements
	return BattleStateScript.new(encounter, _rng())


func _test_initiative_sorted_by_speed() -> void:
	var state: BattleState = _state([_ally(&"slow", 5, 6), _ally(&"fast", 20, 6)], [_enemy(&"mid", 10)])
	state.start_battle()
	check_eq("fastest acts first", state.initiative[0].data.id, &"fast")
	check_eq("enemy in the middle", state.initiative[1].data.id, &"mid")
	check_eq("slowest acts last", state.initiative[2].data.id, &"slow")


func _test_initiative_ties_broken_by_id() -> void:
	var state: BattleState = _state([_ally(&"a", 10, 6), _ally(&"b", 10, 6)], [_enemy(&"e", 10)])
	state.start_battle()
	var ids: Array = []
	for unit in state.initiative:
		ids.append(unit.unit_id)
	check_eq("ties resolve by ascending unit_id", ids, [0, 1, 2])


func _test_turn_start_refills_sp_and_draws() -> void:
	var state: BattleState = _state([_ally(&"a", 20, 6)], [_enemy(&"e", 1)])
	state.start_battle()
	var actor: Unit = state.current_unit()
	check_eq("stopped on the ally", actor.data.id, &"a")
	check_eq("sp refilled", actor.sp, 3)
	check_eq("drew four cards", actor.hand.size(), BattleState.DRAW_PER_TURN)
	check_eq("block reset", actor.block, 0)


# 아군을 둘 두는 이유: end_turn 은 "다음 아군 차례"까지 진행하므로,
# 아군이 하나뿐이면 같은 유닛이 다음 라운드에 곧바로 다시 드로우해서
# 손패가 비워졌는지 확인할 수 없다.
func _test_end_turn_discards_hand() -> void:
	var state: BattleState = _state([_ally(&"first", 20, 6), _ally(&"second", 15, 6)], [_enemy(&"e", 1)])
	state.start_battle()
	var actor: Unit = state.current_unit()
	check_eq("faster ally goes first", actor.data.id, &"first")
	state.end_turn()
	check_eq("hand emptied at end of turn", actor.hand.size(), 0)
	check_eq("hand moved to discard", actor.discard.size(), BattleState.DRAW_PER_TURN)
	check_eq("turn passed to the next ally", state.current_unit().data.id, &"second")


func _test_dead_units_are_skipped() -> void:
	var state: BattleState = _state([_ally(&"fast", 20, 6), _ally(&"slow", 5, 6)], [_enemy(&"e", 10)])
	state.start_battle()
	var slow: Unit = state.initiative[2]
	slow.take_damage(999)
	state.end_turn()
	check("dead ally never becomes current", state.current_unit() != slow)


func _test_new_round_after_everyone_acted() -> void:
	var state: BattleState = _state([_ally(&"a", 20, 8)], [_enemy(&"e", 1)])
	state.start_battle()
	check_eq("first round", state.round_index, 1)
	state.end_turn()
	check_eq("second round begins", state.round_index, 2)
	check_eq("ally acts again", state.current_unit().data.id, &"a")


# 유닛이 하나도 없는 인카운터(작성 실수로 빈 encounter 가 로드된 경우 등)에서
# start_battle() 이 무한 루프에 빠지지 않고 즉시 종료되는지 확인한다.
func _test_empty_encounter_finishes_without_hanging() -> void:
	var state: BattleState = _state([], [])
	state.start_battle()
	check("start_battle returns instead of hanging", true)
	check_eq("battle already finished with no units", state.finished, true)
