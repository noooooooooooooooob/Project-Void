# TargetResolver(사거리·막힘·범위 계산) 테스트.
extends TestCase

# 유닛 스크립트.
const UnitScript := preload("res://Scripts/combat/unit.gd")
# 대상 판정기 스크립트.
const ResolverScript := preload("res://Scripts/combat/target_resolver.gd")
# 공통 유닛 데이터 스크립트.
const UnitDataScript := preload("res://Scripts/combat/data/unit_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 열 거리.
	_test_col_distance()
	# 같은 크기 격자의 행 거리.
	_test_row_distance_same_size()
	# 행 수가 다른 격자의 행 거리.
	_test_row_distance_different_size()
	# 홀수·짝수 행 격자의 반 칸 차이는 내림.
	_test_row_distance_odd_even_rounds_down()
	# 근접은 앞줄에 막힌다.
	_test_melee_blocked_by_front()
	# 앞줄이 쓰러지면 막힘이 풀린다.
	_test_melee_unblocked_after_front_dies()
	# 원거리는 막힘을 무시한다.
	_test_ranged_ignores_blocking()
	# 사거리 밖은 거절.
	_test_out_of_range_rejected()
	# 관통 범위.
	_test_expand_pierce()
	# 횡렬 범위.
	_test_expand_sweep()
	# 광역 2×2 범위.
	_test_expand_area()
	# 관통로 범위.
	_test_expand_line()
	# 빈 칸도 사거리 판정을 받을 수 있는지.
	_test_is_valid_cell_allows_empty_cell()
	# 빈 칸을 겨냥해도 범위 안의 다른 유닛은 맞는지.
	_test_expand_shape_cell_hits_neighbors_from_empty_anchor()
	# 범위 모양이 덮는 칸 목록에 빈 칸도 포함되고 격자 밖은 빠지는지.
	_test_shape_cells_includes_empty_cells_and_clips_to_grid()
	# 가운데 칸의 이동 후보 네 칸.
	_test_movable_cells_in_the_middle()
	# 모서리 칸의 이동 후보 두 칸.
	_test_movable_cells_at_a_corner()
	# 살아 있는 유닛 칸은 빼고 쓰러진 유닛 칸은 넣는다.
	_test_movable_cells_skip_living_units()
	# 자기 편 격자 크기 안에서만.
	_test_movable_cells_stay_in_own_grid()
	# 결과를 돌려준다.
	return results()


# 번호·편·칸·체력으로 테스트 유닛을 만든다.
func _unit(id: int, team: Unit.Team, cell: Vector2i, hp: int = 10) -> Unit:
	# 공통 데이터.
	var data: UnitData = UnitDataScript.new()
	# 최대 체력.
	data.max_hp = hp
	# 유닛을 만든다.
	return UnitScript.new(id, data, team, cell)


# 앞줄끼리는 거리 1, 적 뒷줄(열 2)까지는 0 + 1 + 2 = 3 인지.
func _test_col_distance() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 앞줄 가운데.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 앞줄 가운데.
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 거리 1.
	check_eq("front row vs front row is 1", resolver.reach(a, e), 1)

	# 적 뒷줄 가운데.
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	# 거리 3.
	check_eq("front vs enemy col2 is 3", resolver.reach(a, back), 3)


# 같은 3 행 격자에서 0 행과 2 행은 행 차이 2 가 더해져 1 + 2 = 3 인지.
func _test_row_distance_same_size() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 0 행.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	# 적 2 행.
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	# 거리 3.
	check_eq("two rows apart adds 2", resolver.reach(a, e), 3)


# 3 행 격자의 가운데(1 행)와 5 행 격자의 가운데(2 행)는 마주 보므로 거리 1, 한 행 벗어나면 2 인지.
func _test_row_distance_different_size() -> void:
	# 아군 3 행, 적 5 행.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 5))
	# 아군 가운데 행.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 가운데 행.
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	# 거리 1.
	check_eq("3-row centre faces 5-row centre", resolver.reach(a, e), 1)

	# 적 가운데에서 한 행 아래.
	var off: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 3))
	# 거리 2.
	check_eq("one row off centre adds 1", resolver.reach(a, off), 2)


# 3 행 vs 4 행: 반 칸(0.5) 차이는 내림해 0, 1.5 칸 차이는 내림해 1 이 되는지.
func _test_row_distance_odd_even_rounds_down() -> void:
	# 아군 3 행, 적 4 행.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 4))
	# 아군 가운데 행 (가운데 기준 0).
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 1 행 (가운데 기준 -0.5).
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 0.5 내림 0 → 거리 1.
	check_eq("half-cell offset counts as facing", resolver.reach(a, e), 1)

	# 적 3 행 (가운데 기준 +1.5).
	var far: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 3))
	# 1.5 내림 1 → 거리 2.
	check_eq("one and a half rows off rounds down to 1", resolver.reach(a, far), 2)


# 근접: 적 앞줄은 칠 수 있지만 같은 행 뒤의 적은 사거리가 충분해도 막히는지.
func _test_melee_blocked_by_front() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 공격자.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 앞줄.
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 같은 행 적 뒷줄.
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, front, back]
	# 앞줄은 사거리 1 로 칠 수 있다.
	check("front is reachable", resolver.is_valid_target(a, front, CardData.AttackType.MELEE, 1, all))
	# 뒷줄은 사거리 4 여도 막힌다.
	check("back is blocked", not resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


# 앞줄 적이 쓰러지면 뒷줄 적을 근접으로 칠 수 있게 되는지.
func _test_melee_unblocked_after_front_dies() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 공격자.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 앞줄.
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 적 뒷줄.
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, front, back]
	# 앞줄을 쓰러뜨린다.
	front.take_damage(999)
	# 이제 뒷줄을 칠 수 있다.
	check("dead front no longer blocks", resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


# 원거리는 앞줄이 살아 있어도 뒷줄을 칠 수 있는지.
func _test_ranged_ignores_blocking() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 공격자.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 적 앞줄.
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 적 뒷줄.
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, front, back]
	# 원거리 사거리 3 이면 뒷줄(거리 2)에 닿는다.
	check("ranged reaches behind the front", resolver.is_valid_target(a, back, CardData.AttackType.RANGED, 3, all))


# 거리 5 인 대상은 사거리 3 으로 칠 수 없는지.
func _test_out_of_range_rejected() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 앞줄 0 행.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	# 적 뒷줄 2 행: 0 + 1 + 2 + 2 = 5.
	var far: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 2))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, far]
	# 거절.
	check("reach 5 exceeds range 3", not resolver.is_valid_target(a, far, CardData.AttackType.RANGED, 3, all))


# 관통: 대상과 같은 행의 적만 맞고, 다른 행의 적과 공격자 편은 맞지 않는지.
func _test_expand_pierce() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 고른 대상 (1 행 앞줄).
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	# 같은 행 뒷줄.
	var same_row: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	# 다른 행.
	var other_row: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 2))
	# 같은 행 좌표지만 아군.
	var ally: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [ally, primary, same_row, other_row]
	# 관통으로 맞는 유닛들.
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.PIERCE, all)
	# 대상 + 같은 행 = 2 명.
	check_eq("pierce hits the whole row", hit.size(), 2)
	# 다른 행 제외.
	check("pierce excludes other rows", not hit.has(other_row))
	# 아군 제외.
	check("pierce never hits the attacker camp", not hit.has(ally))


# 횡렬: 대상과 같은 열의 적만 맞고 다른 열은 맞지 않는지.
func _test_expand_sweep() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 고른 대상 (앞줄 0 행).
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	# 같은 열 2 행.
	var same_col: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 2))
	# 다른 열.
	var other_col: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(1, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [primary, same_col, other_col]
	# 횡렬로 맞는 유닛들.
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.SWEEP, all)
	# 대상 + 같은 열 = 2 명.
	check_eq("sweep hits the whole column", hit.size(), 2)
	# 다른 열 제외.
	check("sweep excludes other columns", not hit.has(other_col))


# 광역: 대상 칸을 왼쪽 위로 삼는 2×2 블록 안의 적만 맞고, 블록 밖·아군은 맞지 않는지.
func _test_expand_area() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 고른 대상 (블록 왼쪽 위 모서리, (0,0)).
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	# 블록 안 오른쪽 (1,0).
	var right: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 0))
	# 블록 안 아래 (0,1).
	var below: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 1))
	# 블록 안 대각선 (1,1).
	var diagonal: Unit = _unit(5, Unit.Team.ENEMY, Vector2i(1, 1))
	# 블록 밖 (2,0).
	var outside: Unit = _unit(6, Unit.Team.ENEMY, Vector2i(2, 0))
	# 블록 안 좌표지만 아군.
	var ally: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [ally, primary, right, below, diagonal, outside]
	# 광역으로 맞는 유닛들.
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.AREA, all)
	# 대상 + 오른쪽 + 아래 + 대각선 = 4 명.
	check_eq("area hits the whole 2x2 block", hit.size(), 4)
	# 블록 밖 제외.
	check("area excludes cells outside the block", not hit.has(outside))
	# 아군 제외.
	check("area never hits the attacker camp", not hit.has(ally))


# 관통로: 대상과 같은 행에서 앞줄부터 대상 열까지만 맞고, 대상 뒤·다른 행은 맞지 않는지.
func _test_expand_line() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 고른 대상 (1 행, 1 열 — 중간).
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(1, 1))
	# 같은 행 앞줄 (길목).
	var front: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 1))
	# 같은 행 대상 뒤 (길 밖).
	var behind: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(2, 1))
	# 다른 행.
	var other_row: Unit = _unit(5, Unit.Team.ENEMY, Vector2i(0, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [primary, front, behind, other_row]
	# 관통로로 맞는 유닛들.
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.LINE, all)
	# 대상 + 앞줄 = 2 명.
	check_eq("line hits the path up to the target", hit.size(), 2)
	# 대상 뒤는 제외.
	check("line excludes cells behind the target", not hit.has(behind))
	# 다른 행 제외.
	check("line excludes other rows", not hit.has(other_row))


# 사거리 안의 빈 칸은 칠 수 있다고(true) 판정하고, 사거리 밖의 빈 칸은 거절하는지.
func _test_is_valid_cell_allows_empty_cell() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 공격자 (앞줄 0 행).
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	# 전장 유닛 목록 (공격자뿐 — 겨냥할 칸에는 아무도 없다).
	var all: Array[Unit] = [a]
	# 사거리 3 이면 거리 1 인 빈 칸(0,0)을 겨냥할 수 있다.
	check("empty cell in range is valid", resolver.is_valid_cell(a, Unit.Team.ENEMY, Vector2i(0, 0), CardData.AttackType.RANGED, 3, all))
	# 사거리 3 이면 거리 5 인 빈 칸(2,2)은 겨냥할 수 없다.
	check("empty cell out of range is invalid", not resolver.is_valid_cell(a, Unit.Team.ENEMY, Vector2i(2, 2), CardData.AttackType.RANGED, 3, all))


# 빈 칸을 겨냥한 광역 카드가 그 블록 안의 다른(실제로 서 있는) 유닛은 맞히는지.
func _test_expand_shape_cell_hits_neighbors_from_empty_anchor() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 겨냥한 칸(0,0)에는 아무도 없다. 블록 안(1,0)에만 적이 있다.
	var neighbor: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(1, 0))
	# 블록 밖(2,0)의 적은 맞지 않는다.
	var outside: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [neighbor, outside]
	# 빈 칸(0,0)을 광역으로 겨냥했을 때 맞는 유닛들.
	var hit: Array[Unit] = resolver.expand_shape_cell(Unit.Team.ENEMY, Vector2i(0, 0), CardData.Shape.AREA, all)
	# 블록 안의 이웃만 맞는다.
	check_eq("empty-anchored area still hits the neighbor", hit, [neighbor])


# shape_cells 가 관통(행 전체)·광역(2×2, 격자 밖은 클립)이 덮는 칸을 유닛 유무와 상관없이 모두 돌려주는지.
func _test_shape_cells_includes_empty_cells_and_clips_to_grid() -> void:
	# 3×3 격자.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 관통: 1 행을 겨냥하면 그 행의 세 칸(유닛 유무와 상관없이) 모두.
	var pierce_cells: Array[Vector2i] = resolver.shape_cells(Vector2i(1, 1), CardData.Shape.PIERCE, Vector2i(3, 3))
	var expected_pierce: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	check_eq("pierce covers the whole row regardless of units", pierce_cells, expected_pierce)

	# 광역: 격자 오른쪽 아래 모서리(2,2)를 겨냥하면 격자 밖으로 나가는 칸은 잘려서 한 칸만 남는다.
	var area_cells: Array[Vector2i] = resolver.shape_cells(Vector2i(2, 2), CardData.Shape.AREA, Vector2i(3, 3))
	var expected_area: Array[Vector2i] = [Vector2i(2, 2)]
	check_eq("area clips to the grid at a corner", area_cells, expected_area)


# 3×3 가운데(1,1) 유닛은 위·아래·앞·뒤 순서로 네 칸에 갈 수 있는지.
func _test_movable_cells_in_the_middle() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 가운데 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a]
	# 기대값: 위(1,0), 아래(1,2), 앞(0,1), 뒤(2,1) (타입 있는 배열끼리 비교한다).
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1)]
	# 순서까지 같다.
	check_eq("middle cell has four moves in fixed order", resolver.movable_cells(a, all), expected)


# 모서리(0,0) 유닛은 아래와 뒤 두 칸만 갈 수 있는지.
func _test_movable_cells_at_a_corner() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 모서리 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a]
	# 기대값: 아래(0,1), 뒤(1,0).
	var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0)]
	# 두 칸.
	check_eq("corner cell has two moves", resolver.movable_cells(a, all), expected)


# 같은 편 살아 있는 유닛 칸은 빠지고, 쓰러진 유닛 칸과 다른 편 같은 좌표는 막지 않는지.
func _test_movable_cells_skip_living_units() -> void:
	# 양쪽 3×3.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 가운데 아군.
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 위 칸의 살아 있는 아군.
	var blocker: Unit = _unit(2, Unit.Team.ALLY, Vector2i(1, 0))
	# 아래 칸의 쓰러진 아군.
	var fallen: Unit = _unit(3, Unit.Team.ALLY, Vector2i(1, 2))
	# 쓰러뜨린다.
	fallen.take_damage(999)
	# 앞 칸과 같은 좌표에 선 적 (다른 편 격자라 막지 않는다).
	var foe: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [a, blocker, fallen, foe]
	# 기대값: 위는 막히고 아래·앞·뒤는 열린다.
	var expected: Array[Vector2i] = [Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1)]
	# 비교.
	check_eq("living ally blocks, fallen ally and enemy side do not", resolver.movable_cells(a, all), expected)


# 적 격자가 2×2 이면 (1,1) 적은 위(1,0)와 앞(0,1)만 갈 수 있는지.
func _test_movable_cells_stay_in_own_grid() -> void:
	# 아군 3×3, 적군 2×2.
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(2, 2))
	# 적 격자 오른쪽 아래 칸의 적.
	var e: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(1, 1))
	# 전장 유닛 목록.
	var all: Array[Unit] = [e]
	# 기대값: 위(1,0)와 앞(0,1) — 아래(1,2)와 뒤(2,1)는 격자 밖.
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	# 비교.
	check_eq("moves stay inside the unit's own grid", resolver.movable_cells(e, all), expected)
