# PartyState(파티·인벤토리·장착) 테스트: 가방, 장착·교체·해제, 파티원별 장비, 능력치 합산, 전투용 복사본, changed 신호.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_add_item_goes_to_the_inventory()
	# 장착하면 가방에서 빠진다.
	_test_equip_moves_the_item_out_of_the_inventory()
	# 가방에 없는 아이템은 장착할 수 없다.
	_test_equip_rejects_items_not_in_the_inventory()
	# 같은 부위에 끼면 이전 아이템이 가방으로.
	_test_equip_swaps_the_previous_item_back()
	# 같은 아이템 2 개 중 하나만 장착.
	_test_equipping_one_of_two_copies_keeps_the_other()
	_test_unequip_returns_the_item()
	# 빈 칸 해제는 아무 일 없음.
	_test_unequip_an_empty_slot_does_nothing()
	_test_equipment_is_per_member()
	_test_stats_sum_equipment_bonuses()
	# 능력치는 최소 1.
	_test_stats_never_drop_below_one()
	# 전투용 배치는 복사본에 능력치를 얹는다.
	_test_battle_roster_applies_stats_to_copies()
	# 공격 보너스는 공격 스탯에.
	_test_battle_roster_bakes_attack_into_stats()
	_test_battle_roster_leaves_the_source_untouched()
	# 바뀔 때마다 changed.
	_test_changed_is_emitted_on_every_change()
	return results()


# 시드를 고정한 난수 생성기.
func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# 시작 파티로 만든 빈 가방의 파티 상태.
func _party() -> PartyState:
	# 시드 1 시작 파티로 만든다.
	return PartyState.new(EncounterGenerator.build_ally_roster(_rng(1)))


# 테스트용 아이템을 만든다. 보너스는 체력·속도·SP·공격 순서.
func _item(item_id: StringName, slot: ItemData.Slot, hp: int = 0, speed: int = 0, sp: int = 0, attack: int = 0) -> ItemData:
	var item := ItemData.new()
	# id.
	item.id = item_id
	# 이름은 id 그대로.
	item.display_name = String(item_id)
	item.slot = slot
	item.max_hp_bonus = hp
	item.speed_bonus = speed
	# SP 보너스.
	item.max_sp_bonus = sp
	item.attack_bonus = attack
	return item


# add_item 은 가방에 넣고, null 은 무시한다.
func _test_add_item_goes_to_the_inventory() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check_eq("the item is in the inventory", party.inventory, [knife])
	# null 을 넣는다.
	party.add_item(null)
	check_eq("adding null changes nothing", party.inventory.size(), 1)


# 장착하면 그 부위에 끼워지고 가방에서 빠진다.
func _test_equip_moves_the_item_out_of_the_inventory() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check("equip succeeds", party.equip(0, knife))
	check("the item is equipped in its slot", party.equipped(0, ItemData.Slot.WEAPON) == knife)
	check("the inventory no longer holds it", party.inventory.is_empty())


# 가방에 없는 아이템, 틀린 파티원 번호, null 은 모두 거절되고 가방은 그대로다.
func _test_equip_rejects_items_not_in_the_inventory() -> void:
	var party: PartyState = _party()
	var stranger: ItemData = _item(&"stranger", ItemData.Slot.ARMOR)
	check("an item that isn't in the bag can't be equipped", not party.equip(0, stranger))
	check("nothing got equipped", party.equipped(0, ItemData.Slot.ARMOR) == null)
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check("an unknown member index is rejected", not party.equip(99, knife))
	# null 은 거절.
	check("null is rejected", not party.equip(0, null))
	check_eq("the item stays in the bag after a rejected equip", party.inventory, [knife])


# 같은 부위에 다른 아이템을 끼면 이전 아이템이 가방으로 돌아간다.
func _test_equip_swaps_the_previous_item_back() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	var rifle: ItemData = _item(&"rifle", ItemData.Slot.WEAPON)
	party.add_item(knife)
	party.add_item(rifle)
	party.equip(0, knife)
	party.equip(0, rifle)
	check("the new weapon is equipped", party.equipped(0, ItemData.Slot.WEAPON) == rifle)
	check_eq("the old weapon went back to the bag", party.inventory, [knife])


# 같은 아이템이 2 개 있으면 하나만 장착되고 하나는 가방에 남는다.
func _test_equipping_one_of_two_copies_keeps_the_other() -> void:
	var party: PartyState = _party()
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR)
	party.add_item(vest)
	party.add_item(vest)
	party.equip(0, vest)
	check_eq("one copy stays in the bag", party.inventory.size(), 1)
	check("the other copy is equipped", party.equipped(0, ItemData.Slot.ARMOR) == vest)


# 해제하면 칸이 비고 아이템은 가방으로 돌아간다.
func _test_unequip_returns_the_item() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	party.equip(0, knife)
	check("unequip succeeds", party.unequip(0, ItemData.Slot.WEAPON))
	check("the slot is empty again", party.equipped(0, ItemData.Slot.WEAPON) == null)
	check_eq("the item is back in the bag", party.inventory, [knife])


# 빈 칸이나 없는 파티원은 해제할 수 없고 가방도 그대로다.
func _test_unequip_an_empty_slot_does_nothing() -> void:
	var party: PartyState = _party()
	check("an empty slot can't be unequipped", not party.unequip(0, ItemData.Slot.ACCESSORY))
	check("an unknown member can't be unequipped", not party.unequip(99, ItemData.Slot.ACCESSORY))
	check("the bag is still empty", party.inventory.is_empty())


# 한 파티원이 낀 장비는 다른 파티원에게 보이지 않는다.
func _test_equipment_is_per_member() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	# 1 번 파티원에게 낀다.
	party.equip(1, knife)
	# 1 번은 끼고 있다.
	check("member 1 holds the knife", party.equipped(1, ItemData.Slot.WEAPON) == knife)
	# 0 번은 아니다.
	check("member 0 does not", party.equipped(0, ItemData.Slot.WEAPON) == null)


# 세 부위 장비의 보너스가 모두 더해진다.
func _test_stats_sum_equipment_bonuses() -> void:
	var party: PartyState = _party()
	# 0 번 파티원의 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 조끼: 체력 +3, 속도 -1.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 3, -1)
	# 부적: 체력 +2, SP +1, 공격 +1.
	var charm: ItemData = _item(&"charm", ItemData.Slot.ACCESSORY, 2, 0, 1, 1)
	# 단검: 속도 +1, 공격 +2.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 1, 0, 2)
	for item in [vest, charm, knife]:
		party.add_item(item)
		party.equip(0, item)
	var stats: Dictionary = party.stats(0)
	# 체력 +5.
	check_eq("max hp adds up", stats["max_hp"], base.max_hp + 5)
	# 속도 -1 +1 = 0.
	check_eq("speed adds up", stats["speed"], base.speed + 0)
	# SP +1.
	check_eq("max sp adds up", stats["max_sp"], base.max_sp + 1)
	# 공격 +3.
	check_eq("attack adds up", stats["attack"], base.attack + 3)


# 큰 음수 보너스를 받아도 체력·속도·SP 는 1 아래로 내려가지 않는다.
func _test_stats_never_drop_below_one() -> void:
	var party: PartyState = _party()
	# 저주: 체력·속도·SP 모두 -999.
	var curse: ItemData = _item(&"curse", ItemData.Slot.ACCESSORY, -999, -999, -999)
	party.add_item(curse)
	party.equip(0, curse)
	var stats: Dictionary = party.stats(0)
	# 체력 1.
	check_eq("max hp is clamped to 1", stats["max_hp"], 1)
	# 속도 1.
	check_eq("speed is clamped to 1", stats["speed"], 1)
	# SP 1.
	check_eq("max sp is clamped to 1", stats["max_sp"], 1)


# 전투용 배치는 모든 파티원을 담고, 복사본에 보너스를 얹으며, 칸·이름은 그대로다.
func _test_battle_roster_applies_stats_to_copies() -> void:
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 조끼: 체력 +4, 속도 +2, SP +1.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 2, 1)
	party.add_item(vest)
	party.equip(0, vest)
	var roster: Array[UnitPlacement] = party.build_battle_roster()
	check_eq("the roster has every member", roster.size(), party.member_count())
	# 0 번의 전투용 데이터.
	var ally: AllyData = roster[0].unit_data
	check("the battle unit is a copy", ally != base)
	check_eq("battle max hp includes the bonus", ally.max_hp, base.max_hp + 4)
	check_eq("battle speed includes the bonus", ally.speed, base.speed + 2)
	# SP 보너스 반영.
	check_eq("battle max sp includes the bonus", ally.max_sp, base.max_sp + 1)
	check_eq("the cell is kept", roster[0].cell, party.members[0].cell)
	check_eq("the name is kept", ally.display_name, base.display_name)


# 공격 보너스는 전투 복사본의 공격 스탯에 들어가고, 덱 카드는 원본 그대로다.
func _test_battle_roster_bakes_attack_into_stats() -> void:
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 단검: 공격 +2.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 0, 0, 2)
	party.add_item(knife)
	party.equip(0, knife)
	var ally: AllyData = party.build_battle_roster()[0].unit_data as AllyData
	# 공격 +2.
	check_eq("roster attack includes the bonus", ally.attack, base.attack + 2)
	check("deck cards are the originals", ally.deck == base.deck)


# 전투용 배치를 만들어도 파티 원본의 체력·공격·덱은 그대로다.
func _test_battle_roster_leaves_the_source_untouched() -> void:
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	var strike := CardData.new()
	base.deck = [strike]
	# 원래 체력·공격.
	var base_hp: int = base.max_hp
	var base_attack: int = base.attack
	# 조끼: 체력 +4, 공격 +3.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 0, 0, 3)
	party.add_item(vest)
	party.equip(0, vest)
	party.build_battle_roster()
	check_eq("the party's base hp is unchanged", base.max_hp, base_hp)
	check_eq("the party's base attack is unchanged", base.attack, base_attack)
	check("the party's deck still holds the original card", base.deck[0] == strike)


# 넣기·장착·해제마다 changed 가 나오고, 아무것도 안 바뀐 해제는 나오지 않는다.
func _test_changed_is_emitted_on_every_change() -> void:
	var party: PartyState = _party()
	# 신호 횟수. 람다 안에서 바꾸려면 배열에 담아야 한다 (int 는 값으로 복사된다).
	var counter: Array[int] = [0]
	# 신호마다 1 씩 센다.
	party.changed.connect(func() -> void: counter[0] += 1)
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	# 1 번.
	check_eq("add_item emits changed", counter[0], 1)
	party.equip(0, knife)
	# 2 번.
	check_eq("equip emits changed", counter[0], 2)
	party.unequip(0, ItemData.Slot.WEAPON)
	# 3 번.
	check_eq("unequip emits changed", counter[0], 3)
	party.unequip(0, ItemData.Slot.WEAPON)
	# 그대로 3 번.
	check_eq("a no-op unequip does not emit", counter[0], 3)
