## 상점 (공허 상인): 장비 3개, 카드 3장, 치료를 자금으로 산다. 산 물건은 품절로 바뀐다. 떠나면 done.
class_name ShopView
extends Control

signal done

const CARD_SCALE: float = 1.45

var _ex: Expedition
var _stock: Dictionary
var _gold: Label
var _buttons: Array[Button] = []
var _prices: Array[int] = []
var _sold: Array[bool] = []


func _init(ex: Expedition, stock: Dictionary) -> void:
	_ex = ex
	_stock = stock


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiTheme.backdrop(UiTheme.bg("twilight" if _ex.deep else "void"), 0.62))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	center.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	col.add_child(head)
	head.add_child(UiTheme.title_label("공허 상인", 46, ExpeditionView.TYPE_COLORS["shop"]))
	_gold = UiTheme.label("", 26, UiTheme.GOLD)
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold)
	col.add_child(UiTheme.body("\"...살 거면 사고, 아니면 가.\" 기름에 젖은 망토 아래로 목소리가 새어 나온다.", 19, UiTheme.TEXT_DIM))
	# 카드.
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 36)
	col.add_child(cards_row)
	for choice in _stock["cards"]:
		cards_row.add_child(_card_offer(choice))
	# 장비 + 치료.
	var items_row := HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 20)
	col.add_child(items_row)
	for offer in _stock["items"]:
		items_row.add_child(_item_offer(offer))
	items_row.add_child(_heal_offer())
	var leave := UiTheme.button("떠난다", Vector2(240, 56))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func() -> void: done.emit())
	col.add_child(leave)
	_refresh()


func _card_offer(choice: Dictionary) -> Control:
	var data: AllyData = _ex.game.party.member_data(choice["member"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var who := UiTheme.label(data.display_name, 20, UiTheme.LAVENDER)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.SIZE * CARD_SCALE
	box.add_child(holder)
	var view := CardView.new()
	view.setup(choice["card"], data)
	view.pivot_offset = Vector2.ZERO
	view.position = Vector2.ZERO
	view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(view)
	var price: int = choice["price"]
	box.add_child(_buy_button(price, func() -> void: _ex.game.add_card(choice["member"], choice["card"])))
	return box


func _item_offer(offer: Dictionary) -> Control:
	var item: ItemData = offer["item"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load("res://Art/gen/icons/%s.png" % ["weapon", "armor", "accessory"][item.slot])
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)
	box.add_child(UiTheme.title_label(item.display_name, 24))
	box.add_child(UiTheme.label("%s · %s" % [ItemData.slot_name(item.slot), item.summary()], 17, UiTheme.GOLD))
	box.add_child(_buy_button(offer["price"], func() -> void: _ex.game.party.add_item(item)))
	return panel


func _heal_offer() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.label("✚", 40, Color(0.5, 0.9, 0.6)))
	box.add_child(UiTheme.title_label("응급 처치", 24))
	box.add_child(UiTheme.label("모두 체력 %d%% 회복" % roundi(Expedition.SHOP_HEAL * 100), 17, UiTheme.GOLD))
	box.add_child(_buy_button(_stock["heal_price"], func() -> void: _ex.heal_party(Expedition.SHOP_HEAL)))
	return panel


func _buy_button(price: int, on_buy: Callable) -> Button:
	var index: int = _buttons.size()
	var b := UiTheme.button("구매  %d" % price, Vector2(0, 50))
	b.pressed.connect(func() -> void:
		if _sold[index] or not _ex.spend(price):
			return
		on_buy.call()
		_sold[index] = true
		_refresh())
	_buttons.append(b)
	_prices.append(price)
	_sold.append(false)
	return b


func _refresh() -> void:
	_gold.text = "보유 자금  %d" % _ex.game.gold
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if _sold[i]:
			b.text = "품절"
			b.disabled = true
		else:
			b.disabled = _ex.game.gold < _prices[i]


## 테스트·자동 진행용.
func buy_button(index: int) -> Button:
	return _buttons[index]
