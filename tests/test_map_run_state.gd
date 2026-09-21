extends TestCase

const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


func run() -> Array[Dictionary]:
	_test_start_offers_both_branch_heads()
	_test_only_reachable_nodes_are_selectable()
	_test_entering_one_branch_locks_out_the_other()
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


func _test_start_offers_both_branch_heads() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	check("branch 0 head is selectable", run_state.is_selectable(1))
	check("branch 1 head is selectable", run_state.is_selectable(5))


func _test_only_reachable_nodes_are_selectable() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	check("step 2 of branch 0 is not selectable yet", not run_state.is_selectable(2))
	check("boss is not selectable yet", not run_state.is_selectable(9))
	check("start itself is not selectable", not run_state.is_selectable(0))


func _test_entering_one_branch_locks_out_the_other() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	run_state.resolve_win(1)
	check("branch 0 step 2 now selectable", run_state.is_selectable(2))
	check("branch 1 head no longer selectable", not run_state.is_selectable(5))


func _test_resolve_win_advances_and_clears() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	run_state.resolve_win(1)
	check_eq("current node moved to 1", run_state.current_node_id, 1)
	check("node 1 marked cleared", run_state.cleared.get(1, false))


func _test_resolve_win_ignores_unreachable_nodes() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	run_state.resolve_win(9)
	check_eq("current node unchanged for an unreachable target", run_state.current_node_id, 0)


func _test_boss_win_starts_a_fresh_run() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var old_graph: MapGraph = run_state.graph
	run_state.resolve_win(1)
	run_state.resolve_win(2)
	run_state.resolve_win(3)
	run_state.resolve_win(4)
	run_state.resolve_win(9)
	check("boss win generates a new graph", run_state.graph != old_graph)
	check_eq("run returns to the new start", run_state.current_node_id, run_state.graph.start_id)
	check("new start is cleared", run_state.cleared.get(run_state.graph.start_id, false))


func _test_reset_starts_a_fresh_run() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	run_state.resolve_win(1)
	run_state.reset()
	check_eq("reset returns to start", run_state.current_node_id, run_state.graph.start_id)
	check_eq("reset clears progress back to just the start", run_state.cleared.size(), 1)


func _test_same_seed_produces_the_same_first_encounter() -> void:
	var a: MapRunState = MapRunStateScript.new(_rng(123))
	var b: MapRunState = MapRunStateScript.new(_rng(123))
	var encounter_a: EncounterData = a.encounter_for(1)
	var encounter_b: EncounterData = b.encounter_for(1)
	check_eq("same seed rolls the same enemy count for node 1", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places the same enemy id at %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
