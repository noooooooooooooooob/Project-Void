## 원정 지도: 지금 층과 단계, 고를 수 있는 문(노드)들, 파티 체력, 번 자금. 문을 누르면 node_chosen.
class_name ExpeditionView
extends Control

signal node_chosen(index: int)
signal party_requested

const TYPE_COLORS: Dictionary = {
	"battle": Color(0.85, 0.5, 0.5),
	"elite": Color(1.0, 0.55, 0.3),
	"boss": Color(1.0, 0.3, 0.35),
	"event": Color(0.6, 0.75, 1.0),
	"rest": Color(0.5, 0.9, 0.6),
	"supply": Color(0.95, 0.8, 0.45),
}
const TYPE_ICONS: Dictionary = {"battle": "⚔", "elite": "☠", "boss": "♛", "event": "?", "rest": "☾", "supply": "◆"}

var _ex: Expedition
var _bg: Control
var _header: Label
var _sub: Label
var _doors: HBoxContainer
var _party: VBoxContainer
var _progress: HBoxContainer


func _init(ex: Expedition) -> void:
	_ex = ex


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = UiTheme.backdrop(UiTheme.bg("twilight" if _ex.deep else "void"), 0.35)
	add_child(_bg)
	# 위쪽 머리글.
	var top := VBoxContainer.new()
	top.position = Vector2(60, 40)
	add_child(top)
	_header = UiTheme.title_label("", 44)
	top.add_child(_header)
	_sub = UiTheme.label("", 20, UiTheme.TEXT_DIM)
	top.add_child(_sub)
	_progress = HBoxContainer.new()
	_progress.add_theme_constant_override("separation", 10)
	top.add_child(_progress)
	# 가운데 문들.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_doors = HBoxContainer.new()
	_doors.add_theme_constant_override("separation", 36)
	center.add_child(_doors)
	# 왼쪽 아래 파티.
	var party_panel := PanelContainer.new()
	party_panel.anchor_top = 1.0
	party_panel.anchor_bottom = 1.0
	party_panel.offset_left = 40
	party_panel.offset_top = -230
	party_panel.offset_right = 480
	party_panel.offset_bottom = -40
	add_child(party_panel)
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 10)
	party_panel.add_child(_party)
	# 오른쪽 아래 버튼.
	var party_button := UiTheme.button("사원 명부 · 장비", Vector2(240, 56))
	party_button.anchor_left = 1.0
	party_button.anchor_right = 1.0
	party_button.anchor_top = 1.0
	party_button.anchor_bottom = 1.0
	party_button.offset_left = -290
	party_button.offset_right = -50
	party_button.offset_top = -100
	party_button.offset_bottom = -44
	party_button.pressed.connect(func() -> void: party_requested.emit())
	add_child(party_button)
	refresh()


func refresh() -> void:
	(_bg.get_child(0) as TextureRect).texture = UiTheme.bg("twilight" if _ex.deep else "void")
	var layer: String = "황혼층" if _ex.deep else "공허"
	_header.text = "%d구역 · %s" % [_ex.floor_index + 1, _ex.floor_name()]
	_sub.text = "%s  ·  %s  ·  이번 원정 자금 +%d  ·  보유 %d" % [_ex.request["title"], layer, _ex.gold_earned, _ex.game.gold]
	_clear(_progress)
	for i in _ex.steps_per_floor() + 1:
		var dot := UiTheme.label("●" if i < _ex.step else ("◉" if i == _ex.step else "○"), 22, UiTheme.LAVENDER if i <= _ex.step else UiTheme.TEXT_DIM)
		_progress.add_child(dot)
	var exit_label := UiTheme.label("  출구" if not _ex.at_exit() else "  출구 ◀", 18, UiTheme.TEXT_DIM)
	_progress.add_child(exit_label)
	_clear(_doors)
	for i in _ex.options.size():
		_doors.add_child(_door(_ex.options[i], i))
	_clear(_party)
	for i in _ex.game.party.member_count():
		_party.add_child(_member_row(i))


func _door(node: Dictionary, index: int) -> Control:
	var t: String = node["type"]
	var info: Dictionary = ChapterData.NODE_INFO[t]
	var color: Color = TYPE_COLORS.get(t, UiTheme.LAVENDER)
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 400)
	button.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.08, 0.14, 0.92), color.darkened(0.3), 3, 12))
	button.add_theme_stylebox_override("hover", UiTheme.box(Color(0.18, 0.14, 0.24, 0.97), color, 4, 12))
	button.add_theme_stylebox_override("pressed", UiTheme.box(Color(0.25, 0.2, 0.33, 1.0), color, 4, 12))
	button.pressed.connect(func() -> void: node_chosen.emit(index))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 30
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(col)
	var icon := UiTheme.label(TYPE_ICONS.get(t, "•"), 72, color)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(icon)
	var title_text := UiTheme.title_label(info["name"], 34, color)
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_text)
	var desc := UiTheme.body(info["desc"], 18, UiTheme.TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(desc)
	if node.has("enemies"):
		var names: PackedStringArray = []
		for id in node["enemies"]:
			var data: UnitData = load("res://Resources/content/units/%s.tres" % id)
			names.append(data.display_name)
		var foes := UiTheme.body("\n".join(names), 18, UiTheme.TEXT)
		foes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(foes)
	for c in col.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _member_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var data: AllyData = _ex.game.party.member_data(index)
	var face := TextureRect.new()
	face.texture = data.sprite
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var max_hp: int = _ex.game.party.stats(index)["max_hp"]
	col.add_child(UiTheme.label("%s   %d / %d" % [data.display_name, _ex.hp.get(index, 0), max_hp], 20))
	var bar := ProgressBar.new()
	bar.max_value = max_hp
	bar.value = _ex.hp.get(index, 0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.05, 0.04, 0.07), Color(0.2, 0.18, 0.25), 1, 4, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(Color(0.45, 0.82, 0.5), Color(0.45, 0.82, 0.5), 0, 4, 0))
	col.add_child(bar)
	return row


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
