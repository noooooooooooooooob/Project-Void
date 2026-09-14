# BattleState.move_unit(아군 이동) 테스트: 성공 시 SP·칸·신호·로그, 각종 거절, SP 가 남는 동안 연속 이동, 이동 후 사거리.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
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
	# 성공한 이동의 결과.
	_test_move_spends_sp_and_moves()
	# 규칙에 맞지 않는 칸 거절.
	_test_rejects_invalid_cells()
	# 아군 차례가 아니면 거절.
	_test_rejects_outside_an_ally_turn()
	# SP 가 남는 동안 연속 이동.
	_test_moves_while_sp_lasts()
	# 이동하면 사거리가 새 칸 기준.
	_test_reach_follows_the_new_cell()
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


# id·속도를 정한 아군 데이터 (체력 30, SP 3, 덱 없음).
func _ally(id: StringName, speed: int) -> AllyData:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = id
	# 이름은 id 와 같게.
	data.display_name = String(id)
	# 최대 체력.
	data.max_hp = 30
	# 속도.
	data.speed = speed
	# SP 3.
	data.max_sp = 3
	# 돌려준다.
	return data


# 아군 a(속도 10)를 a_cell 에, 아군 b(속도 5)를 (0,0) 에, 적 e(속도 1)를 적 (0,1) 에 세우고 전투를 시작한다 (a 차례에서 멈춤).
func _started_state(a_cell: Vector2i) -> BattleState:
	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 가장 느리게.
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치: a 는 a_cell, b 는 (0,0).
	var allies: Array[UnitPlacement] = [_placement(_ally(&"a", 10), a_cell), _placement(_ally(&"b", 5), Vector2i(0, 0))]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 21
	# 전투 상태.
	var state: BattleState = BattleStateScript.new(encounter, rng)
	# 시작 (a 의 턴 행동 단계에서 멈춘다).
	state.start_battle()
	# 돌려준다.
	return state


# id 로 전투 속 유닛을 찾는다.
func _unit(state: BattleState, id: StringName) -> Unit:
	# 모든 유닛 중.
	for unit in state.units:
		# id 가 같으면.
		if unit.data.id == id:
			# 그 유닛.
			return unit
	# 못 찾음.
	return null


# (1,1) 에서 뒤(2,1)로 이동: true, 새 칸, SP 3→2, 이동 신호의 두 칸, 로그 "a 이동".
func _test_move_spends_sp_and_moves() -> void:
	# a 가 (1,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(1, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 이동 신호 기록.
	var moved: Array = []
	# 이동 신호를 [id, 이전 칸, 새 칸] 으로 기록한다.
	state.unit_moved.connect(func(unit: Unit, from_cell: Vector2i, to_cell: Vector2i) -> void: moved.append([unit.data.id, from_cell, to_cell]))
	# 로그 기록.
	var logs: Array = []
	# 로그를 기록한다.
	state.log_message.connect(func(text: String) -> void: logs.append(text))
	# 이동 성공.
	check("move accepted", state.move_unit(Vector2i(2, 1)))
	# 새 칸.
	check_eq("unit stands on the new cell", a.cell, Vector2i(2, 1))
	# SP 2.
	check_eq("one sp spent", a.sp, 2)
	# 신호 인자.
	check_eq("move signal carries both cells", moved, [[&"a", Vector2i(1, 1), Vector2i(2, 1)]])
	# 로그.
	check_eq("move logged", logs, ["a 이동"])


# (0,1) 에서 대각선·두 칸·점유 칸·격자 밖은 거절되고 칸·SP 가 그대로이며, SP 0 이면 빈 칸도 거절되는지.
func _test_rejects_invalid_cells() -> void:
	# a 가 (0,1) 인 전투 (b 가 위 칸 (0,0) 에 있다).
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 대각선.
	check("diagonal rejected", not state.move_unit(Vector2i(1, 2)))
	# 두 칸.
	check("two cells rejected", not state.move_unit(Vector2i(2, 1)))
	# b 가 선 칸.
	check("occupied cell rejected", not state.move_unit(Vector2i(0, 0)))
	# 격자 밖.
	check("outside the grid rejected", not state.move_unit(Vector2i(-1, 1)))
	# 칸 그대로.
	check_eq("cell unchanged", a.cell, Vector2i(0, 1))
	# SP 그대로.
	check_eq("sp unchanged", a.sp, 3)
	# SP 를 다 썼다고 가정한다.
	a.sp = 0
	# 비어 있는 아래 칸도 거절.
	check("no sp rejected", not state.move_unit(Vector2i(0, 2)))


# 끝난 전투와 적 차례에서는 이동이 거절되는지.
func _test_rejects_outside_an_ally_turn() -> void:
	# 끝난 전투.
	var finished_state: BattleState = _started_state(Vector2i(0, 1))
	# 끝난 것으로 표시.
	finished_state.finished = true
	# 거절.
	check("finished battle rejects moves", not finished_state.move_unit(Vector2i(0, 2)))
	# 적 차례 전투.
	var enemy_turn: BattleState = _started_state(Vector2i(0, 1))
	# 행동 순서를 적 하나로 바꾼다.
	enemy_turn.initiative = [_unit(enemy_turn, &"e")]
	# 그 적의 차례.
	enemy_turn.turn_index = 0
	# 거절.
	check("enemy turn rejects moves", not enemy_turn.move_unit(Vector2i(0, 2)))


# SP 3 으로 세 번 이동한 뒤 네 번째는 거절되는지.
func _test_moves_while_sp_lasts() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# (1,1) → (2,1) → (2,2) → (2,1) 순서로 시도한다.
	var accepted: Array = [state.move_unit(Vector2i(1, 1)), state.move_unit(Vector2i(2, 1)), state.move_unit(Vector2i(2, 2)), state.move_unit(Vector2i(2, 1))]
	# 세 번 성공, 네 번째 실패.
	check_eq("three moves then out of sp", accepted, [true, true, true, false])
	# SP 0.
	check_eq("sp used up", a.sp, 0)
	# 세 번째 칸에 멈췄다.
	check_eq("stopped on the third cell", a.cell, Vector2i(2, 2))


# 앞줄에서 적까지 거리 1, 한 칸 뒤로 가면 거리 2 인지.
func _test_reach_follows_the_new_cell() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 적 유닛.
	var e: Unit = _unit(state, &"e")
	# 앞줄끼리 1.
	check_eq("front rank reach", state.resolver.reach(a, e), 1)
	# 한 칸 뒤로.
	state.move_unit(Vector2i(1, 1))
	# 2.
	check_eq("one step back adds one", state.resolver.reach(a, e), 2)
