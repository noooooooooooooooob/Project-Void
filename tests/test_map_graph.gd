extends TestCase

const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

const SEEDS: Array[int] = [1, 42, 7]


func run() -> Array[Dictionary]:
	for seed_value in SEEDS:
		_test_start_branches_into_at_least_three(seed_value)
		_test_every_non_boss_node_has_a_way_forward(seed_value)
		_test_boss_has_no_outgoing_connections(seed_value)
		_test_every_node_is_reachable_from_start(seed_value)
		_test_rows_and_columns_stay_in_bounds(seed_value)
		_test_boss_is_last_and_flagged(seed_value)
	return results()


func _graph(seed_value: int) -> MapGraph:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MapGraphScript.new(rng)


func _test_start_branches_into_at_least_three(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	var start_connections: Array[int] = graph.get_node(graph.start_id).connections
	check("seed %d: start branches into 3+ nodes" % seed_value, start_connections.size() >= 3)
	for target_id in start_connections:
		check("seed %d: start branch %d sits on the first row" % [seed_value, target_id], graph.get_node(target_id).row == 0)


func _test_every_non_boss_node_has_a_way_forward(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	for node in graph.nodes:
		if node.is_boss:
			continue
		check("seed %d: node %d has an outgoing connection" % [seed_value, node.id], not node.connections.is_empty())


func _test_boss_has_no_outgoing_connections(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	check("seed %d: boss has no outgoing connections" % seed_value, graph.get_node(graph.boss_id).connections.is_empty())


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


func _test_rows_and_columns_stay_in_bounds(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	for node in graph.nodes:
		if node.id == graph.start_id or node.is_boss:
			continue
		check("seed %d: node %d row in range" % [seed_value, node.id], node.row >= 0 and node.row < MapGraph.ROWS)
		check("seed %d: node %d col in range" % [seed_value, node.id], node.col >= 0 and node.col < MapGraph.COLS)


func _test_boss_is_last_and_flagged(seed_value: int) -> void:
	var graph: MapGraph = _graph(seed_value)
	check_eq("seed %d: boss id is the last node" % seed_value, graph.boss_id, graph.node_count() - 1)
	check("seed %d: boss node is flagged as boss" % seed_value, graph.get_node(graph.boss_id).is_boss)
	check("seed %d: start is not the boss" % seed_value, not graph.get_node(graph.start_id).is_boss)
