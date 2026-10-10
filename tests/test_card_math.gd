# CardMath: 효과 수치(내림·최소 1·0%)와 치명 판정·배율, CardData 의 범위·조준 도우미.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")
# 아군 데이터 스크립트 (스탯을 담는 데 쓴다).
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 기준 스탯 선택.
	_test_base_stat_by_kind()
	# 내림과 최소 1.
	_test_amount_rounds_down_with_minimum_one()
	# 0% 는 0.
	_test_zero_percent_is_zero()
	# 치명 0%·100% 경계.
	_test_crit_bounds()
	# 치명 배율.
	_test_critical_amount()
	# 빈 범위는 단일.
	_test_empty_area_is_single()
	# 조준이 필요한 종류.
	_test_needs_aim()
	# 결과를 돌려준다.
	return results()


# 공격 13, 방어 7 인 스탯.
func _stats() -> AllyData:
	# 빈 데이터.
	var data: AllyData = AllyDataScript.new()
	# 공격.
	data.attack = 13
	# 방어.
	data.defense = 7
	# 돌려준다.
	return data


# 피해·회복은 공격, 방어도는 방어를 기준으로 한다.
func _test_base_stat_by_kind() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 피해 → 공격.
	check_eq("damage uses attack", CardMath.base_stat(CardEffect.Kind.DAMAGE, stats), 13)
	# 회복 → 공격.
	check_eq("heal uses attack", CardMath.base_stat(CardEffect.Kind.HEAL, stats), 13)
	# 방어도 → 방어.
	check_eq("block uses defense", CardMath.base_stat(CardEffect.Kind.BLOCK, stats), 7)


# 13 × 50% = 6.5 → 6, 7 × 10% = 0.7 → 최소 1.
func _test_amount_rounds_down_with_minimum_one() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 내림.
	check_eq("floor", CardMath.amount(Fixtures.effect(CardEffect.Kind.DAMAGE, 50), stats), 6)
	# 최소 1.
	check_eq("minimum one", CardMath.amount(Fixtures.effect(CardEffect.Kind.BLOCK, 10), stats), 1)


# 0% 효과는 0 이다 (적용하지 않는다는 뜻).
func _test_zero_percent_is_zero() -> void:
	# 0%.
	check_eq("zero percent", CardMath.amount(Fixtures.effect(CardEffect.Kind.DAMAGE, 0), _stats()), 0)


# 치명확률 0 은 절대 안 터지고 100 은 항상 터지며, 둘 다 난수를 쓰지 않는다.
func _test_crit_bounds() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 난수.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 7
	# 시작 상태.
	var state_before: int = rng.state
	# 0%.
	stats.crit_chance = 0
	check("0% never crits", not CardMath.rolls_crit(stats, rng))
	# 100%.
	stats.crit_chance = 100
	check("100% always crits", CardMath.rolls_crit(stats, rng))
	# 난수를 건드리지 않았다.
	check_eq("bounds use no randomness", rng.state, state_before)


# 7 × 175% = 12.25 → 12.
func _test_critical_amount() -> void:
	# 기본 치명피해 175.
	check_eq("critical amount", CardMath.critical_amount(7, AllyDataScript.new()), 12)


# area 가 비어 있으면 기준 칸 하나.
func _test_empty_area_is_single() -> void:
	# 빈 범위 카드.
	var card: CardData = Fixtures.damage_card(&"x", CardData.AttackType.RANGED, 100)
	# [(0,0)].
	check_eq("empty area is single", card.area_offsets(), [Vector2i.ZERO])


# 원거리·아군만 조준한다.
func _test_needs_aim() -> void:
	# 종류별.
	check("ranged aims", Fixtures.damage_card(&"a", CardData.AttackType.RANGED, 1).needs_aim())
	check("ally aims", Fixtures.damage_card(&"b", CardData.AttackType.ALLY, 1).needs_aim())
	check("melee auto", not Fixtures.damage_card(&"c", CardData.AttackType.MELEE, 1).needs_aim())
	check("self auto", not Fixtures.damage_card(&"d", CardData.AttackType.SELF, 1).needs_aim())
