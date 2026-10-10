# CardText: % 표기, 계산값 표기, 자신 접두어, 배지 글자.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# % 표기.
	_test_percent_text()
	# 계산값 표기.
	_test_computed_text()
	# 자신 카드는 "자신" 을 붙이지 않는다.
	_test_self_card_has_no_prefix()
	# 배지.
	_test_badges()
	# 결과를 돌려준다.
	return results()


# 피해 80% + 자신 방어도 50% 근접 카드.
func _combo() -> CardData:
	# 효과 목록.
	var effects: Array[CardEffect] = [
		Fixtures.effect(CardEffect.Kind.DAMAGE, 80),
		Fixtures.effect(CardEffect.Kind.BLOCK, 50, CardEffect.Target.SELF),
	]
	# 근접 카드.
	return Fixtures.card(&"combo", CardData.AttackType.MELEE, effects)


# 스탯 없이 부르면 % 로.
func _test_percent_text() -> void:
	# 문구.
	check_eq("percent text", CardText.describe(_combo()), "피해 80% · 자신 방어도 50%")


# 공격 9·방어 8 이면 피해 7, 방어도 4.
func _test_computed_text() -> void:
	# 스탯.
	var stats: AllyData = AllyDataScript.new()
	# 공격.
	stats.attack = 9
	# 방어.
	stats.defense = 8
	# 문구.
	check_eq("computed text", CardText.describe(_combo(), stats), "피해 7 · 자신 방어도 4")


# 자신 카드의 SELF 효과에는 접두어가 없다.
func _test_self_card_has_no_prefix() -> void:
	# 자신 회복 카드.
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.HEAL, 30, CardEffect.Target.SELF)]
	var card: CardData = Fixtures.card(&"rest", CardData.AttackType.SELF, effects)
	# 문구.
	check_eq("self card text", CardText.describe(card), "회복 30%")


# 공격 종류 배지.
func _test_badges() -> void:
	# 네 종류.
	check_eq("badges", [CardText.badge(CardData.AttackType.MELEE), CardText.badge(CardData.AttackType.RANGED), CardText.badge(CardData.AttackType.ALLY), CardText.badge(CardData.AttackType.SELF)], ["근", "원", "아", "자"])
