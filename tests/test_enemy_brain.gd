# EnemyBrain(적 AI) 테스트: 대상 고르기, 휴식, 방어, 근접 막힘, 결정의 일관성.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 적 AI 스크립트.
const BrainScript := preload("res://Scripts/combat/enemy_brain.gd")
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
	# 체력이 낮은 대상을 공격한다.
	_test_attacks_lowest_hp_target()
	# 크게 다치면 휴식한다.
	_test_rests_when_badly_hurt()
	# 칠 대상이 없으면 방어한다.
	_test_defends_when_no_target_in_range()
	# 근접 막힘을 지킨다.
	_test_attack_respects_melee_blocking()
	# 같은 상황이면 같은 결정.
	_test_deterministic_across_runs()
	# 결과를 돌려준다.
	return results()


# 시드 4242 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 4242
	# 돌려준다.
	return rng


# 이름과 체력만 정한 느린(속도 1) 아군 데이터.
func _ally(id: StringName, hp: int) -> AllyData:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = id
	# 이름은 id 와 같게.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = hp
	# 적보다 늦게 행동하도록 속도 1.
	data.speed = 1
	# SP 1.
	data.max_sp = 1
	# 돌려준다.
	return data


# 체력 20, 속도 99 인 원거리 단일 공격 적 데이터 (사거리·피해·방어도·회복량 지정).
func _enemy(attack_range: int, damage: int, block_amount: int, rest_heal: int) -> EnemyData:
	# 적 데이터.
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = &"foe"
	# 이름.
	data.display_name = "적"
	# 최대 체력.
	data.max_hp = 20
	# 가장 먼저 행동하도록 속도 99.
	data.speed = 99
	# 공격 피해.
	data.attack_damage = damage
	# 원거리.
	data.attack_type = CardData.AttackType.RANGED
	# 단일.
	data.attack_shape = CardData.Shape.SINGLE
	# 사거리.
	data.attack_range = attack_range
	# 방어 행동의 방어도.
	data.block_amount = block_amount
	# 휴식 행동의 회복량.
	data.rest_heal = rest_heal
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


# 아군 배치 목록과 적 한 명(앞줄 가운데)으로 전투 상태를 만든다 (시작하지는 않음).
func _state(allies: Array, enemy: EnemyData) -> BattleState:
	# 타입이 있는 아군 배치 배열.
	var ally_placements: Array[UnitPlacement] = []
	# 받은 배치들을 넣는다.
	ally_placements.append_array(allies)
	# 적 배치 배열.
	var enemy_placements: Array[UnitPlacement] = []
	# 적 한 명을 앞줄 가운데에.
	enemy_placements.append(_placement(enemy, Vector2i(0, 1)))

	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자 3×3.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자 3×3.
	encounter.enemy_grid = Vector2i(3, 3)
	# 아군 배치.
	encounter.ally_units = ally_placements
	# 적군 배치.
	encounter.enemy_units = enemy_placements
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, _rng())


# 체력 30 과 8 인 아군 중 8 인 쪽을 골라 공격하고, 피해 6 이 들어가는지.
func _test_attacks_lowest_hp_target() -> void:
	# 튼튼한 아군.
	var healthy: AllyData = _ally(&"healthy", 30)
	# 다친 아군.
	var wounded: AllyData = _ally(&"wounded", 8)
	# 두 아군과 사거리 5·피해 6 적으로 전투를 만든다.
	var state: BattleState = _state([
		_placement(healthy, Vector2i(0, 0)),
		_placement(wounded, Vector2i(0, 1)),
	], _enemy(5, 6, 5, 4))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 공격을 고른다.
	check_eq("picks attack", BrainScript.decide(state, foe), BrainScript.Action.ATTACK)
	# 대상은 다친 아군.
	check_eq("targets the lower hp ally", BrainScript.find_target(state, foe).data.id, &"wounded")

	# 실제로 차례를 진행한다.
	BrainScript.take_turn(state, foe)
	# 다친 아군 체력 8 - 6 = 2.
	check_eq("wounded ally took damage", state.living_units(Unit.Team.ALLY)[1].hp, 2)


# 체력이 30% 이하(20 중 5)면 휴식을 고르고 4 회복해 9 가 되는지.
func _test_rests_when_badly_hurt() -> void:
	# 아군 하나와 회복량 4 적.
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], _enemy(5, 6, 5, 4))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 체력 5 로 만든다 (25%).
	foe.take_damage(15)

	# 휴식을 고른다.
	check_eq("rests at or below 30% hp", BrainScript.decide(state, foe), BrainScript.Action.REST)
	# 차례를 진행한다.
	BrainScript.take_turn(state, foe)
	# 5 + 4 = 9.
	check_eq("healed by rest_heal", foe.hp, 9)


# 사거리 안에 아무도 없으면 방어를 고르고 방어도 7 을 얻는지.
func _test_defends_when_no_target_in_range() -> void:
	# 사거리 1 인데 아군은 후열(col 2)에 있어 reach 가 3 이다.
	var state: BattleState = _state([_placement(_ally(&"far", 30), Vector2i(2, 1))], _enemy(1, 6, 7, 4))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 칠 대상이 없다.
	check("no reachable target", BrainScript.find_target(state, foe) == null)
	# 방어를 고른다.
	check_eq("falls back to defend", BrainScript.decide(state, foe), BrainScript.Action.DEFEND)
	# 차례를 진행한다.
	BrainScript.take_turn(state, foe)
	# 방어도 7.
	check_eq("gained block", foe.block, 7)


# 근접 적은 체력이 더 낮은 뒷줄 아군이 있어도 앞줄 아군을 고르는지.
func _test_attack_respects_melee_blocking() -> void:
	# 앞줄 아군 (체력 30).
	var front: AllyData = _ally(&"front", 30)
	# 뒷줄 아군 (체력 5).
	var back: AllyData = _ally(&"back", 5)
	# 사거리 4 적을 근접으로 바꾼다.
	var melee: EnemyData = _enemy(4, 6, 5, 4)
	# 근접.
	melee.attack_type = CardData.AttackType.MELEE
	# 같은 행에 앞뒤로 선 두 아군.
	var state: BattleState = _state([
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	], melee)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# back 이 hp 가 더 낮지만 같은 행의 front 에 막혀 고를 수 없다.
	check_eq("melee must hit the front rank", BrainScript.find_target(state, foe).data.id, &"front")


# 체력이 같은 두 아군이 있는 같은 상황을 두 번 만들어도 같은 대상을 고르는지 (번호로 동률 처리).
func _test_deterministic_across_runs() -> void:
	# 첫 번째 결과.
	var first: StringName = &""
	# 두 번째 결과.
	var second: StringName = &""
	# 두 번 반복한다.
	for i in 2:
		# 체력 20 짜리 아군 둘.
		var state: BattleState = _state([
			_placement(_ally(&"x", 20), Vector2i(0, 0)),
			_placement(_ally(&"y", 20), Vector2i(0, 2)),
		], _enemy(5, 6, 5, 4))
		# 적 유닛.
		var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
		# 고른 대상의 id.
		var picked: StringName = BrainScript.find_target(state, foe).data.id
		# 첫 번째 반복이면 first 에.
		if i == 0:
			first = picked
		# 두 번째면 second 에.
		else:
			second = picked
	# 둘이 같다.
	check_eq("same situation yields the same target", first, second)
