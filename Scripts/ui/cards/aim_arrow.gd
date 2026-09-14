## 카드를 끌 때 카드에서 커서까지 휘어진 조준 화살표를 그리는 2D 노드.
## 마우스 입력은 받지 않는다 (아래의 보드·카드 클릭을 막지 않게).
class_name AimArrow
# Control: 2D UI 노드. _draw 에서 직접 선과 도형을 그린다.
extends Control

## 화살표 색 (살짝 투명한 흰색).
const COLOR := Color(1.0, 1.0, 1.0, 0.9)
## 선 두께 (픽셀).
const WIDTH: float = 6.0
## 화살촉 길이 (픽셀).
const HEAD_SIZE: float = 18.0
## 곡선을 나누는 조각 수. 많을수록 부드럽다.
const SEGMENTS: int = 20
## 곡선이 위로 휘는 높이 (픽셀).
const ARC_HEIGHT: float = 120.0

## 화살표 시작점 (이 노드 기준 좌표).
var _from: Vector2 = Vector2.ZERO
## 화살표 끝점 (이 노드 기준 좌표).
var _to: Vector2 = Vector2.ZERO


## 만들 때 기본 설정: 입력 무시, 숨김, 부모 전체 크기.
func _init() -> void:
	# 마우스 이벤트를 받지 않고 통과시킨다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 끌기 전에는 보이지 않는다.
	visible = false
	# 부모(HandView) 전체를 덮는 크기로 맞춘다 (화면 어디든 그릴 수 있게).
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 화면(전역) 좌표 두 점 사이에 화살표를 보여 준다.
func show_aim(from_global: Vector2, to_global: Vector2) -> void:
	# 전역 좌표를 이 노드 기준 좌표로 바꿔 저장한다 (_draw 는 노드 기준 좌표로 그린다).
	_from = from_global - global_position
	# 끝점도 같은 방식으로 바꾼다.
	_to = to_global - global_position
	# 보이게 한다.
	visible = true
	# 다음 프레임에 _draw 를 다시 부르도록 요청한다.
	queue_redraw()


## 화살표를 숨긴다.
func hide_aim() -> void:
	# 보이지 않게 한다.
	visible = false


## 조준 중(화살표가 보이는 중)이면 true.
func is_aiming() -> bool:
	# 보이기 상태가 곧 조준 상태다.
	return visible


## 2차 베지에 곡선으로 몸통을 그리고 끝에 삼각형 화살촉을 그린다.
func _draw() -> void:
	# 곡선을 끌어당기는 조절점: 두 점 가로 중간, 더 높은 점보다 ARC_HEIGHT 만큼 위 (화면 y 는 아래가 +).
	var control_point := Vector2((_from.x + _to.x) / 2.0, minf(_from.y, _to.y) - ARC_HEIGHT)
	# 곡선 위의 점들을 담을 배열.
	var points := PackedVector2Array()
	# 0 부터 SEGMENTS 까지 (끝점 포함) 점을 만든다.
	for i in SEGMENTS + 1:
		# 곡선 위 진행 비율 (0 = 시작, 1 = 끝).
		var t: float = float(i) / SEGMENTS
		# 2차 베지에: (시작→조절) 선분과 (조절→끝) 선분 위의 t 지점을 다시 t 로 보간한다.
		points.append(_from.lerp(control_point, t).lerp(control_point.lerp(_to, t), t))
	# 점들을 이어 부드러운(안티앨리어싱) 선으로 그린다.
	draw_polyline(points, COLOR, WIDTH, true)
	# 마지막 조각의 방향 = 화살촉이 향할 방향.
	var direction: Vector2 = (points[SEGMENTS] - points[SEGMENTS - 1]).normalized()
	# 방향에 수직인 벡터 (화살촉 좌우 폭을 벌리는 데 쓴다).
	var normal := Vector2(-direction.y, direction.x)
	# 화살촉 밑변의 중심 = 끝점에서 HEAD_SIZE 만큼 뒤로.
	var base: Vector2 = _to - direction * HEAD_SIZE
	# 끝점과 밑변 양 끝으로 이루어진 삼각형을 채워 그린다.
	draw_colored_polygon(PackedVector2Array([_to, base + normal * HEAD_SIZE * 0.6, base - normal * HEAD_SIZE * 0.6]), COLOR)
