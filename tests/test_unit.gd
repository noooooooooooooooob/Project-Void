# Unit(전투 중 유닛 상태) 테스트: 방어도·피해·회복, 드로우·리셔플·버리기, 적 유닛 기본값.
extends TestCase

# 유닛 스크립트.
const UnitScript := preload("res://Scripts/combat/unit.gd")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 방어도가 먼저 막는다.
	_test_block_absorbs_before_hp()
	# 방어도를 넘는 피해는 체력으로.
	_test_block_depletes()
	# 회복은 최대 체력까지.
	_test_heal_caps_at_max()
	# 드로우가 덱에서 손패로 옮긴다.
	_test_draw_moves_cards()
	# 덱이 비면 묘지를 섞어 이어 뽑는다.
	_test_draw_reshuffles_discard()
	# 덱·묘지가 다 비면 멈춘다.
	_test_draw_stops_when_both_empty()
	# 손패 버리기.
	_test_discard_hand()
	# 적은 덱·SP 가 없다.
	_test_enemy_has_no_zones()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수 생성기 (섞기 결과를 재현하기 위해).
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 돌려준다.
	return rng


# id 만 가진 테스트 카드.
func _card(id: StringName) -> CardData:
	# 빈 카드.
	var card: CardData = CardDataScript.new()
	# id 를 넣는다.
	card.id = id
	# 돌려준다.
	return card


# 체력 20, SP 3, 카드 deck_size 장을 가진 아군 유닛.
func _ally(deck_size: int) -> Unit:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# 최대 체력.
	data.max_hp = 20
	# 최대 SP.
	data.max_sp = 3
	# 덱 배열.
	var deck: Array[CardData] = []
	# c0, c1, ... 카드를 넣는다.
	for i in deck_size:
		deck.append(_card(StringName("c%d" % i)))
	# 데이터에 덱을 넣는다.
	data.deck = deck
	# 유닛을 만든다.
	return UnitScript.new(1, data, Unit.Team.ALLY, Vector2i(0, 0))


# 방어도 5 에 피해 3: 체력은 그대로, 방어도는 2 남는지.
func _test_block_absorbs_before_hp() -> void:
	# 유닛.
	var unit: Unit = _ally(0)
	# 방어도 5.
	unit.gain_block(5)
	# 피해 3.
	unit.take_damage(3)
	# 체력 20 그대로.
	check_eq("block absorbs damage, hp untouched", unit.hp, 20)
	# 방어도 2 남음.
	check_eq("block reduced by absorbed amount", unit.block, 2)


# 방어도 4 에 피해 10: 남은 6 이 체력에서 빠지고 방어도는 0 인지.
func _test_block_depletes() -> void:
	# 유닛.
	var unit: Unit = _ally(0)
	# 방어도 4.
	unit.gain_block(4)
	# 피해 10.
	unit.take_damage(10)
	# 체력 20 - 6 = 14.
	check_eq("leftover damage hits hp", unit.hp, 14)
	# 방어도 0.
	check_eq("block fully spent", unit.block, 0)


# 회복량이 커도 최대 체력을 넘지 않는지.
func _test_heal_caps_at_max() -> void:
	# 유닛.
	var unit: Unit = _ally(0)
	# 체력 15 로.
	unit.take_damage(5)
	# 크게 회복.
	unit.heal(100)
	# 20 에서 멈춘다.
	check_eq("heal does not exceed max_hp", unit.hp, 20)


# 덱 6 장에서 4 장 뽑으면 손패 4, 덱 2 인지.
func _test_draw_moves_cards() -> void:
	# 덱 6 장 유닛.
	var unit: Unit = _ally(6)
	# 4 장 뽑기.
	unit.draw(4, _rng(1))
	# 손패 4.
	check_eq("hand has 4", unit.hand.size(), 4)
	# 덱 2.
	check_eq("deck has 2 left", unit.deck.size(), 2)


# 덱 3 장을 모두 뽑아 버린 뒤 2 장 뽑으면 묘지를 섞어 덱으로 만들고 뽑는지.
func _test_draw_reshuffles_discard() -> void:
	# 덱 3 장 유닛.
	var unit: Unit = _ally(3)
	# 3 장 모두 뽑는다.
	unit.draw(3, _rng(1))
	# 손패를 버린다.
	unit.discard_hand()
	# 묘지 3.
	check_eq("discard holds 3 before redraw", unit.discard.size(), 3)
	# 덱이 빈 상태에서 2 장 뽑는다.
	unit.draw(2, _rng(1))
	# 손패 2.
	check_eq("redraw pulls from reshuffled deck", unit.hand.size(), 2)
	# 묘지는 섞여서 비었다.
	check_eq("discard emptied by reshuffle", unit.discard.size(), 0)
	# 덱에 1 장 남는다.
	check_eq("deck keeps the remainder", unit.deck.size(), 1)


# 덱 2 장, 묘지 0 장에서 5 장 뽑으려 하면 2 장만 뽑는지.
func _test_draw_stops_when_both_empty() -> void:
	# 덱 2 장 유닛.
	var unit: Unit = _ally(2)
	# 5 장 뽑기 시도.
	unit.draw(5, _rng(1))
	# 있는 만큼만.
	check_eq("draws only what exists", unit.hand.size(), 2)


# 손패 4 장을 버리면 손패 0, 묘지 4 인지.
func _test_discard_hand() -> void:
	# 덱 4 장 유닛.
	var unit: Unit = _ally(4)
	# 모두 뽑는다.
	unit.draw(4, _rng(1))
	# 버린다.
	unit.discard_hand()
	# 손패 0.
	check_eq("hand cleared", unit.hand.size(), 0)
	# 묘지 4.
	check_eq("all cards moved to discard", unit.discard.size(), 4)


# 적 데이터로 만든 유닛은 덱이 비어 있고 SP 가 0 이며 아군이 아닌지.
func _test_enemy_has_no_zones() -> void:
	# 적 데이터.
	var data: EnemyData = EnemyDataScript.new()
	# 최대 체력.
	data.max_hp = 15
	# 적 유닛.
	var unit: Unit = UnitScript.new(2, data, Unit.Team.ENEMY, Vector2i(0, 0))
	# 덱 없음.
	check_eq("enemy deck empty", unit.deck.size(), 0)
	# SP 0.
	check_eq("enemy sp zero", unit.sp, 0)
	# 아군 아님.
	check("enemy is not ally", not unit.is_ally())
