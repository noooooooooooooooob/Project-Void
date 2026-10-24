## 원정 지도: 왼쪽에서 오른쪽으로 진행하는 3줄 노드 지도. 노드는 선으로 이어지고, 지금 위치와 이어진 노드만 고를 수 있다.
## 노드에 마우스를 올리면 아래 정보 패널에 내용(적 구성 등)을 보여 준다. 고르면 node_chosen(id).
class_name ExpeditionView
extends Control

signal node_chosen(node_id: int)
signal party_requested

const TYPE_COLORS: Dictionary = {
	"battle": Color(0.88, 0.48, 0.48),
	"elite": Color(1.0, 0.58, 0.28),
	"boss": Color(1.0, 0.28, 0.35),
	"event": Color(0.58, 0.72, 1.0),
	"rest": Color(0.5, 0.9, 0.6),
	"supply": Color(0.95, 0.8, 0.45),
	"shop": Color(0.85, 0.6, 1.0),
}
const TYPE_ICONS: Dictionary = {"battle": "⚔", "elite": "☠", "boss": "♛", "event": "?", "rest": "☾", "supply": "◆", "shop": "$"}
## 지도 영역 (화면 좌표).
const MAP_LEFT: float = 230.0
const MAP_RIGHT: float = 1690.0
const LANE_Y: Array[float] = [330.0, 520.0, 710.0]
const NODE_SIZE: float = 100.0
const EXIT_SIZE: float = 136.0

var _ex: Expedition
var _bg: Control
var _header: Label
var _sub: Label
var _floors: HBoxContainer
var _lines: Control
var _node_layer: Control
var _buttons: Dictionary = {}
var _party: VBoxContainer
var _info_title: Label
var _info_body: Label
var _time: float = 0.0


func expedition() -> Expedition:
	return _ex


func _init(ex: Expedition) -> void:
	_ex = ex


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = UiTheme.backdrop(UiTheme.bg("void"), 0.5)
	add_child(_bg)
	var top := VBoxContainer.new()
	top.position = Vector2(60, 36)
	add_child(top)
	_header = UiTheme.title_label("", 44)
	top.add_child(_header)
	_sub = UiTheme.label("", 20, UiTheme.TEXT_DIM)
	top.add_child(_sub)
	_floors = HBoxContainer.new()
	_floors.add_theme_constant_override("separation", 8)
	top.add_child(_floors)
	_lines = Control.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	_node_layer = Control.new()
	_node_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_layer)
	var party_panel := PanelContainer.new()
	party_panel.anchor_top = 1.0
	party_panel.anchor_bottom = 1.0
	party_panel.offset_left = 40
	party_panel.offset_top = -210
	party_panel.offset_right = 480
	party_panel.offset_bottom = -36
	add_child(party_panel)
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 10)
	party_panel.add_child(_party)
	var info := PanelContainer.new()
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 520
	info.offset_right = 1300
	info.offset_top = -210
	info.offset_bottom = -36
	add_child(info)
	var info_col := VBoxContainer.new()
	info.add_child(info_col)
	_info_title = UiTheme.title_label("", 28)
	info_col.add_child(_info_title)
	_info_body = UiTheme.body("", 19, UiTheme.TEXT)
	info_col.add_child(_info_body)
	var party_button := UiTheme.button("사원 명부 · 장비", Vector2(260, 60))
	party_button.anchor_left = 1.0
	party_button.anchor_right = 1.0
	party_button.anchor_top = 1.0
	party_button.anchor_bottom = 1.0
	party_button.offset_left = -310
	party_button.offset_right = -50
	party_button.offset_top = -100
	party_button.offset_bottom = -40
	party_button.pressed.connect(func() -> void: party_requested.emit())
	add_child(party_button)
	refresh()


func _process(delta: float) -> void:
	_time += delta
	# 고를 수 있는 노드는 숨 쉬듯 커졌다 작아진다.
	var pulse: float = 1.0 + 0.06 * sin(_time * 4.0)
	for id in _buttons:
		var b: Button = _buttons[id]
		b.scale = Vector2(pulse, pulse) if _ex.is_selectable(id) else Vector2.ONE


func refresh() -> void:
	(_bg.get_child(0) as TextureRect).texture = UiTheme.bg("twilight" if _ex.deep else "void")
	_header.text = "%d구역 · %s" % [_ex.floor_index + 1, _ex.floor_name()]
	_sub.text = "%s  ·  %s  ·  이번 원정 자금 +%d  ·  보유 %d" % [_ex.request["title"], "황혼층" if _ex.deep else "공허", _ex.gold_earned, _ex.game.gold]
	_clear(_floors)
	for f in _ex.floor_count():
		var mark: String = "■" if f < _ex.floor_index else ("▣" if f == _ex.floor_index else "□")
		_floors.add_child(UiTheme.label("%s %d구역" % [mark, f + 1], 18, UiTheme.LAVENDER if f <= _ex.floor_index else UiTheme.TEXT_DIM))
	_build_nodes()
	_lines.queue_redraw()
	_clear(_party)
	for i in _ex.game.party.member_count():
		_party.add_child(_member_row(i))
	_show_info(-1)


## 노드 중심의 화면 좌표.
func node_position(id: int) -> Vector2:
	var n: ExpeditionNode = _ex.node(id)
	var x: float = MAP_LEFT + (MAP_RIGHT - MAP_LEFT) * float(n.col) / float(_ex.column_count())
	return Vector2(x, LANE_Y[n.lane])


func button_for(id: int) -> Button:
	return _buttons.get(id)


func _build_nodes() -> void:
	_clear(_node_layer)
	_buttons.clear()
	for n in _ex.nodes:
		var id: int = n.id
		var t: String = n.type
		var color: Color = TYPE_COLORS.get(t, UiTheme.LAVENDER)
		var size: float = EXIT_SIZE if n.exit else NODE_SIZE
		var selectable: bool = _ex.is_selectable(id)
		var visited: bool = _ex.visited.has(id)
		var current: bool = id == _ex.current_id
		var b := Button.new()
		b.text = TYPE_ICONS.get(t, "•")
		b.add_theme_font_size_override("font_size", 46 if n.exit else 38)
		b.custom_minimum_size = Vector2(size, size)
		b.size = Vector2(size, size)
		b.position = node_position(id) - Vector2(size, size) / 2.0
		b.pivot_offset = Vector2(size, size) / 2.0
		var radius: int = int(size / 2.0)
		var fill: Color = Color(0.1, 0.08, 0.14, 0.95)
		var border: Color = color.darkened(0.45)
		var width: int = 3
		if visited:
			fill = color.darkened(0.6)
			border = UiTheme.GOLD.darkened(0.2)
		if selectable:
			border = color
			width = 5
		if current:
			border = UiTheme.GOLD
			width = 6
		b.add_theme_stylebox_override("normal", UiTheme.box(fill, border, width, radius, 0))
		b.add_theme_stylebox_override("hover", UiTheme.box(fill.lightened(0.15), color.lightened(0.3), width + 1, radius, 0))
		b.add_theme_stylebox_override("pressed", UiTheme.box(fill.lightened(0.25), UiTheme.GOLD, width + 1, radius, 0))
		b.add_theme_stylebox_override("disabled", UiTheme.box(fill, border, width, radius, 0))
		b.add_theme_color_override("font_color", color)
		b.add_theme_color_override("font_disabled_color", color.darkened(0.25) if (visited or current) else color.darkened(0.5))
		b.disabled = not selectable
		if not selectable and not visited and not current:
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func() -> void: node_chosen.emit(id))
		b.mouse_entered.connect(_show_info.bind(id))
		b.mouse_exited.connect(_show_info.bind(-1))
		_node_layer.add_child(b)
		_buttons[id] = b
		if n.exit:
			var tag := UiTheme.label("출구 · %s" % ChapterData.NODE_INFO[t]["name"], 18, color)
			tag.position = node_position(id) + Vector2(-60, size / 2.0 + 6)
			_node_layer.add_child(tag)


func _draw_lines() -> void:
	for n in _ex.nodes:
		var from: Vector2 = node_position(n.id)
		for next_id in n.next:
			var to: Vector2 = node_position(next_id)
			var walked: bool = _ex.visited.has(n.id) and _ex.visited.has(next_id)
			var open: bool = n.id == _ex.current_id and _ex.is_selectable(next_id)
			var color := Color(0.55, 0.5, 0.65, 0.35)
			var width: float = 3.0
			if walked:
				color = UiTheme.GOLD
				width = 6.0
			elif open:
				color = UiTheme.LAVENDER
				width = 5.0
			_lines.draw_line(from, to, color, width, true)
	if _ex.current_id < 0:
		for id in _ex.selectable_ids():
			var to: Vector2 = node_position(id)
			_lines.draw_line(Vector2(MAP_LEFT - 140, LANE_Y[1]), to, UiTheme.LAVENDER, 4.0, true)
		_lines.draw_circle(Vector2(MAP_LEFT - 140, LANE_Y[1]), 14.0, UiTheme.GOLD)


func _show_info(id: int) -> void:
	if id < 0:
		_info_title.text = "갈 곳을 고르세요"
		_info_body.text = "빛나는 노드만 고를 수 있습니다. 노드는 선으로 이어진 다음 칸으로만 나아갑니다."
		return
	var n: ExpeditionNode = _ex.node(id)
	var info: Dictionary = ChapterData.NODE_INFO[n.type]
	_info_title.text = info["name"] + ("  (구역 출구)" if n.exit else "")
	var lines: PackedStringArray = [info["desc"]]
	if n.is_battle():
		var names: PackedStringArray = []
		for enemy_id in n.enemies:
			names.append(Content.unit(enemy_id).display_name)
		lines.append("적: " + ", ".join(names))
	if not _ex.is_selectable(id) and not _ex.visited.has(id):
		lines.append("(지금은 갈 수 없음)")
	_info_body.text = "\n".join(lines)


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
