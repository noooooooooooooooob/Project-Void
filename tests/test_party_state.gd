# PartyState(파티·인벤토리·장착) 테스트: 가방, 장착·교체·해제, 파티원별 장비, 능력치 합산, 전투용 복사본, changed 신호.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 아이템은 가방으로.
	_test_add_item_goes_to_the_inventory()
	# 장착하면 가방에서 빠진다.
	_test_equip_moves_the_item_out_of_the_inventory()
	# 가방에 없는 아이템은 장착할 수 없다.
	_test_equip_rejects_items_not_in_the_inventory()
	# 같은 부위에 끼면 이전 아이템이 가방으로.
	_test_equip_swaps_the_previous_item_back()
	# 같은 아이템 2 개 중 하나만 장착.
	_test_equipping_one_of_two_copies_keeps_the_other()
	# 해제하면 가방으로.
	_test_unequip_returns_the_item()
	# 빈 칸 해제는 아무 일 없음.
	_test_unequip_an_empty_slot_does_nothing()
	# 장비는 파티원마다 따로.
	_test_equipment_is_per_member()
	# 능력치는 보너스 합.
	_test_stats_sum_equipment_bonuses()
	# 능력치는 최소 1.
	_test_stats_never_drop_below_one()
	# 전투용 배치는 복사본에 능력치를 얹는다.
	_test_battle_roster_applies_stats_to_copies()
	# 공격 보너스는 공격 스탯에.
	_test_battle_roster_bakes_attack_into_stats()
	# 원본 데이터는 그대로.
	_test_battle_roster_leaves_the_source_untouched()
	# 바뀔 때마다 changed.
	_test_changed_is_emitted_on_every_change()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수 생성기.
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 돌려준다.
	return rng


# 시작 파티로 만든 빈 가방의 파티 상태.
func _party() -> PartyState:
	# 시드 1 시작 파티로 만든다.
	return PartyState.new(EncounterGenerator.build_ally_roster(_rng(1)))


# 테스트용 아이템을 만든다. 보너스는 체력·속도·SP·공격 순서.
func _item(item_id: StringName, slot: ItemData.Slot, hp: int = 0, speed: int = 0, sp: int = 0, attack: int = 0) -> ItemData:
	# 아이템을 만든다.
	var item := ItemData.new()
	# id.
	item.id = item_id
	# 이름은 id 그대로.
	item.display_name = String(item_id)
	# 부위.
	item.slot = slot
	# 체력 보너스.
	item.max_hp_bonus = hp
	# 속도 보너스.
	item.speed_bonus = speed
	# SP 보너스.
	item.max_sp_bonus = sp
	# 공격 보너스.
	item.attack_bonus = attack
	# 돌려준다.
	return item


# add_item 은 가방에 넣고, null 은 무시한다.
func _test_add_item_goes_to_the_inventory() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 넣는다.
	party.add_item(knife)
	# 가방에 단검 하나.
	check_eq("the item is in the inventory", party.inventory, [knife])
	# null 을 넣는다.
	party.add_item(null)
	# 그대로 하나.
	check_eq("adding null changes nothing", party.inventory.size(), 1)


# 장착하면 그 부위에 끼워지고 가방에서 빠진다.
func _test_equip_moves_the_item_out_of_the_inventory() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 가방에 넣는다.
	party.add_item(knife)
	# 장착 성공.
	check("equip succeeds", party.equip(0, knife))
	# 무기 칸에 있다.
	check("the item is equipped in its slot", party.equipped(0, ItemData.Slot.WEAPON) == knife)
	# 가방은 비었다.
	check("the inventory no longer holds it", party.inventory.is_empty())


# 가방에 없는 아이템, 틀린 파티원 번호, null 은 모두 거절되고 가방은 그대로다.
func _test_equip_rejects_items_not_in_the_inventory() -> void:
	# 파티.
	var party: PartyState = _party()
	# 가방에 넣지 않은 아이템.
	var stranger: ItemData = _item(&"stranger", ItemData.Slot.ARMOR)
	# 거절.
	check("an item that isn't in the bag can't be equipped", not party.equip(0, stranger))
	# 아무것도 안 꼈다.
	check("nothing got equipped", party.equipped(0, ItemData.Slot.ARMOR) == null)
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 가방에 넣는다.
	party.add_item(knife)
	# 없는 파티원 번호는 거절.
	check("an unknown member index is rejected", not party.equip(99, knife))
	# null 은 거절.
	check("null is rejected", not party.equip(0, null))
	# 단검은 가방에 그대로.
	check_eq("the item stays in the bag after a rejected equip", party.inventory, [knife])


# 같은 부위에 다른 아이템을 끼면 이전 아이템이 가방으로 돌아간다.
func _test_equip_swaps_the_previous_item_back() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 소총.
	var rifle: ItemData = _item(&"rifle", ItemData.Slot.WEAPON)
	# 둘 다 가방에.
	party.add_item(knife)
	party.add_item(rifle)
	# 단검을 낀다.
	party.equip(0, knife)
	# 소총으로 바꾼다.
	party.equip(0, rifle)
	# 소총이 끼워졌다.
	check("the new weapon is equipped", party.equipped(0, ItemData.Slot.WEAPON) == rifle)
	# 단검은 가방으로.
	check_eq("the old weapon went back to the bag", party.inventory, [knife])


# 같은 아이템이 2 개 있으면 하나만 장착되고 하나는 가방에 남는다.
func _test_equipping_one_of_two_copies_keeps_the_other() -> void:
	# 파티.
	var party: PartyState = _party()
	# 조끼.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR)
	# 같은 조끼를 두 번 넣는다.
	party.add_item(vest)
	party.add_item(vest)
	# 낀다.
	party.equip(0, vest)
	# 하나 남았다.
	check_eq("one copy stays in the bag", party.inventory.size(), 1)
	# 하나는 끼워졌다.
	check("the other copy is equipped", party.equipped(0, ItemData.Slot.ARMOR) == vest)


# 해제하면 칸이 비고 아이템은 가방으로 돌아간다.
func _test_unequip_returns_the_item() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 가방에 넣고.
	party.add_item(knife)
	# 낀다.
	party.equip(0, knife)
	# 해제 성공.
	check("unequip succeeds", party.unequip(0, ItemData.Slot.WEAPON))
	# 칸이 비었다.
	check("the slot is empty again", party.equipped(0, ItemData.Slot.WEAPON) == null)
	# 가방에 돌아왔다.
	check_eq("the item is back in the bag", party.inventory, [knife])


# 빈 칸이나 없는 파티원은 해제할 수 없고 가방도 그대로다.
func _test_unequip_an_empty_slot_does_nothing() -> void:
	# 파티.
	var party: PartyState = _party()
	# 빈 칸 해제 실패.
	check("an empty slot can't be unequipped", not party.unequip(0, ItemData.Slot.ACCESSORY))
	# 없는 파티원 해제 실패.
	check("an unknown member can't be unequipped", not party.unequip(99, ItemData.Slot.ACCESSORY))
	# 가방은 여전히 비었다.
	check("the bag is still empty", party.inventory.is_empty())


# 한 파티원이 낀 장비는 다른 파티원에게 보이지 않는다.
func _test_equipment_is_per_member() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 가방에 넣고.
	party.add_item(knife)
	# 1 번 파티원에게 낀다.
	party.equip(1, knife)
	# 1 번은 끼고 있다.
	check("member 1 holds the knife", party.equipped(1, ItemData.Slot.WEAPON) == knife)
	# 0 번은 아니다.
	check("member 0 does not", party.equipped(0, ItemData.Slot.WEAPON) == null)


# 세 부위 장비의 보너스가 모두 더해진다.
func _test_stats_sum_equipment_bonuses() -> void:
	# 파티.
	var party: PartyState = _party()
	# 0 번 파티원의 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 조끼: 체력 +3, 속도 -1.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 3, -1)
	# 부적: 체력 +2, SP +1, 공격 +1.
	var charm: ItemData = _item(&"charm", ItemData.Slot.ACCESSORY, 2, 0, 1, 1)
	# 단검: 속도 +1, 공격 +2.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 1, 0, 2)
	# 셋 다 넣고 낀다.
	for item in [vest, charm, knife]:
		party.add_item(item)
		party.equip(0, item)
	# 최종 능력치.
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
	# 파티.
	var party: PartyState = _party()
	# 저주: 체력·속도·SP 모두 -999.
	var curse: ItemData = _item(&"curse", ItemData.Slot.ACCESSORY, -999, -999, -999)
	# 넣고 낀다.
	party.add_item(curse)
	party.equip(0, curse)
	# 최종 능력치.
	var stats: Dictionary = party.stats(0)
	# 체력 1.
	check_eq("max hp is clamped to 1", stats["max_hp"], 1)
	# 속도 1.
	check_eq("speed is clamped to 1", stats["speed"], 1)
	# SP 1.
	check_eq("max sp is clamped to 1", stats["max_sp"], 1)


# 전투용 배치는 모든 파티원을 담고, 복사본에 보너스를 얹으며, 칸·이름은 그대로다.
func _test_battle_roster_applies_stats_to_copies() -> void:
	# 파티.
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 조끼: 체력 +4, 속도 +2, SP +1.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 2, 1)
	# 넣고 낀다.
	party.add_item(vest)
	party.equip(0, vest)
	# 전투용 배치.
	var roster: Array[UnitPlacement] = party.build_battle_roster()
	# 전원.
	check_eq("the roster has every member", roster.size(), party.member_count())
	# 0 번의 전투용 데이터.
	var ally: AllyData = roster[0].unit_data
	# 원본과 다른 객체.
	check("the battle unit is a copy", ally != base)
	# 체력 보너스 반영.
	check_eq("battle max hp includes the bonus", ally.max_hp, base.max_hp + 4)
	# 속도 보너스 반영.
	check_eq("battle speed includes the bonus", ally.speed, base.speed + 2)
	# SP 보너스 반영.
	check_eq("battle max sp includes the bonus", ally.max_sp, base.max_sp + 1)
	# 칸은 그대로.
	check_eq("the cell is kept", roster[0].cell, party.members[0].cell)
	# 이름도 그대로.
	check_eq("the name is kept", ally.display_name, base.display_name)


# 공격 보너스는 전투 복사본의 공격 스탯에 들어가고, 덱 카드는 원본 그대로다.
func _test_battle_roster_bakes_attack_into_stats() -> void:
	# 파티.
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 단검: 공격 +2.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 0, 0, 2)
	# 넣고 낀다.
	party.add_item(knife)
	party.equip(0, knife)
	# 전투용 데이터.
	var ally: AllyData = party.build_battle_roster()[0].unit_data as AllyData
	# 공격 +2.
	check_eq("roster attack includes the bonus", ally.attack, base.attack + 2)
	# 덱 카드는 같은 리소스.
	check("deck cards are the originals", ally.deck == base.deck)


# 전투용 배치를 만들어도 파티 원본의 체력·공격·덱은 그대로다.
func _test_battle_roster_leaves_the_source_untouched() -> void:
	# 파티.
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 카드 한 장.
	var strike := CardData.new()
	# 덱을 이 카드 하나로.
	base.deck = [strike]
	# 원래 체력·공격.
	var base_hp: int = base.max_hp
	var base_attack: int = base.attack
	# 조끼: 체력 +4, 공격 +3.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 0, 0, 3)
	# 넣고 낀다.
	party.add_item(vest)
	party.equip(0, vest)
	# 전투용 배치를 만든다.
	party.build_battle_roster()
	# 원본 체력 그대로.
	check_eq("the party's base hp is unchanged", base.max_hp, base_hp)
	# 원본 공격 그대로.
	check_eq("the party's base attack is unchanged", base.attack, base_attack)
	# 원본 덱의 카드도 그대로.
	check("the party's deck still holds the original card", base.deck[0] == strike)


# 넣기·장착·해제마다 changed 가 나오고, 아무것도 안 바뀐 해제는 나오지 않는다.
func _test_changed_is_emitted_on_every_change() -> void:
	# 파티.
	var party: PartyState = _party()
	# 신호 횟수. 람다 안에서 바꾸려면 배열에 담아야 한다 (int 는 값으로 복사된다).
	var counter: Array[int] = [0]
	# 신호마다 1 씩 센다.
	party.changed.connect(func() -> void: counter[0] += 1)
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 넣는다.
	party.add_item(knife)
	# 1 번.
	check_eq("add_item emits changed", counter[0], 1)
	# 낀다.
	party.equip(0, knife)
	# 2 번.
	check_eq("equip emits changed", counter[0], 2)
	# 해제한다.
	party.unequip(0, ItemData.Slot.WEAPON)
	# 3 번.
	check_eq("unequip emits changed", counter[0], 3)
	# 빈 칸을 또 해제한다.
	party.unequip(0, ItemData.Slot.WEAPON)
	# 그대로 3 번.
	check_eq("a no-op unequip does not emit", counter[0], 3)
