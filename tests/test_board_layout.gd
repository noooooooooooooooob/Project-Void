extends TestCase


func run() -> Array[Dictionary]:
	_test_sides_are_mirrored()
	_test_col_zero_is_nearest_the_gap()
	_test_rows_go_into_the_screen()
	_test_odd_even_rows_sit_half_a_cell_apart()
	_test_bounds()
	_test_camera_distance()
	return results()


func _test_sides_are_mirrored() -> void:
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	var ally: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))
	var enemy: Vector3 = layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 1))
	check("ally is on the left", ally.x < 0.0)
	check("enemy is on the right", enemy.x > 0.0)
	check("same column mirrors", is_equal_approx(-ally.x, enemy.x))
	check("front column centre", is_equal_approx(enemy.x, 1.3))
	check_eq("tile top is the floor", ally.y, 0.0)


func _test_col_zero_is_nearest_the_gap() -> void:
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	var front: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))
	var back: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(2, 1))
	check("col 0 is closer to the centre than col 2", absf(front.x) < absf(back.x))
	check("columns are one pitch apart", is_equal_approx(absf(back.x) - absf(front.x), 2.2))


func _test_rows_go_into_the_screen() -> void:
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	var far: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 0))
	var near: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 2))
	check("row 0 is farther from the camera", far.z < near.z)
	check("middle row is centred", is_equal_approx(layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1)).z, 0.0))


func _test_odd_even_rows_sit_half_a_cell_apart() -> void:
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2))
	check("2-row side row 0", is_equal_approx(layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 0)).z, -0.55))
	check("2-row side row 1", is_equal_approx(layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 1)).z, 0.55))


func _test_bounds() -> void:
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2))
	check("left edge", is_equal_approx(layout.min_x(), -4.05))
	check("right edge", is_equal_approx(layout.max_x(), 2.95))
	check("width", is_equal_approx(layout.width(), 7.0))
	check("depth uses the taller side", is_equal_approx(layout.depth(), 3.3))
	check("centre x", is_equal_approx(layout.center().x, -0.55))


func _test_camera_distance() -> void:
	# 가로 시야 90° (세로 90°, 가로세로비 1) 에서 폭 2 를 딱 담는 거리는 1 이다.
	check("fits width exactly", is_equal_approx(BoardLayout.camera_distance(2.0, 0.0, 90.0, 1.0, 1.0), 1.0))
	var narrow: float = BoardLayout.camera_distance(4.0, 2.0, 40.0, 16.0 / 9.0, 1.2)
	var wide: float = BoardLayout.camera_distance(8.0, 2.0, 40.0, 16.0 / 9.0, 1.2)
	check("wider board needs a farther camera", wide > narrow)
	var deep: float = BoardLayout.camera_distance(1.0, 6.0, 40.0, 16.0 / 9.0, 1.2)
	check("a deep narrow board is framed by depth", deep > BoardLayout.camera_distance(1.0, 0.0, 40.0, 16.0 / 9.0, 1.2))
