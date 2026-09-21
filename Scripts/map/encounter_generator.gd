## 맵의 점 하나에서 치를 전투 구성(EncounterData)을 뽑아 주는 도우미 (노드 없음, 순수 계산).
## 카드와 적 자료는 Resources/ 폴더를 훑어 모으므로, 파일을 새로 넣기만 하면 후보에 들어간다.
## 모든 무작위는 넘겨받은 난수기 하나만 쓴다 — 같은 시드면 같은 런이 나와야 한다.
class_name EncounterGenerator
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 아군 한 명이 시작할 때 들고 가는 덱 장수.
const STARTER_DECK_SIZE: int = 8
## 아군 격자 크기 (x = 열 수, y = 행 수).
const ALLY_GRID: Vector2i = Vector2i(3, 3)
## 적군 격자 크기 (x = 열 수, y = 행 수).
const ENEMY_GRID: Vector2i = Vector2i(3, 3)
## 카드 자료를 모을 폴더.
const CARD_DIR: String = "res://Resources/cards"
## 유닛 자료를 모을 폴더 (아군·적군이 섞여 있다).
const UNIT_DIR: String = "res://Resources/units"
## 아군 세 명과 각자 설 칸. 적과 달리 아군은 무작위로 뽑지 않고 이 편성을 고정으로 쓴다.
const ALLY_PLACEMENTS: Array[Dictionary] = [
	{"path": "res://Resources/units/vanguard.tres", "cell": Vector2i(0, 1)},
	{"path": "res://Resources/units/archer.tres", "cell": Vector2i(2, 0)},
	{"path": "res://Resources/units/scout.tres", "cell": Vector2i(1, 2)},
]
## 보통 점에 나오는 적의 최소 수.
const REGULAR_ENEMY_MIN: int = 1
## 보통 점에 나오는 적의 최대 수.
const REGULAR_ENEMY_MAX: int = 3
## 보스 점에 나오는 적의 수 (무작위가 아니라 고정).
const BOSS_ENEMY_COUNT: int = 4


## 런 내내 쓸 아군 편성을 만든다. 자리는 고정이고 덱만 무작위로 뽑는다.
static func build_ally_roster(rng: RandomNumberGenerator) -> Array[UnitPlacement]:
	# 덱을 채울 카드 후보를 모은다.
	var cards: Array[CardData] = _load_cards()
	# 만들어 나갈 편성.
	var roster: Array[UnitPlacement] = []
	# 아군을 한 명씩 만든다.
	for entry in ALLY_PLACEMENTS:
		# 파일에 저장된 원본 자료.
		var base: AllyData = load(entry["path"] as String)
		# 원본을 복사해 쓴다 — 덱을 갈아 끼울 때 파일 쪽 자원이 바뀌면 안 된다.
		var ally: AllyData = base.duplicate()
		# 이 아군만의 덱을 뽑아 넣는다.
		ally.deck = _random_deck(rng, cards)
		# 유닛과 설 칸을 묶는다.
		var placement := UnitPlacement.new()
		# 방금 만든 아군 자료.
		placement.unit_data = ally
		# 정해 둔 자리.
		placement.cell = entry["cell"] as Vector2i
		# 편성에 넣는다.
		roster.append(placement)
	# 완성된 편성을 돌려준다.
	return roster


## 점 하나의 전투 구성을 만든다. 아군 편성은 런 전체가 나눠 쓰는 것을 그대로 받아 넣는다.
static func build_encounter(rng: RandomNumberGenerator, ally_units: Array[UnitPlacement], is_boss: bool) -> EncounterData:
	# 빈 전투 구성.
	var encounter := EncounterData.new()
	# 아군 격자 크기.
	encounter.ally_grid = ALLY_GRID
	# 적군 격자 크기.
	encounter.enemy_grid = ENEMY_GRID
	# 받은 아군 편성을 그대로 쓴다.
	encounter.ally_units = ally_units
	# 보스는 적 수가 고정, 보통 점은 범위 안에서 뽑는다.
	var count: int = BOSS_ENEMY_COUNT if is_boss else rng.randi_range(REGULAR_ENEMY_MIN, REGULAR_ENEMY_MAX)
	# 적 종류와 자리를 뽑아 넣는다.
	encounter.enemy_units = _random_enemy_placements(rng, _load_enemy_pool(), count)
	# 완성된 구성을 돌려준다.
	return encounter


## 카드 폴더를 훑어 카드 자료를 모두 모은다.
static func _load_cards() -> Array[CardData]:
	# 모아 나갈 카드 목록.
	var cards: Array[CardData] = []
	# 폴더를 연다.
	var dir := DirAccess.open(CARD_DIR)
	# 폴더가 없으면 빈 목록으로 둔다.
	if dir == null:
		return cards
	# 폴더 안 파일을 하나씩 본다.
	for file_name in dir.get_files():
		# 자원 파일만 본다.
		if not file_name.ends_with(".tres"):
			continue
		# 파일을 읽는다.
		var card: CardData = load("%s/%s" % [CARD_DIR, file_name])
		# 카드로 읽히지 않으면 건너뛴다.
		if card != null:
			cards.append(card)
	# 모은 카드를 돌려준다.
	return cards


## 유닛 폴더를 훑어 적 자료만 골라 모은다.
static func _load_enemy_pool() -> Array[EnemyData]:
	# 모아 나갈 적 목록.
	var enemies: Array[EnemyData] = []
	# 폴더를 연다.
	var dir := DirAccess.open(UNIT_DIR)
	# 폴더가 없으면 빈 목록으로 둔다.
	if dir == null:
		return enemies
	# 폴더 안 파일을 하나씩 본다.
	for file_name in dir.get_files():
		# 자원 파일만 본다.
		if not file_name.ends_with(".tres"):
			continue
		# 파일을 읽는다.
		var data: Resource = load("%s/%s" % [UNIT_DIR, file_name])
		# 같은 폴더에 아군 자료도 있으므로 적만 골라 담는다.
		if data is EnemyData:
			enemies.append(data)
	# 모은 적을 돌려준다.
	return enemies


## 후보 카드에서 덱 한 벌을 뽑는다. 같은 카드가 여러 장 들어올 수 있다.
static func _random_deck(rng: RandomNumberGenerator, pool: Array[CardData]) -> Array[CardData]:
	# 만들어 나갈 덱.
	var deck: Array[CardData] = []
	# 정해진 장수만큼 뽑는다.
	for i in STARTER_DECK_SIZE:
		# 후보 중 아무거나 한 장.
		deck.append(pool[rng.randi_range(0, pool.size() - 1)])
	# 완성된 덱을 돌려준다.
	return deck


## 적 종류와 자리를 뽑는다. 종류는 겹칠 수 있지만 자리는 겹치지 않는다.
static func _random_enemy_placements(rng: RandomNumberGenerator, pool: Array[EnemyData], count: int) -> Array[UnitPlacement]:
	# 칸을 미리 섞어 두면 앞에서부터 꺼내는 것만으로 자리가 겹치지 않는다.
	var cells: Array[Vector2i] = _shuffled_cells(rng, ENEMY_GRID)
	# 만들어 나갈 배치.
	var placements: Array[UnitPlacement] = []
	# 적을 한 명씩 놓는다.
	for i in count:
		# 유닛과 설 칸을 묶는다.
		var placement := UnitPlacement.new()
		# 종류는 후보 중 아무거나 (겹쳐도 된다).
		placement.unit_data = pool[rng.randi_range(0, pool.size() - 1)]
		# 자리는 섞어 둔 칸에서 앞에서부터 꺼낸다.
		placement.cell = cells[i]
		# 배치에 넣는다.
		placements.append(placement)
	# 완성된 배치를 돌려준다.
	return placements


## 격자의 모든 칸을 만들어 섞는다. Array.shuffle 은 전역 난수를 쓰므로 직접 섞는다.
static func _shuffled_cells(rng: RandomNumberGenerator, grid: Vector2i) -> Array[Vector2i]:
	# 모아 나갈 칸 목록.
	var cells: Array[Vector2i] = []
	# 행을 훑는다.
	for row in grid.y:
		# 그 행의 열을 훑는다.
		for col in grid.x:
			# 칸 하나를 넣는다.
			cells.append(Vector2i(col, row))
	# 피셔-예이츠: 뒤에서부터 앞쪽 아무 칸과 맞바꾼다.
	for i in range(cells.size() - 1, 0, -1):
		# 자기 자신을 포함한 앞쪽 중 하나를 고른다.
		var j: int = rng.randi_range(0, i)
		# 두 칸을 맞바꾼다.
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	# 섞은 칸을 돌려준다.
	return cells
