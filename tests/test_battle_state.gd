# BattleState.play_card 규칙 테스트: 정상 사용과 각종 거절 조건(SP, 막힘, 종료, 차례 없음, 적 차례, 쓰러짐, 번호 범위), 범위 공격, 전투 종료.
# 전투를 시작하지 않고 turn_index·initiative·hand 를 직접 정해 원하는 상황을 만든다.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
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


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 유닛 배치.
	_test_setup_places_units()
	# 정상 사용: 피해와 SP 소모.
	_test_play_card_damages_and_spends_sp()
	# SP 부족 거절.
	_test_play_card_rejected_without_sp()
	# 막힌 대상 거절.
	_test_play_card_rejected_on_blocked_target()
	# 끝난 전투 거절.
	_test_play_card_rejected_when_battle_finished()
	# 차례 유닛 없음 거절.
	_test_play_card_rejected_when_no_current_actor()
	# 적 차례 거절.
	_test_play_card_rejected_when_current_unit_is_enemy()
	# 쓰러진 유닛 거절.
	_test_play_card_rejected_when_current_unit_is_dead()
	# 손패 번호 범위 밖 거절.
	_test_play_card_rejected_on_hand_index_out_of_bounds()
	# 횡렬 범위.
	_test_sweep_hits_multiple()
	# 적 전멸 시 종료.
	_test_battle_ends_when_enemies_wiped()
	# 결과를 돌려준다.
	return results()


# 시드 12345 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 12345
	# 돌려준다.
	return rng


# 주어진 값으로 카드를 만든다.
func _card(id: StringName, cost: int, attack_type: int, shape: int, attack_range: int, damage: int) -> CardData:
	# 빈 카드.
	var card: CardData = CardDataScript.new()
	# id.
	card.id = id
	# 이름.
	card.display_name = String(id)
	# 비용.
	card.sp_cost = cost
	# 공격 방식.
	card.attack_type = attack_type
	# 범위 모양.
	card.shape = shape
	# 사거리.
	card.attack_range = attack_range
	# 피해.
	card.damage = damage
	# 돌려준다.
	return card


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


# 아군 1기(전열 중앙) vs 적 2기(같은 행의 전열/후열).
func _encounter(ally_cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> EncounterData:
	# 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"tester"
	# 이름.
	ally.display_name = "테스터"
	# 최대 체력.
	ally.max_hp = 30
	# 속도.
	ally.speed = 10
	# 최대 SP.
	ally.max_sp = ally_sp
	# 덱.
	ally.deck = ally_cards

	# 전열 적 데이터.
	var front: EnemyData = EnemyDataScript.new()
	# id.
	front.id = &"front"
	# 체력.
	front.max_hp = enemy_hp
	# 속도.
	front.speed = 5

	# 후열 적 데이터.
	var back: EnemyData = EnemyDataScript.new()
	# id.
	back.id = &"back"
	# 체력.
	back.max_hp = enemy_hp
	# 속도.
	back.speed = 4

	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자.
	encounter.enemy_grid = Vector2i(3, 3)
	# 아군을 전열 가운데에.
	encounter.ally_units = [_placement(ally, Vector2i(0, 1))]
	# 적을 같은 행의 전열·후열에.
	encounter.enemy_units = [
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	]
	# 돌려준다.
	return encounter


# 위 구성으로 전투 상태를 만든다 (시작하지 않음).
func _state(cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> BattleState:
	# 구성과 난수 생성기로 만든다.
	return BattleStateScript.new(_encounter(cards, ally_sp, enemy_hp), _rng())


# 유닛 3 명(아군 1, 적 2)이 만들어지고, 판정기가 격자 크기를 알고, 번호가 겹치지 않는지.
func _test_setup_places_units() -> void:
	# 카드 없는 전투.
	var state: BattleState = _state([])
	# 3 명.
	check_eq("three units total", state.units.size(), 3)
	# 아군 1.
	check_eq("one living ally", state.living_units(Unit.Team.ALLY).size(), 1)
	# 적 2.
	check_eq("two living enemies", state.living_units(Unit.Team.ENEMY).size(), 2)
	# 아군 격자 크기.
	check_eq("resolver knows ally grid", state.resolver.ally_grid, Vector2i(3, 3))
	# 번호가 서로 다르다.
	check("unit ids are unique", state.units[0].unit_id != state.units[1].unit_id)


# 근접 사거리 1 피해 6 카드를 전열 적에게: 체력 10→4, SP 5→4, 손패 0, 묘지 1.
func _test_play_card_damages_and_spends_sp() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례로 직접 설정.
	state.turn_index = 0
	# 행동 순서에 아군만.
	state.initiative = [ally]
	# 손패에 카드를 직접 넣는다.
	ally.hand = [strike]

	# 사용.
	var played: bool = state.play_card(0, front)
	# 성공.
	check("card was played", played)
	# 체력 4.
	check_eq("target lost hp", front.hp, 4)
	# SP 4.
	check_eq("sp spent", ally.sp, 4)
	# 손패 0.
	check_eq("hand emptied", ally.hand.size(), 0)
	# 묘지 1.
	check_eq("card went to discard", ally.discard.size(), 1)


# 비용 9 카드를 SP 2 로 쓰면 거절되고 아무것도 바뀌지 않는지.
func _test_play_card_rejected_without_sp() -> void:
	# 비싼 카드.
	var pricey: CardData = _card(&"pricey", 9, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 최대 SP 2 인 전투.
	var state: BattleState = _state([pricey], 2)
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [pricey]

	# 거절.
	check("play rejected", not state.play_card(0, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 2)
	# 손패 그대로.
	check_eq("card stays in hand", ally.hand.size(), 1)


# 근접 카드로 전열에 가려진 후열 적을 치면 사거리가 충분해도 거절되는지.
func _test_play_card_rejected_on_blocked_target() -> void:
	# 사거리 4 근접 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 4, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 후열 적.
	var back: Unit = state.living_units(Unit.Team.ENEMY)[1]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [strike]

	# 거절.
	check("melee cannot reach behind the front", not state.play_card(0, back))
	# 후열 체력 그대로.
	check_eq("back rank untouched", back.hp, 10)


# 전투가 끝난 뒤에는 거절되고 아무것도 바뀌지 않는지.
func _test_play_card_rejected_when_battle_finished() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [strike]
	# 끝난 전투로 표시.
	state.finished = true

	# 거절.
	check("play rejected once battle is finished", not state.play_card(0, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 5)
	# 손패 그대로.
	check_eq("hand untouched", ally.hand.size(), 1)
	# 묘지 그대로.
	check_eq("discard untouched", ally.discard.size(), 0)


# 행동 순서가 비어 차례 유닛이 없으면 거절되는지.
func _test_play_card_rejected_when_no_current_actor() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 0 번째 차례로 두지만.
	state.turn_index = 0
	# 행동 순서를 비워 둔다.
	state.initiative = []  # turn_index out of bounds -> current_unit() returns null
	# 손패.
	ally.hand = [strike]

	# 거절.
	check("play rejected without a current actor", not state.play_card(0, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 5)
	# 손패 그대로.
	check_eq("hand untouched", ally.hand.size(), 1)
	# 묘지 그대로.
	check_eq("discard untouched", ally.discard.size(), 0)


# 지금 차례가 적이면 아군 카드를 쓸 수 없는지.
func _test_play_card_rejected_when_current_unit_is_enemy() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 0 번째 차례.
	state.turn_index = 0
	# 행동 순서에 적만.
	state.initiative = [front]
	# 아군 손패.
	ally.hand = [strike]

	# 거절.
	check("play rejected when current unit is an enemy", not state.play_card(0, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 5)
	# 손패 그대로.
	check_eq("hand untouched", ally.hand.size(), 1)
	# 묘지 그대로.
	check_eq("discard untouched", ally.discard.size(), 0)


# 차례 유닛이 쓰러져 있으면 거절되는지.
func _test_play_card_rejected_when_current_unit_is_dead() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [strike]
	# 아군 체력 0.
	ally.hp = 0

	# 거절.
	check("play rejected when current unit is dead", not state.play_card(0, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 5)
	# 손패 그대로.
	check_eq("hand untouched", ally.hand.size(), 1)
	# 묘지 그대로.
	check_eq("discard untouched", ally.discard.size(), 0)


# 손패 번호가 음수이거나 손패 크기 이상이면 거절되는지.
func _test_play_card_rejected_on_hand_index_out_of_bounds() -> void:
	# 카드.
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	# 전투.
	var state: BattleState = _state([strike])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패 1 장.
	ally.hand = [strike]

	# -1 거절.
	check("negative hand index rejected", not state.play_card(-1, front))
	# 5 거절.
	check("too-large hand index rejected", not state.play_card(5, front))
	# 체력 그대로.
	check_eq("target untouched", front.hp, 10)
	# SP 그대로.
	check_eq("sp untouched", ally.sp, 5)
	# 손패 그대로.
	check_eq("hand untouched", ally.hand.size(), 1)
	# 묘지 그대로.
	check_eq("discard untouched", ally.discard.size(), 0)


# 원거리 횡렬 피해 3: 전열 적만 맞고(같은 열), 다른 열의 후열 적은 그대로인지.
func _test_sweep_hits_multiple() -> void:
	# 횡렬 카드.
	var volley: CardData = _card(&"volley", 1, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3)
	# 전투.
	var state: BattleState = _state([volley])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [volley]

	# front 는 (0,1), back 은 (1,1) 이라 SWEEP(같은 col)은 front 만 맞는다.
	check("sweep played", state.play_card(0, front))
	# 전열 10 - 3 = 7.
	check_eq("front damaged", front.hp, 7)
	# 후열(units[2]) 그대로.
	check_eq("different column untouched", state.units[2].hp, 10)


# 관통 피해 99 로 같은 행의 적 둘을 모두 쓰러뜨리면 전투가 끝나고 아군 승리인지.
func _test_battle_ends_when_enemies_wiped() -> void:
	# 관통 카드.
	var nuke: CardData = _card(&"nuke", 1, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 5, 99)
	# 전투.
	var state: BattleState = _state([nuke])
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 전열 적.
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 아군 차례.
	state.turn_index = 0
	# 행동 순서.
	state.initiative = [ally]
	# 손패.
	ally.hand = [nuke]

	# 사용 (같은 행의 두 적 처치).
	state.play_card(0, front)
	# 끝났다.
	check("battle finished", state.finished)
	# 아군 승리.
	check("ally won", state.ally_won)
