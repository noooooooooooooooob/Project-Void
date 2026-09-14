## 덱 또는 묘지 더미 하나의 화면 표현: 카드 뒷면 위에 장수 숫자, 그 위에 이름.
## 입력은 받지 않는다. 노드 크기(SIZE)는 고정이고 씬(battle_hud.tscn)에서 위치만 정한다.
class_name PileView
# Control: 2D UI 노드.
extends Control

## 더미 크기 (카드보다 조금 작다).
const SIZE := Vector2(90, 126)
## 흐리게 할 때 곱하는 색 (투명도 40%).
const DIM_MODULATE := Color(1, 1, 1, 0.4)

## 더미 위의 이름 글자 (유닛 이름 또는 "묘지").
var _owner_label: Label
## 더미 아래쪽의 장수 숫자.
var _count_label: Label


## 만들 때 뒷면·숫자·이름 자식 노드를 코드로 만든다 (씬 파일 없이도 쓸 수 있게).
func _init() -> void:
	# 마우스 이벤트를 통과시킨다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 컨테이너 안에서도 이 크기 이하로 줄지 않게 한다.
	custom_minimum_size = SIZE

	# --- 카드 뒷면 ---
	# CardView 와 같은 뒷면 패널을 만든다.
	var back: Panel = CardView.make_back()
	# 카드 크기(110×154)의 뒷면을 더미 크기로 줄여 보이게 한다.
	back.scale = SIZE / CardView.SIZE
	# 자식으로 붙인다.
	add_child(back)

	# --- 장수 숫자 ---
	# 글자 노드를 만든다.
	_count_label = Label.new()
	# 더미 아래쪽에 놓는다.
	_count_label.position = Vector2(0, SIZE.y - 38)
	# 더미 폭 전체, 높이 32.
	_count_label.size = Vector2(SIZE.x, 32)
	# 가운데 정렬.
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 글자 크기 24.
	_count_label.add_theme_font_size_override(&"font_size", 24)
	# 외곽선 두께 6.
	_count_label.add_theme_constant_override(&"outline_size", 6)
	# 마우스 이벤트를 통과시킨다.
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 자식으로 붙인다.
	add_child(_count_label)

	# --- 이름 ---
	# 글자 노드를 만든다.
	_owner_label = Label.new()
	# 더미 위쪽 바깥에 놓는다 (y 가 음수).
	_owner_label.position = Vector2(0, -26)
	# 더미 폭 전체, 높이 24.
	_owner_label.size = Vector2(SIZE.x, 24)
	# 가운데 정렬.
	_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 글자 크기 14.
	_owner_label.add_theme_font_size_override(&"font_size", 14)
	# 마우스 이벤트를 통과시킨다.
	_owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 자식으로 붙인다.
	add_child(_owner_label)

	# 처음 장수는 0.
	set_count(0)


## 더미 위의 이름을 바꾼다.
func set_owner_name(owner_name: String) -> void:
	# 글자를 넣는다.
	_owner_label.text = owner_name


## 장수 숫자를 바꾼다.
func set_count(count: int) -> void:
	# 숫자를 문자열로 바꿔 넣는다.
	_count_label.text = str(count)


## 흐리게 하거나(적 차례) 또렷하게 한다.
func set_dimmed(dimmed: bool) -> void:
	# 흐리게면 반투명, 아니면 원래 색.
	modulate = DIM_MODULATE if dimmed else Color.WHITE


## 흐린 상태인지 (테스트용).
func is_dimmed() -> bool:
	# 흐림 색이 적용되어 있으면 true.
	return modulate == DIM_MODULATE


## 장수 글자 (테스트용).
func count_text() -> String:
	# 글자를 돌려준다.
	return _count_label.text


## 이름 글자 (테스트용).
func owner_text() -> String:
	# 글자를 돌려준다.
	return _owner_label.text


## 더미 중심의 화면(전역) 좌표. 카드가 날아가거나 날아오는 기준점으로 쓴다.
func center_global() -> Vector2:
	# 왼쪽 위 전역 위치 + 크기 절반.
	return global_position + SIZE / 2.0
