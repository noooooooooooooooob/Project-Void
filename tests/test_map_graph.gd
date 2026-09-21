extends TestCase

const MapGraphScript := preload("res://Scripts/map/map_graph.gd")


func run() -> Array[Dictionary]:
	_test_node_count()
	_test_start_connects_to_both_branch_heads()
	_test_branch_is_a_linear_chain()
	_test_branch_tails_converge_on_boss()
	_test_boss_flag()
	return results()


func _test_node_count() -> void:
	var graph: MapGraph = MapGraphScript.new()
	check_eq("10 nodes total", graph.node_count(), 10)
	check_eq("nodes array matches count", graph.nodes.size(), 10)
	check_eq("boss id is last", graph.boss_id, 9)
	check_eq("start id is 0", graph.start_id, 0)


func _test_start_connects_to_both_branch_heads() -> void:
	var graph: MapGraph = MapGraphScript.new()
	check_eq("start connects to branch heads", graph.get_node(0).connections, [1, 5])


func _test_branch_is_a_linear_chain() -> void:
	var graph: MapGraph = MapGraphScript.new()
	check_eq("branch 0 step 0 -> step 1", graph.get_node(1).connections, [2])
	check_eq("branch 0 step 1 -> step 2", graph.get_node(2).connections, [3])
	check_eq("branch 1 step 0 -> step 1", graph.get_node(5).connections, [6])
	check_eq("branch 1 step 1 -> step 2", graph.get_node(6).connections, [7])


func _test_branch_tails_converge_on_boss() -> void:
	var graph: MapGraph = MapGraphScript.new()
	check_eq("branch 0 tail connects to boss", graph.get_node(4).connections, [9])
	check_eq("branch 1 tail connects to boss", graph.get_node(8).connections, [9])
	check("boss has no outgoing connections", graph.get_node(9).connections.is_empty())


func _test_boss_flag() -> void:
	var graph: MapGraph = MapGraphScript.new()
	check("node 9 is the boss", graph.get_node(9).is_boss)
	check("start is not the boss", not graph.get_node(0).is_boss)
	check("a regular step is not the boss", not graph.get_node(3).is_boss)
