## 전투 구성(EncounterData)을 만드는 도구. 시작 파티(아군 배치 + 무작위 덱)와 무작위 적 배치를 뽑는다.
## 모든 함수가 정적이고, 난수는 호출하는 쪽의 rng 를 써서 같은 시드면 같은 결과가 나온다.
class_name EncounterGenerator
# RefCounted: 노드가 아닌 가벼운 객체. 정적 함수만 쓰므로 만들 일은 없다.
extends RefCounted

## 시작 덱의 카드 장수.
const STARTER_DECK_SIZE: int = 8
## 아군 격자 크기 (열 × 행).
const ALLY_GRID: Vector2i = Vector2i(3, 3)
## 적 격자 크기 (열 × 행).
const ENEMY_GRID: Vector2i = Vector2i(3, 3)
## 덱에 넣을 카드를 고르는 폴더.
const CARD_DIR: String = "res://Resources/cards"
## 적 종류를 고르는 폴더 (EnemyData 만 골라 쓴다).
const UNIT_DIR: String = "res://Resources/units"
## 시작 파티: 아군 데이터 파일과 서는 칸.
const ALLY_PLACEMENTS: Array[Dictionary] = [
	{"path": "res://Resources/units/vanguard.tres", "cell": Vector2i(0, 1)},
	{"path": "res://Resources/units/archer.tres", "cell": Vector2i(2, 0)},
	{"path": "res://Resources/units/scout.tres", "cell": Vector2i(1, 2)},
]
## 일반 전투의 적 수 최솟값.
const REGULAR_ENEMY_MIN: int = 1
## 일반 전투의 적 수 최댓값.
const REGULAR_ENEMY_MAX: int = 3
## 보스 전투의 적 수.
const BOSS_ENEMY_COUNT: int = 4
## 생성한 모든 전투가 쓰는 방. 방이 늘어나면 여기서 고르게 바꾼다.
const DEFAULT_ROOM_PATH: String = "res://Resources/rooms/warehouse.tres"


## 시작 파티를 만든다. 아군마다 카드 폴더에서 무작위로 STARTER_DECK_SIZE 장을 뽑아 덱을 채운다.
static func build_ally_roster(rng: RandomNumberGenerator) -> Array[UnitPlacement]:
	# 뽑을 수 있는 카드 전부.
	var cards: Array[CardData] = _load_cards()
	# 만든 아군 배치 목록.
	var roster: Array[UnitPlacement] = []
	# 시작 파티 정의를 하나씩 본다.
	for entry in ALLY_PLACEMENTS:
		# 원본 아군 데이터를 불러온다.
		var base: AllyData = load(entry["path"] as String)
		# 복사본을 만든다 — 원본 .tres 의 덱을 바꾸지 않기 위해서다.
		var ally: AllyData = base.duplicate()
		# 무작위 덱을 넣는다.
		ally.deck = _random_deck(rng, cards)
		# 배치 정보를 만든다.
		var placement := UnitPlacement.new()
		# 유닛 데이터를 넣는다.
		placement.unit_data = ally
		# 서는 칸을 넣는다.
		placement.cell = entry["cell"] as Vector2i
		# 목록에 추가한다.
		roster.append(placement)
	# 완성된 파티를 돌려준다.
	return roster


## 아군 배치에 무작위 적을 붙여 전투 구성 하나를 만든다.
static func build_encounter(rng: RandomNumberGenerator, ally_units: Array[UnitPlacement], is_boss: bool) -> EncounterData:
	# 적을 뽑아 아군과 합친다.
	return assemble_encounter(ally_units, build_enemy_placements(rng, is_boss))


## 적 구성만 무작위로 뽑는다. 일반 노드는 REGULAR_ENEMY_MIN~MAX 마리, 보스는 BOSS_ENEMY_COUNT 마리.
static func build_enemy_placements(rng: RandomNumberGenerator, is_boss: bool) -> Array[UnitPlacement]:
	# 적 수를 정한다 (보스는 고정, 일반은 무작위).
	var count: int = BOSS_ENEMY_COUNT if is_boss else rng.randi_range(REGULAR_ENEMY_MIN, REGULAR_ENEMY_MAX)
	# 적 종류 풀에서 그 수만큼 뽑아 칸에 놓는다.
	return _random_enemy_placements(rng, _load_enemy_pool(), count)


## 아군 배치와 적 배치를 합쳐 전투 구성을 만든다.
static func assemble_encounter(ally_units: Array[UnitPlacement], enemy_units: Array[UnitPlacement]) -> EncounterData:
	# 빈 전투 구성을 만든다.
	var encounter := EncounterData.new()
	# 아군 격자 크기.
	encounter.ally_grid = ALLY_GRID
	# 적 격자 크기.
	encounter.enemy_grid = ENEMY_GRID
	# 아군 배치.
	encounter.ally_units = ally_units
	# 적 배치.
	encounter.enemy_units = enemy_units
	# 전투가 벌어질 방.
	encounter.room = load(DEFAULT_ROOM_PATH)
	# 완성된 구성을 돌려준다.
	return encounter


## 카드 폴더의 모든 카드를 불러온다.
static func _load_cards() -> Array[CardData]:
	# 불러온 카드 목록.
	var cards: Array[CardData] = []
	# 파일을 하나씩 본다. DirAccess.get_files 는 내보낸 빌드에서 "x.tres.remap" 을 돌려주므로 ResourceLoader 로 나열한다.
	for file_name in ResourceLoader.list_directory(CARD_DIR):
		# 리소스 파일이 아니면 건너뛴다.
		if not file_name.ends_with(".tres"):
			continue
		# 카드로 불러온다.
		var card: CardData = load("%s/%s" % [CARD_DIR, file_name])
		# 불러오기에 성공했으면 목록에 넣는다.
		if card != null:
			cards.append(card)
	# 다 모은 목록을 돌려준다.
	return cards


## 유닛 폴더에서 적 데이터(EnemyData)만 골라 불러온다.
static func _load_enemy_pool() -> Array[EnemyData]:
	# 불러온 적 종류 목록.
	var enemies: Array[EnemyData] = []
	# 파일을 하나씩 본다. DirAccess.get_files 는 내보낸 빌드에서 "x.tres.remap" 을 돌려주므로 ResourceLoader 로 나열한다.
	for file_name in ResourceLoader.list_directory(UNIT_DIR):
		# 리소스 파일이 아니면 건너뛴다.
		if not file_name.ends_with(".tres"):
			continue
		# 일단 리소스로 불러온다 (아군 데이터도 같은 폴더에 있다).
		var data: Resource = load("%s/%s" % [UNIT_DIR, file_name])
		# 적 데이터일 때만 넣는다.
		if data is EnemyData:
			enemies.append(data)
	# 다 모은 목록을 돌려준다.
	return enemies


## 카드 풀에서 중복을 허용해 STARTER_DECK_SIZE 장을 뽑는다.
static func _random_deck(rng: RandomNumberGenerator, pool: Array[CardData]) -> Array[CardData]:
	# 만들 덱.
	var deck: Array[CardData] = []
	# 정해진 장수만큼 반복한다.
	for i in STARTER_DECK_SIZE:
		# 풀의 무작위 카드를 넣는다.
		deck.append(pool[rng.randi_range(0, pool.size() - 1)])
	# 완성된 덱을 돌려준다.
	return deck


## 적 count 마리를 뽑아 서로 다른 칸에 놓는다.
static func _random_enemy_placements(rng: RandomNumberGenerator, pool: Array[EnemyData], count: int) -> Array[UnitPlacement]:
	# 적 격자의 칸을 섞어 둔다 — 앞에서부터 쓰면 칸이 겹치지 않는다.
	var cells: Array[Vector2i] = _shuffled_cells(rng, ENEMY_GRID)
	# 만든 적 배치 목록.
	var placements: Array[UnitPlacement] = []
	# 적 수만큼 반복한다.
	for i in count:
		# 배치 정보를 만든다.
		var placement := UnitPlacement.new()
		# 적 종류를 무작위로 고른다 (같은 종류가 여러 번 나올 수 있다).
		placement.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
		# 섞인 칸을 차례로 쓴다.
		placement.cell = cells[i]
		# 목록에 추가한다.
		placements.append(placement)
	# 완성된 적 배치를 돌려준다.
	return placements


## 격자의 모든 칸을 무작위 순서로 돌려준다.
static func _shuffled_cells(rng: RandomNumberGenerator, grid: Vector2i) -> Array[Vector2i]:
	# 칸 목록.
	var cells: Array[Vector2i] = []
	# 행마다.
	for row in grid.y:
		# 열마다.
		for col in grid.x:
			# 칸 좌표를 넣는다.
			cells.append(Vector2i(col, row))
	# Fisher–Yates 방식으로 섞는다: 마지막 칸부터 두 번째 칸까지 거꾸로 내려간다.
	for i in range(cells.size() - 1, 0, -1):
		# 0 부터 i 사이에서 무작위 칸을 고른다.
		var j: int = rng.randi_range(0, i)
		# i 칸을 잠시 보관한다.
		var swap: Vector2i = cells[i]
		# j 칸을 i 칸에 넣는다.
		cells[i] = cells[j]
		# 보관한 칸을 j 칸에 넣어 맞바꾼다.
		cells[j] = swap
	# 섞인 칸 목록을 돌려준다.
	return cells
