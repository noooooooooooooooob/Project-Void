extends TestCase

const PartyViewScript := preload("res://Scripts/ui/party_view.gd")


func run() -> Array[Dictionary]:
	_test_lists_every_member_and_shows_their_info()
	_test_selecting_a_member_switches_the_info()
	_test_empty_inventory_shows_a_hint()
	_test_selecting_an_item_enables_equip_and_shows_details()
	_test_equip_selected_moves_the_item_to_the_slot()
	_test_equipping_updates_the_stats()
	_test_pressing_a_slot_unequips()
	_test_replacing_an_item_is_announced()
	_test_selecting_a_member_clears_the_item_selection()
	_test_close_button_emits_closed()
	_test_the_view_follows_party_changes()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _party() -> PartyState:
	return PartyState.new(EncounterGenerator.build_ally_roster(_rng(1)))


func _item(item_id: StringName, slot: ItemData.Slot, hp: int = 0, speed: int = 0) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = String(item_id)
	item.slot = slot
	item.max_hp_bonus = hp
	item.speed_bonus = speed
	return item


func _view(party: PartyState) -> PartyView:
	var view: PartyView = PartyViewScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.bind(party)
	return view


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _test_lists_every_member_and_shows_their_info() -> void:
	var party: PartyState = _party()
	var view: PartyView = _view(party)
	check_eq("one button per member", view.member_button_count(), party.member_count())
	check("the first member is selected", view.selected_member() == 0)
	var data: AllyData = party.member_data(0)
	check("the stats show max hp", view.stats_text().contains(str(data.max_hp)))
	check("the deck summary shows the card count", view.deck_text().contains("%d장" % data.deck.size()))
	check("the selected member's button is marked", view.member_button(0).text.begins_with(PartyView.SELECTED_PREFIX))
	check("the other members' buttons are not", not view.member_button(1).text.begins_with(PartyView.SELECTED_PREFIX))
	view.free()


func _test_selecting_a_member_switches_the_info() -> void:
	var party: PartyState = _party()
	var view: PartyView = _view(party)
	view.member_button(1).pressed.emit()
	check_eq("the second member is selected", view.selected_member(), 1)
	check("the second member's button is marked", view.member_button(1).text.begins_with(PartyView.SELECTED_PREFIX))
	var data: AllyData = party.member_data(1)
	check("the stats now belong to the second member", view.stats_text().contains("체력  %d" % data.max_hp))
	view.select_member(99)
	check_eq("an unknown member index is ignored", view.selected_member(), 1)
	view.free()


func _test_empty_inventory_shows_a_hint() -> void:
	var party: PartyState = _party()
	var view: PartyView = _view(party)
	check_eq("an empty bag has no item buttons", view.inventory_button_count(), 0)
	check("equip is disabled with nothing selected", view.equip_button().disabled)
	check("every slot button is disabled when nothing is equipped", view.slot_button(ItemData.Slot.WEAPON).disabled)
	view.free()


func _test_selecting_an_item_enables_equip_and_shows_details() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	knife.description = "낡은 칼"
	party.add_item(knife)
	var view: PartyView = _view(party)
	check_eq("one item button", view.inventory_button_count(), 1)
	view.inventory_button(0).pressed.emit()
	check("equip is enabled once an item is selected", not view.equip_button().disabled)
	check("the details name the item", view.detail_text().contains("knife"))
	check("the details show the description", view.detail_text().contains("낡은 칼"))
	check("the equip button names the target member", view.equip_button().text.contains(party.member_data(0).display_name))
	view.free()


func _test_equip_selected_moves_the_item_to_the_slot() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	party.add_item(knife)
	var view: PartyView = _view(party)
	check("equip_selected does nothing before a selection", not view.equip_selected())
	view.select_item(0)
	view.equip_button().pressed.emit()
	check("the knife is now equipped", party.equipped(0, ItemData.Slot.WEAPON) == knife)
	check_eq("the bag buttons were rebuilt empty", view.inventory_button_count(), 0)
	check("the weapon slot button shows the item", view.slot_button(ItemData.Slot.WEAPON).text.contains("knife"))
	check("the weapon slot button is now pressable", not view.slot_button(ItemData.Slot.WEAPON).disabled)
	check("equip is disabled again", view.equip_button().disabled)
	view.free()


func _test_equipping_updates_the_stats() -> void:
	var party: PartyState = _party()
	var base: AllyData = party.member_data(0)
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4)
	party.add_item(vest)
	var view: PartyView = _view(party)
	view.select_item(0)
	view.equip_selected()
	check("the stats show the bonus", view.stats_text().contains("체력  %d (+4)" % (base.max_hp + 4)))
	check("the member button shows the new hp", view.member_button(0).text.contains(str(base.max_hp + 4)))
	view.free()


func _test_pressing_a_slot_unequips() -> void:
	var party: PartyState = _party()
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4)
	party.add_item(vest)
	party.equip(0, vest)
	var view: PartyView = _view(party)
	view.slot_button(ItemData.Slot.ARMOR).pressed.emit()
	check("the armor slot is empty again", party.equipped(0, ItemData.Slot.ARMOR) == null)
	check_eq("the vest is back in the bag", view.inventory_button_count(), 1)
	check("the slot button is disabled again", view.slot_button(ItemData.Slot.ARMOR).disabled)
	view.free()


func _test_replacing_an_item_is_announced() -> void:
	var party: PartyState = _party()
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	var rifle: ItemData = _item(&"rifle", ItemData.Slot.WEAPON)
	party.add_item(knife)
	party.add_item(rifle)
	party.equip(0, knife)
	var view: PartyView = _view(party)
	view.select_item(0)
	check("the details warn that the knife returns to the bag", view.detail_text().contains("교체: knife"))
	view.free()


func _test_selecting_a_member_clears_the_item_selection() -> void:
	var party: PartyState = _party()
	party.add_item(_item(&"knife", ItemData.Slot.WEAPON))
	var view: PartyView = _view(party)
	view.select_item(0)
	view.select_member(1)
	check("equip is disabled after switching members", view.equip_button().disabled)
	check("equip_selected does nothing after switching members", not view.equip_selected())
	view.free()


func _test_close_button_emits_closed() -> void:
	var view: PartyView = _view(_party())
	var seen: Array[bool] = []
	view.closed.connect(func() -> void: seen.append(true))
	_find_button(view, "닫기").pressed.emit()
	check_eq("the close button reports closed", seen.size(), 1)
	view.free()


func _test_the_view_follows_party_changes() -> void:
	var party: PartyState = _party()
	var view: PartyView = _view(party)
	party.add_item(_item(&"knife", ItemData.Slot.WEAPON))
	check_eq("an item added to the party appears in the bag", view.inventory_button_count(), 1)
	view.free()
