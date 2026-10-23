## 원정 한 번(의뢰 하나)의 진행 상태. 노드에 의존하지 않는다.
## 구역(층)마다 왼쪽에서 오른쪽으로 진행하는 3줄 노드 지도를 만든다 (슬레이 더 스파이어·림버스 거울 던전 방식).
## 처음엔 첫 열의 노드 중 하나를 고르고, 그 뒤로는 지금 노드와 선으로 이어진 다음 열 노드만 고를 수 있다.
## 마지막 열 뒤의 출구(전투·정예·보스)를 지나면 다음 구역 지도로 넘어간다. 파티 체력은 원정 내내 이어진다.
class_name Expedition
extends RefCounted

## 노드(Dictionary): {"id", "col", "lane", "type", "next": Array[int], "exit": bool, "enemies"(전투류), "event"(사건)}
const UNIT_DIR: String = "res://Resources/content/units"
const ROOM_DIR: String = "res://Resources/content/rooms"
const CARD_DIR: String = "res://Resources/content/cards"
## 줄 수.
const LANES: int = 3
## 이웃 줄로 갈라지는 길이 생길 확률.
const BRANCH_CHANCE: float = 0.45
## 적이 서는 칸 순서 (앞줄 가운데부터).
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, 2)]
## 황혼층(더 깊은 공허)으로 내려가면 적 체력·공격 배율과 자금 배율.
const DEEP_ENEMY_SCALE: float = 1.15
const DEEP_GOLD_SCALE: float = 1.5
## 휴식 노드 회복 비율.
const REST_HEAL: float = 0.35
## 상점 가격과 치료 비율.
const SHOP_ITEM_PRICE: int = 75
const SHOP_CARD_PRICE: int = 45
const SHOP_HEAL_PRICE: int = 30
const SHOP_HEAL: float = 0.3

var request: Dictionary
var game: GameState
var rng: RandomNumberGenerator
var floor_index: int = 0
## 이번 구역의 지도 노드 (id = 배열 번호).
var nodes: Array[Dictionary] = []
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
	for i in game.party.member_count():
		hp[i] = game.party.stats(i)["max_hp"]
	_build_map()


func floor_count() -> int:
	return request["floors"]


## 출구를 뺀 지도 열 수.
func column_count() -> int:
	return request["columns"]


func floor_name() -> String:
	var names: Array = request["floor_names"]
	return names[mini(floor_index, names.size() - 1)]


func node(id: int) -> Dictionary:
	return nodes[id]


func exit_id() -> int:
	return nodes.size() - 1


## 지금 고를 수 있는 노드인지.
func is_selectable(id: int) -> bool:
	if finished or id < 0 or id >= nodes.size():
		return false
	if current_id < 0:
		return int(nodes[id]["col"]) == 0
	return (nodes[current_id]["next"] as Array).has(id)


func selectable_ids() -> Array[int]:
	var out: Array[int] = []
	for n in nodes:
		if is_selectable(n["id"]):
			out.append(n["id"])
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


## 고른 노드를 돌려준다 (상태는 resolve_* 를 불러야 바뀐다). 고를 수 없는 노드면 빈 사전.
func pick(id: int) -> Dictionary:
	if not is_selectable(id):
		return {}
	return nodes[id]


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
	var exit_type: String = (request["exits"] as Array)[floor_index]
	var exit_node: Dictionary = _make_node(nodes.size(), cols, 1, exit_type)
	exit_node["exit"] = true
	nodes.append(exit_node)
	# 같은 줄로는 항상 이어지고, 이웃 줄로는 확률로 갈라진다. 선이 엇갈리지 않게 한다.
	for c in range(cols - 1):
		var went_down: Array[bool] = [false, false, false]
		for lane in LANES:
			var n: Dictionary = nodes[c * LANES + lane]
			var next: Array = n["next"]
			next.append((c + 1) * LANES + lane)
			# 위 줄로: 바로 위 노드가 아래로 내려오는 선이 있으면 엇갈리므로 막는다.
			if lane > 0 and not went_down[lane - 1] and rng.randf() < BRANCH_CHANCE:
				next.append((c + 1) * LANES + lane - 1)
			if lane < LANES - 1 and rng.randf() < BRANCH_CHANCE:
				next.append((c + 1) * LANES + lane + 1)
				went_down[lane] = true
	for lane in LANES:
		(nodes[(cols - 1) * LANES + lane]["next"] as Array).append(exit_id())


func _make_node(id: int, col: int, lane: int, t: String) -> Dictionary:
	var n: Dictionary = {"id": id, "col": col, "lane": lane, "type": t, "next": [], "exit": false}
	match t:
		ChapterData.BATTLE, ChapterData.ELITE, ChapterData.BOSS:
			n["enemies"] = _roll_enemies(t)
		ChapterData.EVENT:
			n["event"] = _roll_event()
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
	var last: bool = col == cols - 1
	var elite_ok: bool = floor_index >= 1 and col >= 2
	if last:
		if roll < 0.4:
			return ChapterData.REST
		if roll < 0.75:
			return ChapterData.BATTLE
		return ChapterData.EVENT
	if roll < 0.45:
		return ChapterData.BATTLE
	if roll < 0.68:
		return ChapterData.EVENT
	if roll < 0.78:
		return ChapterData.REST
	if roll < 0.86:
		return ChapterData.SUPPLY
	return ChapterData.ELITE if elite_ok else ChapterData.BATTLE


func _roll_enemies(t: String) -> Array:
	match t:
		ChapterData.BOSS:
			return (request["boss"] as Array).duplicate()
		ChapterData.ELITE:
			var elites: Array = request["elites"]
			return (elites[rng.randi_range(0, elites.size() - 1)] as Array).duplicate()
	var pools: Array = request["pools"]
	var pool: Array = pools[mini(floor_index, pools.size() - 1)]
	return (pool[rng.randi_range(0, pool.size() - 1)] as Array).duplicate()


func _roll_event() -> String:
	var events: Array = request["events"]
	var fresh: Array = []
	for e in events:
		if not _used_events.has(e):
			fresh.append(e)
	if fresh.is_empty():
		fresh = events
	var picked: String = fresh[rng.randi_range(0, fresh.size() - 1)]
	_used_events.append(picked)
	return picked


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


# ---------------- 전투 ----------------

## 노드의 전투 구성. 아군은 지금 파티(장비 반영)와 이어진 체력으로, 적은 노드의 무리로.
func encounter_for(n: Dictionary) -> EncounterData:
	var allies: Array[UnitPlacement] = game.party.build_battle_roster()
	for i in allies.size():
		allies[i].start_hp = maxi(int(hp.get(i, 1)), 1)
	var enemies: Array[UnitPlacement] = []
	var list: Array = n.get("enemies", [])
	for i in list.size():
		var base: EnemyData = load("%s/%s.tres" % [UNIT_DIR, list[i]])
		var data: EnemyData = base
		if deep:
			data = base.duplicate()
			data.max_hp = roundi(base.max_hp * DEEP_ENEMY_SCALE)
			data.attack = roundi(base.attack * DEEP_ENEMY_SCALE)
		var placement := UnitPlacement.new()
		placement.unit_data = data
		placement.cell = ENEMY_CELLS[i]
		enemies.append(placement)
	var encounter: EncounterData = EncounterGenerator.assemble_encounter(allies, enemies)
	encounter.room = load("%s/%s.tres" % [ROOM_DIR, _room_for(n)])
	return encounter


func _room_for(n: Dictionary) -> String:
	if n.get("type", "") == ChapterData.BOSS:
		return request["boss_room"]
	return request["deep_room"] if deep else request["room"]


## 이긴 전투의 결과를 반영한다. ally_hp 는 파티원 번호 순서의 남은 체력 (쓰러진 파티원은 1 로 일어난다).
func resolve_battle_win(n: Dictionary, ally_hp: Array) -> void:
	for i in ally_hp.size():
		hp[i] = maxi(int(ally_hp[i]), 1)
	battles_won += 1
	_complete(n)


## 보상: {"gold", "cards": [{"member", "card"}], "item"}
func battle_reward(n: Dictionary) -> Dictionary:
	var t: String = n.get("type", ChapterData.BATTLE)
	var base_gold: int = {"battle": 15, "elite": 40, "boss": 120}.get(t, 15) + rng.randi_range(0, 10)
	if deep:
		base_gold = roundi(base_gold * DEEP_GOLD_SCALE)
	var reward: Dictionary = {"gold": base_gold, "cards": card_choices(3), "item": null}
	if t == ChapterData.ELITE or t == ChapterData.BOSS or (deep and rng.randf() < 0.3):
		reward["item"] = ItemPool.roll(rng, ItemPool.load_all())
	return reward


## 파티원 보상 풀에서 서로 다른 카드 count 장: [{"member", "card"}]
func card_choices(count: int) -> Array:
	var choices: Array = []
	var candidates: Array = []
	for i in game.party.member_count():
		var member_id: String = String(game.party.member_data(i).id)
		for card_id in ChapterData.REWARD_CARDS.get(member_id, []):
			candidates.append({"member": i, "card_id": card_id})
	for k in count:
		if candidates.is_empty():
			break
		var pick_entry: Dictionary = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var card: CardData = load("%s/%s.tres" % [CARD_DIR, pick_entry["card_id"]])
		choices.append({"member": pick_entry["member"], "card": card})
	return choices


func add_gold(amount: int) -> void:
	gold_earned += amount
	game.add_gold(amount)


# ---------------- 그 밖의 노드 ----------------

## 휴식: 모두 최대 체력의 REST_HEAL 만큼 회복.
func resolve_rest(n: Dictionary) -> void:
	heal_party(REST_HEAL)
	_complete(n)


## 사건·보급·상점을 마쳤다.
func resolve_simple(n: Dictionary) -> void:
	_complete(n)


## 모든 파티원을 최대 체력의 ratio 만큼 회복 (음수면 피해, 1 아래로는 내려가지 않음).
func heal_party(ratio: float) -> void:
	for i in hp:
		var max_hp: int = game.party.stats(i)["max_hp"]
		hp[i] = clampi(int(hp[i]) + roundi(max_hp * ratio), 1, max_hp)


func supply_choices() -> Array[ItemData]:
	var pool: Array[ItemData] = ItemPool.load_all()
	var out: Array[ItemData] = []
	for i in 3:
		out.append(ItemPool.roll(rng, pool))
	return out


## 상점 진열: {"items": [{"item", "price"}], "cards": [{"member", "card", "price"}], "heal_price"}
func shop_stock() -> Dictionary:
	var items: Array = []
	for item in supply_choices():
		items.append({"item": item, "price": SHOP_ITEM_PRICE + rng.randi_range(-10, 15)})
	var cards: Array = []
	for choice in card_choices(3):
		choice["price"] = SHOP_CARD_PRICE + rng.randi_range(-5, 15)
		cards.append(choice)
	return {"items": items, "cards": cards, "heal_price": SHOP_HEAL_PRICE}


## 자금을 내고 산다. 모자라면 false.
func spend(price: int) -> bool:
	if game.gold < price:
		return false
	game.add_gold(-price)
	return true


## 진 전투를 다시 한다 (되살아남): 체력을 가득 채운다.
func revive() -> void:
	for i in hp:
		hp[i] = game.party.stats(i)["max_hp"]


func retreat() -> void:
	finished = true
	outcome = "retreat"


## 노드를 마쳤다: 그 노드가 지금 위치가 되고, 출구였다면 다음 구역 지도로 넘어간다.
func _complete(n: Dictionary) -> void:
	var id: int = n.get("id", -1)
	if not is_selectable(id):
		return
	visited.append(id)
	current_id = id
	if n.get("exit", false):
		floor_index += 1
		if floor_index >= floor_count():
			finished = true
			outcome = "clear"
			return
		_build_map()


## 파티원 번호 → 최대 체력 대비 비율 (화면용).
func hp_ratio(index: int) -> float:
	return float(hp.get(index, 0)) / float(maxi(game.party.stats(index)["max_hp"], 1))
