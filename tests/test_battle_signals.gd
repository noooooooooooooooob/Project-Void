# BattleState 행동 신호 순서 테스트: 카드 사용·적 공격·방어·휴식에서 "행동 신호 → 결과 신호" 순서와 수치.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")

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
	_test_enemy_attack_signals()
	_test_enemy_defend_signals()
	_test_enemy_rest_signals()
	_test_enemy_rest_reports_capped_amount()
	return results()


# 시드 777 로 고정한 난수 생성기.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	return rng


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# "zap" 카드(원거리 단일, 피해 3) 한 장짜리 덱을 가진 아군을 cell 에 배치한다.
func _ally(cell: Vector2i) -> UnitPlacement:
	var card: CardData = CardDataScript.new()
	# id.
	card.id = &"zap"
	card.display_name = "zap"
	# 비용 1.
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	# 피해 3.
	card.effects = [Fixtures.effect(CardEffect.Kind.DAMAGE, 30)]

	var data: AllyData = AllyDataScript.new()
	# id.
	data.id = &"a"
	data.display_name = "a"
	data.max_hp = 30
	data.speed = 10
	# SP.
	data.max_sp = 3
	var deck: Array[CardData] = [card]
	data.deck = deck
	return _placement(data, cell)


# 체력 20, 피해 6, 방어도 7 인 단일 공격 적 (공격 종류·회복량 지정).
func _enemy(attack_type: int, rest_heal: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	# id.
	data.id = &"e"
	data.display_name = "e"
	data.max_hp = 20
	data.speed = 1
	# 치명타를 끈다 (수치를 정확히 확인하기 위해).
	data.crit_chance = 0
	# 피해 6·방어도 7·회복 rest_heal 카드 (공격·방어 10 기준이라 % = 수치 × 10).
	Fixtures.enemy_cards(data, Fixtures.damage_card(&"enemy_attack", attack_type, 60), 70, rest_heal * 10)
	# 무작위 이동을 끈다 (신호 순서를 정확히 확인하기 위해).
	data.move_chance = 0.0
	return data


# 아군 한 명(ally_cell)과 적 한 명(앞줄 가운데)으로 전투 상태를 만든다.
func _state(ally_cell: Vector2i, enemy: EnemyData) -> BattleState:
	var allies: Array[UnitPlacement] = [_ally(ally_cell)]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return BattleStateScript.new(encounter, _rng())


# 행동·결과 신호를 "card:카드:대상", "acted:행동:대상", "damaged:양" 같은 문자열로 기록하는 배열을 연결해 돌려준다.
func _record(state: BattleState) -> Array:
	var seen: Array = []
	# 카드 사용 (기준 유닛의 id).
	state.card_played.connect(func(_actor: Unit, card: CardData, anchor: Unit) -> void:
		seen.append("card:%s:%s" % [card.id, String(anchor.data.id)]))
	# 적 행동 (대상이 없으면 "null").
	state.enemy_acted.connect(func(_actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
		seen.append("acted:%d:%s" % [action, "null" if target == null else String(target.data.id)]))
	state.unit_damaged.connect(func(_unit: Unit, amount: int, _critical: bool) -> void:
		seen.append("damaged:%d" % amount))
	state.unit_healed.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("healed:%d" % amount))
	state.block_gained.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("block:%d" % amount))
	return seen


# 카드를 쓰면 card_played 가 unit_damaged 보다 먼저 나오는지 (화면이 돌진 → 피격 순서로 보여 주기 위해).
func _test_card_played_precedes_damage() -> void:
	# 원거리, 회복 4 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(CardData.AttackType.RANGED, 4))
	# 시작 (아군 차례).
	state.start_battle()
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 0 번 카드를 적에게 쓴다.
	check("card play accepted", state.play_card(0, foe))
	check_eq("card_played comes before damage", seen, ["card:zap:e", "damaged:3"])


# 적 공격: enemy_acted(ATTACK, a) → 피해 6 순서인지.
func _test_enemy_attack_signals() -> void:
	var state: BattleState = _state(Vector2i(0, 1), _enemy(CardData.AttackType.RANGED, 4))
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	BrainScript.take_turn(state, foe)
	check_eq("attack reports action then damage", seen, ["acted:%d:a" % EnemyBrain.Action.ATTACK, "damaged:6"])


# 적 방어: enemy_acted(DEFEND, null) → 방어도 7 순서이고 실제 방어도도 7 인지.
func _test_enemy_defend_signals() -> void:
	# 근접 적과 다른 행(0)에 아군이 있어 칠 대상이 없으니 방어를 고른다.
	var state: BattleState = _state(Vector2i(2, 0), _enemy(CardData.AttackType.MELEE, 4))
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	BrainScript.take_turn(state, foe)
	check_eq("defend reports action then block", seen, ["acted:%d:null" % EnemyBrain.Action.DEFEND, "block:7"])
	check_eq("block actually applied", foe.block, 7)


# 적 휴식: enemy_acted(REST, null) → 회복 4 순서이고 체력이 5 → 9 인지.
func _test_enemy_rest_signals() -> void:
	# 회복 4 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(CardData.AttackType.RANGED, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 체력 5 로 (휴식 조건).
	foe.take_damage(15)
	var seen: Array = _record(state)

	BrainScript.take_turn(state, foe)
	check_eq("rest reports action then heal", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:4"])
	check_eq("heal actually applied", foe.hp, 9)


# 회복량 30 이어도 최대 체력 20 에 막히므로 신호의 양은 실제로 오른 15 인지.
func _test_enemy_rest_reports_capped_amount() -> void:
	# 회복 30 적.
	var state: BattleState = _state(Vector2i(0, 1), _enemy(CardData.AttackType.RANGED, 30))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 체력 5 로.
	foe.take_damage(15)
	var seen: Array = _record(state)

	BrainScript.take_turn(state, foe)
	# 회복 신호 양은 15.
	check_eq("heal amount is what was restored, not the card value", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:15"])
	# 체력은 최대 20.
	check_eq("hp capped at max", foe.hp, 20)
