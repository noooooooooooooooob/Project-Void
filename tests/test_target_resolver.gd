# TargetResolver(근접 기준·기준 후보·범위·이동 칸 계산) 테스트.
extends TestCase

# 유닛 스크립트.
const UnitScript := preload("res://Scripts/combat/unit.gd")
# 대상 판정기 스크립트.
const ResolverScript := preload("res://Scripts/combat/target_resolver.gd")
# 공통 유닛 데이터 스크립트.
const UnitDataScript := preload("res://Scripts/combat/data/unit_data.gd")
# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 가운데 칸의 이동 후보 네 칸.
	_test_movable_cells_in_the_middle()
	# 모서리 칸의 이동 후보 두 칸.
	_test_movable_cells_at_a_corner()
	# 살아 있는 유닛 칸은 빼고 쓰러진 유닛 칸은 넣는다.
	_test_movable_cells_skip_living_units()
	# 자기 편 격자 크기 안에서만.
	_test_movable_cells_stay_in_own_grid()
	# 근접 기준: 같은 행 맨 앞.
	_test_melee_anchor_is_front_of_same_row()
	# 근접 기준: 행이 비면 없음, 쓰러진 유닛 무시.
	_test_melee_anchor_empty_row_and_dead()
	# 종류별 기준 후보.
	_test_valid_anchors_by_type()
	# 범위 칸: 격자 밖·중복 무시.
	_test_area_cells_clip_and_dedupe()
	# 범위 유닛: 같은 편·생존만.
	_test_units_in_area_same_team_alive()
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


# 아군 (0,1) 의 같은 행(1) 에 적 (2,1)·(1,1) 이 있으면 앞 열인 (1,1) 이 기준. 다른 행의 (0,0) 은 무관.
func _test_melee_anchor_is_front_of_same_row() -> void:
	# 판정기.
	var resolver := ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군.
	var ally: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 1))
	# 같은 행 뒤.
	var back: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(2, 1))
	# 같은 행 앞.
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(1, 1))
	# 다른 행 맨 앞.
	var other_row: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [ally, back, front, other_row]
	# 같은 행 맨 앞.
	check_eq("melee anchor is front of same row", resolver.melee_anchor(ally, units), front)


# 같은 행의 유일한 적이 쓰러져 있으면 기준이 없다.
func _test_melee_anchor_empty_row_and_dead() -> void:
	# 판정기.
	var resolver := ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 (0,2).
	var ally: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 2))
	# 같은 행의 쓰러진 적.
	var dead: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(0, 2))
	dead.hp = 0
	# 다른 행 적.
	var other: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [ally, dead, other]
	# 없음.
	check("no melee anchor when row has only dead", resolver.melee_anchor(ally, units) == null)
	# 근접 카드의 후보도 비어 있다.
	check("melee valid_anchors empty", resolver.valid_anchors(ally, Fixtures.damage_card(&"m", CardData.AttackType.MELEE, 50), units).is_empty())


# 원거리 = 살아 있는 적 전부, 아군 = 살아 있는 아군 전부(자신 포함), 자신 = [사용자].
func _test_valid_anchors_by_type() -> void:
	# 판정기.
	var resolver := ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 사용자.
	var me: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 0))
	# 다른 아군.
	var friend: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 적 둘 (하나는 쓰러짐).
	var foe: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 2))
	var dead_foe: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 1))
	dead_foe.hp = 0
	# 전장.
	var units: Array[Unit] = [me, friend, foe, dead_foe]
	# 원거리.
	check_eq("ranged anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"r", CardData.AttackType.RANGED, 1), units), [foe])
	# 아군.
	check_eq("ally anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"a", CardData.AttackType.ALLY, 1), units), [me, friend])
	# 자신.
	check_eq("self anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"s", CardData.AttackType.SELF, 1), units), [me])


# (2,0) 기준 [(0,0),(1,0),(0,-1),(0,0)] → (2,0) 만 남는다 (뒤쪽·위쪽은 격자 밖, 중복 제거).
func _test_area_cells_clip_and_dedupe() -> void:
	# 판정기.
	var resolver := ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 범위.
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 0)]
	# 결과.
	check_eq("area cells clipped and deduped", resolver.area_cells(Vector2i(2, 0), area, Vector2i(3, 3)), [Vector2i(2, 0)])


# 기준 적 (0,1) + 세로 3칸: 같은 편 살아 있는 (0,1)·(0,0) 만. 쓰러진 (0,2) 와 같은 좌표의 아군은 제외.
func _test_units_in_area_same_team_alive() -> void:
	# 판정기.
	var resolver := ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 기준 적.
	var anchor: Unit = _unit(0, Unit.Team.ENEMY, Vector2i(0, 1))
	# 위 적.
	var above: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(0, 0))
	# 아래 쓰러진 적.
	var below: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	below.hp = 0
	# 같은 좌표의 아군.
	var ally: Unit = _unit(3, Unit.Team.ALLY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [anchor, above, below, ally]
	# 세로 범위.
	var area: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)]
	# 결과 (전장 순서).
	check_eq("units in area", resolver.units_in_area(anchor, area, units), [anchor, above])
