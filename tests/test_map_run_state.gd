extends TestCase

const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


func run() -> Array[Dictionary]:
	_test_start_offers_only_the_first_story_node()
	_test_farms_stay_locked_until_their_story_node_is_cleared()
	_test_story_win_advances_and_unlocks_the_next_story_node()
	_test_cannot_skip_ahead_in_the_story()
	_test_farm_win_does_not_advance_or_clear()
	_test_farms_of_earlier_story_nodes_stay_available()
	_test_story_encounters_are_stable_and_farm_encounters_are_rerolled()
	_test_boss_win_starts_a_fresh_map()
	_test_reset_starts_a_fresh_map()
	_test_same_seed_produces_the_same_first_encounter()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _first_story_id(run_state: MapRunState) -> int:
	return run_state.graph.get_node(run_state.graph.start_id).connections[0]


func _farm_ids_of(run_state: MapRunState, story_id: int) -> Array[int]:
	var ids: Array[int] = []
	for next_id in run_state.graph.get_node(story_id).connections:
		if run_state.graph.get_node(next_id).kind == MapNode.Kind.FARM:
			ids.append(next_id)
	return ids


func _ally_units() -> Array[UnitPlacement]:
	return EncounterGenerator.build_ally_roster(_rng(1))


## 시작에서 보스까지 이야기 노드만 차례로 이긴다. 마지막 호출이 보스를 이겨 새 맵이 시작된다.
func _win_to_boss(run_state: MapRunState) -> void:
	var boss_id: int = run_state.graph.boss_id
	var next_id: int = -1
	while next_id != boss_id:
		next_id = run_state.graph.get_node(run_state.current_node_id).connections[0]
		run_state.resolve_win(next_id)


func _test_start_offers_only_the_first_story_node() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	check("first story node is selectable", run_state.is_selectable(_first_story_id(run_state)))
	check("boss is not selectable yet", not run_state.is_selectable(run_state.graph.boss_id))
	check("start itself is not selectable", not run_state.is_selectable(run_state.graph.start_id))
	var selectable_count: int = 0
	for node in run_state.graph.nodes:
		if run_state.is_selectable(node.id):
			selectable_count += 1
	check_eq("only one node is selectable at the start", selectable_count, 1)


func _test_farms_stay_locked_until_their_story_node_is_cleared() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var story_id: int = _first_story_id(run_state)
	for farm_id in _farm_ids_of(run_state, story_id):
		check("farm %d is locked before its story node is cleared" % farm_id, not run_state.is_selectable(farm_id))
	run_state.resolve_win(story_id)
	for farm_id in _farm_ids_of(run_state, story_id):
		check("farm %d unlocks once its story node is cleared" % farm_id, run_state.is_selectable(farm_id))


func _test_story_win_advances_and_unlocks_the_next_story_node() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var first_id: int = _first_story_id(run_state)
	var second_id: int = run_state.graph.get_node(first_id).connections[0]
	check("second story node is locked at first", not run_state.is_selectable(second_id))
	run_state.resolve_win(first_id)
	check_eq("current node moved to the cleared story node", run_state.current_node_id, first_id)
	check("cleared story node is marked cleared", run_state.cleared.get(first_id, false))
	check("cleared story node can't be entered again", not run_state.is_selectable(first_id))
	check("next story node is now selectable", run_state.is_selectable(second_id))


func _test_cannot_skip_ahead_in_the_story() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var start_id: int = run_state.graph.start_id
	run_state.resolve_win(run_state.graph.boss_id)
	check_eq("winning an unreachable node changes nothing", run_state.current_node_id, start_id)
	check_eq("and clears nothing", run_state.cleared.size(), 1)


func _test_farm_win_does_not_advance_or_clear() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var story_id: int = _first_story_id(run_state)
	run_state.resolve_win(story_id)
	var farm_id: int = _farm_ids_of(run_state, story_id)[0]
	run_state.resolve_win(farm_id)
	check_eq("farm win leaves the story progress where it was", run_state.current_node_id, story_id)
	check("farm node is never marked cleared", not run_state.cleared.has(farm_id))
	check("farm node can be entered again", run_state.is_selectable(farm_id))


func _test_farms_of_earlier_story_nodes_stay_available() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var first_id: int = _first_story_id(run_state)
	var second_id: int = run_state.graph.get_node(first_id).connections[0]
	run_state.resolve_win(first_id)
	run_state.resolve_win(second_id)
	for farm_id in _farm_ids_of(run_state, first_id):
		check("farm %d of the first story node is still open after moving on" % farm_id, run_state.is_selectable(farm_id))


func _test_story_encounters_are_stable_and_farm_encounters_are_rerolled() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(5))
	var story_id: int = _first_story_id(run_state)
	var allies: Array[UnitPlacement] = _ally_units()
	var first: EncounterData = run_state.encounter_for(story_id, allies)
	var again: EncounterData = run_state.encounter_for(story_id, allies)
	check_eq("a story node keeps the same enemy count", first.enemy_units.size(), again.enemy_units.size())
	for i in first.enemy_units.size():
		check_eq("a story node keeps enemy %d" % i, first.enemy_units[i].unit_data.id, again.enemy_units[i].unit_data.id)
	check("encounters carry the given allies", first.ally_units == allies)

	run_state.resolve_win(story_id)
	var farm_id: int = _farm_ids_of(run_state, story_id)[0]
	var signatures: Dictionary = {}
	for i in 12:
		var farm_encounter: EncounterData = run_state.encounter_for(farm_id, allies)
		var parts: PackedStringArray = []
		for placement in farm_encounter.enemy_units:
			parts.append("%s@%s" % [placement.unit_data.id, placement.cell])
		signatures[",".join(parts)] = true
	check("farm encounters are rolled fresh each time", signatures.size() > 1)


func _test_boss_win_starts_a_fresh_map() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	var old_graph: MapGraph = run_state.graph
	_win_to_boss(run_state)
	check("boss win generates a new graph", run_state.graph != old_graph)
	check_eq("map returns to the new start", run_state.current_node_id, run_state.graph.start_id)
	check("new start is cleared", run_state.cleared.get(run_state.graph.start_id, false))


func _test_reset_starts_a_fresh_map() -> void:
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	run_state.resolve_win(_first_story_id(run_state))
	run_state.reset()
	check_eq("reset returns to start", run_state.current_node_id, run_state.graph.start_id)
	check_eq("reset clears progress back to just the start", run_state.cleared.size(), 1)


func _test_same_seed_produces_the_same_first_encounter() -> void:
	var a: MapRunState = MapRunStateScript.new(_rng(123))
	var b: MapRunState = MapRunStateScript.new(_rng(123))
	var story_id: int = _first_story_id(a)
	var encounter_a: EncounterData = a.encounter_for(story_id, _ally_units())
	var encounter_b: EncounterData = b.encounter_for(story_id, _ally_units())
	check_eq("same seed rolls the same enemy count for the first story node", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places the same enemy id at %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
