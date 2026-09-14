# BoardLayout(칸 좌표 → 3D 위치 계산) 테스트.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 아군 왼쪽, 적군 오른쪽 대칭.
	_test_sides_are_mirrored()
	# 0 열이 가운데 틈에 가장 가깝다.
	_test_col_zero_is_nearest_the_gap()
	# 행은 화면 안쪽(z) 방향.
	_test_rows_go_into_the_screen()
	# 행 수가 짝수인 격자는 반 칸 어긋난다.
	_test_odd_even_rows_sit_half_a_cell_apart()
	# 보드 경계·크기.
	_test_bounds()
	# 카메라 거리 계산.
	_test_camera_distance()
	# 결과를 돌려준다.
	return results()


# 같은 칸 좌표면 아군은 -x, 적군은 +x 에 거울처럼 놓이고, 높이는 0 인지.
func _test_sides_are_mirrored() -> void:
	# 양쪽 3×3 격자.
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 앞줄 가운데 칸.
	var ally: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))
	# 적군 앞줄 가운데 칸.
	var enemy: Vector3 = layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 1))
	# 아군은 왼쪽.
	check("ally is on the left", ally.x < 0.0)
	# 적군은 오른쪽.
	check("enemy is on the right", enemy.x > 0.0)
	# 좌우 거리가 같다.
	check("same column mirrors", is_equal_approx(-ally.x, enemy.x))
	# 앞줄 중심 x = 틈 절반 0.75 + 칸 절반 0.55 = 1.3.
	check("front column centre", is_equal_approx(enemy.x, 1.3))
	# 타일 윗면(바닥) 높이 0.
	check_eq("tile top is the floor", ally.y, 0.0)


# 0 열(앞줄)이 2 열(뒷줄)보다 가운데에 가깝고, 두 열 사이는 칸 간격 2 개(2.2)인지.
func _test_col_zero_is_nearest_the_gap() -> void:
	# 양쪽 3×3 격자.
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 앞줄.
	var front: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1))
	# 아군 뒷줄.
	var back: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(2, 1))
	# 앞줄이 가운데에 더 가깝다.
	check("col 0 is closer to the centre than col 2", absf(front.x) < absf(back.x))
	# 거리 차이 1.1 × 2.
	check("columns are one pitch apart", is_equal_approx(absf(back.x) - absf(front.x), 2.2))


# 0 행이 카메라에서 더 멀고(z 가 작음), 가운데 행이 z = 0 인지.
func _test_rows_go_into_the_screen() -> void:
	# 양쪽 3×3 격자.
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(3, 3))
	# 0 행.
	var far: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 0))
	# 2 행.
	var near: Vector3 = layout.cell_position(Unit.Team.ALLY, Vector2i(0, 2))
	# 0 행이 더 안쪽(카메라에서 멀리).
	check("row 0 is farther from the camera", far.z < near.z)
	# 1 행은 가운데.
	check("middle row is centred", is_equal_approx(layout.cell_position(Unit.Team.ALLY, Vector2i(0, 1)).z, 0.0))


# 2 행 격자는 가운데 기준 ±0.5 칸(±0.55) 에 놓여 3 행 격자와 반 칸 어긋나는지.
func _test_odd_even_rows_sit_half_a_cell_apart() -> void:
	# 아군 3×3, 적군 2×2.
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2))
	# 적 0 행은 -0.55.
	check("2-row side row 0", is_equal_approx(layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 0)).z, -0.55))
	# 적 1 행은 +0.55.
	check("2-row side row 1", is_equal_approx(layout.cell_position(Unit.Team.ENEMY, Vector2i(0, 1)).z, 0.55))


# 보드 왼쪽·오른쪽 끝, 폭, 깊이, 중심을 손으로 계산한 값과 비교한다.
func _test_bounds() -> void:
	# 아군 3×3, 적군 2×2.
	var layout := BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2))
	# -(0.75 + 3 × 1.1) = -4.05.
	check("left edge", is_equal_approx(layout.min_x(), -4.05))
	# 0.75 + 2 × 1.1 = 2.95.
	check("right edge", is_equal_approx(layout.max_x(), 2.95))
	# 2.95 - (-4.05) = 7.0.
	check("width", is_equal_approx(layout.width(), 7.0))
	# 행이 많은 쪽 3 × 1.1 = 3.3.
	check("depth uses the taller side", is_equal_approx(layout.depth(), 3.3))
	# (-4.05 + 2.95) / 2 = -0.55.
	check("centre x", is_equal_approx(layout.center().x, -0.55))


# 카메라 거리: 정확한 기준값 하나와, 보드가 넓거나 깊어지면 멀어지는지.
func _test_camera_distance() -> void:
	# 가로 시야 90° (세로 90°, 가로세로비 1) 에서 폭 2 를 딱 담는 거리는 1 이다.
	check("fits width exactly", is_equal_approx(BoardLayout.camera_distance(2.0, 0.0, 90.0, 1.0, 1.0), 1.0))
	# 폭 4 보드의 거리.
	var narrow: float = BoardLayout.camera_distance(4.0, 2.0, 40.0, 16.0 / 9.0, 1.2)
	# 폭 8 보드의 거리.
	var wide: float = BoardLayout.camera_distance(8.0, 2.0, 40.0, 16.0 / 9.0, 1.2)
	# 넓을수록 멀다.
	check("wider board needs a farther camera", wide > narrow)
	# 폭은 좁고 깊이만 깊은 보드의 거리.
	var deep: float = BoardLayout.camera_distance(1.0, 6.0, 40.0, 16.0 / 9.0, 1.2)
	# 깊이 0 인 같은 폭 보드보다 멀다 (깊이가 거리를 정한다).
	check("a deep narrow board is framed by depth", deep > BoardLayout.camera_distance(1.0, 0.0, 40.0, 16.0 / 9.0, 1.2))
