extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const BrainScript := preload("res://Scripts/combat/enemy_brain.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_attacks_lowest_hp_target()
	_test_rests_when_badly_hurt()
	_test_defends_when_no_target_in_range()
	_test_attack_respects_melee_blocking()
	_test_deterministic_across_runs()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	return rng


func _ally(id: StringName, hp: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = hp
	data.speed = 1
	data.max_sp = 1
	return data


func _enemy(attack_range: int, damage: int, block_amount: int, rest_heal: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = &"foe"
	data.display_name = "적"
	data.max_hp = 20
	data.speed = 99
	data.attack_damage = damage
	data.attack_type = CardData.AttackType.RANGED
	data.attack_shape = CardData.Shape.SINGLE
	data.attack_range = attack_range
	data.block_amount = block_amount
	data.rest_heal = rest_heal
	return data


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _state(allies: Array, enemy: EnemyData) -> BattleState:
	var ally_placements: Array[UnitPlacement] = []
	ally_placements.append_array(allies)
	var enemy_placements: Array[UnitPlacement] = []
	enemy_placements.append(_placement(enemy, Vector2i(0, 1)))

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = ally_placements
	encounter.enemy_units = enemy_placements
	return BattleStateScript.new(encounter, _rng())


func _test_attacks_lowest_hp_target() -> void:
	var healthy: AllyData = _ally(&"healthy", 30)
	var wounded: AllyData = _ally(&"wounded", 8)
	var state: BattleState = _state([
		_placement(healthy, Vector2i(0, 0)),
		_placement(wounded, Vector2i(0, 1)),
	], _enemy(5, 6, 5, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	check_eq("picks attack", BrainScript.decide(state, foe), BrainScript.Action.ATTACK)
	check_eq("targets the lower hp ally", BrainScript.find_target(state, foe).data.id, &"wounded")

	BrainScript.take_turn(state, foe)
	check_eq("wounded ally took damage", state.living_units(Unit.Team.ALLY)[1].hp, 2)


func _test_rests_when_badly_hurt() -> void:
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], _enemy(5, 6, 5, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	foe.take_damage(15)

	check_eq("rests at or below 30% hp", BrainScript.decide(state, foe), BrainScript.Action.REST)
	BrainScript.take_turn(state, foe)
	check_eq("healed by rest_heal", foe.hp, 9)


func _test_defends_when_no_target_in_range() -> void:
	# 사거리 1 인데 아군은 후열(col 2)에 있어 reach 가 3 이다.
	var state: BattleState = _state([_placement(_ally(&"far", 30), Vector2i(2, 1))], _enemy(1, 6, 7, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	check("no reachable target", BrainScript.find_target(state, foe) == null)
	check_eq("falls back to defend", BrainScript.decide(state, foe), BrainScript.Action.DEFEND)
	BrainScript.take_turn(state, foe)
	check_eq("gained block", foe.block, 7)


func _test_attack_respects_melee_blocking() -> void:
	var front: AllyData = _ally(&"front", 30)
	var back: AllyData = _ally(&"back", 5)
	var melee: EnemyData = _enemy(4, 6, 5, 4)
	melee.attack_type = CardData.AttackType.MELEE
	var state: BattleState = _state([
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	], melee)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# back 이 hp 가 더 낮지만 같은 행의 front 에 막혀 고를 수 없다.
	check_eq("melee must hit the front rank", BrainScript.find_target(state, foe).data.id, &"front")


func _test_deterministic_across_runs() -> void:
	var first: StringName = &""
	var second: StringName = &""
	for i in 2:
		var state: BattleState = _state([
			_placement(_ally(&"x", 20), Vector2i(0, 0)),
			_placement(_ally(&"y", 20), Vector2i(0, 2)),
		], _enemy(5, 6, 5, 4))
		var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
		var picked: StringName = BrainScript.find_target(state, foe).data.id
		if i == 0:
			first = picked
		else:
			second = picked
	check_eq("same situation yields the same target", first, second)
