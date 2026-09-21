# EncounterGenerator(맵 점 하나에서 치를 전투 구성을 뽑는 도우미) 테스트.
# 같은 시드면 같은 런이 나와야 하므로 "무작위지만 재현된다"를 여러 각도에서 확인한다.
extends TestCase

# 전투 구성 생성 스크립트.
const GeneratorScript := preload("res://Scripts/map/encounter_generator.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 아군 편성의 인원과 자리.
	_test_ally_roster_composition()
	# 같은 시드면 같은 덱.
	_test_ally_roster_is_deterministic()
	# 원본 자원 파일을 건드리지 않는다.
	_test_ally_roster_does_not_mutate_source_resource()
	# 보통 점의 적 수 범위.
	_test_regular_encounter_enemy_count()
	# 보스 점의 적 수.
	_test_boss_encounter_enemy_count()
	# 적 후보에 아군이 섞이지 않는다.
	_test_enemies_come_from_enemy_pool_only()
	# 적 자리가 겹치지 않는다.
	_test_enemy_cells_do_not_overlap()
	# 같은 시드면 같은 전투.
	_test_encounter_generation_is_deterministic()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수기를 만든다 (테스트가 매번 같은 결과를 보도록).
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 난수기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 박는다.
	rng.seed = seed_value
	# 만든 난수기를 돌려준다.
	return rng


# 아군이 세 명이고, 종류는 아군 자료이며, 자리가 정해 둔 대로인지 (아군은 무작위가 아니다).
func _test_ally_roster_composition() -> void:
	# 아군 편성을 뽑는다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(1))
	# 세 명.
	check_eq("three allies", roster.size(), 3)
	# 자리를 모아 둔다.
	var cells: Array[Vector2i] = []
	# 한 명씩 본다.
	for placement in roster:
		# 적 자료가 섞이면 안 된다.
		check("each ally is AllyData", placement.unit_data is AllyData)
		# 자리를 적어 둔다.
		cells.append(placement.cell)
	# ALLY_PLACEMENTS 에 적어 둔 순서와 자리 그대로.
	check_eq("matches vanguard/archer/scout cells", cells, [Vector2i(0, 1), Vector2i(2, 0), Vector2i(1, 2)])


# 같은 시드로 두 번 뽑으면 아군 덱이 카드 순서까지 같은지.
func _test_ally_roster_is_deterministic() -> void:
	# 같은 시드로 편성 하나.
	var a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	# 같은 시드로 편성 또 하나.
	var b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	# 아군을 한 명씩 맞춰 본다.
	for i in a.size():
		# 한쪽 덱.
		var deck_a: Array[CardData] = (a[i].unit_data as AllyData).deck
		# 다른 쪽 덱.
		var deck_b: Array[CardData] = (b[i].unit_data as AllyData).deck
		# 카드 자원은 복사본이라 그대로 비교할 수 없으므로 id 로 견준다.
		var ids_a: Array[StringName] = []
		# 다른 쪽 id 목록.
		var ids_b: Array[StringName] = []
		# 한쪽 id 를 모은다.
		for card in deck_a:
			ids_a.append(card.id)
		# 다른 쪽 id 를 모은다.
		for card in deck_b:
			ids_b.append(card.id)
		# 순서까지 같아야 한다.
		check_eq("same seed rolls the same deck for ally %d" % i, ids_a, ids_b)


# 덱을 갈아 끼울 때 .tres 원본이 아니라 복사본을 고치는지 (원본이 더럽혀지면 다음 런까지 번진다).
func _test_ally_roster_does_not_mutate_source_resource() -> void:
	# 원본 자원을 읽는다.
	var original: AllyData = load("res://Resources/units/vanguard.tres")
	# 편성을 뽑기 전 덱 장수.
	var original_size: int = original.deck.size()
	# 편성을 뽑는다 (여기서 덱을 갈아 끼운다).
	GeneratorScript.build_ally_roster(_rng(7))
	# 원본을 다시 읽는다.
	var reloaded: AllyData = load("res://Resources/units/vanguard.tres")
	# 원본 덱은 그대로여야 한다.
	check_eq("source deck size untouched", reloaded.deck.size(), original_size)


# 보통 점의 적 수가 언제나 정해 둔 범위(1~3) 안인지. 무작위라 시드를 여러 개 돌려 본다.
func _test_regular_encounter_enemy_count() -> void:
	# 시드를 바꿔 가며 확인한다.
	for seed_value in range(20):
		# 아군 편성.
		var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(seed_value))
		# 보통 점의 전투 구성.
		var encounter: EncounterData = GeneratorScript.build_encounter(_rng(seed_value), roster, false)
		# 뽑힌 적 수.
		var count: int = encounter.enemy_units.size()
		# 범위 안이어야 한다.
		check("regular enemy count in range for seed %d" % seed_value, count >= 1 and count <= 3)


# 보스 점은 무작위가 아니라 언제나 정해진 수(4)인지.
func _test_boss_encounter_enemy_count() -> void:
	# 아군 편성.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	# 보스 점의 전투 구성.
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, true)
	# 언제나 4 명.
	check_eq("boss always has 4 enemies", encounter.enemy_units.size(), 4)


# 적 후보가 아군과 한 폴더에 섞여 있으므로, 적 자리에 아군이 들어가지 않는지.
func _test_enemies_come_from_enemy_pool_only() -> void:
	# 아군 편성.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(9))
	# 적이 가장 많은 보스 점으로 확인한다.
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(9), roster, true)
	# 적을 한 명씩 본다.
	for placement in encounter.enemy_units:
		# 모두 적 자료여야 한다.
		check("enemy placement uses EnemyData", placement.unit_data is EnemyData)


# 적 종류는 겹쳐도 되지만 자리는 겹치면 안 되는지.
func _test_enemy_cells_do_not_overlap() -> void:
	# 아군 편성.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(11))
	# 적이 가장 많은 보스 점이 가장 겹치기 쉽다.
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(11), roster, true)
	# 이미 본 자리.
	var seen: Dictionary = {}
	# 겹친 적이 없으면 true 로 남는다.
	var unique: bool = true
	# 적을 한 명씩 본다.
	for placement in encounter.enemy_units:
		# 이미 누가 서 있는 자리면 겹친 것이다.
		if seen.has(placement.cell):
			unique = false
		# 본 자리로 적어 둔다.
		seen[placement.cell] = true
	# 아무도 겹치지 않았다.
	check("no two enemies share a cell", unique)


# 같은 시드로 두 번 뽑으면 적 수·자리·종류가 모두 같은지.
func _test_encounter_generation_is_deterministic() -> void:
	# 같은 시드로 편성 하나.
	var roster_a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	# 같은 시드로 편성 또 하나.
	var roster_b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	# 한쪽 전투 구성.
	var encounter_a: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_a, false)
	# 다른 쪽 전투 구성.
	var encounter_b: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_b, false)
	# 적 수가 같다.
	check_eq("same seed rolls the same enemy count", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	# 적을 한 명씩 맞춰 본다.
	for i in encounter_a.enemy_units.size():
		# 자리가 같다 (칸을 섞는 순서까지 같아야 한다).
		check_eq("same seed places enemy %d at the same cell" % i, encounter_a.enemy_units[i].cell, encounter_b.enemy_units[i].cell)
		# 종류도 같다.
		check_eq("same seed picks the same enemy %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)
