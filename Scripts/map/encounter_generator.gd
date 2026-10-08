class_name EncounterGenerator
extends RefCounted

const STARTER_DECK_SIZE: int = 8
const ALLY_GRID: Vector2i = Vector2i(3, 3)
const ENEMY_GRID: Vector2i = Vector2i(3, 3)
const CARD_DIR: String = "res://Resources/cards"
const UNIT_DIR: String = "res://Resources/units"
const ALLY_PLACEMENTS: Array[Dictionary] = [
	{"path": "res://Resources/units/vanguard.tres", "cell": Vector2i(0, 1)},
	{"path": "res://Resources/units/archer.tres", "cell": Vector2i(2, 0)},
	{"path": "res://Resources/units/scout.tres", "cell": Vector2i(1, 2)},
]
const REGULAR_ENEMY_MIN: int = 1
const REGULAR_ENEMY_MAX: int = 3
const BOSS_ENEMY_COUNT: int = 4
## 생성한 모든 전투가 쓰는 방. 방이 늘어나면 여기서 고르게 바꾼다.
const DEFAULT_ROOM_PATH: String = "res://Resources/rooms/warehouse.tres"


static func build_ally_roster(rng: RandomNumberGenerator) -> Array[UnitPlacement]:
	var cards: Array[CardData] = _load_cards()
	var roster: Array[UnitPlacement] = []
	for entry in ALLY_PLACEMENTS:
		var base: AllyData = load(entry["path"] as String)
		var ally: AllyData = base.duplicate()
		ally.deck = _random_deck(rng, cards)
		var placement := UnitPlacement.new()
		placement.unit_data = ally
		placement.cell = entry["cell"] as Vector2i
		roster.append(placement)
	return roster


static func build_encounter(rng: RandomNumberGenerator, ally_units: Array[UnitPlacement], is_boss: bool) -> EncounterData:
	return assemble_encounter(ally_units, build_enemy_placements(rng, is_boss))


## 적 구성만 무작위로 뽑는다. 일반 노드는 REGULAR_ENEMY_MIN~MAX 마리, 보스는 BOSS_ENEMY_COUNT 마리.
static func build_enemy_placements(rng: RandomNumberGenerator, is_boss: bool) -> Array[UnitPlacement]:
	var count: int = BOSS_ENEMY_COUNT if is_boss else rng.randi_range(REGULAR_ENEMY_MIN, REGULAR_ENEMY_MAX)
	return _random_enemy_placements(rng, _load_enemy_pool(), count)


## 아군 배치와 적 배치를 합쳐 전투 구성을 만든다.
static func assemble_encounter(ally_units: Array[UnitPlacement], enemy_units: Array[UnitPlacement]) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.ally_grid = ALLY_GRID
	encounter.enemy_grid = ENEMY_GRID
	encounter.ally_units = ally_units
	encounter.enemy_units = enemy_units
	encounter.room = load(DEFAULT_ROOM_PATH)
	return encounter


static func _load_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	var dir := DirAccess.open(CARD_DIR)
	if dir == null:
		return cards
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var card: CardData = load("%s/%s" % [CARD_DIR, file_name])
		if card != null:
			cards.append(card)
	return cards


static func _load_enemy_pool() -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	var dir := DirAccess.open(UNIT_DIR)
	if dir == null:
		return enemies
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var data: Resource = load("%s/%s" % [UNIT_DIR, file_name])
		if data is EnemyData:
			enemies.append(data)
	return enemies


static func _random_deck(rng: RandomNumberGenerator, pool: Array[CardData]) -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in STARTER_DECK_SIZE:
		deck.append(pool[rng.randi_range(0, pool.size() - 1)])
	return deck


static func _random_enemy_placements(rng: RandomNumberGenerator, pool: Array[EnemyData], count: int) -> Array[UnitPlacement]:
	var cells: Array[Vector2i] = _shuffled_cells(rng, ENEMY_GRID)
	var placements: Array[UnitPlacement] = []
	for i in count:
		var placement := UnitPlacement.new()
		placement.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
		placement.cell = cells[i]
		placements.append(placement)
	return placements


static func _shuffled_cells(rng: RandomNumberGenerator, grid: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in grid.y:
		for col in grid.x:
			cells.append(Vector2i(col, row))
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	return cells
