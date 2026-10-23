## 대화·이벤트 화면. DialogueRunner 를 받아 배경·일러스트·대사창·선택지를 보여 주고, 끝나면 finished 를 낸다.
## 클릭·스페이스·엔터로 넘긴다 (글자가 나오는 중이면 먼저 전부 보여 준다). 오른쪽 위 "건너뛰기"는 선택지나 끝까지 빨리 넘긴다.
class_name DialogueView
extends Control

signal finished(result: String)

## 한 글자가 나오는 시간(초).
const CHAR_TIME: float = 0.022
const PORTRAIT_HEIGHT_RATIO: float = 0.86
const INACTIVE_TINT := Color(0.45, 0.43, 0.5)

var _runner: DialogueRunner
var _bg: TextureRect
var _portraits: Dictionary = {}
var _box: PanelContainer
var _name_plate: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _hint: Label
var _choices: VBoxContainer
var _skip: Button
var _beat: Dictionary = {}
var _typing: bool = false
var _type_time: float = 0.0
var _shown_bg: String = ""
var _skipping: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var black := ColorRect.new()
	black.color = Color(0.02, 0.01, 0.03)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	for side in ["left", "right"]:
		var p := TextureRect.new()
		p.name = "Portrait_" + side
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_top = 1.0 - PORTRAIT_HEIGHT_RATIO
		p.anchor_bottom = 1.0
		if side == "left":
			p.anchor_left = 0.04
			p.anchor_right = 0.42
		else:
			p.anchor_left = 0.58
			p.anchor_right = 0.96
			p.flip_h = true
		p.visible = false
		add_child(p)
		_portraits[side] = p

	# 아래쪽 글자를 읽기 쉽게 어둡게.
	var fade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.02, 0.01, 0.04, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	fade.texture = gt
	fade.anchor_left = 0.0
	fade.anchor_right = 1.0
	fade.anchor_top = 0.55
	fade.anchor_bottom = 1.0
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.06, 0.12, 0.9), UiTheme.LAVENDER_DIM, 2, 10, 28))
	_box.anchor_left = 0.12
	_box.anchor_right = 0.88
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_top = -250
	_box.offset_bottom = -40
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_constant_override("line_separation", 8)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)

	_name_plate = PanelContainer.new()
	_name_plate.anchor_left = 0.12
	_name_plate.anchor_top = 1.0
	_name_plate.anchor_bottom = 1.0
	_name_plate.offset_left = 24
	_name_plate.offset_top = -290
	_name_plate.offset_bottom = -244
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_plate)
	_name_label = UiTheme.title_label("", 26)
	_name_plate.add_child(_name_label)

	_hint = UiTheme.label("▼", 18, UiTheme.LAVENDER)
	_hint.anchor_left = 0.88
	_hint.anchor_right = 0.88
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -50
	_hint.offset_top = -80
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 12)
	_choices.anchor_left = 0.3
	_choices.anchor_right = 0.7
	_choices.anchor_top = 0.3
	_choices.anchor_bottom = 0.3
	add_child(_choices)

	_skip = UiTheme.button("건너뛰기 ▶▶", Vector2(160, 44))
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -190
	_skip.offset_right = -30
	_skip.offset_top = 24
	_skip.offset_bottom = 68
	_skip.pressed.connect(_on_skip)
	add_child(_skip)


## 대본을 처음부터 보여 준다.
func play(runner: DialogueRunner) -> void:
	_runner = runner
	_next()


func _process(delta: float) -> void:
	if not _typing:
		return
	_type_time += delta
	var total: int = _text.get_total_character_count()
	_text.visible_characters = mini(total, int(_type_time / CHAR_TIME))
	if _text.visible_characters >= total:
		_finish_typing()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance_input()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		_advance_input()
		get_viewport().set_input_as_handled()


func _advance_input() -> void:
	if _beat.get("kind", "") == DialogueRunner.CHOICE:
		return
	if _typing:
		_text.visible_characters = -1
		_finish_typing()
		return
	_next()


func _finish_typing() -> void:
	_typing = false
	_hint.visible = true


func _next() -> void:
	if _runner == null:
		return
	_beat = _runner.advance()
	_sync_scene()
	match _beat["kind"]:
		DialogueRunner.LINE:
			_show_text(_beat["name"], _beat["text"], StoryCast.name_color(_beat["speaker"]), _beat["side"])
		DialogueRunner.NARRATION:
			_show_text("", _beat["text"], UiTheme.TEXT, "none", true)
		DialogueRunner.NOTICE:
			_show_text("", "[color=#%s]◆ %s[/color]" % [UiTheme.GOLD.to_html(false), _beat["text"]], UiTheme.TEXT, "none")
		DialogueRunner.CHOICE:
			_skipping = false
			_show_choices(_beat["options"])
		DialogueRunner.END:
			finished.emit(_beat["result"])
			return
	if _skipping:
		_next.call_deferred()


func _sync_scene() -> void:
	if _runner.background != _shown_bg:
		_shown_bg = _runner.background
		_bg.texture = UiTheme.bg(_shown_bg)
	for side in _portraits:
		var p: TextureRect = _portraits[side]
		var who: String = _runner.portraits.get(side, "")
		var tex: Texture2D = StoryCast.portrait(who) if not who.is_empty() else null
		p.texture = tex
		p.visible = tex != null


func _show_text(speaker_name: String, text: String, color: Color, side: String, italic: bool = false) -> void:
	_clear_choices()
	_box.visible = true
	_name_plate.visible = not speaker_name.is_empty()
	_name_label.text = speaker_name
	_name_label.add_theme_color_override("font_color", color)
	_text.text = ("[i]%s[/i]" % text) if italic else text
	_text.visible_characters = 0
	_typing = true
	_type_time = 0.0
	_hint.visible = false
	# 말하는 사람은 밝게, 나머지는 어둡게.
	for s in _portraits:
		var p: TextureRect = _portraits[s]
		p.modulate = Color.WHITE if (s == side or side == "none") else INACTIVE_TINT


func _show_choices(options: Array) -> void:
	_clear_choices()
	_typing = false
	_hint.visible = false
	for i in options.size():
		var b := UiTheme.button(options[i]["text"], Vector2(0, 60))
		b.pressed.connect(_on_choice.bind(i))
		_choices.add_child(b)


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_choice(index: int) -> void:
	_clear_choices()
	_runner.choose(index)
	_next()


func _on_skip() -> void:
	if _beat.get("kind", "") == DialogueRunner.CHOICE:
		return
	_skipping = true
	_typing = false
	_next()


## 테스트·자동 진행용: 지금 장면.
func current_beat() -> Dictionary:
	return _beat
