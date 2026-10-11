# StageGraph(의뢰 1층 격자) 테스트: 칸 수, 연결 규칙, 첫 칸 전투, 시드 재현. 여러 시드로 반복한다.
extends TestCase

# 격자 스크립트.
const StageGraphScript := preload("res://Scripts/map/stage_graph.gd")

# 무작위 칸 종류가 달라도 규칙이 지켜지는지 보려고 여러 시드로 돌린다.
const SEEDS: Array[int] = [1, 42, 7]


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시드마다.
	for seed_value in SEEDS:
		# 칸 수와 시작·보스.
		_test_node_count_and_ends(seed_value)
		# 시작은 첫 칸 셋과 이어진다.
		_test_start_connects_to_every_first_step_cell(seed_value)
		# 칸은 다음 칸 중 줄 차이 1 이하와 이어진다.
		_test_cells_connect_to_adjacent_lanes_of_the_next_step(seed_value)
		# 마지막 칸 셋은 보스로.
		_test_last_step_connects_to_the_boss(seed_value)
		# 첫 칸은 전투, 나머지는 보스·시작이 아닌 칸.
		_test_first_step_is_battle_and_middle_kinds_are_rollable(seed_value)
	# 같은 시드는 같은 격자.
	_test_same_seed_gives_the_same_kinds()
	# 결과를 돌려준다.
	return results()


# 시드를 고정해 격자를 만든다.
func _graph(seed_value: int) -> StageGraph:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = seed_value
	# 격자를 만들어 돌려준다.
	return StageGraphScript.new(rng)


# 3×5 칸 + 시작 + 보스. 시작은 id 0, lane 1, step -1. 보스는 lane 1, step STEPS.
func _test_node_count_and_ends(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 칸 수.
	check_eq("seed %d: 3x5 cells + start + boss" % seed_value, graph.node_count(), StageGraph.LANES * StageGraph.STEPS + 2)
	# 시작.
	var start: StageNode = graph.get_node(graph.start_id)
	check_eq("seed %d: start is id 0" % seed_value, graph.start_id, 0)
	check_eq("seed %d: start kind" % seed_value, start.kind, StageNode.Kind.START)
	check_eq("seed %d: start step" % seed_value, start.step, -1)
	# 보스.
	var boss: StageNode = graph.get_node(graph.boss_id)
	check_eq("seed %d: boss kind" % seed_value, boss.kind, StageNode.Kind.BOSS)
	check_eq("seed %d: boss step" % seed_value, boss.step, StageGraph.STEPS)
	check_eq("seed %d: boss has no exits" % seed_value, boss.connections.size(), 0)


# 시작의 연결 = step 0 의 세 칸.
func _test_start_connects_to_every_first_step_cell(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 시작의 연결.
	var exits: Array[int] = graph.get_node(graph.start_id).connections
	# 세 개.
	check_eq("seed %d: start has LANES exits" % seed_value, exits.size(), StageGraph.LANES)
	# 줄마다 step 0 칸이 들어 있다.
	for lane in StageGraph.LANES:
		check("seed %d: start reaches lane %d" % [seed_value, lane], exits.has(graph.node_at(lane, 0).id))


# (l, s) 의 연결 = step s+1 중 |l'-l| <= 1 인 칸 전부, 그 외는 없음.
func _test_cells_connect_to_adjacent_lanes_of_the_next_step(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 마지막 step 앞까지.
	for step in StageGraph.STEPS - 1:
		for lane in StageGraph.LANES:
			# 그 칸.
			var node: StageNode = graph.node_at(lane, step)
			# 기대 연결.
			var expected: Array[int] = []
			for next_lane in StageGraph.LANES:
				if absi(next_lane - lane) <= 1:
					expected.append(graph.node_at(next_lane, step + 1).id)
			# 정렬해서 비교한다.
			var actual: Array[int] = node.connections.duplicate()
			actual.sort()
			expected.sort()
			check_eq("seed %d: (%d,%d) connects to adjacent lanes" % [seed_value, lane, step], actual, expected)


# step 4 의 세 칸은 보스로만 이어진다.
func _test_last_step_connects_to_the_boss(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 줄마다.
	for lane in StageGraph.LANES:
		# 마지막 칸.
		var node: StageNode = graph.node_at(lane, StageGraph.STEPS - 1)
		# 보스 하나.
		var expected: Array[int] = [graph.boss_id]
		check_eq("seed %d: last cell in lane %d leads to the boss" % [seed_value, lane], node.connections, expected)


# step 0 은 전부 전투. 가운데 칸은 전투·이벤트·상점·휴식 중 하나.
func _test_first_step_is_battle_and_middle_kinds_are_rollable(seed_value: int) -> void:
	# 격자.
	var graph: StageGraph = _graph(seed_value)
	# 굴릴 수 있는 종류.
	var rollable: Array = [StageNode.Kind.BATTLE, StageNode.Kind.EVENT, StageNode.Kind.SHOP, StageNode.Kind.REST]
	# 칸마다.
	for step in StageGraph.STEPS:
		for lane in StageGraph.LANES:
			# 그 칸.
			var node: StageNode = graph.node_at(lane, step)
			# 첫 칸은 전투.
			if step == 0:
				check_eq("seed %d: (%d,0) is a battle" % [seed_value, lane], node.kind, StageNode.Kind.BATTLE)
			# 나머지는 굴린 종류.
			else:
				check("seed %d: (%d,%d) kind is rollable" % [seed_value, lane, step], rollable.has(node.kind))


# 같은 시드 두 번 → 칸 종류가 같다.
func _test_same_seed_gives_the_same_kinds() -> void:
	# 두 격자.
	var a: StageGraph = _graph(99)
	var b: StageGraph = _graph(99)
	# 종류 목록.
	var kinds_a: Array[int] = []
	var kinds_b: Array[int] = []
	for i in a.node_count():
		kinds_a.append(a.get_node(i).kind)
		kinds_b.append(b.get_node(i).kind)
	# 같다.
	check_eq("same seed gives the same room kinds", kinds_a, kinds_b)
