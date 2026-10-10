# 데이터 리소스(CardData, AllyData, EnemyData)와 시작 카드 .tres 파일 테스트.
extends TestCase

# 스크립트를 직접 불러와 new() 로 빈 리소스를 만든다.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 카드 기본값.
	_test_card_defaults()
	# 상속 관계.
	_test_ally_extends_unit_data()
	# 새 스탯 기본값.
	_test_unit_stat_defaults()
	# 시작 카드 파일.
	_test_starter_cards_exist()
	# 유닛 .tres 의 그림·띠·오라 연결 상태.
	_test_unit_art_links()
	# 전투 방 데이터와 연결.
	_test_rooms()
	# 결과를 돌려준다.
	return results()


# 새로 만든 카드의 기본값이 비용 1, 단일 범위인지.
func _test_card_defaults() -> void:
	# 빈 카드를 만든다.
	var card: CardData = CardDataScript.new()
	# 기본 비용 1.
	check_eq("card default sp_cost", card.sp_cost, 1)
	# 기본 범위 단일.
	check_eq("card default shape is SINGLE", card.shape, CardData.Shape.SINGLE)
	# 기본 분류는 공격.
	check_eq("card default category", card.category, CardData.Category.ATTACK)
	# 기본 효과 없음.
	check("card default effects empty", card.effects.is_empty())


# AllyData 와 EnemyData 가 모두 UnitData 를 상속하고, 서로는 다른 타입인지.
func _test_ally_extends_unit_data() -> void:
	# 빈 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# 빈 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# 아군 데이터는 UnitData.
	check("AllyData is a UnitData", ally is UnitData)
	# 적 데이터는 UnitData.
	check("EnemyData is a UnitData", enemy is UnitData)
	# Checked via the shared UnitData base: `ally is EnemyData` with ally
	# statically typed AllyData is a compile-time error in GDScript (the
	# types are provably unrelated siblings), not just a false runtime check.
	# (부모 타입 변수에 담아 비교해야 컴파일 오류 없이 실행 중 검사가 된다.)
	var ally_as_unit_data: UnitData = ally
	# 아군 데이터는 적 데이터가 아니다.
	check("AllyData is not EnemyData", not (ally_as_unit_data is EnemyData))


# 새 스탯 5종의 기본값이 Notion 캐릭터 양식과 맞는지.
func _test_unit_stat_defaults() -> void:
	# 빈 아군 데이터 (UnitData 의 기본값을 물려받는다).
	var data: AllyData = AllyDataScript.new()
	# 공격 10.
	check_eq("default attack", data.attack, 10)
	# 방어 10.
	check_eq("default defense", data.defense, 10)
	# 치명확률 1%.
	check_eq("default crit_chance", data.crit_chance, 1)
	# 치명피해 175%.
	check_eq("default crit_damage", data.crit_damage, 175)
	# 어그로 100.
	check_eq("default aggro", data.aggro, 100)


# 저장소의 시작 카드 파일이 불러와지고 값이 설계와 맞는지.
func _test_starter_cards_exist() -> void:
	# strike.tres 를 불러온다.
	var strike: CardData = load("res://Resources/cards/strike.tres")
	# 불러와졌는지.
	check("strike.tres loads", strike != null)
	# 못 불러왔으면 아래 검사는 오류가 나므로 멈춘다.
	if strike == null:
		return
	# id.
	check_eq("strike id", strike.id, &"strike")
	# 피해 6.
	check_eq("strike damage", strike.damage, 6)
	# 근접.
	check_eq("strike is melee", strike.attack_type, CardData.AttackType.MELEE)

	# volley.tres 를 불러온다.
	var volley: CardData = load("res://Resources/cards/volley.tres")
	# 불러와졌는지.
	check("volley.tres loads", volley != null)
	# 못 불러왔으면 멈춘다.
	if volley == null:
		return
	# 범위 횡렬.
	check_eq("volley shape is SWEEP", volley.shape, CardData.Shape.SWEEP)
	# 사거리 4.
	check_eq("volley range", volley.attack_range, 4)

	# blast.tres 를 불러온다 (광역 2×2 테스트용 카드).
	var blast: CardData = load("res://Resources/cards/blast.tres")
	# 불러와졌는지.
	check("blast.tres loads", blast != null)
	# 못 불러왔으면 멈춘다.
	if blast == null:
		return
	# 범위 광역.
	check_eq("blast shape is AREA", blast.shape, CardData.Shape.AREA)

	# skewer.tres 를 불러온다 (관통로 테스트용 카드).
	var skewer: CardData = load("res://Resources/cards/skewer.tres")
	# 불러와졌는지.
	check("skewer.tres loads", skewer != null)
	# 못 불러왔으면 멈춘다.
	if skewer == null:
		return
	# 범위 관통로.
	check_eq("skewer shape is LINE", skewer.shape, CardData.Shape.LINE)


# 유닛 6종이 유니티와 같은 그림·애니메이션 띠·오라를 가리키는지 (설계 §4.1 표).
func _test_unit_art_links() -> void:
	# id → [idle, attack, hit, aura] 가 있어야 하는지.
	var expected: Dictionary = {
		"vanguard": [true, true, true, false],
		"archer": [true, true, true, false],
		"scout": [true, true, true, false],
		"stalker": [true, true, true, false],
		"brute": [true, false, true, false],
		"sentry": [false, false, false, true],
	}
	# 유닛마다.
	for id in expected:
		# 데이터 파일을 불러온다.
		var data: UnitData = load("res://Resources/units/%s.tres" % id)
		# 기대값.
		var flags: Array = expected[id]
		# 정지 그림은 모두 있다.
		check("%s has a sprite" % id, data.sprite != null)
		# 대기 띠.
		check_eq("%s idle sheet" % id, data.idle_sheet != null, flags[0])
		# 공격 띠.
		check_eq("%s attack sheet" % id, data.attack_sheet != null, flags[1])
		# 피격 띠.
		check_eq("%s hit sheet" % id, data.hit_sheet != null, flags[2])
		# 오라.
		check_eq("%s aura" % id, data.aura_texture != null, flags[3])
	# 띠는 64px 프레임 16장이다.
	var vanguard: UnitData = load("res://Resources/units/vanguard.tres")
	# 폭 1024, 높이 64.
	check_eq("sheet is 16 frames of 64px", Vector2i(vanguard.idle_sheet.get_width(), vanguard.idle_sheet.get_height()), Vector2i(1024, 64))


# 창고 방이 텍스처 4장과 소품 9개를 갖고, skirmish 가 그 방을 가리키며, 옛 배경 필드는 없는지.
func _test_rooms() -> void:
	# 창고 방.
	var room: BattleRoomData = load("res://Resources/rooms/warehouse.tres")
	# 불러와짐.
	check("warehouse room loads", room != null)
	# 텍스처 4장.
	check("room textures set", room.ground_texture != null and room.wall_texture != null and room.ally_tile_texture != null and room.enemy_tile_texture != null)
	# 소품 9개.
	check_eq("warehouse props", room.props.size(), 9)
	# 첫 소품 (crates, 먼 쪽 왼편).
	check("first prop is the far-left crates", room.props[0].texture != null and room.props[0].position.is_equal_approx(Vector3(-5.8, 0.0, -2.7)) and is_equal_approx(room.props[0].height, 1.6))
	# skirmish.
	var skirmish: EncounterData = load("res://Resources/encounters/skirmish.tres")
	# 같은 방.
	check_eq("skirmish uses the warehouse room", skirmish.room.resource_path, "res://Resources/rooms/warehouse.tres")
	# 옛 배경 필드 제거.
	check("encounter has no background field", not ("background" in skirmish))
