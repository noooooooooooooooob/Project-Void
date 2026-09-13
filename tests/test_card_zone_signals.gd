extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const UnitScript := preload("res://Scripts/combat/unit.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")

const SEED: int = 2024


func run() -> Array[Dictionary]:
	_test_draw_reports_counts()
	_test_reshuffle_happens_mid_draw()
	_test_draw_stops_when_deck_and_discard_are_empty()
	_test_hand_discarded_carries_cards()
	_test_state_draw_matches_unit_draw()
	return results()


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 서로 구분되는 카드 c0..c(n-1) 로 된 덱을 가진 아군 a(속도 10).
func _ally(deck_size: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = &"a"
	data.display_name = "a"
	data.max_hp = 30
	data.speed = 10
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		var card: CardData = CardDataScript.new()
		card.id = StringName("c%d" % i)
		card.display_name = "c%d" % i
		deck.append(card)
	data.deck = deck
	return data


# 적 e(속도 1)는 기본 근접 공격으로 아군을 치기만 한다. 카드와 난수에 영향이 없다.
func _state(ally: AllyData) -> BattleState:
	var enemy: EnemyData = EnemyDataScript.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1

	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return BattleStateScript.new(encounter, rng)


func _record(state: BattleState) -> Array:
	var seen: Array = []
	state.card_drawn.connect(func(_unit: Unit, _card: CardData, deck_count: int, discard_count: int) -> void:
		seen.append("drawn:%d:%d" % [deck_count, discard_count]))
	state.deck_reshuffled.connect(func(_unit: Unit, count: int) -> void:
		seen.append("reshuffled:%d" % count))
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		seen.append("discarded:%d:%d" % [cards.size(), discard_count]))
	return seen


func _ids(cards: Array[CardData]) -> Array:
	var ids: Array = []
	for card in cards:
		ids.append(card.id)
	return ids


func _test_draw_reports_counts() -> void:
	var state: BattleState = _state(_ally(6))
	var seen: Array = _record(state)
	state.start_battle()
	check_eq("four draws with shrinking deck", seen, ["drawn:5:0", "drawn:4:0", "drawn:3:0", "drawn:2:0"])
	check_eq("hand holds four cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


func _test_reshuffle_happens_mid_draw() -> void:
	var state: BattleState = _state(_ally(6))
	state.start_battle()
	var seen: Array = _record(state)
	# 차례 종료 → 적 차례 → 같은 아군의 다음 차례 드로우까지 이어진다. 덱 2장, 묘지 4장에서 시작한다.
	state.end_turn()
	check_eq("discard, two draws, reshuffle, two draws", seen,
		["discarded:4:4", "drawn:1:4", "drawn:0:4", "reshuffled:4", "drawn:3:0", "drawn:2:0"])
	check_eq("hand refilled to four", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


func _test_draw_stops_when_deck_and_discard_are_empty() -> void:
	var state: BattleState = _state(_ally(2))
	var seen: Array = _record(state)
	state.start_battle()
	check_eq("only two draws, no reshuffle", seen, ["drawn:1:0", "drawn:0:0"])
	check_eq("hand holds two cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 2)


func _test_hand_discarded_carries_cards() -> void:
	var state: BattleState = _state(_ally(6))
	state.start_battle()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var before: Array[CardData] = ally.hand.duplicate()
	var discarded: Array = []
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		discarded.append([cards.duplicate(), discard_count]))

	state.end_turn()
	check_eq("discarded cards in hand order", discarded[0][0], before)
	check_eq("discard count right after discarding", discarded[0][1], 4)


func _test_state_draw_matches_unit_draw() -> void:
	var data: AllyData = _ally(6)
	var state: BattleState = _state(data)
	state.start_battle()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var first_hand: Array = _ids(ally.hand)
	state.end_turn()
	var second_hand: Array = _ids(ally.hand)

	# BattleState 생성자는 아군 덱을 한 번 섞고, 적 행동은 난수를 쓰지 않는다.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var reference: Unit = UnitScript.new(0, data, Unit.Team.ALLY, Vector2i(0, 1))
	reference.shuffle_deck(rng)
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	check_eq("first hand matches Unit.draw", first_hand, _ids(reference.hand))
	reference.discard_hand()
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	check_eq("second hand, across a reshuffle, matches Unit.draw", second_hand, _ids(reference.hand))
