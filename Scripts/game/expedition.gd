## 원정 한 번(의뢰 하나)의 진행 상태. 노드에 의존하지 않는다.
## 층마다 steps_per_floor 번 문(노드)을 고르고, 마지막에 출구(전투·정예·보스)를 지나 다음 층으로 간다.
## 파티 체력은 원정 내내 이어진다. 화면(ExpeditionView 등)과 흐름(GameFlow)은 이 객체를 읽고 부른다.
class_name Expedition
extends RefCounted

## 노드 하나: {"type", "enemies"(전투류), "event"(사건), "floor", "step"}
const UNIT_DIR: String = "res://Resources/content/units"
const ROOM_DIR: String = "res://Resources/content/rooms"
const CARD_DIR: String = "res://Resources/content/cards"
## 적이 서는 칸 순서 (앞줄 가운데부터).
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, 2)]
## 황혼층(더 깊은 공허)으로 내려가면 적 체력·공격 배율과 자금 배율.
const DEEP_ENEMY_SCALE: float = 1.15
const DEEP_GOLD_SCALE: float = 1.5
## 휴식 노드 회복 비율.
const REST_HEAL: float = 0.35

var request: Dictionary
var game: GameState
var rng: RandomNumberGenerator
var floor_index: int = 0
var step: int = 0
## 지금 고를 수 있는 노드들.
var options: Array[Dictionary] = []
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
	_roll_options()


func floor_count() -> int:
	return request["floors"]


func steps_per_floor() -> int:
	return request["steps_per_floor"]


func floor_name() -> String:
	var names: Array = request["floor_names"]
	return names[mini(floor_index, names.size() - 1)]


## 지금이 층의 출구 차례인지.
func at_exit() -> bool:
	return step >= steps_per_floor()


## 층을 마친 직후 공허 속의 공허 선택을 해야 하는지.
func needs_void_choice() -> bool:
	return not void_choice_done and floor_index - 1 == int(request.get("void_in_void_after", -1)) and step == 0


func choose_deep(go_deeper: bool) -> void:
	void_choice_done = true
	deep = go_deeper


## 고른 노드를 돌려준다 (상태는 resolve_* 를 불러야 바뀐다).
func pick(index: int) -> Dictionary:
	if index < 0 or index >= options.size():
		return {}
	return options[index]


# ---------------- 노드 생성 ----------------

func _roll_options() -> void:
	options = []
	if at_exit():
		var exit_type: String = (request["exits"] as Array)[floor_index]
		options.append(_battle_node(exit_type))
		return
	var count: int = 3 if rng.randf() < 0.5 else 2
	var types: Array[String] = []
	for i in count:
		types.append(_roll_type())
	# 첫 문 묶음에는 전투가 하나는 있게 한다 (층 시작에 바로 쉬는 일 방지).
	if step == 0 and not types.has(ChapterData.BATTLE):
		types[0] = ChapterData.BATTLE
	for t in types:
		match t:
			ChapterData.BATTLE, ChapterData.ELITE:
				options.append(_battle_node(t))
			ChapterData.EVENT:
				options.append({"type": t, "event": _roll_event(), "floor": floor_index, "step": step})
			_:
				options.append({"type": t, "floor": floor_index, "step": step})


func _roll_type() -> String:
	var roll: float = rng.randf()
	var elite_ok: bool = floor_index >= 1 and step == 1
	if roll < 0.45:
		return ChapterData.BATTLE
	if roll < 0.7:
		return ChapterData.EVENT
	if roll < 0.82:
		return ChapterData.REST
	if roll < 0.92:
		return ChapterData.SUPPLY
	return ChapterData.ELITE if elite_ok else ChapterData.BATTLE


func _battle_node(t: String) -> Dictionary:
	var enemies: Array
	match t:
		ChapterData.BOSS:
			enemies = request["boss"]
		ChapterData.ELITE:
			var elites: Array = request["elites"]
			enemies = elites[rng.randi_range(0, elites.size() - 1)]
		_:
			var pools: Array = request["pools"]
			var pool: Array = pools[mini(floor_index, pools.size() - 1)]
			enemies = pool[rng.randi_range(0, pool.size() - 1)]
	return {"type": t, "enemies": enemies.duplicate(), "floor": floor_index, "step": step}


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


# ---------------- 전투 ----------------

## 노드의 전투 구성. 아군은 지금 파티(장비 반영)와 이어진 체력으로, 적은 노드의 무리로.
func encounter_for(node: Dictionary) -> EncounterData:
	var allies: Array[UnitPlacement] = game.party.build_battle_roster()
	for i in allies.size():
		allies[i].start_hp = maxi(int(hp.get(i, 1)), 1)
	var enemies: Array[UnitPlacement] = []
	var list: Array = node.get("enemies", [])
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
	encounter.room = load("%s/%s.tres" % [ROOM_DIR, _room_for(node)])
	return encounter


func _room_for(node: Dictionary) -> String:
	if node.get("type", "") == ChapterData.BOSS:
		return request["boss_room"]
	return request["deep_room"] if deep else request["room"]


## 이긴 전투의 결과를 반영한다. ally_hp 는 파티원 번호 순서의 남은 체력 (쓰러진 파티원은 1 로 일어난다).
func resolve_battle_win(node: Dictionary, ally_hp: Array) -> void:
	for i in ally_hp.size():
		hp[i] = maxi(int(ally_hp[i]), 1)
	battles_won += 1
	_advance()


## 보상: {"gold", "cards": [{"member", "card"}], "item"}
func battle_reward(node: Dictionary) -> Dictionary:
	var t: String = node.get("type", ChapterData.BATTLE)
	var base_gold: int = {"battle": 15, "elite": 40, "boss": 120}.get(t, 15) + rng.randi_range(0, 10)
	if deep:
		base_gold = roundi(base_gold * DEEP_GOLD_SCALE)
	var reward: Dictionary = {"gold": base_gold, "cards": _card_choices(3), "item": null}
	if t == ChapterData.ELITE or t == ChapterData.BOSS or (deep and rng.randf() < 0.3):
		reward["item"] = ItemPool.roll(rng, ItemPool.load_all())
	return reward


func _card_choices(count: int) -> Array:
	var choices: Array = []
	var candidates: Array = []
	for i in game.party.member_count():
		var member_id: String = String(game.party.member_data(i).id)
		for card_id in ChapterData.REWARD_CARDS.get(member_id, []):
			candidates.append({"member": i, "card_id": card_id})
	for k in count:
		if candidates.is_empty():
			break
		var pick: Dictionary = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var card: CardData = load("%s/%s.tres" % [CARD_DIR, pick["card_id"]])
		choices.append({"member": pick["member"], "card": card})
	return choices


func add_gold(amount: int) -> void:
	gold_earned += amount
	game.add_gold(amount)


# ---------------- 그 밖의 노드 ----------------

## 휴식: 모두 최대 체력의 REST_HEAL 만큼 회복.
func resolve_rest() -> void:
	heal_party(REST_HEAL)
	_advance()


## 사건·보급을 마쳤다.
func resolve_simple() -> void:
	_advance()


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


## 진 전투를 다시 한다 (되살아남): 체력을 가득 채운다.
func revive() -> void:
	for i in hp:
		hp[i] = game.party.stats(i)["max_hp"]


func retreat() -> void:
	finished = true
	outcome = "retreat"


func _advance() -> void:
	if at_exit():
		floor_index += 1
		step = 0
		if floor_index >= floor_count():
			finished = true
			outcome = "clear"
			options = []
			return
	else:
		step += 1
	_roll_options()


## 파티원 번호 → 최대 체력 대비 비율 (화면용).
func hp_ratio(index: int) -> float:
	return float(hp.get(index, 0)) / float(maxi(game.party.stats(index)["max_hp"], 1))
