extends TestCase

const UnitScript := preload("res://Scripts/combat/unit.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


func run() -> Array[Dictionary]:
	_test_block_absorbs_before_hp()
	_test_block_depletes()
	_test_heal_caps_at_max()
	_test_draw_moves_cards()
	_test_draw_reshuffles_discard()
	_test_draw_stops_when_both_empty()
	_test_discard_hand()
	_test_enemy_has_no_zones()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _card(id: StringName) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	return card


func _ally(deck_size: int) -> Unit:
	var data: AllyData = AllyDataScript.new()
	data.max_hp = 20
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		deck.append(_card(StringName("c%d" % i)))
	data.deck = deck
	return UnitScript.new(1, data, Unit.Team.ALLY, Vector2i(0, 0))


func _test_block_absorbs_before_hp() -> void:
	var unit: Unit = _ally(0)
	unit.gain_block(5)
	unit.take_damage(3)
	check_eq("block absorbs damage, hp untouched", unit.hp, 20)
	check_eq("block reduced by absorbed amount", unit.block, 2)


func _test_block_depletes() -> void:
	var unit: Unit = _ally(0)
	unit.gain_block(4)
	unit.take_damage(10)
	check_eq("leftover damage hits hp", unit.hp, 14)
	check_eq("block fully spent", unit.block, 0)


func _test_heal_caps_at_max() -> void:
	var unit: Unit = _ally(0)
	unit.take_damage(5)
	unit.heal(100)
	check_eq("heal does not exceed max_hp", unit.hp, 20)


func _test_draw_moves_cards() -> void:
	var unit: Unit = _ally(6)
	unit.draw(4, _rng(1))
	check_eq("hand has 4", unit.hand.size(), 4)
	check_eq("deck has 2 left", unit.deck.size(), 2)


func _test_draw_reshuffles_discard() -> void:
	var unit: Unit = _ally(3)
	unit.draw(3, _rng(1))
	unit.discard_hand()
	check_eq("discard holds 3 before redraw", unit.discard.size(), 3)
	unit.draw(2, _rng(1))
	check_eq("redraw pulls from reshuffled deck", unit.hand.size(), 2)
	check_eq("discard emptied by reshuffle", unit.discard.size(), 0)
	check_eq("deck keeps the remainder", unit.deck.size(), 1)


func _test_draw_stops_when_both_empty() -> void:
	var unit: Unit = _ally(2)
	unit.draw(5, _rng(1))
	check_eq("draws only what exists", unit.hand.size(), 2)


func _test_discard_hand() -> void:
	var unit: Unit = _ally(4)
	unit.draw(4, _rng(1))
	unit.discard_hand()
	check_eq("hand cleared", unit.hand.size(), 0)
	check_eq("all cards moved to discard", unit.discard.size(), 4)


func _test_enemy_has_no_zones() -> void:
	var data: EnemyData = EnemyDataScript.new()
	data.max_hp = 15
	var unit: Unit = UnitScript.new(2, data, Unit.Team.ENEMY, Vector2i(0, 0))
	check_eq("enemy deck empty", unit.deck.size(), 0)
	check_eq("enemy sp zero", unit.sp, 0)
	check("enemy is not ally", not unit.is_ally())
