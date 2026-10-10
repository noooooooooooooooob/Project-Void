## 카드 한 장의 2D 화면 표현 (앞면·뒷면).
## 앞면: 왼쪽 위 SP 비용 원, 오른쪽 위 공격 종류 배지(근·원·아·자)와 5×5 범위 미니맵, 이름, 일러스트 자리, 아래 효과 문구.
## 테두리·SP 원·미니맵은 카드 분류(공격·스킬·특수) 색이다. 자식 노드는 모두 코드로 만든다.
## 마우스 입력은 HandView 가 gui_input 신호로 받아 처리한다.
class_name CardView
# Control: 2D UI 노드.
extends Control

## 카드 크기 (픽셀).
const SIZE := Vector2(110, 154)
## 카드 분류 → 테두리·SP 원 색. 공격 빨강, 스킬 파랑, 특수 보라.
const CATEGORY_COLORS: Dictionary = {
	CardData.Category.ATTACK: Color(0.85, 0.4, 0.35),
	CardData.Category.SKILL: Color(0.4, 0.6, 0.95),
	CardData.Category.SPECIAL: Color(0.7, 0.45, 0.9),
}
## 앞면 바탕색 (거의 검정).
const FACE_COLOR := Color(0.12, 0.12, 0.15)
## 뒷면 바탕색 (남색).
const BACK_COLOR := Color(0.18, 0.22, 0.38)
## SP 가 모자란 카드에 곱하는 색 (투명도 55%로 흐리게).
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.55)
## 범위 미니맵 한 변의 칸 수 (오프셋 −2~+2).
const AREA_MAP_CELLS: int = 5
## 미니맵 칸 하나의 크기 (픽셀).
const AREA_MAP_CELL_SIZE: float = 6.0
## 미니맵의 꺼진 칸 색.
const AREA_OFF_COLOR := Color(1, 1, 1, 0.12)

## 이 화면이 보여 주는 카드 데이터.
var card: CardData

## 앞면 패널 (앞면 글자들의 부모).
var _face: Panel
## 뒷면 패널.
var _back: Panel
## SP 비용 숫자.
var _cost_label: Label
## 카드 이름.
var _name_label: Label
## 공격 종류 배지 글자.
var _badge_label: Label
## 아래쪽 효과 문구.
var _effect_label: Label
## 미니맵에 켜진 오프셋 (테스트용).
var _area_marks: Array[Vector2i] = []
## 테두리 색 (카드 분류).
var _border_color: Color = Color.WHITE


## 카드 데이터를 받아 앞면·뒷면을 만든다. stats 를 주면 효과를 계산값으로, 없으면 % 로 쓴다. 트리에 붙이기 전에 불러도 된다.
func setup(p_card: CardData, stats: UnitData = null) -> void:
	# 보여 줄 카드를 기억한다.
	card = p_card
	# 컨테이너 안에서 이 크기보다 작아지지 않게 한다.
	custom_minimum_size = SIZE
	# 실제 크기를 카드 크기로.
	size = SIZE
	# 회전·확대의 중심을 카드 가운데로 둔다 (부채꼴 기울기, 뒤집기 연출용).
	pivot_offset = SIZE / 2.0
	# 카드 위의 클릭을 여기서 멈춰 뒤의 보드로 새지 않게 한다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 분류 색.
	_border_color = CATEGORY_COLORS[card.category]

	# --- 앞면 바탕 ---
	# 둥근 모서리(8) 앞면 패널을 만든다.
	_face = _make_panel(FACE_COLOR, _border_color, 8)
	# 카드에 붙인다.
	add_child(_face)

	# --- SP 비용 원 ---
	# 모서리 반지름 14 로 28×28 을 거의 원처럼 만든다 (분류 색으로 채움).
	var cost_badge: Panel = _make_panel(_border_color, _border_color, 14)
	# 왼쪽 위에서 조금 안쪽.
	cost_badge.position = Vector2(6, 6)
	# 28×28 크기.
	cost_badge.size = Vector2(28, 28)
	# 앞면에 붙인다.
	_face.add_child(cost_badge)
	# 원 안에 가운데 정렬된 비용 숫자.
	_cost_label = _make_label(str(card.sp_cost), 18, Vector2.ZERO, cost_badge.size)
	# 원에 붙인다.
	cost_badge.add_child(_cost_label)

	# --- 공격 종류 배지 ---
	# 미니맵 왼쪽의 한 글자.
	_badge_label = _make_label(CardText.badge(card.attack_type), 13, Vector2(52, 10), Vector2(20, 20))
	# 앞면에 붙인다.
	_face.add_child(_badge_label)

	# --- 범위 미니맵 ---
	_face.add_child(_make_area_map(card.area_offsets()))

	# --- 이름 ---
	# 위쪽 가운데 이름 (y 36, 높이 20).
	_name_label = _make_label(card.display_name, 14, Vector2(0, 36), Vector2(SIZE.x, 20))
	# 앞면에 붙인다.
	_face.add_child(_name_label)

	# --- 일러스트 자리 (아직 그림이 없어 분류 색 상자) ---
	var art: Panel = _make_panel(_border_color.darkened(0.55), _border_color.darkened(0.3), 4)
	# 이름 아래.
	art.position = Vector2(8, 58)
	# 94×48.
	art.size = Vector2(94, 48)
	# 앞면에 붙인다.
	_face.add_child(art)

	# --- 효과 문구 ---
	# 아래쪽 두 줄 영역.
	_effect_label = _make_label(CardText.describe(card, stats), 11, Vector2(6, 110), Vector2(98, 40))
	# 길면 단어 단위로 줄바꿈한다.
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 앞면에 붙인다.
	_face.add_child(_effect_label)

	# --- 뒷면 ---
	# 공용 뒷면 패널을 만든다.
	_back = make_back()
	# 카드에 붙인다 (앞면보다 나중에 붙여 위에 그려진다).
	add_child(_back)
	# 처음에는 앞면이 보이게 한다.
	set_face_up(true)


## 5×5 범위 미니맵을 만든다. 가운데 칸이 기준점, 켜진 칸은 분류 색(기준점은 더 밝게).
func _make_area_map(offsets: Array[Vector2i]) -> Control:
	# 미니맵 상자.
	var map := Control.new()
	# 입력을 받지 않는다.
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 오른쪽 위.
	map.position = Vector2(74, 6)
	# 5칸 × 6px.
	map.size = Vector2.ONE * AREA_MAP_CELLS * AREA_MAP_CELL_SIZE
	# 가운데 칸 번호.
	var center: int = AREA_MAP_CELLS / 2
	# 칸마다.
	for j in AREA_MAP_CELLS:
		for i in AREA_MAP_CELLS:
			# 이 칸의 오프셋.
			var offset := Vector2i(i - center, j - center)
			# 칸 색: 켜짐은 분류 색(기준점은 더 밝게), 꺼짐은 옅은 흰색.
			var color: Color = AREA_OFF_COLOR
			if offsets.has(offset):
				color = _border_color.lightened(0.4) if offset == Vector2i.ZERO else _border_color
			# 칸.
			var cell := ColorRect.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.color = color
			cell.position = Vector2(i, j) * AREA_MAP_CELL_SIZE
			cell.size = Vector2.ONE * (AREA_MAP_CELL_SIZE - 1.0)
			map.add_child(cell)
	# 미니맵에 보이는(격자 안) 오프셋만 원래 순서대로 기억한다.
	_area_marks.clear()
	for offset in offsets:
		if absi(offset.x) <= center and absi(offset.y) <= center and not _area_marks.has(offset):
			_area_marks.append(offset)
	# 돌려준다.
	return map


## 카드 뒷면 패널을 만든다 (남색 바탕 + "VOID"). 더미와 리셔플 연출도 같은 뒷면을 쓴다.
static func make_back() -> Panel:
	# 남색 바탕, 밝은 남색 테두리, 둥근 모서리 8.
	var back: Panel = _make_panel(BACK_COLOR, BACK_COLOR.lightened(0.3), 8)
	# 가운데에 "VOID" 글자를 붙인다.
	back.add_child(_make_label("VOID", 22, Vector2(0, 60), Vector2(SIZE.x, 34)))
	# 만든 뒷면을 돌려준다.
	return back


## 앞면(true) 또는 뒷면(false)이 보이게 한다.
func set_face_up(face_up: bool) -> void:
	# 앞면 보이기.
	_face.visible = face_up
	# 뒷면은 반대로.
	_back.visible = not face_up


## 앞면이 보이는 중이면 true.
func is_face_up() -> bool:
	# 앞면 보이기 상태를 돌려준다.
	return _face.visible


## SP 로 쓸 수 있는 카드면 또렷하게, 아니면 흐리게 한다.
func set_affordable(affordable: bool) -> void:
	# 쓸 수 있으면 원래 색, 아니면 반투명.
	modulate = Color.WHITE if affordable else UNAFFORDABLE_MODULATE


## SP 비용 글자 (테스트용).
func cost_text() -> String:
	# 글자를 돌려준다.
	return _cost_label.text


## 이름 글자 (테스트용).
func name_text() -> String:
	# 글자를 돌려준다.
	return _name_label.text


## 효과 문구 (테스트용).
func effect_text() -> String:
	# 글자를 돌려준다.
	return _effect_label.text


## 공격 종류 배지 글자 (테스트용).
func badge_text() -> String:
	# 글자를 돌려준다.
	return _badge_label.text


## 미니맵에 켜진 오프셋 (테스트용).
func area_marks() -> Array[Vector2i]:
	# 목록을 돌려준다.
	return _area_marks


## 테두리 색 (테스트용).
func border_color() -> Color:
	# 색을 돌려준다.
	return _border_color


## 카드 크기의 둥근 사각형 패널을 만든다.
static func _make_panel(background: Color, border: Color, radius: int) -> Panel:
	# 패널 노드를 만든다.
	var panel := Panel.new()
	# 패널은 입력을 받지 않는다 (카드 루트가 받는다).
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 크기는 카드와 같게 (비용 원처럼 필요하면 만든 뒤 바꾼다).
	panel.size = SIZE
	# 코드로 만드는 단색 스타일.
	var style := StyleBoxFlat.new()
	# 바탕색.
	style.bg_color = background
	# 테두리 색.
	style.border_color = border
	# 테두리 두께 3 (네 변 모두).
	style.set_border_width_all(3)
	# 모서리 반지름 (네 모서리 모두).
	style.set_corner_radius_all(radius)
	# 패널의 기본 "panel" 스타일을 이것으로 덮어쓴다.
	panel.add_theme_stylebox_override(&"panel", style)
	# 만든 패널을 돌려준다.
	return panel


## 가운데 정렬된 글자 노드를 만든다. at 은 위치, box 는 글자 영역 크기.
static func _make_label(text: String, font_size: int, at: Vector2, box: Vector2) -> Label:
	# 글자 노드를 만든다.
	var label := Label.new()
	# 내용.
	label.text = text
	# 부모 기준 위치.
	label.position = at
	# 영역 크기. (주의: 글꼴 크기를 바꾸기 전에 정하므로 긴 한 줄은 영역보다 넓어질 수 있다.)
	label.size = box
	# 가로 가운데 정렬.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 세로 가운데 정렬.
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 글꼴 크기를 덮어쓴다.
	label.add_theme_font_size_override(&"font_size", font_size)
	# 입력을 받지 않는다.
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 만든 글자를 돌려준다.
	return label
