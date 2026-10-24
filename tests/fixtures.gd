# 테스트 공용 데이터 생성 함수 (새 카드·효과 형식). class_name 없이 preload 해서 쓴다.
extends RefCounted

# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 카드 효과 스크립트.
const CardEffectScript := preload("res://Scripts/combat/data/card_effect.gd")


# 종류·%·대상으로 효과 하나를 만든다 (target 0 = AREA, 1 = SELF).
static func effect(kind: int, percent: int, target: int = 0) -> CardEffect:
	var made: CardEffect = CardEffectScript.new()
	made.kind = kind
	made.percent = percent
	made.target = target
	return made


# 공격 종류·효과 목록·범위·비용으로 카드를 만든다. 이름은 id 와 같다.
static func card(id: StringName, attack_type: int, effects: Array[CardEffect], area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	var made: CardData = CardDataScript.new()
	# id.
	made.id = id
	made.display_name = String(id)
	made.sp_cost = cost
	made.attack_type = attack_type
	made.effects = effects
	made.area = area
	return made


# 범위 대상 피해 효과 하나짜리 카드.
static func damage_card(id: StringName, attack_type: int, percent: int, area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	var effects: Array[CardEffect] = [effect(CardEffect.Kind.DAMAGE, percent)]
	return card(id, attack_type, effects, area, cost)


# 적 데이터에 공격 카드와 자신 방어도·자신 회복 카드를 단다 (% 가 0 이하면 그 카드는 비워 둔다).
static func enemy_cards(enemy: EnemyData, attack: CardData, block_percent: int, heal_percent: int) -> void:
	enemy.attack_card = attack
	# 방어 카드 (자신 방어도).
	var block_effects: Array[CardEffect] = [effect(CardEffect.Kind.BLOCK, block_percent, CardEffect.Target.SELF)]
	enemy.defend_card = null if block_percent <= 0 else card(&"defend", CardData.AttackType.SELF, block_effects)
	# 휴식 카드 (자신 회복).
	var heal_effects: Array[CardEffect] = [effect(CardEffect.Kind.HEAL, heal_percent, CardEffect.Target.SELF)]
	enemy.rest_card = null if heal_percent <= 0 else card(&"rest", CardData.AttackType.SELF, heal_effects)
