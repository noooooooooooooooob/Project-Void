class_name PileView
extends Control

const SIZE := Vector2(90, 126)
const DIM_MODULATE := Color(1, 1, 1, 0.4)

var _owner_label: Label
var _count_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE

	var back: Panel = CardView.make_back()
	back.scale = SIZE / CardView.SIZE
	add_child(back)

	_count_label = Label.new()
	_count_label.position = Vector2(0, SIZE.y - 38)
	_count_label.size = Vector2(SIZE.x, 32)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override(&"font_size", 24)
	_count_label.add_theme_constant_override(&"outline_size", 6)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	_owner_label = Label.new()
	_owner_label.position = Vector2(0, -26)
	_owner_label.size = Vector2(SIZE.x, 24)
	_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owner_label.add_theme_font_size_override(&"font_size", 14)
	_owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_owner_label)

	set_count(0)


func set_owner_name(owner_name: String) -> void:
	_owner_label.text = owner_name


func set_count(count: int) -> void:
	_count_label.text = str(count)


func set_dimmed(dimmed: bool) -> void:
	modulate = DIM_MODULATE if dimmed else Color.WHITE


func is_dimmed() -> bool:
	return modulate == DIM_MODULATE


func count_text() -> String:
	return _count_label.text


func owner_text() -> String:
	return _owner_label.text


func center_global() -> Vector2:
	return global_position + SIZE / 2.0
