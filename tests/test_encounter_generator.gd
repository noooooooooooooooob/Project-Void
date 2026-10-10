# EncounterGenerator(전투 구성 생성기) 테스트: 시작 파티, 적 수, 적 종류, 칸 겹침, 시드 재현, 방, 조립.
extends TestCase

# 전투 구성 생성기 스크립트.
const GeneratorScript := preload("res://Scripts/map/encounter_generator.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작 파티 구성.
	_test_ally_roster_composition()
	# 같은 시드면 같은 덱.
	_test_ally_roster_is_deterministic()
	# 원본 아군 데이터를 바꾸지 않는다.
	_test_ally_roster_does_not_mutate_source_resource()
	# 일반 전투의 적 수.
	_test_regular_encounter_enemy_count()
	# 보스 전투의 적 수.
	_test_boss_encounter_enemy_count()
	# 적은 적 데이터에서만 나온다.
	_test_enemies_come_from_enemy_pool_only()
	# 적끼리 칸이 겹치지 않는다.
	_test_enemy_cells_do_not_overlap()
	# 같은 시드면 같은 적 구성.
	_test_encounter_generation_is_deterministic()
	# 생성된 전투는 기본 방을 쓴다.
	_test_generated_encounters_use_the_room()
	# 조립은 넘긴 아군·적을 그대로 쓴다.
	_test_assemble_encounter_keeps_both_sides()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수 생성기 (생성 결과를 재현하기 위해).
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 돌려준다.
	return rng


# 시작 파티는 아군 3 명이 정해진 칸에 선다.
func _test_ally_roster_composition() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(1))
	# 3 명.
	check_eq("three allies", roster.size(), 3)
	# 선 칸 모음.
	var cells: Array[Vector2i] = []
	# 파티원마다.
	for placement in roster:
		# 아군 데이터다.
		check("each ally is AllyData", placement.unit_data is AllyData)
		# 칸을 모은다.
		cells.append(placement.cell)
	# 선봉·궁수·정찰병 칸과 같다.
	check_eq("matches vanguard/archer/scout cells", cells, [Vector2i(0, 1), Vector2i(2, 0), Vector2i(1, 2)])


# 같은 시드로 만들면 아군마다 같은 덱이 나온다.
func _test_ally_roster_is_deterministic() -> void:
	# 시드 42 로 한 번.
	var a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	# 시드 42 로 또 한 번.
	var b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(42))
	# 아군마다.
	for i in a.size():
		# 첫 번째 결과의 덱.
		var deck_a: Array[CardData] = (a[i].unit_data as AllyData).deck
		# 두 번째 결과의 덱.
		var deck_b: Array[CardData] = (b[i].unit_data as AllyData).deck
		# 카드 id 목록 (첫 번째).
		var ids_a: Array[StringName] = []
		# 카드 id 목록 (두 번째).
		var ids_b: Array[StringName] = []
		# 첫 번째 덱의 id 를 모은다.
		for card in deck_a:
			ids_a.append(card.id)
		# 두 번째 덱의 id 를 모은다.
		for card in deck_b:
			ids_b.append(card.id)
		# 둘이 같다.
		check_eq("same seed rolls the same deck for ally %d" % i, ids_a, ids_b)


# 파티를 만들어도 원본 .tres 의 덱은 그대로다.
func _test_ally_roster_does_not_mutate_source_resource() -> void:
	# 원본 선봉 데이터.
	var original: AllyData = load("res://Resources/units/vanguard.tres")
	# 원본 덱 장수.
	var original_size: int = original.deck.size()
	# 파티를 만든다.
	GeneratorScript.build_ally_roster(_rng(7))
	# 다시 불러온다 (캐시된 같은 객체라 바뀌었다면 바로 드러난다).
	var reloaded: AllyData = load("res://Resources/units/vanguard.tres")
	# 장수가 그대로다.
	check_eq("source deck size untouched", reloaded.deck.size(), original_size)


# 일반 전투의 적 수는 여러 시드에서 늘 1~3 마리다.
func _test_regular_encounter_enemy_count() -> void:
	# 시드 0~19.
	for seed_value in range(20):
		# 파티를 만든다.
		var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(seed_value))
		# 일반 전투를 만든다.
		var encounter: EncounterData = GeneratorScript.build_encounter(_rng(seed_value), roster, false)
		# 적 수.
		var count: int = encounter.enemy_units.size()
		# 1~3 마리.
		check("regular enemy count in range for seed %d" % seed_value, count >= 1 and count <= 3)


# 보스 전투는 늘 4 마리.
func _test_boss_encounter_enemy_count() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	# 보스 전투를 만든다.
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, true)
	# 4 마리.
	check_eq("boss always has 4 enemies", encounter.enemy_units.size(), 4)


# 적 자리에는 적 데이터만 들어간다 (같은 폴더의 아군 데이터가 섞이지 않는다).
func _test_enemies_come_from_enemy_pool_only() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(9))
	# 보스 전투를 만든다 (적이 가장 많다).
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(9), roster, true)
	# 적마다.
	for placement in encounter.enemy_units:
		# 적 데이터다.
		check("enemy placement uses EnemyData", placement.unit_data is EnemyData)


# 적끼리 같은 칸에 서지 않는다.
func _test_enemy_cells_do_not_overlap() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(11))
	# 보스 전투를 만든다 (적이 가장 많다).
	var encounter: EncounterData = GeneratorScript.build_encounter(_rng(11), roster, true)
	# 이미 나온 칸.
	var seen: Dictionary = {}
	# 겹침이 없으면 true 로 남는다.
	var unique: bool = true
	# 적마다.
	for placement in encounter.enemy_units:
		# 이미 나온 칸이면 겹침.
		if seen.has(placement.cell):
			unique = false
		# 칸을 기록한다.
		seen[placement.cell] = true
	# 겹침이 없다.
	check("no two enemies share a cell", unique)


# 같은 시드로 만들면 적 수·칸·종류가 모두 같다.
func _test_encounter_generation_is_deterministic() -> void:
	# 시드 55 파티 (첫 번째).
	var roster_a: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	# 시드 55 파티 (두 번째).
	var roster_b: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(55))
	# 시드 55 전투 (첫 번째).
	var encounter_a: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_a, false)
	# 시드 55 전투 (두 번째).
	var encounter_b: EncounterData = GeneratorScript.build_encounter(_rng(55), roster_b, false)
	# 적 수가 같다.
	check_eq("same seed rolls the same enemy count", encounter_a.enemy_units.size(), encounter_b.enemy_units.size())
	# 적마다.
	for i in encounter_a.enemy_units.size():
		# 칸이 같다.
		check_eq("same seed places enemy %d at the same cell" % i, encounter_a.enemy_units[i].cell, encounter_b.enemy_units[i].cell)
		# 종류가 같다.
		check_eq("same seed picks the same enemy %d" % i, encounter_a.enemy_units[i].unit_data.id, encounter_b.enemy_units[i].unit_data.id)


# 일반·보스 전투 모두 기본 방(창고)을 쓴다.
func _test_generated_encounters_use_the_room() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	# 일반 전투.
	var regular: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, false)
	# 보스 전투.
	var boss: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, true)
	# 방이 있고, 기본 방 파일이며, 보스 전투도 같은 방이다.
	check("generated encounters use the warehouse room", regular.room != null and regular.room.resource_path == GeneratorScript.DEFAULT_ROOM_PATH and boss.room == regular.room)


# 조립은 넘긴 아군·적 배열을 그대로 쓰고 표준 격자 크기를 넣는다.
func _test_assemble_encounter_keeps_both_sides() -> void:
	# 파티를 만든다.
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	# 적 배치를 따로 뽑는다.
	var enemies: Array[UnitPlacement] = GeneratorScript.build_enemy_placements(_rng(3), false)
	# 조립한다.
	var encounter: EncounterData = GeneratorScript.assemble_encounter(roster, enemies)
	# 아군이 그대로.
	check("assembled encounter keeps the given allies", encounter.ally_units == roster)
	# 적이 그대로.
	check("assembled encounter keeps the given enemies", encounter.enemy_units == enemies)
	# 격자 크기가 표준.
	check_eq("assembled encounter uses the standard grids", [encounter.ally_grid, encounter.enemy_grid], [GeneratorScript.ALLY_GRID, GeneratorScript.ENEMY_GRID])
