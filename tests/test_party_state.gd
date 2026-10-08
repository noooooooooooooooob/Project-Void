extends TestCase


func run() -> Array[Dictionary]:
	_test_add_item_goes_to_the_inventory()
	_test_equip_moves_the_item_out_of_the_inventory()
	_test_equip_rejects_items_not_in_the_inventory()
	_test_equip_swaps_the_previous_item_back()
	_test_equipping_one_of_two_copies_keeps_the_other()
	_test_unequip_returns_the_item()
	_test_unequip_an_empty_slot_does_nothing()
	_test_equipment_is_per_member()
	_test_stats_sum_equipment_bonuses()
	_test_stats_never_drop_below_one()
	_test_battle_roster_applies_stats_to_copies()
	_test_battle_roster_boosts_only_damaging_cards()
	_test_battle_roster_leaves_the_source_untouched()
	_test_changed_is_emitted_on_every_change()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _party() -> PartyState:
	return PartyState.new(EncounterGenerator.build_ally_roster(_rng(1)))


func _item(item_id: StringName, slot: ItemData.Slot, hp: int = 0, speed: int = 0, sp: int = 0, attack: int = 0) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = String(item_id)
	item.slot = slot
	item.max_hp_bonus = hp
	item.speed_bonus = speed
	item.max_sp_bonus = sp
	item.attack_bonus = attack
	return item


func _test_add_item_goes_to_the_inventory() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check_eq("the item is in the inventory", party.inventory, [knife])
	party.add_item(null)
	check_eq("adding null changes nothing", party.inventory.size(), 1)


func _test_equip_moves_the_item_out_of_the_inventory() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check("equip succeeds", party.equip(0, knife))
	check("the item is equipped in its slot", party.equipped(0, ItemData.Slot.WEAPON) == knife)
	check("the inventory no longer holds it", party.inventory.is_empty())


func _test_equip_rejects_items_not_in_the_inventory() -> void:
	var party: PartyState = _party()
	var stranger: ItemData = _item(&"stranger", ItemData.Slot.ARMOR)
	check("an item that isn't in the bag can't be equipped", not party.equip(0, stranger))
	check("nothing got equipped", party.equipped(0, ItemData.Slot.ARMOR) == null)
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check("an unknown member index is rejected", not party.equip(99, knife))
	check("null is rejected", not party.equip(0, null))
	check_eq("the item stays in the bag after a rejected equip", party.inventory, [knife])


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


func _test_equipping_one_of_two_copies_keeps_the_other() -> void:
	var party: PartyState = _party()
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR)
	party.add_item(vest)
	party.add_item(vest)
	party.equip(0, vest)
	check_eq("one copy stays in the bag", party.inventory.size(), 1)
	check("the other copy is equipped", party.equipped(0, ItemData.Slot.ARMOR) == vest)


func _test_unequip_returns_the_item() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	party.equip(0, knife)
	check("unequip succeeds", party.unequip(0, ItemData.Slot.WEAPON))
	check("the slot is empty again", party.equipped(0, ItemData.Slot.WEAPON) == null)
	check_eq("the item is back in the bag", party.inventory, [knife])


func _test_unequip_an_empty_slot_does_nothing() -> void:
	var party: PartyState = _party()
	check("an empty slot can't be unequipped", not party.unequip(0, ItemData.Slot.ACCESSORY))
	check("an unknown member can't be unequipped", not party.unequip(99, ItemData.Slot.ACCESSORY))
	check("the bag is still empty", party.inventory.is_empty())


func _test_equipment_is_per_member() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	party.equip(1, knife)
	check("member 1 holds the knife", party.equipped(1, ItemData.Slot.WEAPON) == knife)
	check("member 0 does not", party.equipped(0, ItemData.Slot.WEAPON) == null)


func _test_stats_sum_equipment_bonuses() -> void:
	var party: PartyState = _party()
	var base: AllyData = party.member_data(0)
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 3, -1)
	var charm: ItemData = _item(&"charm", ItemData.Slot.ACCESSORY, 2, 0, 1, 1)
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 1, 0, 2)
	for item in [vest, charm, knife]:
		party.add_item(item)
		party.equip(0, item)
	var stats: Dictionary = party.stats(0)
	check_eq("max hp adds up", stats["max_hp"], base.max_hp + 5)
	check_eq("speed adds up", stats["speed"], base.speed + 0)
	check_eq("max sp adds up", stats["max_sp"], base.max_sp + 1)
	check_eq("attack bonus adds up", stats["attack_bonus"], 3)


func _test_stats_never_drop_below_one() -> void:
	var party: PartyState = _party()
	var curse: ItemData = _item(&"curse", ItemData.Slot.ACCESSORY, -999, -999, -999)
	party.add_item(curse)
	party.equip(0, curse)
	var stats: Dictionary = party.stats(0)
	check_eq("max hp is clamped to 1", stats["max_hp"], 1)
	check_eq("speed is clamped to 1", stats["speed"], 1)
	check_eq("max sp is clamped to 1", stats["max_sp"], 1)


func _test_battle_roster_applies_stats_to_copies() -> void:
	var party: PartyState = _party()
	var base: AllyData = party.member_data(0)
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 2, 1)
	party.add_item(vest)
	party.equip(0, vest)
	var roster: Array[UnitPlacement] = party.build_battle_roster()
	check_eq("the roster has every member", roster.size(), party.member_count())
	var ally: AllyData = roster[0].unit_data
	check("the battle unit is a copy", ally != base)
	check_eq("battle max hp includes the bonus", ally.max_hp, base.max_hp + 4)
	check_eq("battle speed includes the bonus", ally.speed, base.speed + 2)
	check_eq("battle max sp includes the bonus", ally.max_sp, base.max_sp + 1)
	check_eq("the cell is kept", roster[0].cell, party.members[0].cell)
	check_eq("the name is kept", ally.display_name, base.display_name)


func _test_battle_roster_boosts_only_damaging_cards() -> void:
	var party: PartyState = _party()
	var strike := CardData.new()
	strike.id = &"strike"
	strike.damage = 5
	var guard := CardData.new()
	guard.id = &"guard"
	guard.damage = 0
	party.member_data(0).deck = [strike, strike, guard]
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 0, 0, 2)
	party.add_item(knife)
	party.equip(0, knife)
	var deck: Array[CardData] = (party.build_battle_roster()[0].unit_data as AllyData).deck
	check_eq("the deck keeps its size", deck.size(), 3)
	check_eq("a damaging card hits harder", deck[0].damage, 7)
	check("copies of the same card share one boosted card", deck[0] == deck[1])
	check_eq("a card without damage is left alone", deck[2].damage, 0)
	check("a card without damage is not copied", deck[2] == guard)


func _test_battle_roster_leaves_the_source_untouched() -> void:
	var party: PartyState = _party()
	var base: AllyData = party.member_data(0)
	var strike := CardData.new()
	strike.damage = 5
	base.deck = [strike]
	var base_hp: int = base.max_hp
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4, 0, 0, 3)
	party.add_item(vest)
	party.equip(0, vest)
	party.build_battle_roster()
	check_eq("the party's base hp is unchanged", base.max_hp, base_hp)
	check_eq("the party's base card damage is unchanged", strike.damage, 5)
	check("the party's deck still holds the original card", base.deck[0] == strike)


func _test_changed_is_emitted_on_every_change() -> void:
	var party: PartyState = _party()
	var counter: Array[int] = [0]
	party.changed.connect(func() -> void: counter[0] += 1)
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	check_eq("add_item emits changed", counter[0], 1)
	party.equip(0, knife)
	check_eq("equip emits changed", counter[0], 2)
	party.unequip(0, ItemData.Slot.WEAPON)
	check_eq("unequip emits changed", counter[0], 3)
	party.unequip(0, ItemData.Slot.WEAPON)
	check_eq("a no-op unequip does not emit", counter[0], 3)
