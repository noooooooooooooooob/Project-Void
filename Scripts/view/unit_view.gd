## 3D 보드 위에 서 있는 유닛 한 명의 화면 표현.
## 카메라를 향해 서는 몸(빌보드) 위에 픽셀 그림·애니메이션 띠를 그리고, 발밑 그림자·진영 고리,
## 머리 위 이름·체력 바·수치 글자, 클릭 판정용 충돌 상자를 가진다. 규칙 상태는 바꾸지 않고 보여 주기만 한다.
class_name UnitView
# Node3D: 3D 공간에 위치를 가지는 노드.
extends Node3D

## 유닛·소품 몸 셰이더 (프레임·번쩍임·디더 페이드).
const UNIT_SHADER: Shader = preload("res://Shaders/unit_sprite.gdshader")

## 스프라이트가 화면에 그려질 높이 (3D 단위). 그림 크기와 상관없이 이 높이로 맞춘다.
const SPRITE_HEIGHT: float = 1.6
## 발을 축으로 카메라 반대쪽으로 눕히는 각도. 44° 로 내려다볼 때 판이 덜 눌려 보인다.
const BODY_TILT_DEG: float = 20.0
## 대기 띠의 초당 프레임 수.
const IDLE_FPS: float = 8.0
## 공격 띠 한 번의 길이. 그려진 동작은 코드 모션보다 길어야 읽힌다 (16장 기준 16fps).
const ATTACK_FRAME_TIME: float = 1.0
## 피격 띠 한 번의 길이 (16장 기준 20fps).
const HIT_FRAME_TIME: float = 0.8
## 피격 때 곱하는 붉은색.
const FLASH_TINT := Color(1.0, 0.45, 0.45)
## 발밑 접지 그림자 색.
const CONTACT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
## 아군 진영 고리 색.
const ALLY_RING_COLOR := Color(0.3, 0.55, 1.0, 0.8)
## 적군 진영 고리 색.
const ENEMY_RING_COLOR := Color(1.0, 0.3, 0.25, 0.8)
## 체력 바가 놓이는 높이 (발밑 기준).
const OVERHEAD_Y: float = 2.0
## 체력 바 전체 폭.
const HP_BAR_WIDTH: float = 0.9
## 체력 바 높이.
const HP_BAR_HEIGHT: float = 0.1
## 클릭 광선이 맞히는 충돌 레이어 값 (비트 값 2 = 2번 레이어). 타일도 같은 레이어를 쓴다.
const PICK_LAYER_BIT: int = 2
## 돌진할 때 앞으로 나가는 거리.
const LUNGE_DISTANCE: float = 0.4
## 띠 없는 공격·깡충 한 번에 걸리는 시간.
const ACTION_TIME: float = 0.25
## 띠 없는 피격 연출 시간.
const FLASH_TIME: float = 0.24
## 떠오르는 숫자가 사라지기까지 시간.
const POP_TIME: float = 0.6
## 쓰러질 때 서서히 사라지는 시간.
const FADE_TIME: float = 0.4
## 한 칸 이동할 때 미끄러지는 시간.
const MOVE_TIME: float = 0.25
## 영혼불 한 알이 피어올라 사라지는 시간.
const AURA_LIFETIME: float = 1.6
## 초당 피어오르는 영혼불 수.
const AURA_RATE: float = 2.5
## 영혼불 한 알의 최대 크기 (몸 그림 64px 중 16px 정도).
const AURA_SIZE: float = 0.4
## 맞는 순간 몸이 완전히 흰색인 실제 시간.
const HIT_WHITE_TIME: float = 0.06
## 피해 숫자가 처음 튀는 배율.
const DAMAGE_POP_PUNCH: float = 1.6
## 처치 숫자가 처음 튀는 배율.
const KILL_POP_PUNCH: float = 2.0
## 피해 숫자가 크게 튀었다가 원래 크기로 돌아오는 시간.
const POP_PUNCH_TIME: float = 0.15
## 한 번에 튀는 불꽃 수.
const SPARK_COUNT: int = 12
## 불꽃·화살이 오가는 가슴 높이.
const CHEST_HEIGHT: float = SPRITE_HEIGHT * 0.55
# 불꽃 색 (뜨거운 흰색 → 주황).
const _SPARK_HOT := Color(1.0, 0.95, 0.8)
const _SPARK_WARM := Color(1.0, 0.55, 0.15)
# 피격 흔들림의 좌우 위치 키 (4구간).
const _SHAKE_KEYS: Array[float] = [0.0, 0.08, -0.08, 0.05, 0.0]

## 보여 주는 규칙 유닛.
var unit: Unit
## 유닛이 원래 서 있는 칸의 위치. 돌진 뒤 이 위치로 돌아온다.
var home_position: Vector3 = Vector3.ZERO
## 카메라를 향해 도는 몸 피벗 (발 위치). 깡충·흔들림은 이 노드를 움직인다.
var body: Node3D
## 발을 축으로 늘이기·기울이기를 맡는 피벗.
var pose: Node3D
## 그림을 그리는 사각형 판.
var sprite: MeshInstance3D
## 판의 셰이더 재질 (유닛마다 따로라 번쩍임이 번지지 않는다).
var body_material: ShaderMaterial
## 데이터의 정지 그림 (없으면 임시 그림).
var still_texture: Texture2D
## 대기 띠 (없으면 null).
var idle_sheet: Texture2D
## 공격 띠 (없으면 null).
var attack_sheet: Texture2D
## 피격 띠 (없으면 null).
var hit_sheet: Texture2D
## 몸 주변에 피어오르는 오라 입자 (오라 그림이 없으면 null).
var aura: CPUParticles3D
## 맞는 순간 튀는 불꽃 (한 번씩 터뜨린다).
var sparks: CPUParticles3D
# 흰 번쩍임이 꺼질 실제 시각 (밀리초, 0 이면 꺼져 있음).
var _white_until_msec: int = 0
## 머리 위 이름 글자.
var name_label: Label3D
## 체력 바 아래 "현재/최대 방N" 글자.
var stat_label: Label3D
## 체력 바 배경 (어두운 막대).
var hp_back: MeshInstance3D
## 체력 바 채움 (초록 막대, 체력 비율만큼 폭이 준다).
var hp_fill: MeshInstance3D
## 발밑 접지 그림자.
var shadow: MeshInstance3D
## 발밑 진영 고리.
var ring: MeshInstance3D
## 클릭 판정용 물리 몸체.
var pick_body: StaticBody3D
## pick_body 의 충돌 모양 (쓰러지면 꺼서 클릭이 통과하게 한다).
var pick_shape: CollisionShape3D

## 표시 중인 체력.
var _hp: int = 0
## 표시 중인 최대 체력 (0 으로 나누지 않게 최소 1).
var _max_hp: int = 1
## 표시 중인 방어도.
var _block: int = 0
## 아군 1, 적 −1 (적은 왼쪽을 본다. 기울기 방향을 거울상으로 만든다).
var _facing: float = 1.0
## 연출 중이면 true. 그동안은 대기 동작을 멈춘다 (연출이 자세를 잡는다).
var _acting: bool = false
## 대기 동작용 누적 시간.
var _clock: float = 0.0
## 숨쉬기 박자를 유닛마다 어긋나게 하는 위상.
var _idle_phase: float = 0.0
## 대기 띠 시작 프레임을 유닛마다 어긋나게 하는 값.
var _idle_frame_offset: int = 0

# 모든 유닛이 같이 쓰는 그림자·고리 텍스처 (한 번만 만든다).
static var _shadow_texture: Texture2D
static var _ring_texture: Texture2D


## 유닛과 정지 그림을 받아 필요한 자식 노드를 모두 만든다. 트리에 붙이기 전에 불러도 된다.
func setup(p_unit: Unit, texture: Texture2D) -> void:
	# 보여 줄 유닛을 기억한다.
	unit = p_unit
	# 적은 왼쪽을 보도록 뒤집는다.
	_facing = 1.0 if unit.is_ally() else -1.0
	# 그림과 띠를 기억한다.
	still_texture = texture
	idle_sheet = unit.data.idle_sheet
	attack_sheet = unit.data.attack_sheet
	hit_sheet = unit.data.hit_sheet
	# 유닛마다 숨쉬기·대기 프레임을 어긋나게 한다.
	_idle_phase = unit.unit_id * 1.7
	_idle_frame_offset = unit.unit_id * 5

	# --- 몸 ---
	# 카메라를 향해 도는 피벗.
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# 늘이기·기울이기 피벗.
	pose = Node3D.new()
	pose.name = "Pose"
	body.add_child(pose)
	# 그림 판. 높이 1.6 에 그림 비율대로 폭을 맞춘다.
	sprite = MeshInstance3D.new()
	sprite.name = "Sprite"
	var quad := QuadMesh.new()
	quad.size = Vector2(SPRITE_HEIGHT * float(texture.get_width()) / float(texture.get_height()), SPRITE_HEIGHT)
	sprite.mesh = quad
	# 판 중심을 절반 높이에 두어 발이 피벗에 닿게 한다.
	sprite.position = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)
	# 유닛마다 따로 쓰는 셰이더 재질.
	body_material = ShaderMaterial.new()
	body_material.shader = UNIT_SHADER
	# 적은 왼쪽을 보도록 그림만 좌우로 뒤집는다 (스케일은 양수로 둬야 빛을 제대로 받는다).
	body_material.set_shader_parameter("flip_h", not unit.is_ally())
	sprite.material_override = body_material
	pose.add_child(sprite)
	# 대기 모습으로 시작한다.
	_return_to_idle()

	# --- 불꽃 ---
	sparks = _make_sparks()

	# --- 오라 ---
	# 데이터에 오라 그림이 있을 때만.
	if unit.data.aura_texture != null:
		aura = _make_aura(unit.data.aura_texture)

	# --- 발밑 ---
	# 접지 그림자.
	shadow = _floor_decal(_get_shadow_texture(), Vector2(0.9, 0.5), 0.01, CONTACT_SHADOW_COLOR)
	# 진영 고리.
	ring = _floor_decal(_get_ring_texture(), Vector2(0.95, 0.6), 0.012, ALLY_RING_COLOR if unit.is_ally() else ENEMY_RING_COLOR)

	# --- 이름 ---
	# 유닛 이름 글자를 만든다.
	name_label = _make_label(unit.data.display_name, 36)
	# 체력 바 조금 위에 놓는다.
	name_label.position = Vector3(0.0, OVERHEAD_Y + 0.28, 0.0)
	# 자식으로 붙인다.
	add_child(name_label)

	# --- 체력 바 ---
	# 어두운 배경 막대 (그리기 우선순위 0: 먼저 그림).
	hp_back = _make_bar(Color(0.1, 0.1, 0.1, 0.85), 0)
	# 머리 위 높이에 놓는다.
	hp_back.position = Vector3(0.0, OVERHEAD_Y, 0.0)
	# 자식으로 붙인다.
	add_child(hp_back)
	# 초록 채움 막대 (우선순위 1: 배경 위에 그림).
	hp_fill = _make_bar(Color(0.35, 0.85, 0.4), 1)
	# 배경과 같은 높이에 놓는다.
	hp_fill.position = Vector3(0.0, OVERHEAD_Y, 0.0)
	# 자식으로 붙인다.
	add_child(hp_fill)

	# --- 수치 글자 ---
	# 체력/방어도 숫자 글자를 만든다 (내용은 _refresh_stats 가 채움).
	stat_label = _make_label("", 28)
	# 체력 바 바로 아래에 놓는다.
	stat_label.position = Vector3(0.0, OVERHEAD_Y - 0.18, 0.0)
	# 자식으로 붙인다.
	add_child(stat_label)

	# --- 클릭 판정 ---
	# 움직이지 않는 물리 몸체를 만든다.
	pick_body = StaticBody3D.new()
	# 클릭 광선이 찾는 레이어에 올린다.
	pick_body.collision_layer = PICK_LAYER_BIT
	# 다른 물체와 부딪힐 일은 없으므로 마스크는 비운다.
	pick_body.collision_mask = 0
	# 충돌 모양 노드를 만든다.
	pick_shape = CollisionShape3D.new()
	# 스프라이트를 감싸는 상자 모양.
	var box := BoxShape3D.new()
	# 폭 0.8, 스프라이트 높이, 두께 0.4.
	box.size = Vector3(0.8, SPRITE_HEIGHT, 0.4)
	# 모양을 넣는다.
	pick_shape.shape = box
	# 스프라이트와 같은 높이에 맞춘다.
	pick_shape.position = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)
	# 모양을 몸체에 붙인다.
	pick_body.add_child(pick_shape)
	# 몸체를 이 노드에 붙인다.
	add_child(pick_body)

	# 규칙 유닛의 현재 값으로 표시를 채운다.
	set_stats(unit.hp, unit.data.max_hp, unit.block)


## 매 프레임: 몸을 카메라 쪽으로 돌리고 대기 동작을 진행한다.
func _process(delta: float) -> void:
	# 지금 화면을 그리는 3D 카메라 (헤드리스·전환 중에는 없을 수 있다).
	var camera: Camera3D = get_viewport().get_camera_3d()
	# 있으면 그 방향으로 돌린다.
	if camera != null:
		body.rotation = billboard_rotation(-camera.global_basis.z, BODY_TILT_DEG)
	# 시간을 쌓는다 (게임 시간이라 히트스톱 때 같이 멈춘다).
	_clock += delta
	# 대기 동작.
	tick_idle(_clock)
	# 흰 번쩍임은 실제 시간으로 끈다 (히트스톱 중에도 0.06초면 꺼진다).
	tick_flash(Time.get_ticks_msec())
	# 불꽃은 히트스톱 중에도 제 속도로 날아간다.
	sparks.speed_scale = 1.0 / maxf(Engine.time_scale, 0.01)


## 카메라 시선(camera_forward)의 수평 성분을 보도록 Y축만 돌리고, 위쪽을 카메라 반대로 tilt_deg 만큼 눕힌 회전.
static func billboard_rotation(camera_forward: Vector3, tilt_deg: float) -> Vector3:
	# 높이 성분을 버린 시선.
	var flat := Vector3(camera_forward.x, 0.0, camera_forward.z)
	# 바로 아래를 보면 돌 방향이 없다.
	if flat.length_squared() == 0.0:
		return Vector3(deg_to_rad(-tilt_deg), 0.0, 0.0)
	# 판의 앞(+Z)이 카메라 쪽(시선 반대)을 보게 한다. 회전 순서가 YXZ 라 Y 로 돈 뒤 로컬 X 로 눕는다.
	return Vector3(deg_to_rad(-tilt_deg), atan2(-flat.x, -flat.z), 0.0)


## 띠 텍스처의 프레임 수 (너비 ÷ 높이, 최소 1).
static func frame_count(sheet: Texture2D) -> int:
	# 정수 나눗셈이 의도다 (64px 프레임 단위).
	@warning_ignore("integer_division")
	return maxi(1, sheet.get_width() / sheet.get_height())


## 띠의 index 번 프레임을 보인다 (넘치면 감는다).
func show_frame(sheet: Texture2D, index: int) -> void:
	# 이 띠의 프레임 수.
	var count: int = frame_count(sheet)
	# 셰이더에 띠와 프레임을 넘긴다.
	body_material.set_shader_parameter("texture_albedo", sheet)
	body_material.set_shader_parameter("frame_count", count)
	body_material.set_shader_parameter("frame", posmod(index, count))


## 진행률 t(0~1)에 해당하는 띠 프레임을 보인다. 끝은 마지막 프레임에 머문다.
func show_sheet_progress(sheet: Texture2D, t: float) -> void:
	# 이 띠의 프레임 수.
	var count: int = frame_count(sheet)
	# 진행률을 프레임 번호로.
	show_frame(sheet, mini(int(floor(t * count)), count - 1))


## 대기 동작 한 번: 띠가 있으면 8fps 프레임, 없으면 숨쉬기 자세. 연출 중이면 아무것도 안 한다.
func tick_idle(time: float) -> void:
	# 연출이 자세를 잡고 있다.
	if _acting:
		return
	# 그려진 대기 동작.
	if idle_sheet != null:
		show_frame(idle_sheet, int(floor(time * IDLE_FPS)) + _idle_frame_offset)
		return
	# 코드 숨쉬기.
	apply_pose(UnitMotion.idle(time, _idle_phase))


## 자세를 몸에 적용한다. 위로 늘면 옆으로 얇아져 부피가 유지돼 보인다. 기울기는 바라보는 방향의 뒤쪽.
func apply_pose(p: UnitMotion.Pose) -> void:
	# 늘이기.
	pose.scale = Vector3(1.0 - p.stretch * 0.5, 1.0 + p.stretch, 1.0)
	# 적은 반대로 기운다.
	pose.rotation = Vector3(0.0, 0.0, deg_to_rad(p.lean * _facing))


## 공격 한 번의 길이 (띠가 있으면 띠 길이).
func attack_duration() -> float:
	return ATTACK_FRAME_TIME if attack_sheet != null else ACTION_TIME


## 피격 한 번의 길이 (띠가 있으면 띠 길이).
func hit_duration() -> float:
	return HIT_FRAME_TIME if hit_sheet != null else FLASH_TIME


## 체력·최대 체력·방어도 표시를 한 번에 바꾼다.
func set_stats(hp: int, max_hp: int, block: int) -> void:
	# 체력을 기억한다.
	_hp = hp
	# 최대 체력을 기억한다 (0 이하면 1 로 막아 나눗셈 오류를 피한다).
	_max_hp = maxi(max_hp, 1)
	# 방어도를 기억한다.
	_block = block
	# 화면을 갱신한다.
	_refresh_stats()


## 체력 표시만 바꾼다 (방어도는 그대로).
func set_hp(hp: int, max_hp: int) -> void:
	# 체력을 기억한다.
	_hp = hp
	# 최대 체력을 기억한다 (최소 1).
	_max_hp = maxi(max_hp, 1)
	# 화면을 갱신한다.
	_refresh_stats()


## 방어도 표시만 바꾼다.
func set_block(block: int) -> void:
	# 방어도를 기억한다.
	_block = block
	# 화면을 갱신한다.
	_refresh_stats()


## 원래 서 있을 위치를 정하고 그 자리로 옮긴다.
func set_home(world_position: Vector3) -> void:
	# 돌아올 위치로 기억한다.
	home_position = world_position
	# 지금 위치도 그 자리로 옮긴다.
	position = world_position


## 새 자리로 미끄러져 이동한다. 원래 자리를 먼저 바꾸므로 이후 돌진 연출도 새 자리로 돌아온다. await 가능.
func slide_to(world_position: Vector3) -> void:
	# 돌아올 자리를 새 위치로 바꾼다.
	home_position = world_position
	# 위치 트윈을 만든다.
	var tween: Tween = create_tween()
	# MOVE_TIME 동안 새 위치로 옮긴다.
	tween.tween_property(self, "position", world_position, MOVE_TIME)
	# 끝날 때까지 기다린다.
	await tween.finished


## 연출 도중 끊겼을 수 있는 자세·위치·셰이더 값을 기본으로 되돌린다.
func reset_pose() -> void:
	# 원래 칸 위치로.
	position = home_position
	# 깡충·흔들림 되돌림.
	body.position = Vector3.ZERO
	# 연출 끝.
	_acting = false
	# 기본 자세.
	apply_pose(UnitMotion.Pose.new())
	# 대기 그림.
	_return_to_idle()
	# 색·번쩍임·투명도.
	body_material.set_shader_parameter("tint", Color.WHITE)
	body_material.set_shader_parameter("flash", 0.0)
	body_material.set_shader_parameter("fade", 1.0)
	# 흰 번쩍임 예약도 지운다.
	_white_until_msec = 0


## 살아 있음/쓰러짐에 맞춰 보이기와 클릭 판정을 켜고 끈다.
func set_alive(alive: bool) -> void:
	# 쓰러졌으면 숨긴다.
	visible = alive
	# 쓰러졌으면 클릭 판정을 끈다 (뒤에 있는 타일이 클릭되도록).
	pick_shape.disabled = not alive


## 목표 쪽으로 distance 만큼 나갔다 돌아온다 (음수면 뒤로 물러나는 반동). 끝날 때까지 await 할 수 있다.
func lunge_toward(world_target: Vector3, distance: float = LUNGE_DISTANCE) -> void:
	# 원래 위치에서 목표까지의 수평 방향.
	var direction: Vector3 = world_target - home_position
	direction.y = 0.0
	# 길이가 0 이 아니면 길이 1 로.
	if direction.length() > 0.0:
		direction = direction.normalized()
	# 연출 시작.
	_acting = true
	# 0→1 진행률로 한 걸음씩 그린다.
	var tween: Tween = create_tween()
	tween.tween_method(_lunge_step.bind(home_position, home_position + direction * distance), 0.0, 1.0, attack_duration())
	await tween.finished
	# 연출 끝, 대기 그림으로.
	_acting = false
	_return_to_idle()


# 돌진 한 순간: 위치는 돌진 곡선, 모습은 공격 띠 또는 공격 자세 (둘을 겹치면 과해진다).
func _lunge_step(t: float, home: Vector3, lunge: Vector3) -> void:
	# 위치.
	position = home.lerp(lunge, UnitMotion.lunge_reach(t))
	# 그려진 공격.
	if attack_sheet != null:
		show_sheet_progress(attack_sheet, t)
	# 코드 공격 자세.
	else:
		apply_pose(UnitMotion.attack(t))


## 제자리에서 한 번 뛴다 (방어·휴식 행동 표시). 끝날 때까지 await 할 수 있다.
func hop() -> void:
	# 연출 시작.
	_acting = true
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_hop_step, 0.0, 1.0, ACTION_TIME)
	await tween.finished
	# 바닥으로.
	body.position = Vector3.ZERO
	# 연출 끝.
	_acting = false


# 깡충 한 순간: 높이와 자세.
func _hop_step(t: float) -> void:
	# 높이.
	body.position = Vector3(0.0, UnitMotion.hop_height(t), 0.0)
	# 웅크림·늘어남.
	apply_pose(UnitMotion.hop(t))


## 피격 연출: 흰 번쩍임·불꽃으로 시작해 피격 띠(또는 움찔 자세) + 붉은 번쩍임 2회 + 좌우 흔들림.
## knockback 은 맞아서 밀려날 최대 변위(바닥 평면). 끝나면 정확히 제자리로 돌아온다. await 할 수 있다.
func flash_and_shake(knockback: Vector3 = Vector3.ZERO) -> void:
	# 연출 시작.
	_acting = true
	# 맞는 첫 순간.
	start_impact()
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_hit_step.bind(home_position, knockback), 0.0, 1.0, hit_duration())
	await tween.finished
	# 제자리·원래 색.
	position = home_position
	body.position = Vector3.ZERO
	body_material.set_shader_parameter("tint", Color.WHITE)
	# 연출 끝, 대기 그림으로.
	_acting = false
	_return_to_idle()


# 피격 한 순간: 모습, 4구간 중 0·2번째 붉은색, 좌우 흔들림, 넉백.
func _hit_step(t: float, home: Vector3, knockback: Vector3) -> void:
	# 그려진 피격.
	if hit_sheet != null:
		show_sheet_progress(hit_sheet, t)
	# 코드 움찔 자세.
	else:
		apply_pose(UnitMotion.hit(t))
	# 몇 번째 구간인지 (0~3).
	var quarter: int = mini(int(t * 4.0), 3)
	# 짝수 구간은 붉게.
	body_material.set_shader_parameter("tint", FLASH_TINT if quarter % 2 == 0 and t < 1.0 else Color.WHITE)
	# 구간 안 진행률로 흔들림 키 사이를 잇는다.
	var local: float = t * 4.0 - quarter
	body.position = Vector3(lerpf(_SHAKE_KEYS[quarter], _SHAKE_KEYS[quarter + 1], local), 0.0, 0.0)
	# 밀렸다가 돌아온다 (넉백이 없으면 제자리).
	position = home + knockback * UnitMotion.knockback_reach(t)


# 기다리지 않는다. 숫자가 떠오르는 동안 다음 연출이 겹쳐도 된다.
## 맞는 첫 순간: 몸을 완전한 흰색으로 칠하고 불꽃을 튀긴다. 흰색은 실제 시간 0.06초 뒤 꺼진다.
func start_impact() -> void:
	# 흰색.
	body_material.set_shader_parameter("flash", 1.0)
	# 끌 시각.
	_white_until_msec = Time.get_ticks_msec() + int(HIT_WHITE_TIME * 1000.0)
	# 불꽃 한 번.
	sparks.restart()


## 실제 시각 now_msec 가 흰색을 끌 때를 지났으면 끈다.
func tick_flash(now_msec: int) -> void:
	# 켜져 있고 시간이 됐으면.
	if _white_until_msec > 0 and now_msec >= _white_until_msec:
		_white_until_msec = 0
		body_material.set_shader_parameter("flash", 0.0)


## 피해 숫자 크기: punch 배에서 시작해 POP_PUNCH_TIME 동안 1 로 줄어든다. t 는 POP_TIME 기준 진행률.
static func pop_scale(t: float, punch: float) -> float:
	return lerpf(punch, 1.0, clampf(t * POP_TIME / POP_PUNCH_TIME, 0.0, 1.0))


## 머리 위에 글자(피해 숫자, 카드 이름 등)를 띄워 위로 올리며 사라지게 한다.
func pop_text(text: String, color: Color, punch: float = 1.0) -> void:
	# 큰 글자를 만든다.
	var label: Label3D = _make_label(text, 64)
	# 글자 색을 정한다.
	label.modulate = color
	# 이름보다 위에서 시작한다.
	label.position = Vector3(0.0, OVERHEAD_Y + 0.5, 0.0)
	# 자식으로 붙인다.
	add_child(label)
	# 여러 속성을 동시에 바꾸는 트윈을 만든다.
	var tween: Tween = create_tween().set_parallel(true)
	# 위로 0.6 만큼 떠오른다.
	tween.tween_property(label, "position:y", label.position.y + 0.6, POP_TIME)
	# 글자가 투명해진다.
	tween.tween_property(label, "modulate:a", 0.0, POP_TIME)
	# 외곽선도 함께 투명해진다 (따로 바꾸지 않으면 외곽선만 남는다).
	tween.tween_property(label, "outline_modulate:a", 0.0, POP_TIME)
	# 처음엔 크게 튀었다가 원래 크기로.
	tween.tween_method(func(t: float) -> void: label.scale = Vector3.ONE * pop_scale(t, punch), 0.0, 1.0, POP_TIME)
	# 다 끝나면 글자 노드를 지운다.
	tween.finished.connect(label.queue_free)


## 쓰러짐 연출: 막대·그림자·고리를 바로 숨기고, 넘어지며 픽셀이 흩어져 사라진 뒤 숨긴다.
func fade_out() -> void:
	# 사라지는 동안에도 클릭되지 않게 판정을 끈다.
	pick_shape.disabled = true
	# 체력 바·발밑 표시를 숨긴다.
	hp_back.visible = false
	hp_fill.visible = false
	shadow.visible = false
	ring.visible = false
	# 오라는 새로 나오지 않게 한다 (이미 뜬 불꽃은 마저 사라진다).
	if aura != null:
		aura.emitting = false
	# 연출 시작 (끝나도 숨겨지므로 되돌리지 않는다).
	_acting = true
	# 0→1 진행률.
	var tween: Tween = create_tween()
	tween.tween_method(_fade_step, 0.0, 1.0, FADE_TIME)
	await tween.finished
	# 완전히 숨긴다.
	visible = false


# 쓰러짐 한 순간: 넘어지는 자세, 디더 페이드, 글자 투명도.
func _fade_step(t: float) -> void:
	# 넘어짐.
	apply_pose(UnitMotion.death(t))
	# 남은 불투명도.
	var alpha: float = 1.0 - t
	# 몸.
	body_material.set_shader_parameter("fade", alpha)
	# 글자와 외곽선.
	name_label.modulate.a = alpha
	name_label.outline_modulate.a = alpha
	stat_label.modulate.a = alpha
	stat_label.outline_modulate.a = alpha


# 대기 모습: 대기 띠의 시작 프레임, 없으면 정지 그림.
func _return_to_idle() -> void:
	# 띠가 있으면 그 첫 프레임.
	if idle_sheet != null:
		show_frame(idle_sheet, _idle_frame_offset)
		return
	# 정지 그림 한 장.
	body_material.set_shader_parameter("texture_albedo", still_texture)
	body_material.set_shader_parameter("frame_count", 1)
	body_material.set_shader_parameter("frame", 0)


## 기억한 체력·방어도로 수치 글자와 체력 바 폭을 다시 그린다.
func _refresh_stats() -> void:
	# "현재/최대" 형식으로 체력을 쓴다.
	stat_label.text = "%d/%d" % [_hp, _max_hp]
	# 방어도가 있으면 뒤에 "방N" 을 붙인다.
	if _block > 0:
		stat_label.text += "  방%d" % _block
	# 체력 비율 (0~1 로 제한).
	var ratio: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	# 채움 막대의 폭을 비율만큼 줄인다.
	(hp_fill.mesh as QuadMesh).size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	# 카메라가 좌우로 돌지 않으므로 월드 X 가 화면 가로 방향이다.
	# 줄어든 막대가 왼쪽 끝에 붙어 있도록 줄어든 폭의 절반만큼 왼쪽으로 옮긴다.
	hp_fill.position.x = -HP_BAR_WIDTH * (1.0 - ratio) / 2.0
	# 체력이 0 이면 채움 막대를 숨긴다 (폭 0 메시 방지).
	hp_fill.visible = ratio > 0.0


## 머리 위 글자용 Label3D 를 공통 설정으로 만든다.
func _make_label(text: String, font_size: int) -> Label3D:
	# 3D 글자 노드를 만든다.
	var label := Label3D.new()
	# 내용.
	label.text = text
	# 글꼴 크기 (픽셀 기준).
	label.font_size = font_size
	# 글꼴 픽셀 하나의 3D 크기.
	label.pixel_size = 0.004
	# 배경과 구분되게 외곽선을 두른다.
	label.outline_size = 10
	# 항상 카메라를 정면으로 바라본다.
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# 다른 물체에 가려지지 않고 항상 위에 그린다.
	label.no_depth_test = true
	# 체력 바(0, 1)보다 나중에 그려 위에 보이게 한다.
	label.render_priority = 2
	# 외곽선은 글자보다 먼저 그린다.
	label.outline_render_priority = 1
	# 만든 글자를 돌려준다.
	return label


## 체력 바용 사각형 메시를 만든다. priority 가 클수록 나중에(위에) 그려진다.
func _make_bar(color: Color, priority: int) -> MeshInstance3D:
	# 메시 노드를 만든다.
	var bar := MeshInstance3D.new()
	# 평평한 사각형 메시.
	var quad := QuadMesh.new()
	# 막대 크기.
	quad.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	# 메시를 넣는다.
	bar.mesh = quad
	# 재질을 만든다.
	var material := StandardMaterial3D.new()
	# 조명 영향 없이 색 그대로.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 항상 카메라를 향한다.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# 반투명을 허용한다 (배경 막대의 알파).
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 다른 물체에 가려지지 않게 한다.
	material.no_depth_test = true
	# 그리기 순서.
	material.render_priority = priority
	# 막대 색.
	material.albedo_color = color
	# 재질을 입힌다.
	bar.material_override = material
	# 만든 막대를 돌려준다.
	return bar


# 가슴 높이에서 사방으로 튀는 네모 불꽃 (유니티 UnitView.MakeSparks). 한 번 터뜨리고 끝난다.
func _make_sparks() -> CPUParticles3D:
	# 입자 노드.
	var particles := CPUParticles3D.new()
	particles.name = "Sparks"
	particles.position = Vector3(0.0, CHEST_HEIGHT, 0.0)
	# 한 번에 다 나온다.
	particles.amount = SPARK_COUNT
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.lifetime = 0.25
	# 이미 튄 불꽃은 몸이 밀려도 제자리.
	particles.local_coords = false
	# 작은 구에서 사방으로.
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	# 중력 절반.
	particles.gravity = Vector3(0.0, -4.9, 0.0)
	# 크기 0.06~0.1.
	particles.scale_amount_min = 0.75
	particles.scale_amount_max = 1.25
	# 흰색~주황 사이에서 하나.
	var colors := Gradient.new()
	colors.set_color(0, _SPARK_HOT)
	colors.set_color(1, _SPARK_WARM)
	particles.color_initial_ramp = colors
	# 카메라를 보는 네모, 빛을 더한다.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


# 몸 둘레에서 천천히 떠올라 옅어지며 사라지는 불꽃 (유니티 UnitView.MakeAura).
func _make_aura(texture: Texture2D) -> CPUParticles3D:
	# 입자 노드.
	var particles := CPUParticles3D.new()
	particles.name = "Aura"
	# 몸 가운데 높이.
	particles.position = Vector3(0.0, SPRITE_HEIGHT * 0.45, 0.0)
	# 동시에 떠 있는 최대 수 = 수명 × 초당 수 (올림).
	particles.amount = ceili(AURA_LIFETIME * AURA_RATE)
	particles.lifetime = AURA_LIFETIME
	# 처음부터 가득 차 있게.
	particles.preprocess = AURA_LIFETIME
	# 이미 뜬 불꽃은 몸이 움직여도 제자리.
	particles.local_coords = false
	# 몸을 감싸는 납작한 상자에서 나온다.
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.55, SPRITE_HEIGHT * 0.35, 0.05)
	# 위로 천천히.
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.35
	# 크기 0.7~1 배, 수명 동안 절반으로 준다.
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.5))
	particles.scale_amount_curve = shrink
	# 알파: 0 → 1(0.2) → 1(0.6) → 0.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	# 카메라를 보는 픽셀 그림 판 (알파 섞기, 더하기 아님).
	var quad := QuadMesh.new()
	quad.size = Vector2(AURA_SIZE, AURA_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	quad.material = material
	particles.mesh = quad
	# 그림자는 드리우지 않는다.
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 계속 나온다.
	particles.emitting = true
	add_child(particles)
	return particles


# 발밑 바닥에 까는 평면 하나 (그림자·고리). 조명과 그림자에 영향받지 않는다.
func _floor_decal(texture: Texture2D, size: Vector2, height: float, color: Color) -> MeshInstance3D:
	# 바닥 평면.
	var decal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	decal.mesh = plane
	# 반투명 무광 재질에 색을 곱한다.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = color
	decal.material_override = material
	# 바닥 장식은 그림자를 드리우지 않는다.
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 타일과 겹쳐 깜빡이지 않게 살짝 띄운다.
	decal.position = Vector3(0.0, height, 0.0)
	add_child(decal)
	return decal


# 가운데가 진하고(0.5) 가장자리로 갈수록 투명한 원 (유니티 ViewAssets.CreateShadow).
static func _get_shadow_texture() -> Texture2D:
	# 처음 한 번만 만든다.
	if _shadow_texture == null:
		_shadow_texture = _radial_texture(func(r: float) -> float: return 0.5 * (1.0 - clampf(r, 0.0, 1.0)))
	return _shadow_texture


# 반지름 0.8~0.95 사이만 불투명한 얇은 고리 (유니티 ViewAssets.CreateRing).
static func _get_ring_texture() -> Texture2D:
	# 처음 한 번만 만든다.
	if _ring_texture == null:
		_ring_texture = _radial_texture(func(r: float) -> float: return clampf(1.0 - absf(r - 0.875) / 0.075, 0.0, 1.0))
	return _ring_texture


# 64×64 흰 텍스처. 중심에서의 거리(반지름 1 기준) r 마다 alpha_at(r) 을 알파로 쓴다.
static func _radial_texture(alpha_at: Callable) -> Texture2D:
	# 한 변의 픽셀 수.
	var size: int = 64
	# 빈 이미지.
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# 중심.
	var center := Vector2((size - 1) / 2.0, (size - 1) / 2.0)
	# 픽셀마다 알파를 정한다.
	for y in size:
		for x in size:
			var r: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_at.call(r)))
	# 텍스처로 만든다.
	return ImageTexture.create_from_image(image)
