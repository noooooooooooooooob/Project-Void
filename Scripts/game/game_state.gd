## 게임 전체의 진행 상태: 이야기 플래그, 자금, 소장 수명, 파티(덱·장비·가방), 일지, 장 진행도.
## 원정(Expedition)은 이 상태를 빌려 쓰고, 원정이 끝나면 결과가 여기에 남는다. 저장·불러오기는 to_dict/from_dict.
class_name GameState
extends RefCounted

signal changed

## 처음 소장 수명 (되살아날 때마다 1 년씩 준다).
const START_LIFESPAN: int = 40
const UNIT_DIR: String = "res://Resources/content/units"
const ITEM_DIR: String = "res://Resources/items"
const CARD_DIR: String = "res://Resources/content/cards"
## 합류 순서대로 서는 아군 칸 (x = 열, 0 이 앞줄).
const MEMBER_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1)]
const SAVE_PATH: String = "user://save.json"

## 장 진행도: 0 = 튜토리얼 전, 1 = 1장 진행 중, 2 = 1장 완료.
var chapter: int = 0
var flags: Dictionary = {}
var gold: int = 0
var lifespan: int = START_LIFESPAN
var party: PartyState
## 일지: [{"title", "text"}]
var journal: Array[Dictionary] = []


func _init() -> void:
	var empty: Array[UnitPlacement] = []
	party = PartyState.new(empty)


## 파티원을 합류시킨다 (이미 있으면 무시). 덱은 복사해서 원본 .tres 를 바꾸지 않는다.
func add_member(member_id: String) -> bool:
	if party.index_of(StringName(member_id)) >= 0:
		return false
	var base: AllyData = load("%s/%s.tres" % [UNIT_DIR, member_id])
	if base == null:
		return false
	var data: AllyData = base.duplicate()
	data.deck = base.deck.duplicate()
	var placement := UnitPlacement.new()
	placement.unit_data = data
	placement.cell = MEMBER_CELLS[mini(party.member_count(), MEMBER_CELLS.size() - 1)]
	party.add_member(placement)
	changed.emit()
	return true


func has_member(member_id: String) -> bool:
	return party.index_of(StringName(member_id)) >= 0


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	changed.emit()


func add_journal(title: String, text: String) -> void:
	journal.append({"title": title, "text": text})
	changed.emit()


func spend_lifespan(years: int) -> void:
	lifespan = maxi(0, lifespan - years)
	changed.emit()


## 파티원 덱에 카드를 더한다.
func add_card(member_index: int, card: CardData) -> void:
	var data: AllyData = party.member_data(member_index)
	data.deck.append(card)
	party.changed.emit()
	changed.emit()


# ---------------- 저장 ----------------

func to_dict() -> Dictionary:
	var members: Array = []
	for i in party.member_count():
		var data: AllyData = party.member_data(i)
		var deck: Array = []
		for card in data.deck:
			deck.append(String(card.id))
		members.append({"id": String(data.id), "deck": deck})
	var inventory: Array = []
	for item in party.inventory:
		inventory.append(String(item.id))
	return {
		"version": 1,
		"chapter": chapter,
		"flags": flags.keys(),
		"gold": gold,
		"lifespan": lifespan,
		"members": members,
		"inventory": inventory,
		"equipment": party.equipment_ids(),
		"journal": journal,
	}


static func from_dict(d: Dictionary) -> GameState:
	var state := GameState.new()
	state.chapter = int(d.get("chapter", 0))
	for f in d.get("flags", []):
		state.flags[f] = true
	state.gold = int(d.get("gold", 0))
	state.lifespan = int(d.get("lifespan", START_LIFESPAN))
	for m in d.get("members", []):
		state.add_member(m["id"])
		var index: int = state.party.member_count() - 1
		var deck: Array[CardData] = []
		for card_id in m.get("deck", []):
			var card: CardData = load("%s/%s.tres" % [CARD_DIR, card_id])
			if card != null:
				deck.append(card)
		state.party.member_data(index).deck = deck
	for item_id in d.get("inventory", []):
		state.party.add_item(_item(item_id))
	var equipment: Dictionary = d.get("equipment", {})
	for index_key in equipment:
		var slots: Dictionary = equipment[index_key]
		for slot_key in slots:
			var item: ItemData = _item(slots[slot_key])
			if item != null:
				state.party.add_item(item)
				state.party.equip(int(index_key), item)
	for entry in d.get("journal", []):
		state.journal.append(entry)
	return state


static func _item(item_id: String) -> ItemData:
	var path: String = "%s/%s.tres" % [ITEM_DIR, item_id]
	return load(path) if ResourceLoader.exists(path) else null


func save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict(), "  "))


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_from_disk() -> GameState:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return null
	return from_dict(parsed)
