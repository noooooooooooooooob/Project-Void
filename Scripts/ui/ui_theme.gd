## 게임 전체 UI 테마 (v6 연보라 사이드 패널 톤): 반투명 짙은 보라 패널, 연보라 테두리, 일반 글꼴.
## 픽셀 글꼴은 쓰지 않는다. 글꼴은 시스템 글꼴을 이름으로 찾는다 (Windows: Noto Sans KR → 맑은 고딕).
class_name UiTheme
extends RefCounted

const PANEL := Color(0.11, 0.09, 0.15, 0.92)
const PANEL_LIGHT := Color(0.2, 0.16, 0.27, 0.95)
const LAVENDER := Color(0.76, 0.68, 0.94)
const LAVENDER_DIM := Color(0.5, 0.44, 0.66)
const TEXT := Color(0.93, 0.91, 0.97)
const TEXT_DIM := Color(0.68, 0.64, 0.76)
const GOLD := Color(0.95, 0.8, 0.45)
const DANGER := Color(0.95, 0.42, 0.45)
const TEAL := Color(0.45, 0.88, 0.84)

static var _theme: Theme
static var _sans: SystemFont
static var _serif: SystemFont


static func sans() -> Font:
	if _sans == null:
		_sans = SystemFont.new()
		_sans.font_names = PackedStringArray(["Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo", "Sans-Serif"])
		_sans.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _sans


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Noto Serif KR", "Batang", "Serif"])
		_serif.font_weight = 700
	return _serif


static func box(bg: Color, border: Color = LAVENDER_DIM, width: int = 2, radius: int = 6, margin: float = 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = sans()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "Panel", box(PANEL))
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("normal", "Button", box(Color(0.17, 0.14, 0.23, 0.95), LAVENDER_DIM))
	t.set_stylebox("hover", "Button", box(Color(0.27, 0.22, 0.38, 0.97), LAVENDER))
	t.set_stylebox("pressed", "Button", box(Color(0.38, 0.31, 0.55, 1.0), LAVENDER))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), LAVENDER, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.1, 0.09, 0.13, 0.8), Color(0.3, 0.28, 0.36)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.5))
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


## 제목 글자 (세리프).
static func title_label(text: String, size: int = 40, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 줄바꿈되는 본문 글자.
static func body(text: String, size: int = 19, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, min_size: Vector2 = Vector2(220, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	return b


## 화면 가득 배경 그림 (비율 유지, 넘치면 자름).
static func backdrop(texture: Texture2D, dim: float = 0.0) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.02, 0.05, dim)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	return root


static func bg(id: String) -> Texture2D:
	var path: String = "res://Art/gen/bg/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## 장비 부위 아이콘 (픽셀 아트라 확대해도 흐려지지 않게 NEAREST).
static func item_icon(slot: ItemData.Slot, edge: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://Art/gen/icons/%s.png" % ["weapon", "armor", "accessory"][slot])
	icon.custom_minimum_size = Vector2(edge, edge)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
