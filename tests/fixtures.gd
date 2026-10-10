# 테스트 공용 데이터 생성 함수 (새 카드·효과 형식). class_name 없이 preload 해서 쓴다.
extends RefCounted

# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 카드 효과 스크립트.
const CardEffectScript := preload("res://Scripts/combat/data/card_effect.gd")


# 종류·%·대상으로 효과 하나를 만든다 (target 0 = AREA, 1 = SELF).
static func effect(kind: int, percent: int, target: int = 0) -> CardEffect:
	# 빈 효과.
	var made: CardEffect = CardEffectScript.new()
	# 종류.
	made.kind = kind
	# 계수.
	made.percent = percent
	# 대상.
	made.target = target
	# 돌려준다.
	return made


# 공격 종류·효과 목록·범위·비용으로 카드를 만든다. 이름은 id 와 같다.
static func card(id: StringName, attack_type: int, effects: Array[CardEffect], area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	# 빈 카드.
	var made: CardData = CardDataScript.new()
	# id.
	made.id = id
	# 이름.
	made.display_name = String(id)
	# 비용.
	made.sp_cost = cost
	# 공격 종류.
	made.attack_type = attack_type
	# 효과 목록.
	made.effects = effects
	# 범위.
	made.area = area
	# 돌려준다.
	return made


# 범위 대상 피해 효과 하나짜리 카드.
static func damage_card(id: StringName, attack_type: int, percent: int, area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	# 효과 목록.
	var effects: Array[CardEffect] = [effect(CardEffect.Kind.DAMAGE, percent)]
	# 카드를 만든다.
	return card(id, attack_type, effects, area, cost)
