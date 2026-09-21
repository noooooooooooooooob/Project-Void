# MapRunState(런 진행 상황 — 지금 어디에 서 있고 어디를 깼는지) 테스트.
extends TestCase

# 런 진행 상황 스크립트.
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작점에서는 두 갈래를 모두 고를 수 있다.
	_test_start_offers_both_branch_heads()
	# 이어지지 않은 점은 고를 수 없다.
	_test_only_reachable_nodes_are_selectable()
	# 한 갈래에 들어서면 다른 갈래는 막힌다.
	_test_entering_one_branch_locks_out_the_other()
	# 이기면 그 점으로 옮겨 서고 깬 것으로 표시된다.
	_test_resolve_win_advances_and_clears()
	# 갈 수 없는 점의 승리는 무시한다.
	_test_resolve_win_ignores_unreachable_nodes()
	# 보스를 깨면 런이 새로 시작된다.
	_test_boss_win_starts_a_fresh_run()
	# reset 은 런을 처음부터 다시 짠다.
	_test_reset_starts_a_fresh_run()
	# 같은 시드면 같은 전투가 나온다.
	_test_same_seed_produces_the_same_first_encounter()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수기를 만든다 (테스트가 매번 같은 런을 보도록).
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 난수기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 박는다.
	rng.seed = seed_value
	# 만든 난수기를 돌려준다.
	return rng


# 런을 시작하면 두 갈래의 첫 칸이 모두 열려 있는지.
func _test_start_offers_both_branch_heads() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 갈래 0 의 첫 칸.
	check("branch 0 head is selectable", run_state.is_selectable(1))
	# 갈래 1 의 첫 칸.
	check("branch 1 head is selectable", run_state.is_selectable(5))


# 지금 점에서 길이 이어지지 않은 곳과 이미 깬 곳은 고를 수 없는지.
func _test_only_reachable_nodes_are_selectable() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 칸을 건너뛰고 둘째 칸으로 바로 갈 수는 없다.
	check("step 2 of branch 0 is not selectable yet", not run_state.is_selectable(2))
	# 보스도 마찬가지.
	check("boss is not selectable yet", not run_state.is_selectable(9))
	# 시작점은 이미 깬 것으로 두므로 자기 자신도 고를 수 없다.
	check("start itself is not selectable", not run_state.is_selectable(0))


# 한 갈래로 들어서면 시작점으로 돌아갈 길이 없어 다른 갈래가 막히는지.
func _test_entering_one_branch_locks_out_the_other() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 갈래 0 의 첫 칸을 깬다.
	run_state.resolve_win(1)
	# 같은 갈래의 다음 칸은 열린다.
	check("branch 0 step 2 now selectable", run_state.is_selectable(2))
	# 갈래 1 은 이제 이어지는 길이 없다.
	check("branch 1 head no longer selectable", not run_state.is_selectable(5))


# 이겼을 때 그 점으로 옮겨 서고 깬 것으로 표시되는지.
func _test_resolve_win_advances_and_clears() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 갈래 0 의 첫 칸을 깬다.
	run_state.resolve_win(1)
	# 그 점으로 옮겨 섰다.
	check_eq("current node moved to 1", run_state.current_node_id, 1)
	# 깬 점으로 표시됐다.
	check("node 1 marked cleared", run_state.cleared.get(1, false))


# 갈 수 없는 점의 승리가 들어와도 진행이 움직이지 않는지.
func _test_resolve_win_ignores_unreachable_nodes() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 시작점에서 보스로 건너뛸 수는 없다.
	run_state.resolve_win(9)
	# 시작점 그대로.
	check_eq("current node unchanged for an unreachable target", run_state.current_node_id, 0)


# 보스를 깨면 런이 끝나고 새 맵으로 다시 시작되는지.
func _test_boss_win_starts_a_fresh_run() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 새 맵으로 바뀌었는지 비교할 지금 맵.
	var old_graph: MapGraph = run_state.graph
	# 갈래 0 을 처음부터 끝까지 깬다.
	run_state.resolve_win(1)
	run_state.resolve_win(2)
	run_state.resolve_win(3)
	run_state.resolve_win(4)
	# 보스까지 깬다.
	run_state.resolve_win(9)
	# 맵이 새로 짜였다.
	check("boss win generates a new graph", run_state.graph != old_graph)
	# 새 맵의 시작점에 서 있다.
	check_eq("run returns to the new start", run_state.current_node_id, run_state.graph.start_id)
	# 새 시작점도 처음부터 깬 것으로 둔다.
	check("new start is cleared", run_state.cleared.get(run_state.graph.start_id, false))


# reset 이 진행을 시작점으로 되돌리고 깬 기록을 시작점 하나만 남기는지 (패배했을 때 쓰는 길).
func _test_reset_starts_a_fresh_run() -> void:
	# 런을 시작한다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 한 칸 나아간다.
	run_state.resolve_win(1)
	# 런을 처음부터 다시 짠다.
	run_state.reset()
	# 시작점으로 돌아왔다.
	check_eq("reset returns to start", run_state.current_node_id, run_state.graph.start_id)
	# 깬 기록은 시작점 하나뿐.
	check_eq("reset clears progress back to just the start", run_state.cleared.size(), 1)


# 같은 시드로 런을 두 번 짜면 같은 점에 같은 전투가 들어 있는지.
func _test_same_seed_produces_the_same_first_encounter() -> void:
	# 같은 시드로 런 하나.
	var a: MapRunState = MapRunStateScript.new(_rng(123))
	# 같은 시드로 런 또 하나.
	var b: MapRunState = MapRunStateScript.new(_rng(123))
	# 1 번 점의 전투.
	var encounter_a: EncounterData = a.encounter_for(1)
	# 다른 런의 같은 점.
	var encounter_b: EncounterData = b.encounter_for(1)
	# 적 수가 같다.
	check_eq("same seed rolls the same enemy count for node 1", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	# 적 종류도 순서까지 같다.
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places the same enemy id at %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
