# BattleState 행동 신호 순서 테스트: 카드 사용·적 공격·방어·휴식에서 "행동 신호 → 결과 신호" 순서와 수치.
extends TestCase

# 전투 상태 스크립트.
const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
# 적 AI 스크립트.
const BrainScript := preload("res://Scripts/combat/enemy_brain.gd")
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
	# 카드 사용 신호가 피해보다 먼저.
	_test_card_played_precedes_damage()
	# 적 공격 신호 순서.
	_test_enemy_attack_signals()
	# 적 방어 신호 순서.
	_test_enemy_defend_signals()
	# 적 휴식 신호 순서.
	_test_enemy_rest_signals()
	# 회복 신호는 실제 오른 양.
	_test_enemy_rest_reports_capped_amount()
	# 결과를 돌려준다.
	return results()


# 시드 777 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 777
	# 돌려준다.
	return rng


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


# "zap" 카드(원거리 단일, 사거리 9, 피해 3) 한 장짜리 덱을 가진 아군을 cell 에 배치한다.
func _ally(cell: Vector2i) -> UnitPlacement:
	# 카드.
	var card: CardData = CardDataScript.new()
	# id.
	card.id = &"zap"
	# 이름.
	card.display_name = "zap"
	# 비용 1.
	card.sp_cost = 1
	# 원거리.
	card.attack_type = CardData.AttackType.RANGED
	# 단일.
	card.shape = CardData.Shape.SINGLE
	# 어디든 닿는 사거리 9.
	card.attack_range = 9
	# 피해 3.
	card.damage = 3

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
	# 카드 한 장짜리 덱.
	var deck: Array[CardData] = [card]
	# 데이터에 덱을 넣는다.
	data.deck = deck
	# 배치로 만들어 돌려준다.
	return _placement(data, cell)


# 체력 20, 피해 6, 방어도 7 인 원거리 적 (사거리·회복량 지정).
func _enemy(attack_range: int, rest_heal: int) -> EnemyData:
	# 적 데이터.
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = &"e"
	# 이름.
	data.display_name = "e"
	# 최대 체력.
	data.max_hp = 20
	# 아군보다 느리게.
	data.speed = 1
	# 공격 피해 6.
	data.attack_damage = 6
	# 원거리.
	data.attack_type = CardData.AttackType.RANGED
	# 단일.
	data.attack_shape = CardData.Shape.SINGLE
	# 사거리.
	data.attack_range = attack_range
	# 방어도 7.
	data.block_amount = 7
	# 회복량.
	data.rest_heal = rest_heal
	# 돌려준다.
	return data


# 아군 한 명(ally_cell)과 적 한 명(앞줄 가운데)으로 전투 상태를 만든다.
func _state(ally_cell: Vector2i, enemy: EnemyData) -> BattleState:
	# 아군 배치.
	var allies: Array[UnitPlacement] = [_ally(ally_cell)]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 전투 구성.
	var encounter: EncounterData = EncounterScript.new()
	# 아군 격자.
	encounter.ally_grid = Vector2i(3, 3)
	# 적군 격자.
	encounter.enemy_grid = Vector2i(3, 3)
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적군 배치 넣기.
	encounter.enemy_units = enemies
	# 전투 상태를 만든다.
	return BattleStateScript.new(encounter, _rng())


# 행동·결과 신호를 "card:카드:대상", "acted:행동:대상", "damaged:양" 같은 문자열로 기록하는 배열을 연결해 돌려준다.
func _record(state: BattleState) -> Array:
	# 기록 배열.
	var seen: Array = []
	# 카드 사용.
	state.card_played.connect(func(_actor: Unit, card: CardData, primary: Unit) -> void:
		seen.append("card:%s:%s" % [card.id, primary.data.id]))
	# 적 행동 (대상이 없으면 "null").
	state.enemy_acted.connect(func(_actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
		seen.append("acted:%d:%s" % [action, "null" if target == null else String(target.data.id)]))
	# 피해.
	state.unit_damaged.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("damaged:%d" % amount))
	# 회복.
	state.unit_healed.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("healed:%d" % amount))
	# 방어도.
	state.block_gained.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("block:%d" % amount))
	# 기록 배열을 돌려준다.
	return seen


# 카드를 쓰면 card_played 가 unit_damaged 보다 먼저 나오는지 (화면이 돌진 → 피격 순서로 보여 주기 위해).
func _test_card_played_precedes_damage() -> void:
	# 사거리 9, 회복 4 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	# 시작 (아군 차례).
	state.start_battle()
	# 여기서부터 기록.
	var seen: Array = _record(state)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 0 번 카드를 적에게 쓴다.
	check("card play accepted", state.play_card(0, foe))
	# 사용 → 피해 순서.
	check_eq("card_played comes before damage", seen, ["card:zap:e", "damaged:3"])


# 적 공격: enemy_acted(ATTACK, a) → 피해 6 순서인지.
func _test_enemy_attack_signals() -> void:
	# 사거리 9 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	# 기록 연결.
	var seen: Array = _record(state)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 적 차례 처리.
	BrainScript.take_turn(state, foe)
	# 행동 → 피해.
	check_eq("attack reports action then damage", seen, ["acted:%d:a" % EnemyBrain.Action.ATTACK, "damaged:6"])


# 적 방어: enemy_acted(DEFEND, null) → 방어도 7 순서이고 실제 방어도도 7 인지.
func _test_enemy_defend_signals() -> void:
	# 사거리 1 인데 아군이 col 2 라 reach 가 3 이어서 방어를 고른다.
	var state: BattleState = _state(Vector2i(2, 1), _enemy(1, 4))
	# 기록 연결.
	var seen: Array = _record(state)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 적 차례 처리.
	BrainScript.take_turn(state, foe)
	# 행동 → 방어도.
	check_eq("defend reports action then block", seen, ["acted:%d:null" % EnemyBrain.Action.DEFEND, "block:7"])
	# 실제 방어도.
	check_eq("block actually applied", foe.block, 7)


# 적 휴식: enemy_acted(REST, null) → 회복 4 순서이고 체력이 5 → 9 인지.
func _test_enemy_rest_signals() -> void:
	# 회복 4 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 체력 5 로 (휴식 조건).
	foe.take_damage(15)
	# 기록 연결.
	var seen: Array = _record(state)

	# 적 차례 처리.
	BrainScript.take_turn(state, foe)
	# 행동 → 회복.
	check_eq("rest reports action then heal", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:4"])
	# 실제 체력.
	check_eq("heal actually applied", foe.hp, 9)


# 회복량 30 이어도 최대 체력 20 에 막히므로 신호의 양은 실제로 오른 15 인지.
func _test_enemy_rest_reports_capped_amount() -> void:
	# 회복 30 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 30))
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 체력 5 로.
	foe.take_damage(15)
	# 기록 연결.
	var seen: Array = _record(state)

	# 적 차례 처리.
	BrainScript.take_turn(state, foe)
	# 회복 신호 양은 15.
	check_eq("heal amount is what was restored, not rest_heal", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:15"])
	# 체력은 최대 20.
	check_eq("hp capped at max", foe.hp, 20)
