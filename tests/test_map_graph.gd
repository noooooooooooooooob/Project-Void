extends TestCase

const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

const SEEDS: Array[int] = [1, 42, 7]


func run() -> Array[Dictionary]:
	for seed_value in SEEDS:
		_test_story_path_is_a_straight_line_to_the_boss(seed_value)
		_test_every_story_node_has_one_or_two_farms(seed_value)
		_test_farms_are_leaves_hanging_off_their_story_node(seed_value)
		_test_every_node_is_reachable_from_start(seed_value)
		_test_boss_is_last_and_flagged(seed_value)
		_test_farm_columns_sit_beside_the_story_path(seed_value)
	return results()


func _graph(seed_value: int) -> MapGraph:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MapGraphScript.new(rng)


## 시작에서 출발해 각 노드의 "다음 이야기 노드"(connections[0])만 따라간 경로.
func _story_path(graph: MapGraph) -> Array[int]:
	var path: Array[int] = [graph.start_id]
	while not graph.get_node(path[-1]).is_boss:
		path.append(graph.get_node(path[-1]).connections[0])
	return path


func _test_story_path_is_a_straight_line_to_the_boss(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	var path: Array[int] = _story_path(graph)
	check_eq("seed %d: start + story nodes + boss on the path" % seed_value, path.size(), MapGraph.STORY_COUNT + 2)
	check_eq("seed %d: path ends at the boss" % seed_value, path[-1], graph.boss_id)
	for i in range(1, path.size() - 1):
		check("seed %d: path node %d is a story node" % [seed_value, path[i]], graph.get_node(path[i]).kind == MapNode.Kind.STORY)
		check_eq("seed %d: story node %d sits on row %d" % [seed_value, path[i], i - 1], graph.get_node(path[i]).row, i - 1)
		check_eq("seed %d: story node %d is on the centre column" % [seed_value, path[i]], graph.get_node(path[i]).col, 0)


func _test_every_story_node_has_one_or_two_farms(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	for node in graph.nodes:
		if node.kind != MapNode.Kind.STORY:
			continue
		var farm_count: int = 0
		for next_id in node.connections:
			if graph.get_node(next_id).kind == MapNode.Kind.FARM:
				farm_count += 1
		check("seed %d: story node %d has 1~2 farm nodes" % [seed_value, node.id], farm_count >= MapGraph.FARM_MIN and farm_count <= MapGraph.FARM_MAX)


func _test_farms_are_leaves_hanging_off_their_story_node(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	for node in graph.nodes:
		if node.kind != MapNode.Kind.FARM:
			continue
		check("seed %d: farm %d has no outgoing connections" % [seed_value, node.id], node.connections.is_empty())
		var parent: MapNode = graph.get_node(node.parent_id)
		check("seed %d: farm %d hangs off a story node" % [seed_value, node.id], parent.kind == MapNode.Kind.STORY)
		check("seed %d: farm %d is listed in its parent's connections" % [seed_value, node.id], parent.connections.has(node.id))
		check_eq("seed %d: farm %d shares its parent's row" % [seed_value, node.id], node.row, parent.row)


func _test_every_node_is_reachable_from_start(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	var visited: Dictionary = {graph.start_id: true}
	var frontier: Array[int] = [graph.start_id]
	while not frontier.is_empty():
		var current_id: int = frontier.pop_back()
		for next_id in graph.get_node(current_id).connections:
			if not visited.has(next_id):
				visited[next_id] = true
				frontier.append(next_id)
	check_eq("seed %d: every node reachable from start" % seed_value, visited.size(), graph.node_count())


func _test_boss_is_last_and_flagged(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	check_eq("seed %d: boss id is the last node" % seed_value, graph.boss_id, graph.node_count() - 1)
	check("seed %d: boss node is flagged as boss" % seed_value, graph.get_node(graph.boss_id).is_boss)
	check("seed %d: boss has no outgoing connections" % seed_value, graph.get_node(graph.boss_id).connections.is_empty())
	check("seed %d: start is not the boss" % seed_value, not graph.get_node(graph.start_id).is_boss)


func _test_farm_columns_sit_beside_the_story_path(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	for node in graph.nodes:
		if node.kind == MapNode.Kind.FARM:
			check("seed %d: farm %d is one column off the path" % [seed_value, node.id], absi(node.col) == 1)
