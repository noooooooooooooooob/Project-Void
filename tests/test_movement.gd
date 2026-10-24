# BattleState.move_unit(아군 이동) 테스트: 이동력(기본 2)을 걸음 수만큼 쓰고 SP 는 쓰지 않는다. 각종 거절, 이동력이 남는 동안 연속 이동, 한 번에 여러 칸, 이동 후 근접 기준 행.
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
	_test_move_spends_move_points_not_sp()
	_test_rejects_invalid_cells()
	_test_rejects_outside_an_ally_turn()
	# 이동력이 남는 동안 연속 이동.
	_test_moves_while_move_points_last()
	# 한 번에 여러 칸 (걸음 수만큼 소모).
	_test_moves_several_cells_at_once()
	# 같은 편이 막은 길은 돌아가야 한다.
	_test_paths_go_around_allies()
	# 차례가 시작되면 이동력이 다시 찬다.
	_test_move_points_refill_each_turn()
	# 이동하면 근접 기준이 새 행을 따른다.
	_test_melee_anchor_follows_the_new_row()
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# id·속도를 정한 아군 데이터 (체력 30, SP 3, 덱 없음).
func _ally(id: StringName, speed: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = id
	# 이름은 id 와 같게.
	data.display_name = String(id)
	data.max_hp = 30
	data.speed = speed
	# SP 3.
	data.max_sp = 3
	return data


# 아군 a(속도 10)를 a_cell 에, 아군 b(속도 5)를 (0,0) 에, 적 e(속도 1)를 적 (0,1) 에 세우고 전투를 시작한다 (a 차례에서 멈춤).
func _started_state(a_cell: Vector2i) -> BattleState:
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치: a 는 a_cell, b 는 (0,0).
	var allies: Array[UnitPlacement] = [_placement(_ally(&"a", 10), a_cell), _placement(_ally(&"b", 5), Vector2i(0, 0))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var state: BattleState = BattleStateScript.new(encounter, rng)
	# 시작 (a 의 턴 행동 단계에서 멈춘다).
	state.start_battle()
	return state


# id 로 전투 속 유닛을 찾는다.
func _unit(state: BattleState, id: StringName) -> Unit:
	for unit in state.units:
		# id 가 같으면.
		if unit.data.id == id:
			return unit
	return null


# (1,1) 에서 뒤(2,1)로 이동: true, 새 칸, 이동력 2→1, SP 는 그대로 3, 이동 신호의 두 칸, 로그 "a 이동".
func _test_move_spends_move_points_not_sp() -> void:
	# a 가 (1,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(1, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	var moved: Array = []
	# 이동 신호를 [id, 이전 칸, 새 칸] 으로 기록한다.
	state.unit_moved.connect(func(unit: Unit, from_cell: Vector2i, to_cell: Vector2i) -> void: moved.append([unit.data.id, from_cell, to_cell]))
	var logs: Array = []
	state.log_message.connect(func(text: String) -> void: logs.append(text))
	# 시작 이동력은 기본값 2.
	check_eq("turn starts with full move points", a.move_points, 2)
	check("move accepted", state.move_unit(Vector2i(2, 1)))
	check_eq("unit stands on the new cell", a.cell, Vector2i(2, 1))
	# 이동력 1.
	check_eq("one move point spent", a.move_points, 1)
	# SP 는 그대로.
	check_eq("sp is not spent on moving", a.sp, 3)
	check_eq("move signal carries both cells", moved, [[&"a", Vector2i(1, 1), Vector2i(2, 1)]])
	check_eq("move logged", logs, ["a 이동"])


# (0,1) 에서 이동력보다 먼 칸·점유 칸·격자 밖은 거절되고, 이동력 0 이면 빈 칸도 거절되는지.
func _test_rejects_invalid_cells() -> void:
	# a 가 (0,1) 인 전투 (b 가 위 칸 (0,0) 에 있다).
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# 세 걸음 떨어진 칸 (이동력 2 로는 닿지 않음).
	check("too far rejected", not state.move_unit(Vector2i(2, 2)))
	# b 가 선 칸.
	check("occupied cell rejected", not state.move_unit(Vector2i(0, 0)))
	check("outside the grid rejected", not state.move_unit(Vector2i(-1, 1)))
	check("own cell rejected", not state.move_unit(Vector2i(0, 1)))
	check_eq("cell unchanged", a.cell, Vector2i(0, 1))
	check_eq("move points unchanged", a.move_points, 2)
	# 이동력을 다 썼다고 가정한다.
	a.move_points = 0
	check("no move points rejected", not state.move_unit(Vector2i(0, 2)))


# 끝난 전투와 적 차례에서는 이동이 거절되는지.
func _test_rejects_outside_an_ally_turn() -> void:
	var finished_state: BattleState = _started_state(Vector2i(0, 1))
	finished_state.finished = true
	check("finished battle rejects moves", not finished_state.move_unit(Vector2i(0, 2)))
	var enemy_turn: BattleState = _started_state(Vector2i(0, 1))
	# 행동 순서를 적 하나로 바꾼다.
	enemy_turn.initiative = [_unit(enemy_turn, &"e")]
	enemy_turn.turn_index = 0
	check("enemy turn rejects moves", not enemy_turn.move_unit(Vector2i(0, 2)))


# 이동력 2 로 한 칸씩 두 번 이동한 뒤 세 번째는 거절되는지.
func _test_moves_while_move_points_last() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	# (1,1) → (2,1) → (2,2) 순서로 시도한다.
	var accepted: Array = [state.move_unit(Vector2i(1, 1)), state.move_unit(Vector2i(2, 1)), state.move_unit(Vector2i(2, 2))]
	# 두 번 성공, 세 번째 실패.
	check_eq("two moves then out of move points", accepted, [true, true, false])
	# 이동력 0.
	check_eq("move points used up", a.move_points, 0)
	check_eq("stopped on the second cell", a.cell, Vector2i(2, 1))


# 두 걸음 떨어진 칸으로 한 번에 이동하면 이동력 2 를 쓰고, 신호는 한 번만 나간다.
func _test_moves_several_cells_at_once() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	var moves: Array[int] = [0]
	state.unit_moved.connect(func(_unit: Unit, _from: Vector2i, _to: Vector2i) -> void: moves[0] += 1)
	# 대각선 칸 (두 걸음).
	check("a two-step diagonal cell is reachable", state.move_unit(Vector2i(1, 2)))
	# 이동력 0.
	check_eq("two move points spent", a.move_points, 0)
	check_eq("one move signal", moves[0], 1)


# 같은 편이 선 칸은 지나갈 수 없다: b 가 (1,0) 을 막으면 (0,0)→(2,0) 은 돌아가야 해서 이동력 2 로는 닿지 않는다.
func _test_paths_go_around_allies() -> void:
	# a 가 (0,1) 인 전투에서 b 를 (1,1) 로 옮겨 길을 막는다.
	var state: BattleState = _started_state(Vector2i(0, 1))
	var b: Unit = _unit(state, &"b")
	b.cell = Vector2i(1, 1)
	# (2,1) 로 가려면 (1,1) 을 지나야 하는데 막혔고, 돌아가면 네 걸음이다.
	check("cannot walk through an ally", not state.move_unit(Vector2i(2, 1)))
	# 막히지 않은 (0,2) 는 된다.
	check("an open neighbour is fine", state.move_unit(Vector2i(0, 2)))


# 다음 차례가 시작되면 이동력이 data.move 로 다시 찬다.
func _test_move_points_refill_each_turn() -> void:
	# a 가 (0,1) 인 전투.
	var state: BattleState = _started_state(Vector2i(0, 1))
	var a: Unit = _unit(state, &"a")
	state.move_unit(Vector2i(1, 2))
	check_eq("spent", a.move_points, 0)
	# a → b → e → (다음 라운드) a 까지 진행한다.
	state.end_turn()
	state.end_turn()
	# 다시 a 차례.
	check("a is acting again", state.current_unit() == a)
	check_eq("move points refilled", a.move_points, a.data.move)


# 근접 기준 유닛은 이동한 뒤의 행을 따른다: 같은 행이면 그대로, 다른 행으로 가면 없다.
func _test_melee_anchor_follows_the_new_row() -> void:
	# a 가 (0,1) 인 전투 (적 e 는 (0,1)).
	var state: BattleState = _started_state(Vector2i(0, 1))
	# a 유닛.
	var a: Unit = _unit(state, &"a")
	var e: Unit = _unit(state, &"e")
	# 같은 행이라 e 가 기준.
	check_eq("same row anchors the enemy", state.resolver.melee_anchor(a, state.units), e)
	# 한 칸 뒤로 (같은 행).
	state.move_unit(Vector2i(1, 1))
	# 여전히 e.
	check_eq("moving back keeps the row", state.resolver.melee_anchor(a, state.units), e)
	# 한 칸 위로 (행 0, 적 없음).
	state.move_unit(Vector2i(1, 0))
	check("another row has no melee anchor", state.resolver.melee_anchor(a, state.units) == null)
