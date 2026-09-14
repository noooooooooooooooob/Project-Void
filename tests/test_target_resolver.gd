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
