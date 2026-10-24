## 가운데 뜨는 범용 선택 창: 제목, 본문, 버튼들. 버튼을 누르면 그 번호로 chosen 을 낸다.
## 휴식·패배·공허 속의 공허·정화·원정 결과 등에 쓴다. 배경 그림을 주면 그 위에 띄운다.
class_name ChoiceDialog
extends Control

signal chosen(index: int)

var _title: String
var _body: String
var _options: Array
var _background: Texture2D
var _accent: Color


## options: 문자열 또는 {"text", "desc", "disabled"} 의 목록.
func title() -> String:
	return _title


func _init(title: String, body: String, options: Array, background: Texture2D = null, accent: Color = UiTheme.LAVENDER) -> void:
	_title = title
	_body = body
	_options = options
	_background = background
	_accent = accent


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _background != null:
		add_child(UiTheme.backdrop(_background, 0.55))
	else:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.04, 0.7)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, _accent, 2, 10, 36))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var t := UiTheme.title_label(_title, 38, _accent)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	if not _body.is_empty():
		var b := UiTheme.body(_body, 21)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	for i in _options.size():
		var opt: Variant = _options[i]
		var text: String = opt if opt is String else opt["text"]
		var button := UiTheme.button(text, Vector2(240, 64))
		if opt is Dictionary:
			if opt.has("desc"):
				button.tooltip_text = opt["desc"]
				button.text = "%s\n%s" % [text, opt["desc"]]
				button.custom_minimum_size = Vector2(300, 96)
			button.disabled = opt.get("disabled", false)
		button.pressed.connect(func() -> void: chosen.emit(i))
		row.add_child(button)
		if i == 0:
			button.grab_focus.call_deferred()
