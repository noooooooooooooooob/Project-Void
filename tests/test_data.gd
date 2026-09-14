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
	# 시작 카드 파일.
	_test_starter_cards_exist()
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
