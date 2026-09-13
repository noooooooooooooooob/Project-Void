extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_start_battle_records_first_turn()
	_test_end_turn_records_enemies_in_order()
	_test_card_play_records_action_then_damage()
	_test_kill_records_death_and_battle_end()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	return rng


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _enemy(id: StringName, speed: int, damage: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 20
	data.speed = speed
	data.attack_damage = damage
	data.attack_type = CardData.AttackType.RANGED
	data.attack_shape = CardData.Shape.SINGLE
	data.attack_range = 9
	data.block_amount = 5
	data.rest_heal = 0
	return data


# 아군 a(속도 10) 1기 vs 적 e1(속도 5, 피해 4), e2(속도 4, 피해 3).
func _state(card_damage: int, enemy_count: int) -> BattleState:
	var card: CardData = CardDataScript.new()
	card.id = &"zap"
	card.display_name = "zap"
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	card.shape = CardData.Shape.SINGLE
	card.attack_range = 9
	card.damage = card_damage

	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = 3
	var deck: Array[CardData] = [card]
	ally.deck = deck

	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(_enemy(&"e1", 5, 4), Vector2i(0, 0))]
	if enemy_count > 1:
		enemies.append(_placement(_enemy(&"e2", 4, 3), Vector2i(0, 1)))

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return BattleStateScript.new(encounter, _rng())


func _kinds(events: Array[BattleEvent]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func _test_start_battle_records_first_turn() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	var events: Array[BattleEvent] = recorder.take_events()

	check_eq("one event", events.size(), 1)
	check_eq("turn started", events[0].kind, BattleEvent.Kind.TURN_STARTED)
	check("subject is the ally", events[0].unit.is_ally())
	check_eq("round snapshot", events[0].round_index, 1)
	check_eq("turn index snapshot", events[0].turn_index, 0)
	check_eq("order has every unit", events[0].order.size(), 3)
	check_eq("alive flags", events[0].alive, [true, true, true])
	check_eq("hp snapshot", events[0].hp, 30)
	check_eq("take_events empties the queue", recorder.take_events().size(), 0)


func _test_end_turn_records_enemies_in_order() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]

	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("event kinds in play order", _kinds(events), [
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED,
	])
	check_eq("faster enemy acts first", events[0].unit.data.id, &"e1")
	check_eq("attack targets the ally", events[1].target.data.id, &"a")
	check_eq("first hit snapshot", events[3].hp, 26)
	check_eq("second hit snapshot", events[7].hp, 23)
	check_eq("last snapshot matches state", events[7].hp, ally.hp)
	check_eq("ally's next turn is round 2", events[8].round_index, 2)


func _test_card_play_records_action_then_damage() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	state.play_card(0, foe)
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("card play kinds", _kinds(events), [k.CARD_PLAYED, k.LOG, k.DAMAGED])
	check("target is the clicked enemy", events[0].target == foe)
	check_eq("card recorded", events[0].card.id, &"zap")
	check_eq("damage amount", events[2].amount, 1)
	check_eq("damage hp snapshot", events[2].hp, 19)


func _test_kill_records_death_and_battle_end() -> void:
	var state: BattleState = _state(50, 1)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	state.play_card(0, foe)
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("kill kinds", _kinds(events), [k.CARD_PLAYED, k.LOG, k.DAMAGED, k.DIED, k.LOG, k.BATTLE_ENDED])
	check("died event names the foe", events[3].unit == foe)
	check("death log follows", events[4].text.ends_with("쓰러짐"))
	check("ally won", events[5].ally_won)
