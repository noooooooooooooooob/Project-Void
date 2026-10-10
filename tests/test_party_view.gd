# PartyView(캐릭터 정보·인벤토리 화면) 테스트: 파티원 목록과 정보, 아이템 선택과 장착, 장착 칸 해제, 교체 안내, 닫기, 파티 변경 따라가기.
extends TestCase

# 파티 화면 스크립트.
const PartyViewScript := preload("res://Scripts/ui/party_view.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 파티원 목록과 첫 파티원 정보.
	_test_lists_every_member_and_shows_their_info()
	# 파티원을 고르면 정보가 바뀐다.
	_test_selecting_a_member_switches_the_info()
	# 빈 가방.
	_test_empty_inventory_shows_a_hint()
	# 아이템을 고르면 장착 버튼과 설명.
	_test_selecting_an_item_enables_equip_and_shows_details()
	# 장착하면 칸으로 옮겨진다.
	_test_equip_selected_moves_the_item_to_the_slot()
	# 장착하면 능력치가 바뀐다.
	_test_equipping_updates_the_stats()
	# 장착 칸을 누르면 해제.
	_test_pressing_a_slot_unequips()
	# 교체되는 아이템을 알려 준다.
	_test_replacing_an_item_is_announced()
	# 파티원을 바꾸면 아이템 선택이 풀린다.
	_test_selecting_a_member_clears_the_item_selection()
	# 닫기 버튼.
	_test_close_button_emits_closed()
	# 파티가 바뀌면 화면이 따라간다.
	_test_the_view_follows_party_changes()
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


# 테스트용 아이템을 만든다 (체력·속도 보너스만).
func _item(item_id: StringName, slot: ItemData.Slot, hp: int = 0, speed: int = 0) -> ItemData:
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
	# 돌려준다.
	return item


# 화면을 만들어 씬 트리에 붙이고 파티와 연결한다.
func _view(party: PartyState) -> PartyView:
	# 화면을 만든다.
	var view: PartyView = PartyViewScript.new()
	# 실행기의 루트에 붙인다 (_ready 가 돌아 화면 틀이 생긴다).
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 파티와 연결한다.
	view.bind(party)
	# 돌려준다.
	return view


# 노드 아래에서 글자가 text 인 버튼을 찾는다 (접근자가 없는 버튼용). 없으면 null.
func _find_button(node: Node, text: String) -> Button:
	# 이 노드가 찾는 버튼이면 돌려준다.
	if node is Button and (node as Button).text == text:
		return node as Button
	# 자식마다 재귀로 찾는다.
	for child in node.get_children():
		# 자식 아래에서 찾는다.
		var found: Button = _find_button(child, text)
		# 찾았으면 돌려준다.
		if found != null:
			return found
	# 못 찾았다.
	return null


# 파티원마다 버튼이 있고, 첫 파티원이 골라져 그 정보가 보인다.
func _test_lists_every_member_and_shows_their_info() -> void:
	# 파티.
	var party: PartyState = _party()
	# 화면.
	var view: PartyView = _view(party)
	# 버튼 수 = 파티원 수.
	check_eq("one button per member", view.member_button_count(), party.member_count())
	# 첫 파티원이 골라져 있다.
	check("the first member is selected", view.selected_member() == 0)
	# 첫 파티원 데이터.
	var data: AllyData = party.member_data(0)
	# 체력이 보인다.
	check("the stats show max hp", view.stats_text().contains(str(data.max_hp)))
	# 덱 장수가 보인다.
	check("the deck summary shows the card count", view.deck_text().contains("%d장" % data.deck.size()))
	# 공격·방어·치명·어그로가 보인다.
	check("the stats show attack", view.stats_text().contains("공격  %d" % data.attack))
	check("the stats show defense", view.stats_text().contains("방어  %d" % data.defense))
	check("the stats show crit chance", view.stats_text().contains("치명확률  %d%%" % data.crit_chance))
	check("the stats show crit damage", view.stats_text().contains("치명피해  %d%%" % data.crit_damage))
	check("the stats show aggro", view.stats_text().contains("어그로  %d" % data.aggro))
	# 덱 줄에 카드 효과가 % 로 보인다.
	check("the deck shows effects in percent", view.deck_text().contains("%s ×" % data.deck[0].display_name) and view.deck_text().contains("— " + CardText.describe(data.deck[0])))
	# 고른 파티원 버튼에 ▶ 표시.
	check("the selected member's button is marked", view.member_button(0).text.begins_with(PartyView.SELECTED_PREFIX))
	# 다른 파티원은 표시 없음.
	check("the other members' buttons are not", not view.member_button(1).text.begins_with(PartyView.SELECTED_PREFIX))
	# 정리한다.
	view.free()


# 두 번째 파티원 버튼을 누르면 그 파티원이 골라지고, 없는 번호는 무시된다.
func _test_selecting_a_member_switches_the_info() -> void:
	# 파티.
	var party: PartyState = _party()
	# 화면.
	var view: PartyView = _view(party)
	# 두 번째 파티원 버튼을 누른다.
	view.member_button(1).pressed.emit()
	# 골라졌다.
	check_eq("the second member is selected", view.selected_member(), 1)
	# 표시가 옮겨졌다.
	check("the second member's button is marked", view.member_button(1).text.begins_with(PartyView.SELECTED_PREFIX))
	# 두 번째 파티원 데이터.
	var data: AllyData = party.member_data(1)
	# 능력치가 그 파티원 것이다.
	check("the stats now belong to the second member", view.stats_text().contains("체력  %d" % data.max_hp))
	# 없는 번호를 고른다.
	view.select_member(99)
	# 무시된다.
	check_eq("an unknown member index is ignored", view.selected_member(), 1)
	# 정리한다.
	view.free()


# 빈 가방이면 아이템 버튼이 없고, 장착·장착 칸 버튼이 막혀 있다.
func _test_empty_inventory_shows_a_hint() -> void:
	# 파티.
	var party: PartyState = _party()
	# 화면.
	var view: PartyView = _view(party)
	# 아이템 버튼 없음.
	check_eq("an empty bag has no item buttons", view.inventory_button_count(), 0)
	# 장착 버튼 막힘.
	check("equip is disabled with nothing selected", view.equip_button().disabled)
	# 빈 장착 칸 버튼 막힘.
	check("every slot button is disabled when nothing is equipped", view.slot_button(ItemData.Slot.WEAPON).disabled)
	# 정리한다.
	view.free()


# 아이템을 누르면 장착 버튼이 열리고, 설명에 이름·설명이, 장착 버튼에 파티원 이름이 보인다.
func _test_selecting_an_item_enables_equip_and_shows_details() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 설명.
	knife.description = "낡은 칼"
	# 가방에 넣는다.
	party.add_item(knife)
	# 화면.
	var view: PartyView = _view(party)
	# 아이템 버튼 하나.
	check_eq("one item button", view.inventory_button_count(), 1)
	# 누른다.
	view.inventory_button(0).pressed.emit()
	# 장착 버튼이 열렸다.
	check("equip is enabled once an item is selected", not view.equip_button().disabled)
	# 설명에 이름.
	check("the details name the item", view.detail_text().contains("knife"))
	# 설명에 설명 문구.
	check("the details show the description", view.detail_text().contains("낡은 칼"))
	# 장착 버튼에 파티원 이름.
	check("the equip button names the target member", view.equip_button().text.contains(party.member_data(0).display_name))
	# 정리한다.
	view.free()


# 장착 버튼을 누르면 아이템이 칸으로 옮겨지고 화면이 그에 맞게 바뀐다.
func _test_equip_selected_moves_the_item_to_the_slot() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 가방에 넣는다.
	party.add_item(knife)
	# 화면.
	var view: PartyView = _view(party)
	# 아무것도 안 골랐을 때는 실패.
	check("equip_selected does nothing before a selection", not view.equip_selected())
	# 단검을 고른다.
	view.select_item(0)
	# 장착 버튼을 누른다.
	view.equip_button().pressed.emit()
	# 끼워졌다.
	check("the knife is now equipped", party.equipped(0, ItemData.Slot.WEAPON) == knife)
	# 가방 버튼이 비었다.
	check_eq("the bag buttons were rebuilt empty", view.inventory_button_count(), 0)
	# 무기 칸에 이름이 보인다.
	check("the weapon slot button shows the item", view.slot_button(ItemData.Slot.WEAPON).text.contains("knife"))
	# 무기 칸을 눌러 해제할 수 있다.
	check("the weapon slot button is now pressable", not view.slot_button(ItemData.Slot.WEAPON).disabled)
	# 장착 버튼은 다시 막혔다.
	check("equip is disabled again", view.equip_button().disabled)
	# 정리한다.
	view.free()


# 장착하면 능력치 줄과 파티원 버튼의 체력이 바뀐다.
func _test_equipping_updates_the_stats() -> void:
	# 파티.
	var party: PartyState = _party()
	# 0 번 기본 데이터.
	var base: AllyData = party.member_data(0)
	# 조끼: 체력 +4.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4)
	# 가방에 넣는다.
	party.add_item(vest)
	# 화면.
	var view: PartyView = _view(party)
	# 조끼를 고른다.
	view.select_item(0)
	# 장착한다.
	view.equip_selected()
	# "체력  14 (+4)" 형태로 보인다.
	check("the stats show the bonus", view.stats_text().contains("체력  %d (+4)" % (base.max_hp + 4)))
	# 파티원 버튼에도 새 체력.
	check("the member button shows the new hp", view.member_button(0).text.contains(str(base.max_hp + 4)))
	# 정리한다.
	view.free()


# 장착 칸 버튼을 누르면 해제되고 아이템이 가방으로 돌아간다.
func _test_pressing_a_slot_unequips() -> void:
	# 파티.
	var party: PartyState = _party()
	# 조끼.
	var vest: ItemData = _item(&"vest", ItemData.Slot.ARMOR, 4)
	# 넣고 낀다.
	party.add_item(vest)
	party.equip(0, vest)
	# 화면.
	var view: PartyView = _view(party)
	# 방어구 칸을 누른다.
	view.slot_button(ItemData.Slot.ARMOR).pressed.emit()
	# 칸이 비었다.
	check("the armor slot is empty again", party.equipped(0, ItemData.Slot.ARMOR) == null)
	# 가방에 버튼 하나.
	check_eq("the vest is back in the bag", view.inventory_button_count(), 1)
	# 칸 버튼은 다시 막혔다.
	check("the slot button is disabled again", view.slot_button(ItemData.Slot.ARMOR).disabled)
	# 정리한다.
	view.free()


# 같은 부위에 이미 낀 아이템이 있으면 설명에 교체 안내가 붙는다.
func _test_replacing_an_item_is_announced() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검.
	var knife: ItemData = _item(&"knife", ItemData.Slot.WEAPON)
	# 소총.
	var rifle: ItemData = _item(&"rifle", ItemData.Slot.WEAPON)
	# 둘 다 가방에.
	party.add_item(knife)
	party.add_item(rifle)
	# 단검을 낀다 (가방에는 소총만 남는다).
	party.equip(0, knife)
	# 화면.
	var view: PartyView = _view(party)
	# 소총을 고른다.
	view.select_item(0)
	# 단검이 가방으로 돌아간다는 안내.
	check("the details warn that the knife returns to the bag", view.detail_text().contains("교체: knife"))
	# 정리한다.
	view.free()


# 아이템을 고른 뒤 파티원을 바꾸면 선택이 풀려 장착할 수 없다.
func _test_selecting_a_member_clears_the_item_selection() -> void:
	# 파티.
	var party: PartyState = _party()
	# 단검을 가방에.
	party.add_item(_item(&"knife", ItemData.Slot.WEAPON))
	# 화면.
	var view: PartyView = _view(party)
	# 단검을 고른다.
	view.select_item(0)
	# 다른 파티원을 고른다.
	view.select_member(1)
	# 장착 버튼 막힘.
	check("equip is disabled after switching members", view.equip_button().disabled)
	# 장착 시도도 실패.
	check("equip_selected does nothing after switching members", not view.equip_selected())
	# 정리한다.
	view.free()


# 닫기 버튼을 누르면 closed 가 한 번 나온다.
func _test_close_button_emits_closed() -> void:
	# 화면.
	var view: PartyView = _view(_party())
	# 받은 횟수 기록.
	var seen: Array[bool] = []
	# 신호를 받으면 기록한다.
	view.closed.connect(func() -> void: seen.append(true))
	# 닫기 버튼을 찾아 누른다.
	_find_button(view, "닫기").pressed.emit()
	# 한 번.
	check_eq("the close button reports closed", seen.size(), 1)
	# 정리한다.
	view.free()


# 화면 밖에서 파티에 아이템을 넣어도 화면이 따라 바뀐다 (changed 신호 연결).
func _test_the_view_follows_party_changes() -> void:
	# 파티.
	var party: PartyState = _party()
	# 화면.
	var view: PartyView = _view(party)
	# 파티에 직접 아이템을 넣는다.
	party.add_item(_item(&"knife", ItemData.Slot.WEAPON))
	# 가방 버튼이 생겼다.
	check_eq("an item added to the party appears in the bag", view.inventory_button_count(), 1)
	# 정리한다.
	view.free()
