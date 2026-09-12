extends TestCase

const UnitScript := preload("res://Scripts/combat/unit.gd")
const ResolverScript := preload("res://Scripts/combat/target_resolver.gd")
const UnitDataScript := preload("res://Scripts/combat/data/unit_data.gd")


func run() -> Array[Dictionary]:
	_test_col_distance()
	_test_row_distance_same_size()
	_test_row_distance_different_size()
	_test_row_distance_odd_even_rounds_up()
	_test_melee_blocked_by_front()
	_test_melee_unblocked_after_front_dies()
	_test_ranged_ignores_blocking()
	_test_out_of_range_rejected()
	_test_expand_pierce()
	_test_expand_sweep()
	return results()


func _unit(id: int, team: Unit.Team, cell: Vector2i, hp: int = 10) -> Unit:
	var data: UnitData = UnitDataScript.new()
	data.max_hp = hp
	return UnitScript.new(id, data, team, cell)


func _test_col_distance() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	check_eq("front row vs front row is 1", resolver.reach(a, e), 1)

	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	check_eq("front vs enemy col2 is 3", resolver.reach(a, back), 3)


func _test_row_distance_same_size() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	check_eq("two rows apart adds 2", resolver.reach(a, e), 3)


func _test_row_distance_different_size() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 5))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	check_eq("3-row centre faces 5-row centre", resolver.reach(a, e), 1)

	var off: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 3))
	check_eq("one row off centre adds 1", resolver.reach(a, off), 2)


func _test_row_distance_odd_even_rounds_up() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 4))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	check_eq("half-cell offset rounds up to 1", resolver.reach(a, e), 2)


func _test_melee_blocked_by_front() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	check("front is reachable", resolver.is_valid_target(a, front, CardData.AttackType.MELEE, 1, all))
	check("back is blocked", not resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


func _test_melee_unblocked_after_front_dies() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	front.take_damage(999)
	check("dead front no longer blocks", resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


func _test_ranged_ignores_blocking() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	check("ranged reaches behind the front", resolver.is_valid_target(a, back, CardData.AttackType.RANGED, 3, all))


func _test_out_of_range_rejected() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	var far: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 2))
	var all: Array[Unit] = [a, far]
	check("reach 5 exceeds range 3", not resolver.is_valid_target(a, far, CardData.AttackType.RANGED, 3, all))


func _test_expand_pierce() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var same_row: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	var other_row: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 2))
	var ally: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var all: Array[Unit] = [ally, primary, same_row, other_row]
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.PIERCE, all)
	check_eq("pierce hits the whole row", hit.size(), 2)
	check("pierce excludes other rows", not hit.has(other_row))
	check("pierce never hits the attacker camp", not hit.has(ally))


func _test_expand_sweep() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	var same_col: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 2))
	var other_col: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(1, 0))
	var all: Array[Unit] = [primary, same_col, other_col]
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.SWEEP, all)
	check_eq("sweep hits the whole column", hit.size(), 2)
	check("sweep excludes other columns", not hit.has(other_col))
