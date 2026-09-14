# BattleState 턴 단계 테스트: 스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후 신호 순서,
# 스탠바이 처리 시점, 적 차례의 빈 드로우 단계, 전투가 끝나면 남은 단계 생략.
extends TestCase

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
	# 아군 차례 시작의 단계 순서.
	_test_ally_turn_start_order()
	# 차례 종료 → 적 차례 → 다음 아군 차례의 단계 순서.
	_test_end_turn_runs_end_phases_then_enemy_turn()
	# 스탠바이 신호 시점엔 이전 값, 차례 시작 신호 시점엔 초기화된 값.
	_test_standby_resets_before_turn_started()
	# 적 행동으로 전투가 끝나면 적의 종료 단계는 없다.
	_test_battle_end_skips_end_phases()
	# 결과를 돌려준다.
	return results()


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


# 아군 a(속도 10, SP 3, 카드 6장)를 ally_cell 에, 적 e(속도 1, 기본 근접 사거리 1·피해 5)를 적 앞줄 가운데에 세운 전투.
func _state(ally_cell: Vector2i) -> BattleState:
	# 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	# 이름.
	ally.display_name = "a"
	# 최대 체력.
	ally.max_hp = 30
	# 먼저 행동하도록 빠르게.
	ally.speed = 10
	# SP.
	ally.max_sp = 3
	# 덱 배열.
	var deck: Array[CardData] = []
	# 카드 6장.
	for i in 6:
		# 빈 카드.
		var card: CardData = CardDataScript.new()
		# 구분용 id.
		card.id = StringName("c%d" % i)
		# 덱에 넣는다.
		deck.append(card)
	# 덱을 넣는다.
	ally.deck = deck

	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 늦게 행동하도록 느리게.
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치.
	var allies: Array[UnitPlacement] = [_placement(ally, ally_cell)]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 11
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, rng)


# 단계·차례 시작·드로우·손패 버리기 신호를 "phase:a:STANDBY" 같은 문자열로 기록하는 배열을 연결해 돌려준다.
func _record(state: BattleState) -> Array:
	# 기록 배열.
	var seen: Array = []
	# 단계 시작 → "phase:유닛:단계이름".
	state.phase_started.connect(func(unit: Unit, started: BattleState.Phase) -> void:
		seen.append("phase:%s:%s" % [unit.data.id, BattleState.Phase.keys()[started]]))
	# 차례 시작 → "turn:유닛".
	state.turn_started.connect(func(unit: Unit) -> void:
		seen.append("turn:%s" % unit.data.id))
	# 드로우 → "drawn:유닛".
	state.card_drawn.connect(func(unit: Unit, _card: CardData, _deck_count: int, _discard_count: int) -> void:
		seen.append("drawn:%s" % unit.data.id))
	# 손패 버리기 → "discarded:유닛".
	state.hand_discarded.connect(func(unit: Unit, _cards: Array[CardData], _discard_count: int) -> void:
		seen.append("discarded:%s" % unit.data.id))
	# 기록 배열을 돌려준다.
	return seen


# 시작하면 스탠바이 → 차례 시작 → 드로우(4장) → 턴 행동 순서이고, 현재 단계가 턴 행동인지.
func _test_ally_turn_start_order() -> void:
	# 전투.
	var state: BattleState = _state(Vector2i(0, 1))
	# 기록 연결.
	var seen: Array = _record(state)
	# 시작.
	state.start_battle()
	# 신호 순서.
	check_eq("ally turn start phases", seen, ["phase:a:STANDBY", "turn:a", "phase:a:DRAW", "drawn:a", "drawn:a", "drawn:a", "drawn:a", "phase:a:ACTION"])
	# 입력을 기다리는 단계.
	check_eq("waiting in the action phase", state.phase, BattleState.Phase.ACTION)


# 차례 종료: 아군 종료 전 → 종료 후(버리기) → 적 다섯 단계(드로우 없음) → 다음 아군 차례 시작.
func _test_end_turn_runs_end_phases_then_enemy_turn() -> void:
	# 전투.
	var state: BattleState = _state(Vector2i(0, 1))
	# 시작.
	state.start_battle()
	# 여기서부터 기록.
	var seen: Array = _record(state)
	# 차례 종료.
	state.end_turn()
	# 전체 순서 (적 드로우 단계에는 drawn 이 없다).
	check_eq("end phases, enemy phases, next ally start", seen, ["phase:a:BEFORE_END", "phase:a:AFTER_END", "discarded:a", "phase:e:STANDBY", "turn:e", "phase:e:DRAW", "phase:e:ACTION", "phase:e:BEFORE_END", "phase:e:AFTER_END", "phase:a:STANDBY", "turn:a", "phase:a:DRAW", "drawn:a", "drawn:a", "drawn:a", "drawn:a", "phase:a:ACTION"])


# 스탠바이 신호가 날 때는 이전 block·SP 이고, 차례 시작 신호가 날 때는 초기화된 값인지.
func _test_standby_resets_before_turn_started() -> void:
	# 아군이 뒷줄(2,1)이라 사거리 1 적에게 맞지 않는다.
	var state: BattleState = _state(Vector2i(2, 1))
	# 시작.
	state.start_battle()
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 이전 차례에 방어도가 남았다고 가정한다.
	ally.block = 7
	# SP 를 다 썼다고 가정한다.
	ally.sp = 0
	# 시점별 값을 담을 사전.
	var seen: Dictionary = {}
	# 아군의 스탠바이 신호 시점 값을 기록한다.
	state.phase_started.connect(func(unit: Unit, started: BattleState.Phase) -> void:
		if unit == ally and started == BattleState.Phase.STANDBY:
			seen["standby"] = [unit.block, unit.sp])
	# 아군의 차례 시작 신호 시점 값을 기록한다.
	state.turn_started.connect(func(unit: Unit) -> void:
		if unit == ally:
			seen["turn"] = [unit.block, unit.sp])
	# 차례 종료 → 적 차례(방어) → 아군 다음 차례.
	state.end_turn()
	# 스탠바이 시점 block 은 이전 값.
	check_eq("block still old at standby signal", seen["standby"][0], 7)
	# 스탠바이 시점 SP 는 이전 값.
	check_eq("sp still old at standby signal", seen["standby"][1], 0)
	# 차례 시작 시점 block 은 0.
	check_eq("block reset by turn_started", seen["turn"][0], 0)
	# 차례 시작 시점 SP 는 최대.
	check_eq("sp refilled by turn_started", seen["turn"][1], 3)


# 적 공격으로 마지막 아군이 쓰러지면 전투가 끝나고 적의 종료 전·종료 후 단계는 오지 않는지.
func _test_battle_end_skips_end_phases() -> void:
	# 아군이 적 사거리 안(0,1).
	var state: BattleState = _state(Vector2i(0, 1))
	# 시작.
	state.start_battle()
	# 아군 체력을 1 로 만든다.
	state.living_units(Unit.Team.ALLY)[0].take_damage(29)
	# 여기서부터 기록.
	var seen: Array = _record(state)
	# 차례 종료 → 적이 공격해 아군이 쓰러진다.
	state.end_turn()
	# 적 턴 행동에서 끝난다.
	check_eq("stops after the enemy action phase", seen, ["phase:a:BEFORE_END", "phase:a:AFTER_END", "discarded:a", "phase:e:STANDBY", "turn:e", "phase:e:DRAW", "phase:e:ACTION"])
	# 전투 종료.
	check("battle finished", state.finished)
