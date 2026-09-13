extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const BrainScript := preload("res://Scripts/combat/enemy_brain.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_card_played_precedes_damage()
	_test_enemy_attack_signals()
	_test_enemy_defend_signals()
	_test_enemy_rest_signals()
	_test_enemy_rest_reports_capped_amount()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	return rng


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _ally(cell: Vector2i) -> UnitPlacement:
	var card: CardData = CardDataScript.new()
	card.id = &"zap"
	card.display_name = "zap"
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	card.shape = CardData.Shape.SINGLE
	card.attack_range = 9
	card.damage = 3

	var data: AllyData = AllyDataScript.new()
	data.id = &"a"
	data.display_name = "a"
	data.max_hp = 30
	data.speed = 10
	data.max_sp = 3
	var deck: Array[CardData] = [card]
	data.deck = deck
	return _placement(data, cell)


func _enemy(attack_range: int, rest_heal: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = &"e"
	data.display_name = "e"
	data.max_hp = 20
	data.speed = 1
	data.attack_damage = 6
	data.attack_type = CardData.AttackType.RANGED
	data.attack_shape = CardData.Shape.SINGLE
	data.attack_range = attack_range
	data.block_amount = 7
	data.rest_heal = rest_heal
	return data


func _state(ally_cell: Vector2i, enemy: EnemyData) -> BattleState:
	var allies: Array[UnitPlacement] = [_ally(ally_cell)]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return BattleStateScript.new(encounter, _rng())


func _record(state: BattleState) -> Array:
	var seen: Array = []
	state.card_played.connect(func(_actor: Unit, card: CardData, primary: Unit) -> void:
		seen.append("card:%s:%s" % [card.id, primary.data.id]))
	state.enemy_acted.connect(func(_actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
		seen.append("acted:%d:%s" % [action, "null" if target == null else String(target.data.id)]))
	state.unit_damaged.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("damaged:%d" % amount))
	state.unit_healed.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("healed:%d" % amount))
	state.block_gained.connect(func(_unit: Unit, amount: int) -> void:
		seen.append("block:%d" % amount))
	return seen


func _test_card_played_precedes_damage() -> void:
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	state.start_battle()
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	check("card play accepted", state.play_card(0, foe))
	check_eq("card_played comes before damage", seen, ["card:zap:e", "damaged:3"])


func _test_enemy_attack_signals() -> void:
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	BrainScript.take_turn(state, foe)
	check_eq("attack reports action then damage", seen, ["acted:%d:a" % EnemyBrain.Action.ATTACK, "damaged:6"])


func _test_enemy_defend_signals() -> void:
	# 사거리 1 인데 아군이 col 2 라 reach 가 3 이어서 방어를 고른다.
	var state: BattleState = _state(Vector2i(2, 1), _enemy(1, 4))
	var seen: Array = _record(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	BrainScript.take_turn(state, foe)
	check_eq("defend reports action then block", seen, ["acted:%d:null" % EnemyBrain.Action.DEFEND, "block:7"])
	check_eq("block actually applied", foe.block, 7)


func _test_enemy_rest_signals() -> void:
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	foe.take_damage(15)
	var seen: Array = _record(state)

	BrainScript.take_turn(state, foe)
	check_eq("rest reports action then heal", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:4"])
	check_eq("heal actually applied", foe.hp, 9)


func _test_enemy_rest_reports_capped_amount() -> void:
	var state: BattleState = _state(Vector2i(0, 1), _enemy(9, 30))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	foe.take_damage(15)
	var seen: Array = _record(state)

	BrainScript.take_turn(state, foe)
	check_eq("heal amount is what was restored, not rest_heal", seen, ["acted:%d:null" % EnemyBrain.Action.REST, "healed:15"])
	check_eq("hp capped at max", foe.hp, 20)
