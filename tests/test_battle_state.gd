extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_setup_places_units()
	_test_play_card_damages_and_spends_sp()
	_test_play_card_rejected_without_sp()
	_test_play_card_rejected_on_blocked_target()
	_test_sweep_hits_multiple()
	_test_battle_ends_when_enemies_wiped()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func _card(id: StringName, cost: int, attack_type: int, shape: int, attack_range: int, damage: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	card.display_name = String(id)
	card.sp_cost = cost
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 1기(전열 중앙) vs 적 2기(같은 행의 전열/후열).
func _encounter(ally_cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> EncounterData:
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"tester"
	ally.display_name = "테스터"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = ally_sp
	ally.deck = ally_cards

	var front: EnemyData = EnemyDataScript.new()
	front.id = &"front"
	front.max_hp = enemy_hp
	front.speed = 5

	var back: EnemyData = EnemyDataScript.new()
	back.id = &"back"
	back.max_hp = enemy_hp
	back.speed = 4

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = [_placement(ally, Vector2i(0, 1))]
	encounter.enemy_units = [
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	]
	return encounter


func _state(cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> BattleState:
	return BattleStateScript.new(_encounter(cards, ally_sp, enemy_hp), _rng())


func _test_setup_places_units() -> void:
	var state: BattleState = _state([])
	check_eq("three units total", state.units.size(), 3)
	check_eq("one living ally", state.living_units(Unit.Team.ALLY).size(), 1)
	check_eq("two living enemies", state.living_units(Unit.Team.ENEMY).size(), 2)
	check_eq("resolver knows ally grid", state.resolver.ally_grid, Vector2i(3, 3))
	check("unit ids are unique", state.units[0].unit_id != state.units[1].unit_id)


func _test_play_card_damages_and_spends_sp() -> void:
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	var state: BattleState = _state([strike])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [strike]

	var played: bool = state.play_card(0, front)
	check("card was played", played)
	check_eq("target lost hp", front.hp, 4)
	check_eq("sp spent", ally.sp, 4)
	check_eq("hand emptied", ally.hand.size(), 0)
	check_eq("card went to discard", ally.discard.size(), 1)


func _test_play_card_rejected_without_sp() -> void:
	var pricey: CardData = _card(&"pricey", 9, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	var state: BattleState = _state([pricey], 2)
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [pricey]

	check("play rejected", not state.play_card(0, front))
	check_eq("target untouched", front.hp, 10)
	check_eq("sp untouched", ally.sp, 2)
	check_eq("card stays in hand", ally.hand.size(), 1)


func _test_play_card_rejected_on_blocked_target() -> void:
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 4, 6)
	var state: BattleState = _state([strike])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var back: Unit = state.living_units(Unit.Team.ENEMY)[1]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [strike]

	check("melee cannot reach behind the front", not state.play_card(0, back))
	check_eq("back rank untouched", back.hp, 10)


func _test_sweep_hits_multiple() -> void:
	var volley: CardData = _card(&"volley", 1, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3)
	var state: BattleState = _state([volley])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [volley]

	# front 는 (0,1), back 은 (1,1) 이라 SWEEP(같은 col)은 front 만 맞는다.
	check("sweep played", state.play_card(0, front))
	check_eq("front damaged", front.hp, 7)
	check_eq("different column untouched", state.units[2].hp, 10)


func _test_battle_ends_when_enemies_wiped() -> void:
	var nuke: CardData = _card(&"nuke", 1, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 5, 99)
	var state: BattleState = _state([nuke])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [nuke]

	state.play_card(0, front)
	check("battle finished", state.finished)
	check("ally won", state.ally_won)
