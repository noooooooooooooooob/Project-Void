## 캐릭터 정보와 인벤토리 화면. PartyState 를 읽어 보여 주고, 장착·해제를 PartyState 에 요청한다.
## 씬 파일 없이 코드로 화면을 짠다 (MapView 와 같은 방식).
class_name PartyView
# Control: 화면 전체를 덮는 UI 노드.
extends Control

## 닫기 버튼을 눌렀을 때.
signal closed

## 화면 배경색.
const BACKGROUND_COLOR := Color(0.1, 0.1, 0.12)
## 고른 파티원·아이템 버튼 앞에 붙이는 표시.
const SELECTED_PREFIX: String = "▶ "
## 인벤토리 격자의 열 수.
const INVENTORY_COLUMNS: int = 4

## 보여 주는 파티.
var _party: PartyState
## 고른 파티원 번호.
var _selected_member: int = 0
## 가방 안에서 고른 아이템 번호. 고른 게 없으면 -1.
var _selected_item: int = -1

## 왼쪽 열: 파티원 버튼 목록.
var _member_list: VBoxContainer
## 가운데 열: 고른 파티원 그림.
var _portrait: TextureRect
## 가운데 열: 이름.
var _name_label: Label
## 가운데 열: 능력치 (장비 보너스 포함).
var _stats_label: Label
## 가운데 열: 덱 구성.
var _deck_label: Label
## 오른쪽 열: 부위 -> 장착 칸 버튼 (누르면 해제).
var _slot_buttons: Dictionary = {}
## 오른쪽 열: 가방 아이템 버튼 격자.
var _inventory_grid: GridContainer
## 가방이 비었을 때 보이는 안내.
var _inventory_empty_label: Label
## 고른 아이템의 설명.
var _detail_label: Label
## 고른 아이템을 장착하는 버튼.
var _equip_button: Button


## 화면을 짜고, 이미 파티가 연결돼 있으면 내용을 채운다.
func _ready() -> void:
	# 빈 화면 틀을 만든다.
	_build_ui()
	# bind 가 _ready 보다 먼저 불렸다면 지금 채운다.
	if _party != null:
		_refresh()


## 보여 줄 파티를 정한다. 파티가 바뀌면 화면이 알아서 다시 그려진다.
func bind(party: PartyState) -> void:
	# 이전 파티가 있으면 신호 연결을 끊는다.
	if _party != null:
		_party.changed.disconnect(_refresh)
	# 새 파티를 기억한다.
	_party = party
	# 파티가 바뀔 때마다 다시 그린다.
	_party.changed.connect(_refresh)
	# 첫 파티원을 고른다.
	_selected_member = 0
	# 고른 아이템은 없앤다.
	_selected_item = -1
	# 화면 틀이 이미 있으면 바로 채운다 (없으면 _ready 가 채운다).
	if is_node_ready():
		_refresh()


## 파티원을 고른다. 번호가 틀리면 무시한다.
func select_member(index: int) -> void:
	# 파티가 없거나 번호가 범위 밖이면 무시한다.
	if _party == null or index < 0 or index >= _party.member_count():
		return
	# 고른 파티원을 바꾼다.
	_selected_member = index
	# 파티원을 바꾸면 아이템 선택은 푼다.
	_selected_item = -1
	# 다시 그린다.
	_refresh()


## 가방의 아이템을 고른다. 번호가 틀리면 무시한다.
func select_item(index: int) -> void:
	# 파티가 없거나 번호가 범위 밖이면 무시한다.
	if _party == null or index < 0 or index >= _party.inventory.size():
		return
	# 고른 아이템을 바꾼다.
	_selected_item = index
	# 다시 그린다.
	_refresh()


## 고른 아이템을 고른 파티원에게 장착한다. 고른 아이템이 없으면 false.
func equip_selected() -> bool:
	# 파티가 없거나 고른 아이템이 없으면 실패.
	if _party == null or _selected_item < 0 or _selected_item >= _party.inventory.size():
		return false
	# 고른 아이템.
	var item: ItemData = _party.inventory[_selected_item]
	# 장착하면 가방 순서가 바뀌므로 선택을 먼저 푼다.
	_selected_item = -1
	# 장착을 요청한다 (성공하면 changed 신호로 다시 그려진다).
	return _party.equip(_selected_member, item)


## 고른 파티원이 그 부위에 낀 아이템을 벗는다.
func unequip_slot(slot: ItemData.Slot) -> bool:
	# 파티가 없으면 실패.
	if _party == null:
		return false
	# 해제를 요청한다.
	return _party.unequip(_selected_member, slot)


## 고른 파티원 번호 (테스트용 접근자).
func selected_member() -> int:
	# 번호를 돌려준다.
	return _selected_member


## 파티원 버튼 개수 (테스트용 접근자).
func member_button_count() -> int:
	# 목록의 자식 수를 돌려준다.
	return _member_list.get_child_count()


## 파티원 버튼 (테스트용 접근자).
func member_button(index: int) -> Button:
	# 목록의 그 자식을 돌려준다.
	return _member_list.get_child(index) as Button


## 장착 칸 버튼 (테스트용 접근자).
func slot_button(slot: ItemData.Slot) -> Button:
	# 부위로 찾는다.
	return _slot_buttons[slot]


## 가방 아이템 버튼 개수 (테스트용 접근자).
func inventory_button_count() -> int:
	# 격자의 자식 수를 돌려준다.
	return _inventory_grid.get_child_count()


## 가방 아이템 버튼 (테스트용 접근자).
func inventory_button(index: int) -> Button:
	# 격자의 그 자식을 돌려준다.
	return _inventory_grid.get_child(index) as Button


## 장착 버튼 (테스트용 접근자).
func equip_button() -> Button:
	# 버튼을 돌려준다.
	return _equip_button


## 능력치 글자 (테스트용 접근자).
func stats_text() -> String:
	# 글자를 돌려준다.
	return _stats_label.text


## 덱 구성 글자 (테스트용 접근자).
func deck_text() -> String:
	# 글자를 돌려준다.
	return _deck_label.text


## 아이템 설명 글자 (테스트용 접근자).
func detail_text() -> String:
	# 글자를 돌려준다.
	return _detail_label.text


## 화면 틀을 만든다: 위에 제목·닫기, 아래에 파티원 | 정보 | 장비·인벤토리 세 열.
func _build_ui() -> void:
	# 화면 전체를 덮는다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 지도를 가리는 불투명 배경.
	var background := ColorRect.new()
	# 배경색.
	background.color = BACKGROUND_COLOR
	# 화면 전체 크기.
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 붙인다.
	add_child(background)

	# 화면 가장자리 여백.
	var margin := MarginContainer.new()
	# 화면 전체 크기.
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 네 방향 모두 40 픽셀.
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	# 붙인다.
	add_child(margin)

	# 머리줄과 본문을 세로로 쌓는 상자.
	var root := VBoxContainer.new()
	# 사이 간격 20 픽셀.
	root.add_theme_constant_override("separation", 20)
	# 여백 안에 넣는다.
	margin.add_child(root)

	# 제목과 닫기 버튼 줄.
	root.add_child(_build_header())

	# 세 열을 가로로 늘어놓는 본문.
	var body := HBoxContainer.new()
	# 남은 세로 공간을 다 쓴다.
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 열 사이 간격 32 픽셀.
	body.add_theme_constant_override("separation", 32)
	# 붙인다.
	root.add_child(body)
	# 왼쪽: 파티원 목록.
	body.add_child(_build_member_column())
	# 가운데: 고른 파티원 정보.
	body.add_child(_build_info_column())
	# 오른쪽: 장비 칸과 인벤토리.
	body.add_child(_build_inventory_column())


## 제목과 닫기 버튼 줄.
func _build_header() -> HBoxContainer:
	# 가로 줄.
	var header := HBoxContainer.new()
	# 제목 글자.
	var title := Label.new()
	# 문구.
	title.text = "파티 · 인벤토리"
	# 크게.
	title.add_theme_font_size_override("font_size", 32)
	# 남은 가로 공간을 다 써서 닫기 버튼을 오른쪽 끝으로 민다.
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 붙인다.
	header.add_child(title)
	# 닫기 버튼.
	var close_button := Button.new()
	# 글자.
	close_button.text = "닫기"
	# 크기.
	close_button.custom_minimum_size = Vector2(120.0, 44.0)
	# 누르면 닫기 신호를 낸다.
	close_button.pressed.connect(func() -> void: closed.emit())
	# 붙인다.
	header.add_child(close_button)
	# 완성된 줄을 돌려준다.
	return header


## 왼쪽 열: 제목 + 파티원 버튼 목록(버튼은 _refresh_members 가 채운다).
func _build_member_column() -> VBoxContainer:
	# 세로 열.
	var column := VBoxContainer.new()
	# 너비 280 픽셀.
	column.custom_minimum_size = Vector2(280.0, 0.0)
	# 항목 간격 10 픽셀.
	column.add_theme_constant_override("separation", 10)
	# 제목.
	column.add_child(_make_heading("파티원"))
	# 파티원 버튼을 담을 목록.
	_member_list = VBoxContainer.new()
	# 버튼 간격 10 픽셀.
	_member_list.add_theme_constant_override("separation", 10)
	# 붙인다.
	column.add_child(_member_list)
	# 완성된 열을 돌려준다.
	return column


## 가운데 열: 그림, 이름, 능력치, 덱 구성.
func _build_info_column() -> VBoxContainer:
	# 세로 열.
	var column := VBoxContainer.new()
	# 너비 480 픽셀.
	column.custom_minimum_size = Vector2(480.0, 0.0)
	# 항목 간격 12 픽셀.
	column.add_theme_constant_override("separation", 12)

	# 파티원 그림.
	_portrait = TextureRect.new()
	# 256 픽셀 정사각형.
	_portrait.custom_minimum_size = Vector2(256.0, 256.0)
	# 그림 원래 크기를 무시하고 칸 크기에 맞춘다.
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 비율을 지키며 가운데에 놓는다.
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 픽셀 아트가 흐려지지 않게 확대할 때 보간하지 않는다.
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 붙인다.
	column.add_child(_portrait)

	# 이름 글자.
	_name_label = Label.new()
	# 크게.
	_name_label.add_theme_font_size_override("font_size", 28)
	# 붙인다.
	column.add_child(_name_label)

	# 능력치 글자.
	_stats_label = Label.new()
	# 보통 크기.
	_stats_label.add_theme_font_size_override("font_size", 20)
	# 붙인다.
	column.add_child(_stats_label)

	# 덱 구성 글자.
	_deck_label = Label.new()
	# 작게.
	_deck_label.add_theme_font_size_override("font_size", 16)
	# 붙인다.
	column.add_child(_deck_label)
	# 완성된 열을 돌려준다.
	return column


## 오른쪽 열: 장비 칸 3 개, 인벤토리 격자, 아이템 설명, 장착 버튼.
func _build_inventory_column() -> VBoxContainer:
	# 세로 열.
	var column := VBoxContainer.new()
	# 남은 가로 공간을 다 쓴다.
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 항목 간격 10 픽셀.
	column.add_theme_constant_override("separation", 10)

	# 장비 칸 제목.
	column.add_child(_make_heading("장비 (눌러서 해제)"))
	# 부위마다 장착 칸 버튼을 만든다.
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.ACCESSORY]:
		# 버튼을 만든다.
		var button := Button.new()
		# 높이 48 픽셀.
		button.custom_minimum_size = Vector2(0.0, 48.0)
		# 글자를 왼쪽 정렬.
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 누르면 그 부위를 해제한다.
		button.pressed.connect(unequip_slot.bind(slot))
		# 붙인다.
		column.add_child(button)
		# 부위로 찾을 수 있게 기억한다.
		_slot_buttons[slot] = button

	# 인벤토리 제목.
	column.add_child(_make_heading("인벤토리 (눌러서 선택)"))
	# 아이템 버튼 격자.
	_inventory_grid = GridContainer.new()
	# 열 수.
	_inventory_grid.columns = INVENTORY_COLUMNS
	# 가로 간격 8 픽셀.
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	# 세로 간격 8 픽셀.
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	# 붙인다.
	column.add_child(_inventory_grid)

	# 가방이 비었을 때의 안내.
	_inventory_empty_label = Label.new()
	# 문구.
	_inventory_empty_label.text = "가방이 비었습니다"
	# 붙인다.
	column.add_child(_inventory_empty_label)

	# 고른 아이템 설명.
	_detail_label = Label.new()
	# 너비를 넘으면 단어 단위로 줄을 바꾼다.
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 줄 수가 바뀌어도 아래 버튼이 들썩이지 않게 높이를 확보한다.
	_detail_label.custom_minimum_size = Vector2(0.0, 110.0)
	# 붙인다.
	column.add_child(_detail_label)

	# 장착 버튼.
	_equip_button = Button.new()
	# 높이 52 픽셀.
	_equip_button.custom_minimum_size = Vector2(0.0, 52.0)
	# 누르면 고른 아이템을 장착한다.
	_equip_button.pressed.connect(equip_selected)
	# 붙인다.
	column.add_child(_equip_button)
	# 완성된 열을 돌려준다.
	return column


## 열 제목 글자를 만든다.
func _make_heading(text: String) -> Label:
	# 글자를 만든다.
	var label := Label.new()
	# 문구.
	label.text = text
	# 조금 크게.
	label.add_theme_font_size_override("font_size", 22)
	# 만든 글자를 돌려준다.
	return label


## 화면 전체를 파티 상태에 맞춰 다시 그린다.
func _refresh() -> void:
	# 파티가 없으면 그릴 것이 없다.
	if _party == null:
		return
	# 장착 등으로 가방이 줄어 고른 번호가 범위를 벗어났으면 선택을 푼다.
	if _selected_item >= _party.inventory.size():
		_selected_item = -1
	# 파티원 목록.
	_refresh_members()
	# 가운데 정보.
	_refresh_info()
	# 장착 칸.
	_refresh_slots()
	# 가방.
	_refresh_inventory()
	# 아이템 설명과 장착 버튼.
	_refresh_detail()


## 파티원 버튼을 새로 만든다. 고른 파티원 앞에는 ▶ 를 붙인다.
func _refresh_members() -> void:
	# 기존 버튼을 지운다.
	_clear(_member_list)
	# 파티원마다.
	for i in _party.member_count():
		# 기본 데이터 (이름용).
		var data: AllyData = _party.member_data(i)
		# 장비 반영 능력치 (체력 표시용).
		var final_stats: Dictionary = _party.stats(i)
		# 버튼을 만든다.
		var button := Button.new()
		# 높이 64 픽셀.
		button.custom_minimum_size = Vector2(0.0, 64.0)
		# 글자를 왼쪽 정렬.
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# 고른 파티원이면 표시를 붙인다.
		var prefix: String = SELECTED_PREFIX if i == _selected_member else ""
		# "▶ 이름   HP 12" 형태.
		button.text = "%s%s   HP %d" % [prefix, data.display_name, final_stats["max_hp"]]
		# 누르면 그 파티원을 고른다.
		button.pressed.connect(select_member.bind(i))
		# 붙인다.
		_member_list.add_child(button)


## 가운데 열을 고른 파티원으로 채운다.
func _refresh_info() -> void:
	# 기본 데이터.
	var data: AllyData = _party.member_data(_selected_member)
	# 장비 반영 능력치.
	var final_stats: Dictionary = _party.stats(_selected_member)
	# 그림.
	_portrait.texture = data.sprite
	# 이름.
	_name_label.text = data.display_name
	# 능력치 줄들 (장비로 바뀐 값은 차이를 괄호로 붙인다).
	var lines: PackedStringArray = [
		_stat_line("체력", final_stats["max_hp"], data.max_hp),
		_stat_line("속도", final_stats["speed"], data.speed),
		_stat_line("SP", final_stats["max_sp"], data.max_sp),
		_stat_line("공격", final_stats["attack"], data.attack),
		_stat_line("방어", final_stats["defense"], data.defense),
		"치명확률  %d%%" % final_stats["crit_chance"],
		"치명피해  %d%%" % final_stats["crit_damage"],
		_stat_line("어그로", final_stats["aggro"], data.aggro),
	]
	# 줄바꿈으로 이어 넣는다.
	_stats_label.text = "\n".join(lines)
	# 덱 구성.
	_deck_label.text = _deck_summary(data)


## 장착 칸 버튼 글자를 고른 파티원의 장비로 바꾼다. 빈 칸은 누를 수 없다.
func _refresh_slots() -> void:
	# 부위마다.
	for slot in _slot_buttons:
		# 그 부위의 버튼.
		var button: Button = _slot_buttons[slot]
		# 그 부위에 낀 아이템.
		var item: ItemData = _party.equipped(_selected_member, slot)
		# 부위 이름.
		var slot_label: String = ItemData.slot_name(slot)
		# 비어 있으면.
		if item == null:
			# "무기:  비어 있음".
			button.text = "%s:  비어 있음" % slot_label
			# 해제할 것이 없으니 막는다.
			button.disabled = true
		# 끼고 있으면.
		else:
			# "무기:  녹슨 단검   공격 +1".
			button.text = "%s:  %s   %s" % [slot_label, item.display_name, item.summary()]
			# 눌러서 해제할 수 있다.
			button.disabled = false


## 가방 아이템 버튼을 새로 만든다.
func _refresh_inventory() -> void:
	# 기존 버튼을 지운다.
	_clear(_inventory_grid)
	# 가방이 비었을 때만 안내를 보인다.
	_inventory_empty_label.visible = _party.inventory.is_empty()
	# 가방의 아이템마다.
	for i in _party.inventory.size():
		# 그 아이템.
		var item: ItemData = _party.inventory[i]
		# 버튼을 만든다.
		var button := Button.new()
		# 크기 150 × 64 픽셀.
		button.custom_minimum_size = Vector2(150.0, 64.0)
		# 고른 아이템이면 표시를 붙인다.
		var prefix: String = SELECTED_PREFIX if i == _selected_item else ""
		# 이름.
		button.text = prefix + item.display_name
		# 마우스를 올리면 설명이 뜬다.
		button.tooltip_text = item.description
		# 누르면 그 아이템을 고른다.
		button.pressed.connect(select_item.bind(i))
		# 붙인다.
		_inventory_grid.add_child(button)


## 고른 아이템의 설명과 장착 버튼을 채운다.
func _refresh_detail() -> void:
	# 고른 아이템이 없으면 안내만 보이고 장착 버튼을 막는다.
	if _selected_item < 0:
		# 안내 문구.
		_detail_label.text = "아이템을 선택하면 설명이 보입니다."
		# 버튼 글자.
		_equip_button.text = "장착"
		# 막는다.
		_equip_button.disabled = true
		# 끝.
		return
	# 고른 아이템.
	var item: ItemData = _party.inventory[_selected_item]
	# 설명 줄들: 이름과 부위, 보너스 요약, 설명.
	var lines: PackedStringArray = [
		"%s  [%s]" % [item.display_name, ItemData.slot_name(item.slot)],
		item.summary(),
		item.description,
	]
	# 같은 부위에 이미 낀 아이템.
	var current: ItemData = _party.equipped(_selected_member, item.slot)
	# 있으면 교체된다는 안내를 붙인다.
	if current != null:
		lines.append("교체: %s 은(는) 가방으로 돌아갑니다." % current.display_name)
	# 줄바꿈으로 이어 넣는다.
	_detail_label.text = "\n".join(lines)
	# "이름 에게 장착".
	_equip_button.text = "%s 에게 장착" % _party.member_data(_selected_member).display_name
	# 누를 수 있다.
	_equip_button.disabled = false


## 능력치 한 줄. 장비로 바뀌었으면 "체력  14 (+4)", 아니면 "체력  10".
func _stat_line(label: String, final_value: int, base_value: int) -> String:
	# 바뀐 게 없으면 값만.
	if final_value == base_value:
		return "%s  %d" % [label, final_value]
	# 바뀌었으면 차이를 부호와 함께 붙인다.
	return "%s  %d (%+d)" % [label, final_value, final_value - base_value]


## 덱 구성 글자. 첫 줄에 총 장수, 다음 줄부터 카드 이름별 장수와 효과(%).
func _deck_summary(data: AllyData) -> String:
	# 카드 이름 -> 장수.
	var counts: Dictionary = {}
	# 카드 이름 -> 그 카드 (효과 문구용, 처음 나온 것).
	var cards: Dictionary = {}
	# 덱의 카드마다 장수를 센다.
	for card in data.deck:
		counts[card.display_name] = int(counts.get(card.display_name, 0)) + 1
		if not cards.has(card.display_name):
			cards[card.display_name] = card
	# 첫 줄: 총 장수.
	var lines: PackedStringArray = ["덱  %d장" % data.deck.size()]
	# 카드 이름마다 한 줄씩 (덱 편집 화면이라 % 로 보여 준다).
	for card_name in counts:
		lines.append("  %s ×%d — %s" % [card_name, counts[card_name], CardText.describe(cards[card_name])])
	# 줄바꿈으로 이어 돌려준다.
	return "\n".join(lines)


## 컨테이너의 자식을 모두 지운다.
func _clear(container: Container) -> void:
	# 자식마다.
	for child in container.get_children():
		# 바로 떼어 낸다 — queue_free 만 하면 이번 프레임 동안 자식 수가 줄지 않는다.
		container.remove_child(child)
		# 메모리에서 지운다.
		child.queue_free()
