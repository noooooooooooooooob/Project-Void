## 파티(아군 캐릭터들)와 인벤토리, 장착 상태를 가진 규칙 코어. 노드에 의존하지 않는다.
## 화면(PartyView)은 이 객체를 읽고 바꾸며, 바뀔 때마다 changed 를 받아 다시 그린다.
## 전투 규칙(Scripts/combat/)은 건드리지 않는다 — 장비 효과는 build_battle_roster 가
## AllyData 복사본의 능력치와 덱 카드 피해량에 미리 얹어서 넘긴다.
class_name PartyState
extends RefCounted

## 파티·인벤토리·장착 중 무엇이든 바뀌면 낸다.
signal changed

## 파티원 기본 데이터와 전투 배치 칸. 순서가 곧 파티원 번호다.
var members: Array[UnitPlacement] = []
## 장착하지 않고 가방에 든 아이템. 같은 아이템이 여러 개일 수 있다.
var inventory: Array[ItemData] = []
## 파티원 번호 -> {부위(int) -> ItemData}.
var _equipment: Dictionary = {}


func _init(roster: Array[UnitPlacement]) -> void:
	members = roster
	for i in members.size():
		_equipment[i] = {}


func member_count() -> int:
	return members.size()


func member_data(index: int) -> AllyData:
	return members[index].unit_data as AllyData


func add_item(item: ItemData) -> void:
	if item == null:
		return
	inventory.append(item)
	changed.emit()


## 그 파티원이 그 부위에 낀 아이템. 비어 있으면 null.
func equipped(index: int, slot: ItemData.Slot) -> ItemData:
	return (_equipment[index] as Dictionary).get(slot)


## 가방의 아이템을 장착한다. 그 부위에 이미 낀 아이템이 있으면 가방으로 되돌린다.
## 가방에 없는 아이템이거나 파티원 번호가 틀리면 아무것도 하지 않고 false.
func equip(index: int, item: ItemData) -> bool:
	if index < 0 or index >= members.size() or item == null:
		return false
	var inventory_index: int = inventory.find(item)
	if inventory_index == -1:
		return false
	inventory.remove_at(inventory_index)
	var slots: Dictionary = _equipment[index]
	var previous: ItemData = slots.get(item.slot)
	if previous != null:
		inventory.append(previous)
	slots[item.slot] = item
	changed.emit()
	return true


## 장착한 아이템을 벗어 가방으로 되돌린다. 낀 게 없으면 false.
func unequip(index: int, slot: ItemData.Slot) -> bool:
	if index < 0 or index >= members.size():
		return false
	var slots: Dictionary = _equipment[index]
	var item: ItemData = slots.get(slot)
	if item == null:
		return false
	slots.erase(slot)
	inventory.append(item)
	changed.emit()
	return true


## 장비 보너스를 더한 최종 능력치. {max_hp, speed, max_sp, attack_bonus}. 체력·속도·SP 는 최소 1.
func stats(index: int) -> Dictionary:
	var data: AllyData = member_data(index)
	var max_hp: int = data.max_hp
	var speed: int = data.speed
	var max_sp: int = data.max_sp
	var attack_bonus: int = 0
	for item in (_equipment[index] as Dictionary).values():
		var equipment: ItemData = item
		max_hp += equipment.max_hp_bonus
		speed += equipment.speed_bonus
		max_sp += equipment.max_sp_bonus
		attack_bonus += equipment.attack_bonus
	return {
		"max_hp": maxi(max_hp, 1),
		"speed": maxi(speed, 1),
		"max_sp": maxi(max_sp, 1),
		"attack_bonus": attack_bonus,
	}


## 전투에 넘길 아군 배치를 만든다. 원본 AllyData 는 건드리지 않고 복사본에 장비 효과를 얹는다.
func build_battle_roster() -> Array[UnitPlacement]:
	var roster: Array[UnitPlacement] = []
	for i in members.size():
		var base: AllyData = member_data(i)
		var final_stats: Dictionary = stats(i)
		var ally: AllyData = base.duplicate()
		ally.max_hp = final_stats["max_hp"]
		ally.speed = final_stats["speed"]
		ally.max_sp = final_stats["max_sp"]
		ally.deck = _boosted_deck(base.deck, final_stats["attack_bonus"])
		var placement := UnitPlacement.new()
		placement.unit_data = ally
		placement.cell = members[i].cell
		roster.append(placement)
	return roster


## 피해를 주는 카드만 복사해 피해량을 올린다. 같은 카드는 같은 복사본을 공유한다.
func _boosted_deck(deck: Array[CardData], attack_bonus: int) -> Array[CardData]:
	var boosted: Array[CardData] = []
	var copies: Dictionary = {}
	for card in deck:
		if attack_bonus == 0 or card.damage <= 0:
			boosted.append(card)
			continue
		if not copies.has(card):
			var copy: CardData = card.duplicate()
			copy.damage += attack_bonus
			copies[card] = copy
		boosted.append(copies[card])
	return boosted
