extends TestCase

const GeneratorScript := preload("res://Scripts/map/encounter_generator.gd")


func run() -> Array[Dictionary]:
	_test_ally_roster_composition()
	_test_ally_roster_is_deterministic()
	_test_ally_roster_does_not_mutate_source_resource()
	_test_regular_encounter_enemy_count()
	_test_boss_encounter_enemy_count()
	_test_enemies_come_from_enemy_pool_only()
	_test_enemy_cells_do_not_overlap()
	_test_encounter_generation_is_deterministic()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_ally_roster_composition() -> void:
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(1))
	check_eq("three allies", roster.size(), 3)
	var cells: Array[Vector2i] = []
	for placement in roster:
		check("each ally is AllyData", placement.unit_data is AllyData)
		cells.append(placement.cell)
	check_eq("matches vanguard/archer/scout cells", cells, [Vector2i(0, 1), Vector2i(2, 0), Vector2i(1, 2)])


func _test_ally_roster_is_deterministic() -> void:
	var a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	var b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	for i in a.size():
		var deck_a: Array[CardData] = (a[i].unit_data as AllyData).deck
		var deck_b: Array[CardData] = (b[i].unit_data as AllyData).deck
		var ids_a: Array[StringName] = []
		var ids_b: Array[StringName] = []
		for card in deck_a:
			ids_a.append(card.id)
		for card in deck_b:
			ids_b.append(card.id)
		check_eq("same seed rolls the same deck for ally %d" % i, ids_a, ids_b)


func _test_ally_roster_does_not_mutate_source_resource() -> void:
	var original: AllyData = load("res://Resources/units/vanguard.tres")
	var original_size: int = original.deck.size()
	GeneratorScript.build_ally_roster(_rng(7))
	var reloaded: AllyData = load("res://Resources/units/vanguard.tres")
	check_eq("source deck size untouched", reloaded.deck.size(), original_size)


func _test_regular_encounter_enemy_count() -> void:
	for seed_value in range(20):
		var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(seed_value))
		var encounter: EncounterData = GeneratorScript.build_encounter(_rng(seed_value), roster, false)
		var count: int = encounter.enemy_units.size()
		check("regular enemy count in range for seed %d" % seed_value, count >= 1 and count <= 3)


func _test_boss_encounter_enemy_count() -> void:
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, true)
	check_eq("boss always has 4 enemies", encounter.enemy_units.size(), 4)


func _test_enemies_come_from_enemy_pool_only() -> void:
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(9))
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(9), roster, true)
	for placement in encounter.enemy_units:
		check("enemy placement uses EnemyData", placement.unit_data is EnemyData)


func _test_enemy_cells_do_not_overlap() -> void:
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(11))
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(11), roster, true)
	var seen: Dictionary = {}
	var unique: bool = true
	for placement in encounter.enemy_units:
		if seen.has(placement.cell):
			unique = false
		seen[placement.cell] = true
	check("no two enemies share a cell", unique)


func _test_encounter_generation_is_deterministic() -> void:
	var roster_a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	var roster_b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	var encounter_a: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_a, false)
	var encounter_b: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_b, false)
	check_eq("same seed rolls the same enemy count", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	for i in encounter_a.enemy_units.size():
		check_eq("same seed places enemy %d at the same cell" % i, encounter_a.enemy_units[i].cell, encounter_b.enemy_units[i].cell)
		check_eq("same seed picks the same enemy %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
