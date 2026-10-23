## 보급: 장비 3개 중 하나를 고른다. done(index).
class_name SupplyView
extends Control

signal done(index: int)

var _items: Array[ItemData]


func _init(items: Array[ItemData]) -> void:
	_items = items


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiTheme.backdrop(UiTheme.bg("void"), 0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	center.add_child(col)
	var title := UiTheme.title_label("보급 상자", 48, UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)
	for i in _items.size():
		var item: ItemData = _items[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(320, 260)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 20
		inner.offset_right = -20
		inner.offset_top = 24
		inner.add_theme_constant_override("separation", 12)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var icon := TextureRect.new()
		icon.texture = load("res://Art/gen/icons/%s.png" % ["weapon", "armor", "accessory"][item.slot])
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		for l in [UiTheme.title_label(item.display_name, 28), UiTheme.label("%s · %s" % [ItemData.slot_name(item.slot), item.summary()], 18, UiTheme.GOLD), UiTheme.body(item.description, 16, UiTheme.TEXT_DIM)]:
			(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(l)
		b.pressed.connect(func() -> void: done.emit(i))
		row.add_child(b)
	var skip := UiTheme.button("두고 간다", Vector2(220, 52))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void: done.emit(-1))
	col.add_child(skip)
