# 흐트러짐(기절·탈진)과 상태 스택(혈갑), 홍연 패시브(혈갑·피의 갈망), 새 카드 효과(상태 획득·폭발·체력 소모·흐트러짐) 테스트.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_damage_drains_stagger_even_when_blocked()
	_test_enemy_breaks_and_skips_its_next_turn()
	_test_broken_ally_is_exhausted_and_skips()
	_test_stagger_effect_only_drains_the_gauge()
	_test_gain_status_adds_and_caps_blood_armor()
	_test_blood_armor_passive_grants_block_each_turn()
	_test_blood_thirst_gains_armor_on_hp_loss_only()
	_test_blood_thirst_gains_armor_on_kill()
	_test_burst_consumes_stacks_for_damage()
	_test_burst_without_stacks_does_nothing()
	_test_hp_cost_never_kills_and_feeds_blood_thirst()
	_test_card_text_describes_new_effects()
	return results()


# 효과 하나를 만든다.
func _effect(kind: CardEffect.Kind, percent: int = 100, value: int = 0, status: StringName = &"", target: CardEffect.Target = CardEffect.Target.AREA) -> CardEffect:
	var effect := CardEffect.new()
	effect.kind = kind
	effect.percent = percent
	effect.value = value
	effect.status = status
	effect.target = target
	return effect


# 카드를 만든다 (SP 0 이라 여러 번 쓸 수 있다).
func _card(id: StringName, attack_type: CardData.AttackType, effects: Array[CardEffect]) -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = String(id)
	card.sp_cost = 0
	card.attack_type = attack_type
	card.effects = effects
	return card


# 아군 a(속도 10, 공격 10, 치명 없음)와 적 e(속도 1)의 전투. a 의 손패에 cards 를 그대로 넣고 a 차례에서 멈춘 상태를 돌려준다.
func _battle(cards: Array[CardData], ally_passives: Array[StringName] = [], enemy_hp: int = 100, enemy_stagger: int = 15, ally_stagger: int = 15) -> BattleState:
	var ally := AllyData.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.attack = 10
	ally.defense = 10
	ally.crit_chance = 0
	ally.max_sp = 3
	ally.stagger = ally_stagger
	ally.passives = ally_passives
	var enemy := EnemyData.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = enemy_hp
	enemy.speed = 1
	enemy.crit_chance = 0
	enemy.move_chance = 0.0
	enemy.stagger = enemy_stagger
	var encounter := EncounterData.new()
	var a_place := UnitPlacement.new()
	a_place.unit_data = ally
	a_place.cell = Vector2i(0, 1)
	var e_place := UnitPlacement.new()
	e_place.unit_data = enemy
	e_place.cell = Vector2i(0, 1)
	var allies: Array[UnitPlacement] = [a_place]
	var enemies: Array[UnitPlacement] = [e_place]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var state: BattleState = BattleStateScript.new(encounter, rng)
	state.start_battle()
	# 손패를 원하는 카드로 바꾼다.
	var a: Unit = state.units[0]
	a.hand = cards.duplicate()
	return state


func _a(state: BattleState) -> Unit:
	return state.units[0]


func _e(state: BattleState) -> Unit:
	return state.units[1]


func _strike(percent: int) -> CardData:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.DAMAGE, percent)]
	return _card(&"strike", CardData.AttackType.MELEE, effects)


# 방어도로 전부 막아도 흐트러짐은 피해량만큼 깎인다.
func _test_damage_drains_stagger_even_when_blocked() -> void:
	var state: BattleState = _battle([_strike(60)])
	var e: Unit = _e(state)
	e.block = 50
	state.play_card(0, e)
	check_eq("blocked hit leaves hp alone", e.hp, 100)
	check_eq("but the stagger gauge drops by the full hit", e.stagger, 15 - 6)


# 적의 게이지가 0 이 되면 기절하고, 다음 차례를 쉬며 게이지를 되찾는다.
func _test_enemy_breaks_and_skips_its_next_turn() -> void:
	var cards: Array[CardData] = [_strike(100), _strike(100)]
	var state: BattleState = _battle(cards, [], 100, 15)
	var e: Unit = _e(state)
	var staggered: Array[Unit] = []
	var skipped: Array[Unit] = []
	var logs: Array[String] = []
	state.unit_staggered.connect(func(u: Unit) -> void: staggered.append(u))
	state.turn_skipped.connect(func(u: Unit) -> void: skipped.append(u))
	state.log_message.connect(func(t: String) -> void: logs.append(t))
	state.play_card(0, e)
	check("one hit is not enough", not e.broken)
	state.play_card(0, e)
	check("two hits break the enemy", e.broken)
	check_eq("gauge is empty", e.stagger, 0)
	check_eq("staggered signal names the enemy", staggered, [e])
	check("enemy break is logged as 기절", logs.has("e 기절"))
	# 차례를 넘기면 적 차례가 쉬고 다시 a 차례가 된다.
	state.end_turn()
	check_eq("the enemy skipped its turn", skipped, [e])
	check("the enemy recovered", not e.broken)
	check_eq("the gauge is full again", e.stagger, 15)
	check("back to the ally", state.current_unit() == _a(state))


# 아군도 게이지가 0 이 되면 탈진하고 다음 차례를 쉰다 (입력을 기다리지 않고 지나간다).
func _test_broken_ally_is_exhausted_and_skips() -> void:
	var state: BattleState = _battle([], [], 100, 15, 5)
	var a: Unit = _a(state)
	var logs: Array[String] = []
	state.log_message.connect(func(t: String) -> void: logs.append(t))
	state.apply_damage(a, 5)
	check("the ally is broken", a.broken)
	check("ally break is logged as 탈진", logs.has("a 탈진"))
	var skipped: Array[Unit] = []
	state.turn_skipped.connect(func(u: Unit) -> void: skipped.append(u))
	# a 차례를 끝낸다 → e → (다음 라운드) a 가 쉬고 → e → a 에서 멈춘다.
	state.end_turn()
	check_eq("the exhausted ally skipped once", skipped, [a])
	check("the ally acts again afterwards", state.current_unit() == a and not a.broken)


# 흐트러짐 효과는 체력은 그대로 두고 게이지만 깎는다.
func _test_stagger_effect_only_drains_the_gauge() -> void:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.STAGGER, 80)]
	var state: BattleState = _battle([_card(&"jab", CardData.AttackType.MELEE, effects)])
	var e: Unit = _e(state)
	var drained: Array[int] = []
	state.stagger_damaged.connect(func(_u: Unit, amount: int) -> void: drained.append(amount))
	state.play_card(0, e)
	check_eq("hp untouched", e.hp, 100)
	check_eq("gauge drained by 80% of attack", e.stagger, 15 - 8)
	check_eq("stagger_damaged reports the amount", drained, [8])


# 상태 획득 카드는 혈갑을 더하고, 최대치(10)에서 멈춘다.
func _test_gain_status_adds_and_caps_blood_armor() -> void:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.GAIN_STATUS, 100, 6, BattleState.BLOOD_ARMOR)]
	var card: CardData = _card(&"harden", CardData.AttackType.SELF, effects)
	var state: BattleState = _battle([card, card])
	var a: Unit = _a(state)
	var changes: Array[int] = []
	state.status_changed.connect(func(_u: Unit, _id: StringName, value: int) -> void: changes.append(value))
	state.play_card(0, a)
	check_eq("first use gives 6", a.status(BattleState.BLOOD_ARMOR), 6)
	state.play_card(0, a)
	check_eq("capped at 10", a.status(BattleState.BLOOD_ARMOR), BattleState.BLOOD_ARMOR_MAX)
	check_eq("each change is announced with the new value", changes, [6, 10])


# 혈갑 패시브: 차례가 시작될 때 혈갑만큼 방어도를 얻는다.
func _test_blood_armor_passive_grants_block_each_turn() -> void:
	var passives: Array[StringName] = [BattleState.BLOOD_ARMOR]
	var state: BattleState = _battle([], passives)
	var a: Unit = _a(state)
	a.set_status(BattleState.BLOOD_ARMOR, 4)
	state.end_turn()
	check("a's turn again", state.current_unit() == a)
	check_eq("block equals blood armor at turn start", a.block, 4)


# 피의 갈망: 체력을 잃으면 혈갑 +1, 방어도로 다 막으면 얻지 않는다.
func _test_blood_thirst_gains_armor_on_hp_loss_only() -> void:
	var passives: Array[StringName] = [BattleState.BLOOD_THIRST]
	var state: BattleState = _battle([], passives)
	var a: Unit = _a(state)
	a.block = 10
	state.apply_damage(a, 5)
	check_eq("fully blocked hit gives nothing", a.status(BattleState.BLOOD_ARMOR), 0)
	state.apply_damage(a, 8)
	check_eq("losing hp gives one stack", a.status(BattleState.BLOOD_ARMOR), 1)


# 피의 갈망: 적을 쓰러뜨리면 혈갑 +2.
func _test_blood_thirst_gains_armor_on_kill() -> void:
	var passives: Array[StringName] = [BattleState.BLOOD_THIRST]
	var state: BattleState = _battle([_strike(100)], passives, 5)
	var a: Unit = _a(state)
	state.play_card(0, _e(state))
	check("the enemy died", not _e(state).is_alive())
	check_eq("kill gives two stacks", a.status(BattleState.BLOOD_ARMOR), BattleState.BLOOD_THIRST_KILL_STACKS)


# 폭발: 혈갑을 모두 소모하고 스택당 공격 % 피해.
func _test_burst_consumes_stacks_for_damage() -> void:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.BURST, 60, 0, BattleState.BLOOD_ARMOR)]
	var state: BattleState = _battle([_card(&"burst", CardData.AttackType.MELEE, effects)])
	var a: Unit = _a(state)
	var e: Unit = _e(state)
	a.set_status(BattleState.BLOOD_ARMOR, 5)
	state.play_card(0, e)
	check_eq("all stacks consumed", a.status(BattleState.BLOOD_ARMOR), 0)
	check_eq("damage = 6 per stack x 5", e.hp, 100 - 30)


# 스택이 없으면 폭발은 아무 일도 하지 않는다 (카드는 쓰인다).
func _test_burst_without_stacks_does_nothing() -> void:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.BURST, 60, 0, BattleState.BLOOD_ARMOR)]
	var state: BattleState = _battle([_card(&"burst", CardData.AttackType.MELEE, effects)])
	var e: Unit = _e(state)
	check("the card is still played", state.play_card(0, e))
	check_eq("no damage without stacks", e.hp, 100)


# 체력 소모: 1 은 남기고, 피의 갈망이 있으면 혈갑 +1.
func _test_hp_cost_never_kills_and_feeds_blood_thirst() -> void:
	var effects: Array[CardEffect] = [_effect(CardEffect.Kind.HP_COST, 100, 4, &"", CardEffect.Target.SELF)]
	var card: CardData = _card(&"bleed", CardData.AttackType.SELF, effects)
	var passives: Array[StringName] = [BattleState.BLOOD_THIRST]
	var state: BattleState = _battle([card, card], passives)
	var a: Unit = _a(state)
	a.block = 20
	state.play_card(0, a)
	check_eq("hp cost ignores block", a.hp, 26)
	check_eq("block untouched", a.block, 20)
	check_eq("stagger untouched", a.stagger, 15)
	check_eq("blood thirst triggers", a.status(BattleState.BLOOD_ARMOR), 1)
	a.hp = 2
	state.play_card(0, a)
	check_eq("never drops below 1", a.hp, 1)


# 카드 문구가 새 효과를 설명한다.
func _test_card_text_describes_new_effects() -> void:
	var effects: Array[CardEffect] = [
		_effect(CardEffect.Kind.HP_COST, 100, 3, &"", CardEffect.Target.SELF),
		_effect(CardEffect.Kind.GAIN_STATUS, 100, 2, BattleState.BLOOD_ARMOR, CardEffect.Target.SELF),
	]
	var card: CardData = _card(&"x", CardData.AttackType.SELF, effects)
	check_eq("hp cost and status gain text", CardText.describe(card), "체력 3 소모 · 혈갑 +2")
	var burst: Array[CardEffect] = [_effect(CardEffect.Kind.BURST, 60, 0, BattleState.BLOOD_ARMOR)]
	check_eq("burst text with stats", CardText.describe(_card(&"b", CardData.AttackType.MELEE, burst), AllyData.new()), "혈갑 전부 소모, 스택당 피해 6")
