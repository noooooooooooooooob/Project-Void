extends TestCase

const MapNodeScript := preload("res://Scripts/map/map_node.gd")
const MapLayoutScript := preload("res://Scripts/map/map_layout.gd")
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")


func run() -> Array[Dictionary]:
	_test_start_centres_on_x_and_sits_at_y_zero()
	_test_columns_spread_around_centre()
	_test_rows_move_away_from_start()
	_test_boss_is_farthest_and_centred()
	return results()


func _test_start_centres_on_x_and_sits_at_y_zero() -> void:
	var start := MapNodeScript.new(0, -1, MapGraphScript.COLS / 2, false)
	var pos: Vector2 = MapLayoutScript.node_position(start)
	check_eq("start centres on x", pos.x, 0.0)
	check_eq("start sits at y 0", pos.y, 0.0)


func _test_columns_spread_around_centre() -> void:
	var center_col: int = MapGraphScript.COLS / 2
	var centre := MapNodeScript.new(1, 0, center_col, false)
	var left := MapNodeScript.new(2, 0, center_col - 1, false)
	var right := MapNodeScript.new(3, 0, center_col + 1, false)
	check_eq("centre column sits on the axis", MapLayoutScript.node_position(centre).x, 0.0)
	check("one column left of centre sits left", MapLayoutScript.node_position(left).x < 0.0)
	check("one column right of centre sits right", MapLayoutScript.node_position(right).x > 0.0)


func _test_rows_move_away_from_start() -> void:
	var row0 := MapNodeScript.new(1, 0, 0, false)
	var row1 := MapNodeScript.new(2, 1, 0, false)
	check("row 1 is farther than row 0", MapLayoutScript.node_position(row1).y > MapLayoutScript.node_position(row0).y)


func _test_boss_is_farthest_and_centred() -> void:
	var last_row := MapNodeScript.new(1, MapGraphScript.ROWS - 1, 0, false)
	var boss := MapNodeScript.new(2, MapGraphScript.ROWS, MapGraphScript.COLS / 2, true)
	check("boss is farther than the last regular row", MapLayoutScript.node_position(boss).y > MapLayoutScript.node_position(last_row).y)
	check_eq("boss is centred", MapLayoutScript.node_position(boss).x, 0.0)
