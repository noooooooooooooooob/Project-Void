## 원거리 공격의 화살. 쏜 쪽 가슴에서 맞을 쪽 가슴까지 낮은 포물선으로 날아가고,
## 판은 카메라를 보되 그림은 화면에서 날아가는 방향을 가리킨다 (유니티 Projectile).
class_name Projectile
# Node3D: 3D 공간을 날아간다.
extends Node3D

## 가장 짧은 비행 시간.
const MIN_FLIGHT: float = 0.12
## 가장 긴 비행 시간.
const MAX_FLIGHT: float = 0.35
## 비행 속도 (초당 3D 단위).
const SPEED: float = 16.0
## 거리 1 당 포물선 최고 높이.
const ARC_PER_DISTANCE: float = 0.06
## 화살 판 길이.
const LENGTH: float = 0.8
# 그림이 없을 때 쓰는 흰 줄무늬의 세로/가로 비.
const _FALLBACK_ASPECT: float = 0.2

## 날아가는 데 걸리는 시간.
var duration: float = 0.0
## 화살 그림 판.
var mesh: MeshInstance3D

# 출발·도착·포물선 높이.
var _from: Vector3
var _to: Vector3
var _arc: float

# 그림이 없을 때 쓰는 흰 줄 (한 번만 만든다).
static var _fallback: Texture2D


## 거리에 비례하되 하한·상한이 있는 비행 시간.
static func flight_time(distance: float) -> float:
	# 거리 ÷ 속도를 최소·최대 사이로 자른다.
	return clampf(distance / SPEED, MIN_FLIGHT, MAX_FLIGHT)


## 진행률 t 의 위치: 직선 위에 4·arc·t·(1−t) 만큼 띄운다 (가운데에서 arc).
static func position_at(from: Vector3, to: Vector3, arc: float, t: float) -> Vector3:
	# 직선 위 점 + 위로 띄운 높이 (t = 0.5 에서 최고 arc).
	return from.lerp(to, t) + Vector3.UP * (4.0 * arc * t * (1.0 - t))


## 화살 하나를 만들어 parent 에 붙이고 출발점에 놓는다. texture 가 null 이면 흰 줄로 그린다.
static func spawn(parent: Node, texture: Texture2D, from: Vector3, to: Vector3) -> Projectile:
	# 화살 노드.
	var arrow := Projectile.new()
	# 이름.
	arrow.name = "Projectile"
	# 그림 (없으면 흰 줄).
	var art: Texture2D = texture if texture != null else _get_fallback()
	# 판의 세로/가로 비 (그림이 있으면 그림 비율대로).
	var aspect: float = float(art.get_height()) / float(art.get_width()) if texture != null else _FALLBACK_ASPECT
	# 판.
	arrow.mesh = MeshInstance3D.new()
	# 사각 판 메시.
	var quad := QuadMesh.new()
	# 길이는 고정, 높이는 비율대로.
	quad.size = Vector2(LENGTH, LENGTH * aspect)
	# 판을 붙인다.
	arrow.mesh.mesh = quad
	# 무광, 알파 잘라내기, 픽셀 그대로, 양면.
	var material := StandardMaterial3D.new()
	# 조명을 받지 않는다.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 투명한 부분은 잘라 낸다 (반투명 정렬 문제 없음).
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	# 픽셀 아트가 흐려지지 않게.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# 뒷면도 그린다 (회전하다 뒤집혀도 보이게).
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 그림.
	material.albedo_texture = art
	# 재질을 입힌다.
	arrow.mesh.material_override = material
	# 그림자를 만들지 않는다.
	arrow.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 판을 화살 노드에 붙인다.
	arrow.add_child(arrow.mesh)
	# 궤적.
	var distance: float = from.distance_to(to)
	# 출발점.
	arrow._from = from
	# 도착점.
	arrow._to = to
	# 멀수록 높게 휜다.
	arrow._arc = distance * ARC_PER_DISTANCE
	# 비행 시간.
	arrow.duration = flight_time(distance)
	# 붙이고 출발점에 놓는다.
	parent.add_child(arrow)
	# 진행률 0 위치에 놓는다.
	arrow._place(0.0)
	# 만든 화살을 돌려준다.
	return arrow


## 도착할 때까지 날아가고 스스로 지운다. await 할 수 있다.
func fly() -> void:
	# 0→1 진행률.
	var tween: Tween = create_tween()
	# 비행 시간 동안 진행률을 0 에서 1 로 올리며 매번 _place 를 부른다.
	tween.tween_method(_place, 0.0, 1.0, duration)
	# 끝날 때까지 기다린다.
	await tween.finished
	# 지운다.
	queue_free()


# 진행률 t 의 위치에 놓고, 카메라를 보며 화면상 진행 방향으로 돌린다.
func _place(t: float) -> void:
	# 위치.
	position = position_at(_from, _to, _arc, t)
	# 카메라가 없으면 (테스트) 방향은 그대로.
	if not is_inside_tree():
		return
	# 지금 화면을 그리는 카메라.
	var camera: Camera3D = get_viewport().get_camera_3d()
	# 카메라가 없으면 방향은 그대로.
	if camera == null:
		return
	# 조금 뒤 위치와의 차이 = 진행 방향.
	var direction: Vector3 = position_at(_from, _to, _arc, t + 0.02) - position
	# 카메라 오른쪽·위로 투영한 화면상 각도.
	var view: Basis = camera.global_basis
	# 화면 위쪽 성분과 오른쪽 성분으로 각도를 구한다.
	var angle: float = atan2(direction.dot(view.y), direction.dot(view.x))
	# 판(+Z)이 카메라를 보게 하고 그 평면 안에서 돌린다.
	basis = view * Basis(Vector3.BACK, angle)


# 16×4 흰 줄 (가운데 두 줄만 불투명).
static func _get_fallback() -> Texture2D:
	# 처음 한 번만 만든다.
	if _fallback == null:
		# 16 × 4 빈 그림.
		var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
		# 행마다.
		for y in 4:
			# 열마다.
			for x in 16:
				# 가운데 두 행만 흰색, 나머지는 투명.
				image.set_pixel(x, y, Color.WHITE if y == 1 or y == 2 else Color(1, 1, 1, 0))
		# 그림을 텍스처로 만든다.
		_fallback = ImageTexture.create_from_image(image)
	# 만들어 둔 텍스처를 돌려준다.
	return _fallback
