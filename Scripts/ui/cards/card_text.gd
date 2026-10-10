## 카드 효과 문구와 공격 종류 배지 글자를 만드는 순수 함수 모음.
## 전투 카드(계산값)와 파티 화면 덱 목록(%)이 같은 함수를 쓴다.
class_name CardText
# RefCounted: 모든 함수가 static 이다.
extends RefCounted

## 효과 종류 → 이름.
const KIND_NAMES: Dictionary = {
	CardEffect.Kind.DAMAGE: "피해",
	CardEffect.Kind.BLOCK: "방어도",
	CardEffect.Kind.HEAL: "회복",
}
## 공격 종류 → 배지 글자.
const BADGES: Dictionary = {
	CardData.AttackType.MELEE: "근",
	CardData.AttackType.RANGED: "원",
	CardData.AttackType.ALLY: "아",
	CardData.AttackType.SELF: "자",
}


## 효과 문구. stats 가 있으면 계산된 수치(치명 미적용), 없으면 % 로 쓴다. 예: "피해 7 · 자신 방어도 4".
static func describe(card: CardData, stats: UnitData = null) -> String:
	# 효과별 조각.
	var parts: PackedStringArray = []
	# 효과마다.
	for effect in card.effects:
		# 수치 글자.
		var value: String = ("%d" % CardMath.amount(effect, stats)) if stats != null else ("%d%%" % effect.percent)
		# 자신 효과인데 카드가 자신 카드가 아니면 "자신 " 을 붙인다.
		var prefix: String = "자신 " if effect.target == CardEffect.Target.SELF and card.attack_type != CardData.AttackType.SELF else ""
		# 조각을 만든다.
		parts.append("%s%s %s" % [prefix, KIND_NAMES[effect.kind], value])
	# 가운뎃점으로 잇는다.
	return " · ".join(parts)


## 공격 종류 배지 글자 (근·원·아·자).
static func badge(attack_type: CardData.AttackType) -> String:
	# 사전에서 꺼낸다.
	return BADGES[attack_type]
