## 캐릭터 정보와 인벤토리 화면. PartyState 를 읽어 보여 주고, 장착·해제를 PartyState 에 요청한다.
## 씬 파일 없이 코드로 화면을 짠다 (MapView 와 같은 방식).
class_name PartyView
extends Control

## 닫기 버튼을 눌렀을 때.
signal closed

const BACKGROUND_COLOR := Color(0.1, 0.1, 0.12)
const SELECTED_PREFIX: String = "▶ "
const INVENTORY_COLUMNS: int = 4

var _party: PartyState
var _selected_member: int = 0
## 가방 안에서 고른 아이템 번호. 고른 게 없으면 -1.
var _selected_item: int = -1

var _member_list: VBoxContainer
var _portrait: TextureRect
var _name_label: Label
var _stats_label: Label
var _deck_label: Label
var _slot_buttons: Dictionary = {}
var _inventory_grid: GridContainer
var _inventory_empty_label: Label
var _detail_label: Label
var _equip_button: Button


func _ready() -> void:
	_build_ui()
	if _party != null:
		_refresh()


## 보여 줄 파티를 정한다. 파티가 바뀌면 화면이 알아서 다시 그려진다.
func bind(party: PartyState) -> void:
	if _party != null:
		_party.changed.disconnect(_refresh)
	_party = party
	_party.changed.connect(_refresh)
	_selected_member = 0
	_selected_item = -1
	if is_node_ready():
		_refresh()


func select_member(index: int) -> void:
	if _party == null or index < 0 or index >= _party.member_count():
		return
	_selected_member = index
	_selected_item = -1
	_refresh()


func select_item(index: int) -> void:
	if _party == null or index < 0 or index >= _party.inventory.size():
		return
	_selected_item = index
	_refresh()


## 고른 아이템을 고른 파티원에게 장착한다. 고른 아이템이 없으면 false.
func equip_selected() -> bool:
	if _party == null or _selected_item < 0 or _selected_item >= _party.inventory.size():
		return false
	var item: ItemData = _party.inventory[_selected_item]
	_selected_item = -1
	return _party.equip(_selected_member, item)


## 고른 파티원이 그 부위에 낀 아이템을 벗는다.
func unequip_slot(slot: ItemData.Slot) -> bool:
	if _party == null:
		return false
	return _party.unequip(_selected_member, slot)


func selected_member() -> int:
	return _selected_member


func member_button_count() -> int:
	return _member_list.get_child_count()


func member_button(index: int) -> Button:
	return _member_list.get_child(index) as Button


func slot_button(slot: ItemData.Slot) -> Button:
	return _slot_buttons[slot]


func inventory_button_count() -> int:
	return _inventory_grid.get_child_count()


func inventory_button(index: int) -> Button:
	return _inventory_grid.get_child(index) as Button


func equip_button() -> Button:
	return _equip_button


func stats_text() -> String:
	return _stats_label.text


func deck_text() -> String:
	return _deck_label.text


func detail_text() -> String:
	return _detail_label.text


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 32)
	root.add_child(body)
	body.add_child(_build_member_column())
	body.add_child(_build_info_column())
	body.add_child(_build_inventory_column())


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "파티 · 인벤토리"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(120.0, 44.0)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	return header


func _build_member_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(280.0, 0.0)
	column.add_theme_constant_override("separation", 10)
	column.add_child(_make_heading("파티원"))
	_member_list = VBoxContainer.new()
	_member_list.add_theme_constant_override("separation", 10)
	column.add_child(_member_list)
	return column


func _build_info_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(480.0, 0.0)
	column.add_theme_constant_override("separation", 12)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(256.0, 256.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_portrait)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_name_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_stats_label)

	_deck_label = Label.new()
	_deck_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_deck_label)
	return column


func _build_inventory_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	column.add_child(_make_heading("장비 (눌러서 해제)"))
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.ACCESSORY]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(unequip_slot.bind(slot))
		column.add_child(button)
		_slot_buttons[slot] = button

	column.add_child(_make_heading("인벤토리 (눌러서 선택)"))
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = INVENTORY_COLUMNS
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_inventory_grid)

	_inventory_empty_label = Label.new()
	_inventory_empty_label.text = "가방이 비었습니다"
	column.add_child(_inventory_empty_label)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(0.0, 110.0)
	column.add_child(_detail_label)

	_equip_button = Button.new()
	_equip_button.custom_minimum_size = Vector2(0.0, 52.0)
	_equip_button.pressed.connect(equip_selected)
	column.add_child(_equip_button)
	return column


func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	return label


func _refresh() -> void:
	if _party == null:
		return
	if _selected_item >= _party.inventory.size():
		_selected_item = -1
	_refresh_members()
	_refresh_info()
	_refresh_slots()
	_refresh_inventory()
	_refresh_detail()


func _refresh_members() -> void:
	_clear(_member_list)
	for i in _party.member_count():
		var data: AllyData = _party.member_data(i)
		var final_stats: Dictionary = _party.stats(i)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 64.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var prefix: String = SELECTED_PREFIX if i == _selected_member else ""
		button.text = "%s%s   HP %d" % [prefix, data.display_name, final_stats["max_hp"]]
		button.pressed.connect(select_member.bind(i))
		_member_list.add_child(button)


func _refresh_info() -> void:
	var data: AllyData = _party.member_data(_selected_member)
	var final_stats: Dictionary = _party.stats(_selected_member)
	_portrait.texture = data.sprite
	_name_label.text = data.display_name
	var lines: PackedStringArray = [
		_stat_line("체력", final_stats["max_hp"], data.max_hp),
		_stat_line("속도", final_stats["speed"], data.speed),
		_stat_line("SP", final_stats["max_sp"], data.max_sp),
	]
	if final_stats["attack_bonus"] != 0:
		lines.append("공격  %+d" % final_stats["attack_bonus"])
	_stats_label.text = "\n".join(lines)
	_deck_label.text = _deck_summary(data)


func _refresh_slots() -> void:
	for slot in _slot_buttons:
		var button: Button = _slot_buttons[slot]
		var item: ItemData = _party.equipped(_selected_member, slot)
		var slot_label: String = ItemData.slot_name(slot)
		if item == null:
			button.text = "%s:  비어 있음" % slot_label
			button.disabled = true
		else:
			button.text = "%s:  %s   %s" % [slot_label, item.display_name, item.summary()]
			button.disabled = false


func _refresh_inventory() -> void:
	_clear(_inventory_grid)
	_inventory_empty_label.visible = _party.inventory.is_empty()
	for i in _party.inventory.size():
		var item: ItemData = _party.inventory[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150.0, 64.0)
		var prefix: String = SELECTED_PREFIX if i == _selected_item else ""
		button.text = prefix + item.display_name
		button.tooltip_text = item.description
		button.pressed.connect(select_item.bind(i))
		_inventory_grid.add_child(button)


func _refresh_detail() -> void:
	if _selected_item < 0:
		_detail_label.text = "아이템을 선택하면 설명이 보입니다."
		_equip_button.text = "장착"
		_equip_button.disabled = true
		return
	var item: ItemData = _party.inventory[_selected_item]
	var lines: PackedStringArray = [
		"%s  [%s]" % [item.display_name, ItemData.slot_name(item.slot)],
		item.summary(),
		item.description,
	]
	var current: ItemData = _party.equipped(_selected_member, item.slot)
	if current != null:
		lines.append("교체: %s 은(는) 가방으로 돌아갑니다." % current.display_name)
	_detail_label.text = "\n".join(lines)
	_equip_button.text = "%s 에게 장착" % _party.member_data(_selected_member).display_name
	_equip_button.disabled = false


func _stat_line(label: String, final_value: int, base_value: int) -> String:
	if final_value == base_value:
		return "%s  %d" % [label, final_value]
	return "%s  %d (%+d)" % [label, final_value, final_value - base_value]


func _deck_summary(data: AllyData) -> String:
	var counts: Dictionary = {}
	for card in data.deck:
		counts[card.display_name] = int(counts.get(card.display_name, 0)) + 1
	var lines: PackedStringArray = ["덱  %d장" % data.deck.size()]
	for card_name in counts:
		lines.append("  %s ×%d" % [card_name, counts[card_name]])
	return "\n".join(lines)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
