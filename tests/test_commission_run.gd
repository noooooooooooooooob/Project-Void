# CommissionRun(의뢰 진행) 테스트: 이동 규칙, 빈 칸, 전투 배치의 체력, 체력 되돌리기, 성공·실패, 끝난 뒤 이동 불가.
extends TestCase

# 의뢰 진행 스크립트.
const CommissionRunScript := preload("res://Scripts/map/commission_run.gd")
# 배치 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 처음 상태.
	_test_starts_at_start_with_full_hp()
	# 처음엔 첫 걸음만.
	_test_only_first_step_is_selectable_at_start()
	# 이동하면 다음 걸음 이웃만.
	_test_enter_moves_and_offers_adjacent_next_cells()
	# 못 가는 칸은 무시.
	_test_enter_rejects_unconnected_cells()
	# 전투 배치에 체력이 실린다.
	_test_battle_roster_carries_hp_and_skips_the_fallen()
	# 체력이 올바른 파티원에게 돌아간다.
	_test_apply_battle_hp_maps_back_skipping_the_fallen()
	# 일반 칸 승리는 계속.
	_test_regular_win_keeps_the_run_going()
	# 보스 승리는 성공.
	_test_boss_win_succeeds()
	# 패배는 실패.
	_test_loss_fails()
	# 도망은 실패.
	_test_fail_marks_failed()
	# 끝난 뒤 이동 불가.
	_test_finished_run_accepts_no_moves()
	# 결과를 돌려준다.
	return results()


# 시드 고정 의뢰 (월드맵 노드 3, 파티 최대 체력 [30, 20, 10]).
func _run(seed_value: int = 5) -> CommissionRun:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = seed_value
	# 최대 체력.
	var max_hp: Array[int] = [30, 20, 10]
	# 만들어 돌려준다.
	return CommissionRunScript.new(rng, 3, max_hp)


# 파티원 n 명의 전투 배치 (칸은 번호대로).
func _full_roster(count: int) -> Array[UnitPlacement]:
	# 배치 목록.
	var roster: Array[UnitPlacement] = []
	# 명수만큼.
	for i in count:
		# 데이터.
		var data: AllyData = AllyDataScript.new()
		# 이름으로 구분.
		data.id = StringName("m%d" % i)
		# 배치.
		var placement: UnitPlacement = PlacementScript.new()
		placement.unit_data = data
		placement.cell = Vector2i(0, i)
		roster.append(placement)
	# 돌려준다.
	return roster


# 보스 바로 앞(마지막 걸음 가운데 줄)까지 걸어간다.
func _walk_to_last_step(run: CommissionRun) -> void:
	# 걸음마다 가운데 줄로.
	for step in StageGraph.STEPS:
		run.enter(run.graph.node_at(1, step).id)


# 시작 칸에 서 있고, 진행 중이고, 체력은 최대, 지나온 칸은 시작뿐.
func _test_starts_at_start_with_full_hp() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 시작.
	check_eq("starts at start", run.current_id, run.graph.start_id)
	check_eq("starts in progress", run.state, CommissionRun.State.IN_PROGRESS)
	var full: Array[int] = [30, 20, 10]
	check_eq("hp starts full", run.member_hp, full)
	var visited: Array[int] = [run.graph.start_id]
	check_eq("visited starts with start", run.visited, visited)
	check_eq("map node id kept", run.map_node_id, 3)


# 처음엔 첫 걸음 세 칸만 고를 수 있다.
func _test_only_first_step_is_selectable_at_start() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 첫 걸음.
	for lane in StageGraph.LANES:
		check("first step lane %d selectable" % lane, run.is_selectable(run.graph.node_at(lane, 0).id))
	# 둘째 걸음과 보스는 아니다.
	check("second step not selectable", not run.is_selectable(run.graph.node_at(1, 1).id))
	check("boss not selectable", not run.is_selectable(run.graph.boss_id))


# (0,0) 에 들어가면 (0,1)·(1,1) 만 열리고 (2,1) 은 닫힌다.
func _test_enter_moves_and_offers_adjacent_next_cells() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 위 줄 첫 칸.
	var first: StageNode = run.graph.node_at(0, 0)
	check("entering a selectable cell succeeds", run.enter(first.id))
	check_eq("current moves", run.current_id, first.id)
	check("visited records the cell", run.visited.has(first.id))
	check_eq("current kind is the cell's kind", run.current_kind(), first.kind)
	check("same lane next is open", run.is_selectable(run.graph.node_at(0, 1).id))
	check("diagonal next is open", run.is_selectable(run.graph.node_at(1, 1).id))
	check("two lanes away is closed", not run.is_selectable(run.graph.node_at(2, 1).id))


# 이어지지 않은 칸은 들어갈 수 없고 상태가 그대로다.
func _test_enter_rejects_unconnected_cells() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 둘째 걸음으로 건너뛰기.
	check("skipping ahead is rejected", not run.enter(run.graph.node_at(1, 1).id))
	check_eq("current stays at start", run.current_id, run.graph.start_id)
	check_eq("visited unchanged", run.visited.size(), 1)


# 체력 [30, 0, 7] → 배치는 둘(0번 30, 2번 7), 데이터와 칸은 원래 것.
func _test_battle_roster_carries_hp_and_skips_the_fallen() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 둘째는 쓰러졌고 셋째는 7.
	run.member_hp = [30, 0, 7]
	# 전체 배치.
	var full: Array[UnitPlacement] = _full_roster(3)
	# 전투 배치.
	var roster: Array[UnitPlacement] = run.battle_roster(full)
	check_eq("fallen member is left out", roster.size(), 2)
	check_eq("first keeps its data", roster[0].unit_data, full[0].unit_data)
	check_eq("first starts at 30", roster[0].start_hp, 30)
	check_eq("third keeps its data", roster[1].unit_data, full[2].unit_data)
	check_eq("third keeps its cell", roster[1].cell, full[2].cell)
	check_eq("third starts at 7", roster[1].start_hp, 7)
	check_eq("original placement untouched", full[2].start_hp, -1)


# 위 배치로 싸운 결과 [12, 3] → 체력 [12, 0, 3].
func _test_apply_battle_hp_maps_back_skipping_the_fallen() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.member_hp = [30, 0, 7]
	# 배치를 만든다 (번호를 기억시킨다).
	run.battle_roster(_full_roster(3))
	# 전투 결과.
	var final_hp: Array[int] = [12, 3]
	run.apply_battle_hp(final_hp)
	var expected: Array[int] = [12, 0, 3]
	check_eq("hp goes back to the right members", run.member_hp, expected)


# 전투 칸에서 이기면 진행 중 그대로.
func _test_regular_win_keeps_the_run_going() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 첫 칸(전투).
	run.enter(run.graph.node_at(1, 0).id)
	# 승리.
	run.finish_battle(true)
	check_eq("regular win keeps the run in progress", run.state, CommissionRun.State.IN_PROGRESS)


# 보스에서 이기면 성공.
func _test_boss_win_succeeds() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	# 보스 앞까지.
	_walk_to_last_step(run)
	# 보스.
	check("boss is selectable from the last step", run.enter(run.graph.boss_id))
	# 승리.
	run.finish_battle(true)
	check_eq("boss win succeeds", run.state, CommissionRun.State.SUCCEEDED)
	check("succeeded run is finished", run.is_finished())


# 지면 실패.
func _test_loss_fails() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	# 패배.
	run.finish_battle(false)
	check_eq("loss fails the run", run.state, CommissionRun.State.FAILED)


# 도망은 실패.
func _test_fail_marks_failed() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	# 도망.
	run.fail()
	check_eq("fleeing fails the run", run.state, CommissionRun.State.FAILED)


# 끝난 의뢰는 아무 칸도 고를 수 없고, 끝난 뒤의 승리가 상태를 바꾸지 않는다.
func _test_finished_run_accepts_no_moves() -> void:
	# 의뢰.
	var run: CommissionRun = _run()
	run.enter(run.graph.node_at(1, 0).id)
	run.fail()
	# 다음 칸.
	var next_id: int = run.graph.node_at(1, 1).id
	check("finished run offers nothing", not run.is_selectable(next_id))
	check("finished run rejects moves", not run.enter(next_id))
	# 끝난 뒤 승리 보고.
	run.finish_battle(true)
	check_eq("late win does not change a failed run", run.state, CommissionRun.State.FAILED)
