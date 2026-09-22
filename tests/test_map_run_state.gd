extends TestCase

const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


func run() -> Array[Dictionary]:
	_test_start_offers_all_first_branches()
	_test_only_reachable_nodes_are_selectable()
	_test_entering_one_branch_locks_out_the_others()
	_test_resolve_win_advances_and_clears()
	_test_resolve_win_ignores_unreachable_nodes()
	_test_boss_win_starts_a_fresh_run()
	_test_reset_starts_a_fresh_run()
	_test_same_seed_produces_the_same_first_encounter()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 시작에서 보스까지 첫 번째 연결만 따라가며 이긴다. 마지막 호출이 보스를 이겨 런을 새로 시작시킨다.
func _win_to_boss(run_state: MapRunState) -> void:
	while run_state.current_node_id != run_state.graph.boss_id:
		var next_id: int = run_state.graph.get_node(run_state.current_node_id).connections[0]
		run_state.resolve_win(next_id)


func _test_start_offers_all_first_branches() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	for head_id in run_state.graph.get_node(run_state.graph.start_id).connections:
		check("branch head %d is selectable" % head_id, run_state.is_selectable(head_id))


func _test_only_reachable_nodes_are_selectable() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	check("boss is not selectable yet", not run_state.is_selectable(run_state.graph.boss_id))
	check("start itself is not selectable", not run_state.is_selectable(run_state.graph.start_id))


func _test_entering_one_branch_locks_out_the_others() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var heads: Array[int] = run_state.graph.get_node(run_state.graph.start_id).connections.duplicate()
	var chosen: int = heads[0]
	run_state.resolve_win(chosen)
	for next_id in run_state.graph.get_node(chosen).connections:
		check("node %d past the chosen head is now selectable" % next_id, run_state.is_selectable(next_id))
	for other_head in heads:
		if other_head == chosen:
			continue
		check("other head %d is no longer selectable" % other_head, not run_state.is_selectable(other_head))


func _test_resolve_win_advances_and_clears() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var head: int = run_state.graph.get_node(run_state.graph.start_id).connections[0]
	run_state.resolve_win(head)
	check_eq("current node moved to the chosen head", run_state.current_node_id, head)
	check("chosen head marked cleared", run_state.cleared.get(head, false))


func _test_resolve_win_ignores_unreachable_nodes() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var start_id: int = run_state.graph.start_id
	run_state.resolve_win(run_state.graph.boss_id)
	check_eq("current node unchanged for an unreachable target", run_state.current_node_id, start_id)


func _test_boss_win_starts_a_fresh_run() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var old_graph: MapGraph = run_state.graph
	_win_to_boss(run_state)
	check("boss win generates a new graph", run_state.graph != old_graph)
	check_eq("run returns to the new start", run_state.current_node_id, run_state.graph.start_id)
	check("new start is cleared", run_state.cleared.get(run_state.graph.start_id, false))


func _test_reset_starts_a_fresh_run() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var head: int = run_state.graph.get_node(run_state.graph.start_id).connections[0]
	run_state.resolve_win(head)
	run_state.reset()
	check_eq("reset returns to start", run_state.current_node_id, run_state.graph.start_id)
	check_eq("reset clears progress back to just the start", run_state.cleared.size(), 1)


func _test_same_seed_produces_the_same_first_encounter() -> void:
	var a: MapRunState = MapRunStateScript.new(_rng(123))
	var b: MapRunState = MapRunStateScript.new(_rng(123))
	var head: int = a.graph.get_node(a.graph.start_id).connections[0]
	var encounter_a: EncounterData = a.encounter_for(head)
	var encounter_b: EncounterData = b.encounter_for(head)
	check_eq("same seed rolls the same enemy count for the first head", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places the same enemy id at %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
