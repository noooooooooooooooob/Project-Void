# BattleEventRecorder(신호 → 이벤트 기록) 테스트: 이벤트 종류 순서와 기록 시점 값(체력, 장수, 라운드 등).
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 전투 시작: 첫 차례 기록.
	_test_start_battle_records_first_turn()
	# 차례 종료: 적 차례들이 순서대로 기록.
	_test_end_turn_records_enemies_in_order()
	# 카드 사용: 행동 → 로그 → 피해.
	_test_card_play_records_action_then_damage()
	# 처치: 쓰러짐과 전투 종료.
	_test_kill_records_death_and_battle_end()
	# 방어·휴식 기록.
	_test_defend_and_rest_record_snapshots()
	_test_card_zone_events_snapshot()
	# 아군 이동: 이동 → 로그.
	_test_ally_move_records_move_then_log()
	# 적 이동: 행동 → 이동 → 로그.
	_test_enemy_move_records_action_move_log()
	_test_damage_records_critical()
	return results()


# 시드 99 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	return rng


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 원거리 단일 공격 적 (휴식 카드가 없어 휴식하지 않는다).
func _enemy(id: StringName, speed: int, damage: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = id
	data.display_name = String(id)
	data.max_hp = 20
	data.speed = speed
	data.crit_chance = 0
	# 원거리 단일 피해 damage·방어도 5·회복 없음 카드 (공격·방어 10 기준이라 % = 수치 × 10).
	Fixtures.enemy_cards(data, Fixtures.damage_card(&"enemy_attack", CardData.AttackType.RANGED, damage * 10), 50, 0)
	# 무작위 이동을 끈다 (이벤트 순서를 정확히 확인하기 위해).
	data.move_chance = 0.0
	return data


# 아군 a(속도 10) 1기 vs 적 e1(속도 5, 피해 4), e2(속도 4, 피해 3).
# 아군 덱은 zap(원거리, 피해 card_damage) 한 장. enemy_count 가 1 이면 e1 만.
func _state(card_damage: int, enemy_count: int) -> BattleState:
	# zap 카드.
	var card: CardData = CardDataScript.new()
	# id.
	card.id = &"zap"
	card.display_name = "zap"
	# 비용 1.
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	card.effects = [Fixtures.effect(CardEffect.Kind.DAMAGE, card_damage * 10)]

	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	# SP.
	ally.max_sp = 3
	var deck: Array[CardData] = [card]
	ally.deck = deck

	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	# 적 배치 (e1).
	var enemies: Array[UnitPlacement] = [_placement(_enemy(&"e1", 5, 4), Vector2i(0, 0))]
	# 둘이면 e2 도.
	if enemy_count > 1:
		enemies.append(_placement(_enemy(&"e2", 4, 3), Vector2i(0, 1)))

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return BattleStateScript.new(encounter, _rng())


# 이벤트 목록을 종류 목록으로 바꾼다 (순서 비교용).
func _kinds(events: Array[BattleEvent]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


# 시작하면 [차례 시작, 드로우] 가 기록되고, 차례 시작 이벤트에 라운드·순서·생존·체력·드로우 전 장수가 담기는지.
func _test_start_battle_records_first_turn() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	var events: Array[BattleEvent] = recorder.take_events()
	# 종류 enum 을 짧게 부르기 위한 별칭.
	var k := BattleEvent.Kind

	check_eq("turn start then the single draw", _kinds(events), [k.TURN_STARTED, k.CARD_DRAWN])
	check("subject is the ally", events[0].unit.is_ally())
	# 1 라운드.
	check_eq("round snapshot", events[0].round_index, 1)
	# 순서 0 번째.
	check_eq("turn index snapshot", events[0].turn_index, 0)
	# 순서에 3 명.
	check_eq("order has every unit", events[0].order.size(), 3)
	check_eq("alive flags", events[0].alive, [true, true, true])
	# 체력 30.
	check_eq("hp snapshot", events[0].hp, 30)
	check_eq("cell snapshot", events[0].cell, Vector2i(0, 1))
	# 드로우 전 덱 1.
	check_eq("deck snapshot before the draw", events[0].deck_count, 1)
	# 드로우 전 묘지 0.
	check_eq("discard snapshot before the draw", events[0].discard_count, 0)
	check_eq("take_events empties the queue", recorder.take_events().size(), 0)


# 차례 종료 뒤: 버리기 → e1 차례(행동·로그·피해) → e2 차례 → 아군 차례(리셔플·드로우) 순서와 체력 기록.
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
		k.HAND_DISCARDED,
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED, k.ENEMY_ACTED, k.LOG, k.DAMAGED,
		k.TURN_STARTED, k.DECK_RESHUFFLED, k.CARD_DRAWN,
	])
	# 빠른 e1 이 먼저.
	check_eq("faster enemy acts first", events[1].unit.data.id, &"e1")
	check_eq("attack targets the ally", events[2].target.data.id, &"a")
	# 첫 피해 후 체력 30 - 4 = 26.
	check_eq("first hit snapshot", events[4].hp, 26)
	# 둘째 피해 후 26 - 3 = 23.
	check_eq("second hit snapshot", events[8].hp, 23)
	# 마지막 기록이 실제 상태와 같다.
	check_eq("last snapshot matches state", events[8].hp, ally.hp)
	# 아군 다음 차례는 2 라운드.
	check_eq("ally's next turn is round 2", events[9].round_index, 2)


# 카드 사용: [카드 사용, 로그, 피해] 순서와 대상·카드·피해량·체력·사용 직후 장수.
func _test_card_play_records_action_then_damage() -> void:
	# 피해 1 카드, 적 둘.
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	# 첫 적 (e1).
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	state.play_card(0, foe)
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("card play kinds", _kinds(events), [k.CARD_PLAYED, k.LOG, k.DAMAGED])
	check("target is the clicked enemy", events[0].target == foe)
	check_eq("card recorded", events[0].card.id, &"zap")
	# 피해량 1.
	check_eq("damage amount", events[2].amount, 1)
	# 체력 19.
	check_eq("damage hp snapshot", events[2].hp, 19)
	# 사용 직후 덱 0.
	check_eq("deck after playing", events[0].deck_count, 0)
	# 사용 직후 묘지 1.
	check_eq("discard after playing", events[0].discard_count, 1)


# 한 방에 처치: [사용, 로그, 피해, 쓰러짐, 쓰러짐 로그, 전투 종료] 순서와 승리 기록.
func _test_kill_records_death_and_battle_end() -> void:
	# 피해 50 카드, 적 하나.
	var state: BattleState = _state(50, 1)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 카드 사용 (처치).
	state.play_card(0, foe)
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("kill kinds", _kinds(events), [k.CARD_PLAYED, k.LOG, k.DAMAGED, k.DIED, k.LOG, k.BATTLE_ENDED])
	check("died event names the foe", events[3].unit == foe)
	check_eq("died cell snapshot", events[3].cell, Vector2i(0, 0))
	check("death log follows", events[4].text.ends_with("쓰러짐"))
	check("ally won", events[5].ally_won)


# 방어: [행동, 방어도, 로그] 와 방어도 값 / 휴식: [행동, 회복, 로그] 와 회복량·체력.
func _test_defend_and_rest_record_snapshots() -> void:
	var state: BattleState = _state(1, 1)
	var recorder := BattleEventRecorder.new(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 적 데이터 (수치를 바꿔 행동을 유도한다).
	var data: EnemyData = foe.data as EnemyData
	var k := BattleEvent.Kind

	# 공격 카드를 빼면 칠 대상이 없어 방어를 고른다.
	data.attack_card = null
	EnemyBrain.take_turn(state, foe)
	var defend: Array[BattleEvent] = recorder.take_events()
	check_eq("defend kinds", _kinds(defend), [k.ENEMY_ACTED, k.BLOCK_GAINED, k.LOG])
	check_eq("defend action", defend[0].action, EnemyBrain.Action.DEFEND)
	check("defend has no target", defend[0].target == null)
	# 얻은 양 5.
	check_eq("block amount", defend[1].amount, 5)
	# 방어도 5.
	check_eq("block snapshot", defend[1].block, 5)

	# 방어도 5 가 먼저 흡수해 HP 는 5 (25%) 가 되고, 휴식 카드(회복 40% = 4)가 있으니 휴식을 고른다.
	Fixtures.enemy_cards(data, null, 50, 40)
	# 피해 20.
	foe.take_damage(20)
	EnemyBrain.take_turn(state, foe)
	var rest: Array[BattleEvent] = recorder.take_events()
	check_eq("rest kinds", _kinds(rest), [k.ENEMY_ACTED, k.HEALED, k.LOG])
	check_eq("rest action", rest[0].action, EnemyBrain.Action.REST)
	# 회복량 4.
	check_eq("heal amount", rest[1].amount, 4)
	# 체력 9.
	check_eq("heal hp snapshot", rest[1].hp, 9)


# 차례 종료 뒤 버리기(0번)·리셔플(10번)·드로우(11번) 이벤트에 담긴 카드와 장수.
func _test_card_zone_events_snapshot() -> void:
	var state: BattleState = _state(1, 2)
	var recorder := BattleEventRecorder.new(state)
	state.start_battle()
	recorder.take_events()

	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()
	var discarded: BattleEvent = events[0]
	var reshuffled: BattleEvent = events[10]
	var drawn: BattleEvent = events[11]
	# 버린 카드 1 장.
	check_eq("discarded cards", discarded.cards.size(), 1)
	# 버린 뒤 묘지 1.
	check_eq("discard pile after discarding", discarded.discard_count, 1)
	# 버릴 때 덱 0.
	check_eq("deck when discarding", discarded.deck_count, 0)
	# 리셔플 1 장.
	check_eq("reshuffled amount", reshuffled.amount, 1)
	# 리셔플 뒤 덱 1.
	check_eq("deck after reshuffle", reshuffled.deck_count, 1)
	# 리셔플 뒤 묘지 0.
	check_eq("discard after reshuffle", reshuffled.discard_count, 0)
	# 뽑은 카드 zap.
	check_eq("drawn card", drawn.card.id, &"zap")
	# 뽑은 뒤 덱 0.
	check_eq("deck after the draw", drawn.deck_count, 0)


# 아군이 (0,1)→(1,1) 로 이동하면 [UNIT_MOVED, LOG] 가 기록되고 두 칸·유닛·로그 문장이 맞는지.
func _test_ally_move_records_move_then_log() -> void:
	var state: BattleState = _state(1, 1)
	var recorder := BattleEventRecorder.new(state)
	# 시작 (아군 차례).
	state.start_battle()
	recorder.take_events()

	state.move_unit(Vector2i(1, 1))
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("ally move kinds", _kinds(events), [k.UNIT_MOVED, k.LOG])
	check_eq("from cell", events[0].from_cell, Vector2i(0, 1))
	check_eq("to cell", events[0].to_cell, Vector2i(1, 1))
	check("moved unit is the ally", events[0].unit.is_ally())
	check_eq("move log text", events[1].text, "a 이동")


# 이동 확률 100% 적의 차례를 돌리면 [ENEMY_ACTED(MOVE), UNIT_MOVED, LOG] 이고 새 칸이 실제 칸과 같은지.
func _test_enemy_move_records_action_move_log() -> void:
	# 적 하나인 전투 (e1 은 적 격자 (0,0)).
	var state: BattleState = _state(1, 1)
	var recorder := BattleEventRecorder.new(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	(foe.data as EnemyData).move_chance = 1.0
	EnemyBrain.take_turn(state, foe)
	var events: Array[BattleEvent] = recorder.take_events()
	var k := BattleEvent.Kind
	check_eq("enemy move kinds", _kinds(events), [k.ENEMY_ACTED, k.UNIT_MOVED, k.LOG])
	check_eq("enemy action is move", events[0].action, EnemyBrain.Action.MOVE)
	# 기록된 새 칸 = 실제 칸.
	check_eq("recorded destination matches the unit", events[1].to_cell, foe.cell)


# 치명타 피해는 DAMAGED 기록의 critical 이 true.
func _test_damage_records_critical() -> void:
	# 상태 (카드 피해 1, 적 1명).
	var state: BattleState = _state(1, 1)
	var recorder := BattleEventRecorder.new(state)
	# 피해를 직접 적용한다 (치명).
	state.apply_damage(state.units[1], 3, true)
	var events: Array[BattleEvent] = recorder.take_events()
	# DAMAGED + critical.
	check("damaged critical recorded", events[0].kind == BattleEvent.Kind.DAMAGED and events[0].critical)
