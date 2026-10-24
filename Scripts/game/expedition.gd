## 원정 한 번(의뢰 하나)의 진행 상태. 노드에 의존하지 않는다.
## 구역(층)마다 왼쪽에서 오른쪽으로 진행하는 3줄 노드 지도를 만든다 (슬레이 더 스파이어·림버스 거울 던전 방식).
## 처음엔 첫 열의 노드 중 하나를 고르고, 그 뒤로는 지금 노드와 선으로 이어진 다음 열 노드만 고를 수 있다.
## 마지막 열 뒤의 출구(전투·정예·보스)를 지나면 다음 구역 지도로 넘어간다. 파티 체력은 원정 내내 이어진다.
class_name Expedition
extends RefCounted

## 줄 수.
const LANES: int = 3
## 이웃 줄로 갈라지는 길이 생길 확률.
const BRANCH_CHANCE: float = 0.45
## 적이 서는 칸 순서 (앞줄 가운데부터).
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, 2)]
## 황혼층(더 깊은 공허)으로 내려가면 적 체력·공격 배율과 자금 배율.
const DEEP_ENEMY_SCALE: float = 1.15
const DEEP_GOLD_SCALE: float = 1.5
## 황혼층 일반 전투에서 장비가 나올 확률.
const DEEP_ITEM_CHANCE: float = 0.3
## 휴식 노드 회복 비율.
const REST_HEAL: float = 0.35
## 상점 가격과 치료 비율.
const SHOP_ITEM_PRICE: int = 75
const SHOP_CARD_PRICE: int = 45
const SHOP_HEAL_PRICE: int = 30
const SHOP_HEAL: float = 0.3
## 전투 종류별 기본 자금 보상 (여기에 0 ~ GOLD_JITTER 를 더한다).
const BASE_GOLD: Dictionary = {"battle": 15, "elite": 40, "boss": 120}
const GOLD_JITTER: int = 10
## 보상·상점 카드 수와 보급·상점 장비 수.
const OFFER_COUNT: int = 3

## 마지막 열이 아닌 열의 노드 종류 확률 (누적 경계). 남은 확률은 정예 (2구역부터, 셋째 열부터) 또는 전투.
const TYPE_ODDS: Array = [[0.45, ChapterData.BATTLE], [0.68, ChapterData.EVENT], [0.78, ChapterData.REST], [0.86, ChapterData.SUPPLY]]
## 마지막 열(출구 바로 앞)의 노드 종류 확률. 남은 확률은 사건.
const LAST_COLUMN_ODDS: Array = [[0.4, ChapterData.REST], [0.75, ChapterData.BATTLE]]

var request: Dictionary
var game: GameState
var rng: RandomNumberGenerator
var floor_index: int = 0
## 이번 구역의 지도 노드 (id = 배열 번호).
var nodes: Array[ExpeditionNode] = []
## 이번 구역에서 마지막으로 마친 노드. 구역 시작 전이면 -1.
var current_id: int = -1
## 이번 구역에서 지나온 노드 id 들.
var visited: Array[int] = []
## 파티원 번호 → 현재 체력.
var hp: Dictionary = {}
## 황혼층으로 내려갔는지.
var deep: bool = false
## 공허 속의 공허 선택을 이미 했는지.
var void_choice_done: bool = false
var gold_earned: int = 0
var battles_won: int = 0
## 끝났는지와 그 결과 ("clear" / "retreat").
var finished: bool = false
var outcome: String = ""
var _used_events: Array[String] = []


func _init(p_request: Dictionary, p_game: GameState, p_rng: RandomNumberGenerator) -> void:
	request = p_request
	game = p_game
	rng = p_rng
	revive()
	_build_map()


func floor_count() -> int:
	return request["floors"]


## 출구를 뺀 지도 열 수.
func column_count() -> int:
	return request["columns"]


func floor_name() -> String:
	var names: Array = request["floor_names"]
	return names[mini(floor_index, names.size() - 1)]


func node(id: int) -> ExpeditionNode:
	return nodes[id]


func exit_id() -> int:
	return nodes.size() - 1


## 지금 고를 수 있는 노드인지.
func is_selectable(id: int) -> bool:
	if finished or id < 0 or id >= nodes.size():
		return false
	if current_id < 0:
		return nodes[id].col == 0
	return nodes[current_id].next.has(id)


func selectable_ids() -> Array[int]:
	var out: Array[int] = []
	for n in nodes:
		if is_selectable(n.id):
			out.append(n.id)
	return out


## 지금 고를 수 있는 것이 구역 출구뿐인지.
func at_exit() -> bool:
	return is_selectable(exit_id())


## 구역을 마친 직후 공허 속의 공허 선택을 해야 하는지.
func needs_void_choice() -> bool:
	return not void_choice_done and floor_index - 1 == int(request.get("void_in_void_after", -1)) and current_id < 0


func choose_deep(go_deeper: bool) -> void:
	void_choice_done = true
	deep = go_deeper


## 고른 노드를 돌려준다 (상태는 resolve_* 를 불러야 바뀐다). 고를 수 없는 노드면 null.
func pick(id: int) -> ExpeditionNode:
	return nodes[id] if is_selectable(id) else null


## 이야기 의뢰인지 (대본·정화 장면이 있다).
func is_story() -> bool:
	return request.get("story", false)


## 의뢰 대본 표("scripts")의 대본 id. 없으면 빈 문자열.
func script_id(key: String) -> String:
	return String((request.get("scripts", {}) as Dictionary).get(key, ""))


## 지금 구역에 처음 들어설 때 보여 줄 대본. 없으면 빈 문자열.
func floor_intro_id() -> String:
	var scripts: Dictionary = request.get("scripts", {})
	if deep:
		var deep_intro: String = _entry(scripts.get("deep_floor_intros", []), floor_index)
		if not deep_intro.is_empty():
			return deep_intro
	return _entry(scripts.get("floor_intros", []), floor_index)


static func _entry(list: Array, index: int) -> String:
	return String(list[index]) if index < list.size() else ""


# ---------------- 지도 생성 ----------------

func _build_map() -> void:
	nodes = []
	visited = []
	current_id = -1
	var cols: int = column_count()
	var types: Array = _roll_types(cols)
	for c in cols:
		for lane in LANES:
			nodes.append(_make_node(nodes.size(), c, lane, types[c][lane]))
	var exit_node: ExpeditionNode = _make_node(nodes.size(), cols, 1, (request["exits"] as Array)[floor_index])
	exit_node.exit = true
	nodes.append(exit_node)
	# 같은 줄로는 항상 이어지고, 이웃 줄로는 확률로 갈라진다. 선이 엇갈리지 않게 한다.
	for c in range(cols - 1):
		var went_down: Array[bool] = [false, false, false]
		for lane in LANES:
			var next: Array[int] = nodes[c * LANES + lane].next
			next.append((c + 1) * LANES + lane)
			# 위 줄로: 바로 위 노드가 아래로 내려오는 선이 있으면 엇갈리므로 막는다.
			if lane > 0 and not went_down[lane - 1] and rng.randf() < BRANCH_CHANCE:
				next.append((c + 1) * LANES + lane - 1)
			if lane < LANES - 1 and rng.randf() < BRANCH_CHANCE:
				next.append((c + 1) * LANES + lane + 1)
				went_down[lane] = true
	for lane in LANES:
		nodes[(cols - 1) * LANES + lane].next.append(exit_id())


func _make_node(id: int, col: int, lane: int, t: String) -> ExpeditionNode:
	var n := ExpeditionNode.new(id, col, lane, t)
	if n.is_battle():
		n.enemies.assign(_roll_enemies(t))
	elif t == ChapterData.EVENT:
		n.event = _roll_event()
	return n


## 열마다 3줄의 노드 종류. 첫 열은 전투 위주, 상점은 구역마다 하나, 마지막 열은 휴식이 잘 나온다.
func _roll_types(cols: int) -> Array:
	var grid: Array = []
	for c in cols:
		var column: Array = []
		for lane in LANES:
			column.append(_roll_type(c, cols))
		grid.append(column)
	# 첫 열: 전투 둘 + 사건 하나.
	grid[0] = [ChapterData.BATTLE, ChapterData.BATTLE, ChapterData.EVENT]
	_shuffle(grid[0])
	# 상점 하나를 가운데 열 어딘가에.
	if cols >= 3:
		var shop_col: int = rng.randi_range(1, cols - 2)
		grid[shop_col][rng.randi_range(0, LANES - 1)] = ChapterData.SHOP
	return grid


func _roll_type(col: int, cols: int) -> String:
	var roll: float = rng.randf()
	if col == cols - 1:
		return _from_odds(roll, LAST_COLUMN_ODDS, ChapterData.EVENT)
	var elite_ok: bool = floor_index >= 1 and col >= 2
	return _from_odds(roll, TYPE_ODDS, ChapterData.ELITE if elite_ok else ChapterData.BATTLE)


static func _from_odds(roll: float, odds: Array, fallback: String) -> String:
	for entry in odds:
		if roll < float(entry[0]):
			return entry[1]
	return fallback


func _roll_enemies(t: String) -> Array:
	match t:
		ChapterData.BOSS:
			return request["boss"]
		ChapterData.ELITE:
			return _choose(request["elites"])
	var pools: Array = request["pools"]
	return _choose(pools[mini(floor_index, pools.size() - 1)])


func _roll_event() -> String:
	var events: Array = request["events"]
	var fresh: Array = events.filter(func(e: String) -> bool: return not _used_events.has(e))
	var picked: String = _choose(fresh if not fresh.is_empty() else events)
	_used_events.append(picked)
	return picked


func _choose(list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


# ---------------- 전투 ----------------

## 노드의 전투 구성. 아군은 지금 파티(장비 반영)와 이어진 체력으로, 적은 노드의 무리로.
func encounter_for(n: ExpeditionNode) -> EncounterData:
	var allies: Array[UnitPlacement] = game.party.build_battle_roster()
	for i in allies.size():
		allies[i].start_hp = maxi(int(hp.get(i, 1)), 1)
	return build_encounter(allies, n.enemies, _room_for(n), DEEP_ENEMY_SCALE if deep else 1.0)


## 아군 배치와 적 id 들로 전투를 만든다. 적은 ENEMY_CELLS 순서로 서고,
## scale 이 1 이 아니면 체력·공격을 키운 복사본을 쓴다 (원본 .tres 는 그대로).
static func build_encounter(allies: Array[UnitPlacement], enemy_ids: Array[String], room_id: String, scale: float = 1.0) -> EncounterData:
	var enemies: Array[UnitPlacement] = []
	for i in enemy_ids.size():
		var data: EnemyData = Content.unit(enemy_ids[i])
		if not is_equal_approx(scale, 1.0):
			var base: EnemyData = data
			data = base.duplicate()
			data.max_hp = roundi(base.max_hp * scale)
			data.attack = roundi(base.attack * scale)
		enemies.append(Content.placement_of(data, ENEMY_CELLS[i]))
	var encounter: EncounterData = EncounterGenerator.assemble_encounter(allies, enemies)
	encounter.room = Content.room(room_id)
	return encounter


func _room_for(n: ExpeditionNode) -> String:
	if n.type == ChapterData.BOSS:
		return request["boss_room"]
	return request["deep_room"] if deep else request["room"]


## 이긴 전투의 결과를 반영한다. ally_hp 는 파티원 번호 순서의 남은 체력 (쓰러진 파티원은 1 로 일어난다).
func resolve_battle_win(n: ExpeditionNode, ally_hp: Array) -> void:
	for i in ally_hp.size():
		hp[i] = maxi(int(ally_hp[i]), 1)
	battles_won += 1
	_complete(n)


## 전투 종류에 맞는 보상을 굴린다. 자금은 아직 주지 않는다 (add_gold 로 준다).
func battle_reward(n: ExpeditionNode) -> BattleReward:
	var reward := BattleReward.new()
	var gold: int = int(BASE_GOLD.get(n.type, BASE_GOLD[ChapterData.BATTLE])) + rng.randi_range(0, GOLD_JITTER)
	reward.gold = roundi(gold * DEEP_GOLD_SCALE) if deep else gold
	reward.cards = card_choices(OFFER_COUNT)
	if n.type == ChapterData.ELITE or n.type == ChapterData.BOSS or (deep and rng.randf() < DEEP_ITEM_CHANCE):
		reward.item = ItemPool.roll(rng, ItemPool.load_all())
	return reward


## 파티원 보상 풀에서 서로 다른 카드 count 장.
func card_choices(count: int) -> Array[CardOffer]:
	return reward_cards(game, rng, count)


## 파티원 보상 풀에서 서로 다른 카드 count 장을 뽑는다 (원정 밖 선물에도 쓴다).
static func reward_cards(state: GameState, random: RandomNumberGenerator, count: int) -> Array[CardOffer]:
	var candidates: Array = []
	for i in state.party.member_count():
		for card_id in ChapterData.REWARD_CARDS.get(String(state.party.member_data(i).id), []):
			candidates.append([i, card_id])
	var offers: Array[CardOffer] = []
	for k in mini(count, candidates.size()):
		var entry: Array = candidates.pop_at(random.randi_range(0, candidates.size() - 1))
		offers.append(CardOffer.new(entry[0], Content.card(entry[1])))
	return offers


func add_gold(amount: int) -> void:
	gold_earned += amount
	game.add_gold(amount)


# ---------------- 그 밖의 노드 ----------------

## 휴식: 모두 최대 체력의 REST_HEAL 만큼 회복.
func resolve_rest(n: ExpeditionNode) -> void:
	heal_party(REST_HEAL)
	_complete(n)


## 사건·보급·상점을 마쳤다.
func resolve_simple(n: ExpeditionNode) -> void:
	_complete(n)


## 모든 파티원을 최대 체력의 ratio 만큼 회복 (음수면 피해, 1 아래로는 내려가지 않음).
func heal_party(ratio: float) -> void:
	for i in hp:
		var max_hp: int = _max_hp(i)
		hp[i] = clampi(int(hp[i]) + roundi(max_hp * ratio), 1, max_hp)


func supply_choices() -> Array[ItemData]:
	var pool: Array[ItemData] = ItemPool.load_all()
	var out: Array[ItemData] = []
	for i in OFFER_COUNT:
		out.append(ItemPool.roll(rng, pool))
	return out


func shop_stock() -> ShopStock:
	var stock := ShopStock.new()
	for item in supply_choices():
		stock.items.append(ShopStock.ItemOffer.new(item, SHOP_ITEM_PRICE + rng.randi_range(-10, 15)))
	for offer in card_choices(OFFER_COUNT):
		offer.price = SHOP_CARD_PRICE + rng.randi_range(-5, 15)
		stock.cards.append(offer)
	stock.heal_price = SHOP_HEAL_PRICE
	return stock


## 자금을 내고 산다. 모자라면 false.
func spend(price: int) -> bool:
	if game.gold < price:
		return false
	game.add_gold(-price)
	return true


## 모든 파티원의 체력을 가득 채운다 (원정 시작, 전멸 뒤 되살아남).
func revive() -> void:
	for i in game.party.member_count():
		hp[i] = _max_hp(i)


func retreat() -> void:
	finished = true
	outcome = "retreat"


## 노드를 마쳤다: 그 노드가 지금 위치가 되고, 출구였다면 다음 구역 지도로 넘어간다.
func _complete(n: ExpeditionNode) -> void:
	if n == null or not is_selectable(n.id):
		return
	visited.append(n.id)
	current_id = n.id
	if n.exit:
		floor_index += 1
		if floor_index >= floor_count():
			finished = true
			outcome = "clear"
			return
		_build_map()


## 파티원 번호 → 최대 체력 대비 비율 (화면용).
func hp_ratio(index: int) -> float:
	return float(hp.get(index, 0)) / float(maxi(_max_hp(index), 1))


func _max_hp(index: int) -> int:
	return game.party.stats(index)["max_hp"]
