## 메인 메뉴: 새 게임 / 이어하기(저장이 있을 때) / 종료. 이어하기에 마우스를 올리면 저장 요약을 보여 준다.
class_name MainMenu
extends Control

signal new_game
signal continue_game
signal quit_game

var _summary: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.backdrop(UiTheme.bg("title"), 0.45))
	var col := VBoxContainer.new()
	col.position = Vector2(140, 300)
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	col.add_child(UiTheme.title_label("공허 정화자", 72))
	col.add_child(UiTheme.label("VOID PURIFIER", 20, UiTheme.LAVENDER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)
	var cont := UiTheme.button("01   이어하기", Vector2(360, 60))
	cont.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cont.disabled = not GameState.has_save()
	cont.pressed.connect(func() -> void: continue_game.emit())
	cont.mouse_entered.connect(_show_summary)
	col.add_child(cont)
	var new_b := UiTheme.button("02   새 게임", Vector2(360, 60))
	new_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_b.pressed.connect(func() -> void: new_game.emit())
	col.add_child(new_b)
	var quit_b := UiTheme.button("03   종료", Vector2(360, 60))
	quit_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit_b.pressed.connect(func() -> void: quit_game.emit())
	col.add_child(quit_b)
	_summary = UiTheme.body("", 18, UiTheme.TEXT_DIM)
	_summary.custom_minimum_size = Vector2(360, 0)
	col.add_child(_summary)
	var version := UiTheme.label("프로토타입 · 튜토리얼 + 1장", 16, UiTheme.TEXT_DIM)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 30
	version.offset_top = -44
	add_child(version)
	if not cont.disabled:
		cont.grab_focus.call_deferred()
	else:
		new_b.grab_focus.call_deferred()


func _show_summary() -> void:
	var state: GameState = GameState.load_from_disk()
	if state == null:
		return
	var chapter_text: String = ["튜토리얼", "1장 · 잠든 하수도", "1장 완료"][clampi(state.chapter, 0, 2)]
	_summary.text = "진행: %s\n자금 %d · 사원 %d명 · 소장 수명 %d년" % [chapter_text, state.gold, state.party.member_count(), state.lifespan]
