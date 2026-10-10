# MapRunState(지도 진행 상태) 테스트: 해금 규칙, 이야기·파밍 승리, 적 구성 고정·재추첨, 보스 후 새 지도, 시드 재현.
extends TestCase

# 지도 진행 상태 스크립트.
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 처음엔 첫 이야기 노드만 열린다.
	_test_start_offers_only_the_first_story_node()
	# 파밍은 부모 이야기 노드를 깨야 열린다.
	_test_farms_stay_locked_until_their_story_node_is_cleared()
	# 이야기 승리는 진행도를 올리고 다음을 연다.
	_test_story_win_advances_and_unlocks_the_next_story_node()
	# 앞질러 갈 수 없다.
	_test_cannot_skip_ahead_in_the_story()
	# 파밍 승리는 진행도를 바꾸지 않는다.
	_test_farm_win_does_not_advance_or_clear()
	# 지난 이야기 노드의 파밍도 계속 열려 있다.
	_test_farms_of_earlier_story_nodes_stay_available()
	# 이야기 적은 고정, 파밍 적은 매번 새로.
	_test_story_encounters_are_stable_and_farm_encounters_are_rerolled()
	# 보스를 깨면 새 지도.
	_test_boss_win_starts_a_fresh_map()
	# reset 은 새 지도.
	_test_reset_starts_a_fresh_map()
	# 같은 시드면 같은 첫 전투.
	_test_same_seed_produces_the_same_first_encounter()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수 생성기.
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 돌려준다.
	return rng


# 시작 노드 다음의 첫 이야기 노드 id.
func _first_story_id(run_state: MapRunState) -> int:
	# 시작 노드의 첫 연결.
	return run_state.graph.get_node(run_state.graph.start_id).connections[0]


# 그 이야기 노드에 매달린 파밍 노드 id 들.
func _farm_ids_of(run_state: MapRunState, story_id: int) -> Array[int]:
	# 모을 목록.
	var ids: Array[int] = []
	# 이야기 노드의 연결마다.
	for next_id in run_state.graph.get_node(story_id).connections:
		# 파밍 노드면 넣는다.
		if run_state.graph.get_node(next_id).kind == MapNode.Kind.FARM:
			ids.append(next_id)
	# 돌려준다.
	return ids


# 전투 구성에 넘길 아군 배치.
func _ally_units() -> Array[UnitPlacement]:
	# 시드 1 로 시작 파티를 만든다.
	return EncounterGenerator.build_ally_roster(_rng(1))


## 시작에서 보스까지 이야기 노드만 차례로 이긴다. 마지막 호출이 보스를 이겨 새 맵이 시작된다.
func _win_to_boss(run_state: MapRunState) -> void:
	# 처음 지도의 보스 id (이기면 지도가 바뀌므로 미리 기억한다).
	var boss_id: int = run_state.graph.boss_id
	# 방금 이긴 노드.
	var next_id: int = -1
	# 보스를 이길 때까지.
	while next_id != boss_id:
		# 지금 위치의 다음 이야기 노드.
		next_id = run_state.graph.get_node(run_state.current_node_id).connections[0]
		# 이긴다.
		run_state.resolve_win(next_id)


# 처음엔 첫 이야기 노드 하나만 고를 수 있다.
func _test_start_offers_only_the_first_story_node() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드는 열려 있다.
	check("first story node is selectable", run_state.is_selectable(_first_story_id(run_state)))
	# 보스는 아직 닫혀 있다.
	check("boss is not selectable yet", not run_state.is_selectable(run_state.graph.boss_id))
	# 시작 노드는 고를 수 없다.
	check("start itself is not selectable", not run_state.is_selectable(run_state.graph.start_id))
	# 열린 노드 수.
	var selectable_count: int = 0
	# 모든 노드를 센다.
	for node in run_state.graph.nodes:
		if run_state.is_selectable(node.id):
			selectable_count += 1
	# 딱 하나.
	check_eq("only one node is selectable at the start", selectable_count, 1)


# 파밍 노드는 부모 이야기 노드를 깨기 전엔 닫혀 있고, 깨면 열린다.
func _test_farms_stay_locked_until_their_story_node_is_cleared() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드.
	var story_id: int = _first_story_id(run_state)
	# 깨기 전: 파밍마다 닫혀 있다.
	for farm_id in _farm_ids_of(run_state, story_id):
		check("farm %d is locked before its story node is cleared" % farm_id, not run_state.is_selectable(farm_id))
	# 이야기 노드를 깬다.
	run_state.resolve_win(story_id)
	# 깬 뒤: 파밍마다 열린다.
	for farm_id in _farm_ids_of(run_state, story_id):
		check("farm %d unlocks once its story node is cleared" % farm_id, run_state.is_selectable(farm_id))


# 이야기 노드를 이기면 현재 위치가 옮겨지고, 깬 노드는 닫히고, 다음 이야기 노드가 열린다.
func _test_story_win_advances_and_unlocks_the_next_story_node() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드.
	var first_id: int = _first_story_id(run_state)
	# 두 번째 이야기 노드.
	var second_id: int = run_state.graph.get_node(first_id).connections[0]
	# 처음엔 두 번째가 닫혀 있다.
	check("second story node is locked at first", not run_state.is_selectable(second_id))
	# 첫 번째를 이긴다.
	run_state.resolve_win(first_id)
	# 현재 위치가 첫 번째로.
	check_eq("current node moved to the cleared story node", run_state.current_node_id, first_id)
	# 깬 노드로 기록.
	check("cleared story node is marked cleared", run_state.cleared.get(first_id, false))
	# 다시 들어갈 수 없다.
	check("cleared story node can't be entered again", not run_state.is_selectable(first_id))
	# 두 번째가 열렸다.
	check("next story node is now selectable", run_state.is_selectable(second_id))


# 닿을 수 없는 노드(보스)를 이겼다고 해도 아무것도 바뀌지 않는다.
func _test_cannot_skip_ahead_in_the_story() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 시작 노드 id.
	var start_id: int = run_state.graph.start_id
	# 보스를 바로 이긴 것처럼 부른다.
	run_state.resolve_win(run_state.graph.boss_id)
	# 위치가 그대로.
	check_eq("winning an unreachable node changes nothing", run_state.current_node_id, start_id)
	# 깬 노드도 시작 하나뿐.
	check_eq("and clears nothing", run_state.cleared.size(), 1)


# 파밍 노드를 이겨도 진행도는 그대로이고, 파밍 노드는 다시 들어갈 수 있다.
func _test_farm_win_does_not_advance_or_clear() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드.
	var story_id: int = _first_story_id(run_state)
	# 이야기 노드를 깨서 파밍을 연다.
	run_state.resolve_win(story_id)
	# 첫 파밍 노드.
	var farm_id: int = _farm_ids_of(run_state, story_id)[0]
	# 파밍 노드를 이긴다.
	run_state.resolve_win(farm_id)
	# 위치는 이야기 노드 그대로.
	check_eq("farm win leaves the story progress where it was", run_state.current_node_id, story_id)
	# 파밍은 깬 노드로 기록되지 않는다.
	check("farm node is never marked cleared", not run_state.cleared.has(farm_id))
	# 또 들어갈 수 있다.
	check("farm node can be entered again", run_state.is_selectable(farm_id))


# 다음 이야기로 넘어가도 이전 이야기 노드의 파밍은 열려 있다.
func _test_farms_of_earlier_story_nodes_stay_available() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드.
	var first_id: int = _first_story_id(run_state)
	# 두 번째 이야기 노드.
	var second_id: int = run_state.graph.get_node(first_id).connections[0]
	# 첫 번째를 깬다.
	run_state.resolve_win(first_id)
	# 두 번째도 깬다.
	run_state.resolve_win(second_id)
	# 첫 번째의 파밍마다 여전히 열려 있다.
	for farm_id in _farm_ids_of(run_state, first_id):
		check("farm %d of the first story node is still open after moving on" % farm_id, run_state.is_selectable(farm_id))


# 이야기 노드는 몇 번 물어도 같은 적이, 파밍 노드는 물을 때마다 다른 적이 나온다.
func _test_story_encounters_are_stable_and_farm_encounters_are_rerolled() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(5))
	# 첫 이야기 노드.
	var story_id: int = _first_story_id(run_state)
	# 아군 배치.
	var allies: Array[UnitPlacement] = _ally_units()
	# 첫 번째 구성.
	var first: EncounterData = run_state.encounter_for(story_id, allies)
	# 다시 물은 구성.
	var again: EncounterData = run_state.encounter_for(story_id, allies)
	# 적 수가 같다.
	check_eq("a story node keeps the same enemy count", first.enemy_units.size(), again.enemy_units.size())
	# 적마다 종류가 같다.
	for i in first.enemy_units.size():
		check_eq("a story node keeps enemy %d" % i, first.enemy_units[i].unit_data.id, again.enemy_units[i].unit_data.id)
	# 넘긴 아군이 그대로 들어 있다.
	check("encounters carry the given allies", first.ally_units == allies)

	# 이야기 노드를 깨서 파밍을 연다.
	run_state.resolve_win(story_id)
	# 첫 파밍 노드.
	var farm_id: int = _farm_ids_of(run_state, story_id)[0]
	# 나온 적 구성의 서로 다른 모양들.
	var signatures: Dictionary = {}
	# 12 번 묻는다.
	for i in 12:
		# 파밍 구성.
		var farm_encounter: EncounterData = run_state.encounter_for(farm_id, allies)
		# "종류@칸" 조각들.
		var parts: PackedStringArray = []
		# 적마다 조각을 만든다.
		for placement in farm_encounter.enemy_units:
			parts.append("%s@%s" % [placement.unit_data.id, placement.cell])
		# 이어 붙여 모양 하나로 기록한다.
		signatures[",".join(parts)] = true
	# 두 가지 이상 나왔다.
	check("farm encounters are rolled fresh each time", signatures.size() > 1)


# 보스를 깨면 새 지도가 만들어지고 새 시작 노드로 돌아간다.
func _test_boss_win_starts_a_fresh_map() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 처음 지도.
	var old_graph: MapGraph = run_state.graph
	# 보스까지 이긴다.
	_win_to_boss(run_state)
	# 지도가 바뀌었다.
	check("boss win generates a new graph", run_state.graph != old_graph)
	# 새 시작 노드에 있다.
	check_eq("map returns to the new start", run_state.current_node_id, run_state.graph.start_id)
	# 새 시작 노드는 깬 상태.
	check("new start is cleared", run_state.cleared.get(run_state.graph.start_id, false))


# reset 은 진행도를 지우고 시작 노드로 돌아간다.
func _test_reset_starts_a_fresh_map() -> void:
	# 진행 상태를 만든다.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 첫 이야기 노드를 깬다.
	run_state.resolve_win(_first_story_id(run_state))
	# 초기화한다.
	run_state.reset()
	# 시작 노드로.
	check_eq("reset returns to start", run_state.current_node_id, run_state.graph.start_id)
	# 깬 노드는 시작 하나뿐.
	check_eq("reset clears progress back to just the start", run_state.cleared.size(), 1)


# 같은 시드면 첫 이야기 노드의 적 구성이 같다.
func _test_same_seed_produces_the_same_first_encounter() -> void:
	# 시드 123 (첫 번째).
	var a: MapRunState = MapRunStateScript.new(_rng(123))
	# 시드 123 (두 번째).
	var b: MapRunState = MapRunStateScript.new(_rng(123))
	# 첫 이야기 노드 (두 지도에서 id 가 같다).
	var story_id: int = _first_story_id(a)
	# 첫 번째 구성.
	var encounter_a: EncounterData = a.encounter_for(story_id, _ally_units())
	# 두 번째 구성.
	var encounter_b: EncounterData = b.encounter_for(story_id, _ally_units())
	# 적 수가 같다.
	check_eq("same seed rolls the same enemy count for the first story node", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	# 적마다 종류가 같다.
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places the same enemy id at %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
