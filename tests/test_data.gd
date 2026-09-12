extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


func run() -> Array[Dictionary]:
	_test_card_defaults()
	_test_ally_extends_unit_data()
	_test_starter_cards_exist()
	return results()


func _test_card_defaults() -> void:
	var card: CardData = CardDataScript.new()
	check_eq("card default sp_cost", card.sp_cost, 1)
	check_eq("card default shape is SINGLE", card.shape, CardData.Shape.SINGLE)


func _test_ally_extends_unit_data() -> void:
	var ally: AllyData = AllyDataScript.new()
	var enemy: EnemyData = EnemyDataScript.new()
	check("AllyData is a UnitData", ally is UnitData)
	check("EnemyData is a UnitData", enemy is UnitData)
	# Checked via the shared UnitData base: `ally is EnemyData` with ally
	# statically typed AllyData is a compile-time error in GDScript (the
	# types are provably unrelated siblings), not just a false runtime check.
	var ally_as_unit_data: UnitData = ally
	check("AllyData is not EnemyData", not (ally_as_unit_data is EnemyData))


func _test_starter_cards_exist() -> void:
	var strike: CardData = load("res://Resources/cards/strike.tres")
	check("strike.tres loads", strike != null)
	if strike == null:
		return
	check_eq("strike id", strike.id, &"strike")
	check_eq("strike damage", strike.damage, 6)
	check_eq("strike is melee", strike.attack_type, CardData.AttackType.MELEE)

	var volley: CardData = load("res://Resources/cards/volley.tres")
	check("volley.tres loads", volley != null)
	if volley == null:
		return
	check_eq("volley shape is SWEEP", volley.shape, CardData.Shape.SWEEP)
	check_eq("volley range", volley.attack_range, 4)
