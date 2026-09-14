# BattleState 의 카드 더미 신호(드로우, 리셔플, 손패 버리기) 테스트.
# 신호 순서와 함께 넘어오는 장수가 맞는지, 그리고 신호를 내는 드로우가 Unit.draw 와 같은 결과인지 확인한다.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 유닛 스크립트.
const UnitScript := preload("res://Scripts/combat/unit.gd")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")

# 모든 테스트가 같은 섞기 결과를 쓰도록 고정한 시드.
const SEED: int = 2024


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 드로우마다 장수를 알린다.
	_test_draw_reports_counts()
	# 드로우 도중 리셔플.
	_test_reshuffle_happens_mid_draw()
	# 덱·묘지가 다 비면 드로우가 멈춘다.
	_test_draw_stops_when_deck_and_discard_are_empty()
	# 손패 버리기 신호에 버린 카드가 담긴다.
	_test_hand_discarded_carries_cards()
	# 신호 드로우와 Unit.draw 의 결과가 같다.
	_test_state_draw_matches_unit_draw()
	# 적이 무작위로 움직여도 드로우 순서는 같다.
	_test_enemy_moves_do_not_change_draws()
	# 결과를 돌려준다.
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# 서로 구분되는 카드 c0..c(n-1) 로 된 덱을 가진 아군 a(속도 10).
func _ally(deck_size: int) -> AllyData:
	# 아군 데이터.
	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = &"a"
	# 이름.
	data.display_name = "a"
	# 최대 체력.
	data.max_hp = 30
	# 적보다 빠르게.
	data.speed = 10
	# SP.
	data.max_sp = 3
	# 덱 배열.
	var deck: Array[CardData] = []
	# 카드마다.
	for i in deck_size:
		# 빈 카드.
		var card: CardData = CardDataScript.new()
		# 구분용 id.
		card.id = StringName("c%d" % i)
		# 이름.
		card.display_name = "c%d" % i
		# 덱에 넣는다.
		deck.append(card)
	# 데이터에 덱을 넣는다.
	data.deck = deck
	# 돌려준다.
	return data


# 적 e(속도 1)는 기본 근접 공격으로 아군을 친다. move_chance 로 무작위 이동을 켤 수 있다 (기본 0).
# 적 AI 는 전용 난수(ai_rng)를 쓰므로 카드 순서에 영향이 없다.
func _state(ally: AllyData, move_chance: float = 0.0) -> BattleState:
	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 아군보다 느리게.
	enemy.speed = 1
	# 무작위 이동 확률.
	enemy.move_chance = move_chance

	# 전투 구성 (격자 크기는 기본값 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 한 명을 앞줄 가운데에.
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	# 적 한 명을 앞줄 가운데에.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치.
	encounter.ally_units = allies
	# 적군 배치.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = SEED
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, rng)


# 세 카드 더미 신호를 "drawn:덱:묘지" 같은 짧은 문자열로 기록하는 배열을 연결해 돌려준다.
func _record(state: BattleState) -> Array:
	# 기록 배열 (람다가 이 배열에 추가한다).
	var seen: Array = []
	# 드로우 → "drawn:덱장수:묘지장수".
	state.card_drawn.connect(func(_unit: Unit, _card: CardData, deck_count: int, discard_count: int) -> void:
		seen.append("drawn:%d:%d" % [deck_count, discard_count]))
	# 리셔플 → "reshuffled:옮긴장수".
	state.deck_reshuffled.connect(func(_unit: Unit, count: int) -> void:
		seen.append("reshuffled:%d" % count))
	# 손패 버리기 → "discarded:버린장수:묘지장수".
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		seen.append("discarded:%d:%d" % [cards.size(), discard_count]))
	# 기록 배열을 돌려준다 (신호가 날 때마다 채워진다).
	return seen


# 카드 목록을 id 목록으로 바꾼다 (비교하기 쉽게).
func _ids(cards: Array[CardData]) -> Array:
	# id 배열.
	var ids: Array = []
	# 카드마다.
	for card in cards:
		# id 를 넣는다.
		ids.append(card.id)
	# 돌려준다.
	return ids


# 덱 6 장으로 전투를 시작하면 드로우 4 번이 덱 5→4→3→2, 묘지 0 으로 알려지는지.
func _test_draw_reports_counts() -> void:
	# 덱 6 장 아군.
	var state: BattleState = _state(_ally(6))
	# 기록을 연결한다.
	var seen: Array = _record(state)
	# 시작 → 첫 아군 차례에서 4 장 드로우.
	state.start_battle()
	# 신호 순서와 장수.
	check_eq("four draws with shrinking deck", seen, ["drawn:5:0", "drawn:4:0", "drawn:3:0", "drawn:2:0"])
	# 손패 4.
	check_eq("hand holds four cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


# 덱 2 장·묘지 4 장 상태에서 다음 드로우: 2 장 뽑고, 리셔플 4 장, 다시 2 장 뽑는 순서인지.
func _test_reshuffle_happens_mid_draw() -> void:
	# 덱 6 장 아군.
	var state: BattleState = _state(_ally(6))
	# 시작 (손패 4, 덱 2).
	state.start_battle()
	# 여기서부터 기록한다.
	var seen: Array = _record(state)
	# 차례 종료 → 적 차례 → 같은 아군의 다음 차례 드로우까지 이어진다. 덱 2장, 묘지 4장에서 시작한다.
	state.end_turn()
	# 버리기, 드로우 2, 리셔플, 드로우 2.
	check_eq("discard, two draws, reshuffle, two draws", seen,
		["discarded:4:4", "drawn:1:4", "drawn:0:4", "reshuffled:4", "drawn:3:0", "drawn:2:0"])
	# 손패 4 로 다시 찼다.
	check_eq("hand refilled to four", state.living_units(Unit.Team.ALLY)[0].hand.size(), 4)


# 덱 2 장뿐이면 2 번만 뽑고 리셔플 신호는 없는지.
func _test_draw_stops_when_deck_and_discard_are_empty() -> void:
	# 덱 2 장 아군.
	var state: BattleState = _state(_ally(2))
	# 기록을 연결한다.
	var seen: Array = _record(state)
	# 시작.
	state.start_battle()
	# 드로우 2 번뿐.
	check_eq("only two draws, no reshuffle", seen, ["drawn:1:0", "drawn:0:0"])
	# 손패 2.
	check_eq("hand holds two cards", state.living_units(Unit.Team.ALLY)[0].hand.size(), 2)


# 손패 버리기 신호가 버리기 전 손패와 같은 카드들(같은 순서)과 버린 뒤 묘지 장수 4 를 담는지.
func _test_hand_discarded_carries_cards() -> void:
	# 덱 6 장 아군.
	var state: BattleState = _state(_ally(6))
	# 시작.
	state.start_battle()
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 버리기 전 손패를 복사해 둔다.
	var before: Array[CardData] = ally.hand.duplicate()
	# 신호 인자를 담을 배열.
	var discarded: Array = []
	# 버리기 신호의 카드 목록과 묘지 장수를 기록한다.
	state.hand_discarded.connect(func(_unit: Unit, cards: Array[CardData], discard_count: int) -> void:
		discarded.append([cards.duplicate(), discard_count]))

	# 차례를 끝낸다 (손패를 버린다).
	state.end_turn()
	# 버린 카드 = 버리기 전 손패.
	check_eq("discarded cards in hand order", discarded[0][0], before)
	# 묘지 장수 4.
	check_eq("discard count right after discarding", discarded[0][1], 4)


# 전투 속 신호 드로우의 손패가, 같은 시드로 Unit.draw 를 직접 부른 결과와 두 차례 모두 같은지 (리셔플 포함).
func _test_state_draw_matches_unit_draw() -> void:
	# 덱 6 장 아군 데이터 (참조용 유닛도 같은 데이터로 만든다).
	var data: AllyData = _ally(6)
	# 전투 상태.
	var state: BattleState = _state(data)
	# 시작.
	state.start_battle()
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 첫 손패 id.
	var first_hand: Array = _ids(ally.hand)
	# 다음 차례까지 (리셔플이 끼어든다).
	state.end_turn()
	# 두 번째 손패 id.
	var second_hand: Array = _ids(ally.hand)

	# BattleState 생성자는 아군 덱을 한 번 섞고, 적 행동은 난수를 쓰지 않는다.
	# 같은 시드의 새 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = SEED
	# 참조용 유닛.
	var reference: Unit = UnitScript.new(0, data, Unit.Team.ALLY, Vector2i(0, 1))
	# 생성자와 똑같이 한 번 섞는다.
	reference.shuffle_deck(rng)
	# 4 장 뽑는다.
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	# 첫 손패 비교.
	check_eq("first hand matches Unit.draw", first_hand, _ids(reference.hand))
	# 손패를 버린다.
	reference.discard_hand()
	# 다시 4 장 뽑는다 (리셔플 포함).
	reference.draw(BattleState.DRAW_PER_TURN, rng)
	# 두 번째 손패 비교.
	check_eq("second hand, across a reshuffle, matches Unit.draw", second_hand, _ids(reference.hand))


# 적이 매 차례 무작위로 이동해도(적 전용 난수) 아군이 뽑는 카드는 이동하지 않을 때와 같은지.
func _test_enemy_moves_do_not_change_draws() -> void:
	# 적이 움직이지 않는 전투.
	var still: BattleState = _state(_ally(6), 0.0)
	# 적이 항상 움직이는 전투 (같은 시드).
	var moving: BattleState = _state(_ally(6), 1.0)
	# 둘 다 시작.
	still.start_battle()
	# 둘 다 시작.
	moving.start_battle()
	# 둘 다 차례 종료 (적 차례를 지나 다음 드로우까지).
	still.end_turn()
	# 둘 다 차례 종료.
	moving.end_turn()
	# 두 전투의 두 번째 손패가 같다.
	check_eq("enemy randomness leaves the draw order alone", _ids(still.living_units(Unit.Team.ALLY)[0].hand), _ids(moving.living_units(Unit.Team.ALLY)[0].hand))
	# 움직이는 전투에서는 적이 실제로 자리를 옮겼다.
	check("the moving enemy left its cell", moving.living_units(Unit.Team.ENEMY)[0].cell != Vector2i(0, 1))
