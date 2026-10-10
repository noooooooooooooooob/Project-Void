# MapGraph(지도 모양) 테스트: 이야기 길, 파밍 노드 수·위치, 도달 가능성, 보스. 여러 시드로 반복한다.
extends TestCase

# 지도 그래프 스크립트.
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

# 무작위 모양이 달라도 규칙이 지켜지는지 보려고 여러 시드로 돌린다.
const SEEDS: Array[int] = [1, 42, 7]


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시드마다 모든 검사를 돌린다.
	for seed_value in SEEDS:
		# 이야기 길은 보스까지 일직선.
		_test_story_path_is_a_straight_line_to_the_boss(seed_value)
		# 이야기 노드마다 파밍 노드 1~2 개.
		_test_every_story_node_has_one_or_two_farms(seed_value)
		# 파밍 노드는 이야기 노드에 매달린 끝 노드.
		_test_farms_are_leaves_hanging_off_their_story_node(seed_value)
		# 모든 노드가 시작에서 닿는다.
		_test_every_node_is_reachable_from_start(seed_value)
		# 보스는 마지막 노드.
		_test_boss_is_last_and_flagged(seed_value)
		# 파밍 노드는 이야기 길 바로 옆 열.
		_test_farm_columns_sit_beside_the_story_path(seed_value)
	# 결과를 돌려준다.
	return results()


# 시드를 고정해 지도를 만든다.
func _graph(seed_value: int) -> MapGraph:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 지도를 만들어 돌려준다.
	return MapGraphScript.new(rng)


## 시작에서 출발해 각 노드의 "다음 이야기 노드"(connections[0])만 따라간 경로.
func _story_path(graph: MapGraph) -> Array[int]:
	# 시작 노드에서 출발.
	var path: Array[int] = [graph.start_id]
	# 보스에 닿을 때까지.
	while not graph.get_node(path[-1]).is_boss:
		# 마지막 노드의 첫 연결(다음 이야기 노드)로 간다.
		path.append(graph.get_node(path[-1]).connections[0])
	# 경로를 돌려준다.
	return path


# 이야기 길: 시작 + 이야기 노드 STORY_COUNT 개 + 보스, 가운데 열에 한 행씩.
func _test_story_path_is_a_straight_line_to_the_boss(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 이야기 길을 따라간다.
	var path: Array[int] = _story_path(graph)
	# 길이가 맞다.
	check_eq("seed %d: start + story nodes + boss on the path" % seed_value, path.size(), MapGraph.STORY_COUNT + 2)
	# 끝이 보스다.
	check_eq("seed %d: path ends at the boss" % seed_value, path[-1], graph.boss_id)
	# 시작·보스를 뺀 가운데 노드마다.
	for i in range(1, path.size() - 1):
		# 이야기 노드다.
		check("seed %d: path node %d is a story node" % [seed_value, path[i]], graph.get_node(path[i]).kind == MapNode.Kind.STORY)
		# 순서대로 행이 0, 1, 2 ...
		check_eq("seed %d: story node %d sits on row %d" % [seed_value, path[i], i - 1], graph.get_node(path[i]).row, i - 1)
		# 가운데 열.
		check_eq("seed %d: story node %d is on the centre column" % [seed_value, path[i]], graph.get_node(path[i]).col, 0)


# 이야기 노드마다 연결된 파밍 노드가 FARM_MIN~FARM_MAX 개다.
func _test_every_story_node_has_one_or_two_farms(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 노드마다.
	for node in graph.nodes:
		# 이야기 노드만 본다.
		if node.kind != MapNode.Kind.STORY:
			continue
		# 연결된 파밍 노드 수.
		var farm_count: int = 0
		# 연결마다.
		for next_id in node.connections:
			# 파밍 노드면 센다.
			if graph.get_node(next_id).kind == MapNode.Kind.FARM:
				farm_count += 1
		# 범위 안이다.
		check("seed %d: story node %d has 1~2 farm nodes" % [seed_value, node.id], farm_count >= MapGraph.FARM_MIN and farm_count <= MapGraph.FARM_MAX)


# 파밍 노드는 더 나아가는 연결이 없고, 부모 이야기 노드와 같은 행에 매달려 있다.
func _test_farms_are_leaves_hanging_off_their_story_node(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 노드마다.
	for node in graph.nodes:
		# 파밍 노드만 본다.
		if node.kind != MapNode.Kind.FARM:
			continue
		# 끝 노드다.
		check("seed %d: farm %d has no outgoing connections" % [seed_value, node.id], node.connections.is_empty())
		# 부모 노드.
		var parent: MapNode = graph.get_node(node.parent_id)
		# 부모는 이야기 노드다.
		check("seed %d: farm %d hangs off a story node" % [seed_value, node.id], parent.kind == MapNode.Kind.STORY)
		# 부모의 연결 목록에 들어 있다.
		check("seed %d: farm %d is listed in its parent's connections" % [seed_value, node.id], parent.connections.has(node.id))
		# 부모와 같은 행.
		check_eq("seed %d: farm %d shares its parent's row" % [seed_value, node.id], node.row, parent.row)


# 시작에서 연결을 따라가면 모든 노드에 닿는다 (깊이 우선 탐색).
func _test_every_node_is_reachable_from_start(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 방문한 노드.
	var visited: Dictionary = {graph.start_id: true}
	# 다음에 볼 노드.
	var frontier: Array[int] = [graph.start_id]
	# 볼 노드가 남아 있는 동안.
	while not frontier.is_empty():
		# 하나 꺼낸다.
		var current_id: int = frontier.pop_back()
		# 그 노드의 연결마다.
		for next_id in graph.get_node(current_id).connections:
			# 처음 보는 노드면.
			if not visited.has(next_id):
				# 방문 표시.
				visited[next_id] = true
				# 나중에 볼 목록에 넣는다.
				frontier.append(next_id)
	# 방문 수가 전체 노드 수와 같다.
	check_eq("seed %d: every node reachable from start" % seed_value, visited.size(), graph.node_count())


# 보스는 마지막 id 이고, 보스 표시가 있으며, 더 나아가는 연결이 없다.
func _test_boss_is_last_and_flagged(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 마지막 id.
	check_eq("seed %d: boss id is the last node" % seed_value, graph.boss_id, graph.node_count() - 1)
	# 보스 표시.
	check("seed %d: boss node is flagged as boss" % seed_value, graph.get_node(graph.boss_id).is_boss)
	# 끝 노드.
	check("seed %d: boss has no outgoing connections" % seed_value, graph.get_node(graph.boss_id).connections.is_empty())
	# 시작은 보스가 아니다.
	check("seed %d: start is not the boss" % seed_value, not graph.get_node(graph.start_id).is_boss)


# 파밍 노드는 가운데에서 한 열 떨어져 있다 (열 -1 또는 1).
func _test_farm_columns_sit_beside_the_story_path(seed_value: int) -> void:
	# 지도를 만든다.
	var graph: MapGraph = _graph(seed_value)
	# 노드마다.
	for node in graph.nodes:
		# 파밍 노드면 열을 확인한다.
		if node.kind == MapNode.Kind.FARM:
			check("seed %d: farm %d is one column off the path" % [seed_value, node.id], absi(node.col) == 1)
