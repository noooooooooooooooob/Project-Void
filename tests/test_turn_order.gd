# 차례 진행 테스트: 속도 순서, 동률 처리, 차례 시작 시 SP·드로우, 차례 종료 시 버리기, 쓰러진 유닛 건너뛰기, 라운드 넘김.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 속도 순 정렬.
	_test_initiative_sorted_by_speed()
	# 속도가 같으면 번호 순.
	_test_initiative_ties_broken_by_id()
	# 차례 시작 시 SP 충전과 드로우.
	_test_turn_start_refills_sp_and_draws()
	# 차례 종료 시 손패 버리기.
	_test_end_turn_discards_hand()
	# 쓰러진 유닛은 차례를 받지 않는다.
	_test_dead_units_are_skipped()
	# 모두 행동하면 새 라운드.
	_test_new_round_after_everyone_acted()
	# 빈 전투는 멈추지 않고 끝난다.
	_test_empty_encounter_finishes_without_hanging()
	# 결과를 돌려준다.
	return results()


# 시드 999 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 999
	# 돌려준다.
	return rng


# id·속도·덱 장수를 정한 아군 데이터.
func _ally(id: StringName, speed: int, deck_size: int) -> AllyData:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = id
	# 이름.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = 30
	# 속도.
	data.speed = speed
	# SP.
	data.max_sp = 3
	# 덱 배열.
	var deck: Array[CardData] = []
	# 카드마다.
	for i in deck_size:
		# 빈 카드.
		var card: CardData = CardDataScript.new()
		# "아군id_c번호" 형식 id.
		card.id = StringName("%s_c%d" % [id, i])
		# 덱에 넣는다.
		deck.append(card)
	# 데이터에 덱을 넣는다.
	data.deck = deck
	# 돌려준다.
	return data


# id·속도를 정한 적 데이터 (나머지는 기본값).
func _enemy(id: StringName, speed: int) -> EnemyData:
	# 적 데이터.
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = id
	# 이름.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = 10
	# 속도.
	data.speed = speed
	# 돌려준다.
	return data


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# 아군·적 데이터 목록을 각자 앞줄에 위에서부터 한 행씩 세워 전투 상태를 만든다.
func _state(allies: Array, enemies: Array) -> BattleState:
	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자.
	encounter.enemy_grid = Vector2i(3, 3)
	# 아군 배치 배열.
	var ally_placements: Array[UnitPlacement] = []
	# 행 번호.
	var row: int = 0
	# 아군마다.
	for data in allies:
		# 앞줄 row 행에 세운다.
		ally_placements.append(_placement(data, Vector2i(0, row)))
		# 다음 행.
		row += 1
	# 적 배치 배열.
	var enemy_placements: Array[UnitPlacement] = []
	# 행 번호를 처음으로.
	row = 0
	# 적마다.
	for data in enemies:
		# 앞줄 row 행에 세운다.
		enemy_placements.append(_placement(data, Vector2i(0, row)))
		# 다음 행.
		row += 1
	# 아군 배치.
	encounter.ally_units = ally_placements
	# 적군 배치.
	encounter.enemy_units = enemy_placements
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, _rng())


# 속도 20(아군) > 10(적) > 5(아군) 순서로 행동 순서가 정렬되는지.
func _test_initiative_sorted_by_speed() -> void:
	# 느린 아군, 빠른 아군, 중간 적.
	var state: BattleState = _state([_ally(&"slow", 5, 6), _ally(&"fast", 20, 6)], [_enemy(&"mid", 10)])
	# 시작 (행동 순서 계산).
	state.start_battle()
	# 1 번째 fast.
	check_eq("fastest acts first", state.initiative[0].data.id, &"fast")
	# 2 번째 mid.
	check_eq("enemy in the middle", state.initiative[1].data.id, &"mid")
	# 3 번째 slow.
	check_eq("slowest acts last", state.initiative[2].data.id, &"slow")


# 모두 속도 10 이면 unit_id 0, 1, 2 순서인지.
func _test_initiative_ties_broken_by_id() -> void:
	# 속도가 모두 같은 셋.
	var state: BattleState = _state([_ally(&"a", 10, 6), _ally(&"b", 10, 6)], [_enemy(&"e", 10)])
	# 시작.
	state.start_battle()
	# 순서대로 번호를 모은다.
	var ids: Array = []
	# 행동 순서마다.
	for unit in state.initiative:
		# 번호를 넣는다.
		ids.append(unit.unit_id)
	# 0, 1, 2.
	check_eq("ties resolve by ascending unit_id", ids, [0, 1, 2])


# 시작하면 아군 차례에서 멈추고 SP 3, 손패 4 장, 방어도 0 인지.
func _test_turn_start_refills_sp_and_draws() -> void:
	# 빠른 아군 하나, 느린 적 하나.
	var state: BattleState = _state([_ally(&"a", 20, 6)], [_enemy(&"e", 1)])
	# 시작.
	state.start_battle()
	# 지금 차례 유닛.
	var actor: Unit = state.current_unit()
	# 아군에서 멈췄다.
	check_eq("stopped on the ally", actor.data.id, &"a")
	# SP 3.
	check_eq("sp refilled", actor.sp, 3)
	# 4 장 드로우.
	check_eq("drew four cards", actor.hand.size(), BattleState.DRAW_PER_TURN)
	# 방어도 0.
	check_eq("block reset", actor.block, 0)


# 아군을 둘 두는 이유: end_turn 은 "다음 아군 차례"까지 진행하므로,
# 아군이 하나뿐이면 같은 유닛이 다음 라운드에 곧바로 다시 드로우해서
# 손패가 비워졌는지 확인할 수 없다.
func _test_end_turn_discards_hand() -> void:
	# 속도 20, 15 아군 둘과 느린 적.
	var state: BattleState = _state([_ally(&"first", 20, 6), _ally(&"second", 15, 6)], [_enemy(&"e", 1)])
	# 시작.
	state.start_battle()
	# 첫 차례 유닛.
	var actor: Unit = state.current_unit()
	# 빠른 아군이 먼저.
	check_eq("faster ally goes first", actor.data.id, &"first")
	# 차례 종료.
	state.end_turn()
	# 손패가 비었다.
	check_eq("hand emptied at end of turn", actor.hand.size(), 0)
	# 묘지에 4 장.
	check_eq("hand moved to discard", actor.discard.size(), BattleState.DRAW_PER_TURN)
	# 다음 아군 차례로 넘어갔다.
	check_eq("turn passed to the next ally", state.current_unit().data.id, &"second")


# 행동 순서 3 번째 아군을 쓰러뜨리면 차례가 오지 않는지.
func _test_dead_units_are_skipped() -> void:
	# fast(20), e(10), slow(5).
	var state: BattleState = _state([_ally(&"fast", 20, 6), _ally(&"slow", 5, 6)], [_enemy(&"e", 10)])
	# 시작 (fast 차례).
	state.start_battle()
	# 순서의 3 번째 = slow.
	var slow: Unit = state.initiative[2]
	# slow 를 쓰러뜨린다.
	slow.take_damage(999)
	# 차례 종료 (적 차례 → slow 건너뜀 → 다음 라운드 fast).
	state.end_turn()
	# slow 는 차례를 받지 않았다.
	check("dead ally never becomes current", state.current_unit() != slow)


# 아군 하나·적 하나에서 차례를 끝내면 2 라운드가 되고 같은 아군 차례가 다시 오는지.
func _test_new_round_after_everyone_acted() -> void:
	# 아군 a, 적 e.
	var state: BattleState = _state([_ally(&"a", 20, 8)], [_enemy(&"e", 1)])
	# 시작.
	state.start_battle()
	# 1 라운드.
	check_eq("first round", state.round_index, 1)
	# 차례 종료.
	state.end_turn()
	# 2 라운드.
	check_eq("second round begins", state.round_index, 2)
	# 다시 a 차례.
	check_eq("ally acts again", state.current_unit().data.id, &"a")


# 유닛이 하나도 없는 인카운터(작성 실수로 빈 encounter 가 로드된 경우 등)에서
# start_battle() 이 무한 루프에 빠지지 않고 즉시 종료되는지 확인한다.
func _test_empty_encounter_finishes_without_hanging() -> void:
	# 빈 전투.
	var state: BattleState = _state([], [])
	# 시작 (무한 루프면 여기서 멈춘다).
	state.start_battle()
	# 여기까지 왔으면 돌아온 것이다.
	check("start_battle returns instead of hanging", true)
	# 끝난 상태.
	check_eq("battle already finished with no units", state.finished, true)
