extends TestCase

const MapGraphScript := preload("res://Scripts/map/map_graph.gd")
const MapLayoutScript := preload("res://Scripts/map/map_layout.gd")


func run() -> Array[Dictionary]:
	_test_start_at_origin()
	_test_branches_are_mirrored()
	_test_steps_move_away_from_start()
	_test_boss_is_farthest_and_centred()
	return results()


func _graph() -> MapGraph:
	return MapGraphScript.new()


func _test_start_at_origin() -> void:
	var graph: MapGraph = _graph()
	check_eq("start sits at the origin", MapLayoutScript.node_position(graph.get_node(0)), Vector2.ZERO)


func _test_branches_are_mirrored() -> void:
	var graph: MapGraph = _graph()
	var branch0: Vector2 = MapLayoutScript.node_position(graph.get_node(1))
	var branch1: Vector2 = MapLayoutScript.node_position(graph.get_node(5))
	check("branch 0 is on one side", branch0.x < 0.0)
	check("branch 1 is on the other side", branch1.x > 0.0)
	check("same step mirrors in x", is_equal_approx(-branch0.x, branch1.x))
	check("same step matches in y", is_equal_approx(branch0.y, branch1.y))


func _test_steps_move_away_from_start() -> void:
	var graph: MapGraph = _graph()
	var step0: Vector2 = MapLayoutScript.node_position(graph.get_node(1))
	var step1: Vector2 = MapLayoutScript.node_position(graph.get_node(2))
	var step3: Vector2 = MapLayoutScript.node_position(graph.get_node(4))
	check("step 1 is farther than step 0", step1.y > step0.y)
	check("step 3 is the farthest regular step", step3.y > step1.y)


func _test_boss_is_farthest_and_centred() -> void:
	var graph: MapGraph = _graph()
	var last_step: Vector2 = MapLayoutScript.node_position(graph.get_node(4))
	var boss: Vector2 = MapLayoutScript.node_position(graph.get_node(9))
	check("boss is farther than the last regular step", boss.y > last_step.y)
	check_eq("boss is centred", boss.x, 0.0)
