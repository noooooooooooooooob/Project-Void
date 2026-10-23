## 사무소 허브 (v6 사이드 레일): 오른쪽 레일에서 메뉴를 고르면 왼쪽에 연보라 패널이 열린다.
## 의뢰 게시판 → 의뢰를 골라 출발(request_chosen), 사원 명부·창고 → party_requested, 일지 → 기록 목록, 메인 메뉴로 → main_menu_requested.
class_name OfficeScreen
extends Control

signal request_chosen(request_id: String)
signal party_requested
signal main_menu_requested

const RAIL: Array[Array] = [["01", "의뢰 게시판", "requests"], ["02", "사원 명부 · 창고", "party"], ["03", "일지", "journal"], ["04", "저장하고 메인 메뉴로", "menu"]]
const OFFICE_LINES: Array[String] = [
	"홍연: ...캥.",
	"홍연: 졸려. ...의뢰, 있어?",
	"홍연: 아빠가 차 마시러 온대. ...피 말고 차.",
	"홍연: 장비, 정비했어. ...아마.",
]

var _game: GameState
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _hud: Label
var _bubble: Label
var _rail_buttons: Dictionary = {}


func _init(game: GameState) -> void:
	_game = game


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.backdrop(UiTheme.bg("office"), 0.12))
	# 홍연 일러스트 (합류했으면).
	if _game.has_member("hongyeon"):
		var p := TextureRect.new()
		p.texture = StoryCast.portrait("hongyeon")
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		p.anchor_left = 0.36
		p.anchor_right = 0.66
		p.anchor_top = 0.24
		p.anchor_bottom = 1.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_bubble = UiTheme.label(OFFICE_LINES[randi() % OFFICE_LINES.size()], 20)
		var bubble_panel := PanelContainer.new()
		bubble_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.08, 0.14, 0.85), UiTheme.LAVENDER_DIM, 1, 8, 14))
		bubble_panel.anchor_left = 0.42
		bubble_panel.anchor_top = 0.2
		bubble_panel.add_child(_bubble)
		add_child(bubble_panel)
	# 머리글·HUD.
	var title := UiTheme.title_label("공허 정화 사무소", 40)
	title.position = Vector2(48, 32)
	add_child(title)
	_hud = UiTheme.label("", 20, UiTheme.TEXT)
	var hud_panel := PanelContainer.new()
	hud_panel.anchor_left = 1.0
	hud_panel.anchor_right = 1.0
	hud_panel.offset_left = -560
	hud_panel.offset_right = -40
	hud_panel.offset_top = 30
	hud_panel.add_child(_hud)
	add_child(hud_panel)
	# 오른쪽 레일.
	var rail := VBoxContainer.new()
	rail.anchor_left = 1.0
	rail.anchor_right = 1.0
	rail.anchor_top = 0.5
	rail.anchor_bottom = 0.5
	rail.offset_left = -420
	rail.offset_right = -40
	rail.offset_top = -170
	rail.add_theme_constant_override("separation", 12)
	add_child(rail)
	for entry in RAIL:
		var b := UiTheme.button("%s    %s" % [entry[0], entry[1]], Vector2(380, 64))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_rail.bind(entry[2]))
		rail.add_child(b)
		_rail_buttons[entry[2]] = b
	# 왼쪽 패널 (처음엔 닫힘).
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.1, 0.17, 0.95), UiTheme.LAVENDER, 2, 10, 28))
	_panel.position = Vector2(48, 120)
	_panel.custom_minimum_size = Vector2(760, 820)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 16)
	scroll.add_child(_panel_body)
	refresh()
	_on_rail("requests")


func refresh() -> void:
	_hud.text = "자금 %d   ·   소장 수명 %d년   ·   사원 %d명" % [_game.gold, _game.lifespan, _game.party.member_count()]


func _on_rail(key: String) -> void:
	match key:
		"requests":
			_show_requests()
		"party":
			party_requested.emit()
		"journal":
			_show_journal()
		"menu":
			main_menu_requested.emit()


func _clear_panel() -> void:
	for c in _panel_body.get_children():
		_panel_body.remove_child(c)
		c.queue_free()
	_panel.visible = true


func _show_requests() -> void:
	_clear_panel()
	_panel_body.add_child(UiTheme.title_label("의뢰 게시판", 34, UiTheme.LAVENDER))
	var any: bool = false
	if _game.chapter == 1:
		_panel_body.add_child(_request_card(ChapterData.CHAPTER1, "본 이야기"))
		any = true
	if _game.chapter >= 2:
		_panel_body.add_child(_request_card(ChapterData.REPEAT1, "반복 의뢰"))
		var done := UiTheme.body("1장 · 잠든 하수도 — 정화 완료. 다음 이야기는 아직 준비 중입니다.", 18, UiTheme.TEXT_DIM)
		_panel_body.add_child(done)
		any = true
	if not any:
		_panel_body.add_child(UiTheme.body("받을 수 있는 의뢰가 없습니다.", 20, UiTheme.TEXT_DIM))


func _request_card(request: Dictionary, tag: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.14, 0.23, 0.95), UiTheme.LAVENDER_DIM, 1, 8, 22))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.add_child(UiTheme.label(tag, 16, UiTheme.GOLD))
	col.add_child(UiTheme.title_label(request["title"], 30))
	col.add_child(UiTheme.label("의뢰인: %s   ·   %d구역" % [request["client"], request["floors"]], 18, UiTheme.TEXT_DIM))
	col.add_child(UiTheme.body(request["summary"], 19))
	var go := UiTheme.button("출발 준비", Vector2(220, 54))
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(func() -> void: request_chosen.emit(request["id"]))
	col.add_child(go)
	return card


func _show_journal() -> void:
	_clear_panel()
	_panel_body.add_child(UiTheme.title_label("일지", 34, UiTheme.LAVENDER))
	if _game.journal.is_empty():
		_panel_body.add_child(UiTheme.body("아직 기록이 없습니다.", 20, UiTheme.TEXT_DIM))
	for i in range(_game.journal.size() - 1, -1, -1):
		var entry: Dictionary = _game.journal[i]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.14, 0.23, 0.95), UiTheme.LAVENDER_DIM, 1, 8, 20))
		var col := VBoxContainer.new()
		box.add_child(col)
		col.add_child(UiTheme.title_label(entry["title"], 24, UiTheme.GOLD))
		col.add_child(UiTheme.body(entry["text"], 18))
		_panel_body.add_child(box)
