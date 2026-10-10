## 카드 효과 수치를 계산하는 순수 함수 모음. 규칙(BattleState)과 카드 문구(CardText)가 함께 쓴다.
class_name CardMath
# RefCounted: 모든 함수가 static 이라 객체를 만들 필요는 없다.
extends RefCounted


## 효과 종류의 기준 스탯 값. 방어도는 방어, 피해·회복은 공격.
static func base_stat(kind: CardEffect.Kind, stats: UnitData) -> int:
	# 방어도면 방어, 아니면 공격.
	return stats.defense if kind == CardEffect.Kind.BLOCK else stats.attack


## 효과 하나의 수치 = 내림(기준 스탯 × % / 100). % 가 0 이하면 0, 그 외에는 최소 1.
static func amount(effect: CardEffect, stats: UnitData) -> int:
	# 0% 이하는 적용하지 않는다.
	if effect.percent <= 0:
		return 0
	# 내림하고 최소 1 로 막는다.
	return maxi(1, floori(float(base_stat(effect.kind, stats) * effect.percent) / 100.0))


## 이번 타격이 치명타인지 판정한다. 0 이하·100 이상이면 난수를 쓰지 않는다 (시드 재현성 유지).
static func rolls_crit(stats: UnitData, rng: RandomNumberGenerator) -> bool:
	# 확률 0 이하면 절대 아님.
	if stats.crit_chance <= 0:
		return false
	# 100 이상이면 항상.
	if stats.crit_chance >= 100:
		return true
	# 1~100 중 확률 이하가 나오면 치명.
	return rng.randi_range(1, 100) <= stats.crit_chance


## 치명타 피해 = 내림(수치 × 치명피해 / 100).
static func critical_amount(amount: int, stats: UnitData) -> int:
	# 배율을 곱해 내림한다.
	return floori(float(amount * stats.crit_damage) / 100.0)
