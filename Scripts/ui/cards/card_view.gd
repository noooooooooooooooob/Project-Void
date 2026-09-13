class_name CardView
extends Control

const SIZE := Vector2(110, 154)
const MELEE_COLOR := Color(0.85, 0.4, 0.35)
const RANGED_COLOR := Color(0.4, 0.6, 0.95)
const FACE_COLOR := Color(0.12, 0.12, 0.15)
const BACK_COLOR := Color(0.18, 0.22, 0.38)
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.55)
const SHAPE_NAMES: Dictionary = {
	CardData.Shape.SINGLE: "단일",
	CardData.Shape.SWEEP: "횡렬",
	CardData.Shape.PIERCE: "관통",
}

var card: CardData

var _face: Panel
var _back: Panel
var _cost_label: Label
var _name_label: Label
var _damage_label: Label
var _footer_label: Label
var _border_color: Color = Color.WHITE


func setup(p_card: CardData) -> void:
	card = p_card
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var melee: bool = card.attack_type == CardData.AttackType.MELEE
	_border_color = MELEE_COLOR if melee else RANGED_COLOR

	_face = _make_panel(FACE_COLOR, _border_color, 8)
	add_child(_face)

	var cost_badge: Panel = _make_panel(_border_color, _border_color, 14)
	cost_badge.position = Vector2(6, 6)
	cost_badge.size = Vector2(28, 28)
	_face.add_child(cost_badge)
	_cost_label = _make_label(str(card.sp_cost), 18, Vector2.ZERO, cost_badge.size)
	cost_badge.add_child(_cost_label)

	_name_label = _make_label(card.display_name, 16, Vector2(0, 36), Vector2(SIZE.x, 24))
	_face.add_child(_name_label)
	_damage_label = _make_label(str(card.damage), 40, Vector2(0, 62), Vector2(SIZE.x, 50))
	_face.add_child(_damage_label)
	var kind: String = "근접" if melee else "원거리"
	_footer_label = _make_label("%s · 사거리 %d · %s" % [kind, card.attack_range, SHAPE_NAMES[card.shape]], 11, Vector2(4, 114), Vector2(SIZE.x - 8, 34))
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_face.add_child(_footer_label)

	_back = make_back()
	add_child(_back)
	set_face_up(true)


static func make_back() -> Panel:
	var back: Panel = _make_panel(BACK_COLOR, BACK_COLOR.lightened(0.3), 8)
	back.add_child(_make_label("VOID", 22, Vector2(0, 60), Vector2(SIZE.x, 34)))
	return back


func set_face_up(face_up: bool) -> void:
	_face.visible = face_up
	_back.visible = not face_up


func is_face_up() -> bool:
	return _face.visible


func set_affordable(affordable: bool) -> void:
	modulate = Color.WHITE if affordable else UNAFFORDABLE_MODULATE


func cost_text() -> String:
	return _cost_label.text


func name_text() -> String:
	return _name_label.text


func damage_text() -> String:
	return _damage_label.text


func footer_text() -> String:
	return _footer_label.text


func border_color() -> Color:
	return _border_color


static func _make_panel(background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


static func _make_label(text: String, font_size: int, at: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
