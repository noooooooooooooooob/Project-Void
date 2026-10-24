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


## 파티원 목록으로 시작한다. 처음에는 아무것도 장착하지 않은 상태다.
func _init(roster: Array[UnitPlacement]) -> void:
	members = roster
	# 파티원마다 빈 장착 칸을 만든다.
	for i in members.size():
		_equipment[i] = {}


## 파티원을 한 명 더한다 (이야기 중에 합류할 때). 장착 칸은 비어 있다.
func add_member(placement: UnitPlacement) -> void:
	_equipment[members.size()] = {}
	members.append(placement)
	changed.emit()


## 이 id 의 파티원 번호. 없으면 -1.
func index_of(member_id: StringName) -> int:
	for i in members.size():
		if members[i].unit_data.id == member_id:
			return i
	return -1


## 장착 상태를 저장용으로 꺼낸다: 파티원 번호 → {부위 → 아이템 id}.
func equipment_ids() -> Dictionary:
	var out: Dictionary = {}
	for index in _equipment:
		var slots: Dictionary = {}
		for slot in _equipment[index]:
			slots[slot] = String((_equipment[index][slot] as ItemData).id)
		out[index] = slots
	return out


## 파티원 수.
func member_count() -> int:
	return members.size()


## 그 파티원의 기본 데이터 (장비 보너스가 없는 원본).
func member_data(index: int) -> AllyData:
	# 배치 정보 안의 유닛 데이터를 아군 데이터로 꺼낸다.
	return members[index].unit_data as AllyData


## 가방에 아이템을 넣는다. null 이면 무시한다.
func add_item(item: ItemData) -> void:
	# 넣을 것이 없으면 아무것도 하지 않는다.
	if item == null:
		return
	inventory.append(item)
	changed.emit()


## 그 파티원이 그 부위에 낀 아이템. 비어 있으면 null.
func equipped(index: int, slot: ItemData.Slot) -> ItemData:
	# 그 파티원의 장착 칸에서 부위로 찾는다 (없으면 get 이 null 을 돌려준다).
	return (_equipment[index] as Dictionary).get(slot)


## 가방의 아이템을 장착한다. 그 부위에 이미 낀 아이템이 있으면 가방으로 되돌린다.
## 가방에 없는 아이템이거나 파티원 번호가 틀리면 아무것도 하지 않고 false.
func equip(index: int, item: ItemData) -> bool:
	# 파티원 번호가 범위 밖이거나 아이템이 없으면 실패.
	if index < 0 or index >= members.size() or item == null:
		return false
	# 가방에서 그 아이템의 위치를 찾는다.
	var inventory_index: int = inventory.find(item)
	if inventory_index == -1:
		return false
	inventory.remove_at(inventory_index)
	var slots: Dictionary = _equipment[index]
	# 같은 부위에 이미 낀 아이템.
	var previous: ItemData = slots.get(item.slot)
	# 있었다면 가방으로 되돌린다.
	if previous != null:
		inventory.append(previous)
	slots[item.slot] = item
	changed.emit()
	return true


## 장착한 아이템을 벗어 가방으로 되돌린다. 낀 게 없으면 false.
func unequip(index: int, slot: ItemData.Slot) -> bool:
	# 파티원 번호가 범위 밖이면 실패.
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


## 장비 보너스를 더한 최종 능력치. {max_hp, speed, max_sp, attack, defense, crit_chance, crit_damage, aggro}.
## 체력·속도·SP 는 최소 1, 공격은 최소 0.
func stats(index: int) -> Dictionary:
	# 원본 데이터에서 시작한다.
	var data: AllyData = member_data(index)
	var max_hp: int = data.max_hp
	var speed: int = data.speed
	# 최대 SP.
	var max_sp: int = data.max_sp
	var attack: int = data.attack
	# 낀 아이템마다 보너스를 더한다.
	for item in (_equipment[index] as Dictionary).values():
		var equipment: ItemData = item
		max_hp += equipment.max_hp_bonus
		speed += equipment.speed_bonus
		# SP 보너스.
		max_sp += equipment.max_sp_bonus
		attack += equipment.attack_bonus
	# 음수 보너스로 0 이하가 되지 않게 막고, 장비 보너스가 없는 스탯은 원본 그대로 넣는다.
	return {
		"max_hp": maxi(max_hp, 1),
		"speed": maxi(speed, 1),
		"max_sp": maxi(max_sp, 1),
		"attack": maxi(attack, 0),
		"defense": data.defense,
		"crit_chance": data.crit_chance,
		"crit_damage": data.crit_damage,
		"aggro": data.aggro,
	}


## 전투에 넘길 아군 배치를 만든다. 원본 AllyData 는 건드리지 않고 복사본에 장비 효과를 얹는다.
func build_battle_roster() -> Array[UnitPlacement]:
	var roster: Array[UnitPlacement] = []
	for i in members.size():
		var base: AllyData = member_data(i)
		# 장비를 반영한 최종 능력치.
		var final_stats: Dictionary = stats(i)
		# 원본을 복사한다 — 원본 .tres 를 바꾸면 다음 전투에 보너스가 겹쳐 쌓인다.
		var ally: AllyData = base.duplicate()
		ally.max_hp = final_stats["max_hp"]
		ally.speed = final_stats["speed"]
		# 최종 SP 를 넣는다.
		ally.max_sp = final_stats["max_sp"]
		# 최종 공격을 넣는다 (카드 피해는 공격 × % 로 계산된다).
		ally.attack = final_stats["attack"]
		var placement := UnitPlacement.new()
		placement.unit_data = ally
		placement.cell = members[i].cell
		roster.append(placement)
	return roster
