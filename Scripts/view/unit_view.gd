## 3D 보드 위에 서 있는 유닛 한 명의 화면 표현.
## 항상 카메라를 향하는 스프라이트(빌보드), 발밑 그림자, 머리 위 이름·체력 바·수치 글자,
## 클릭 판정용 충돌 상자를 가진다. 규칙 상태는 바꾸지 않고 보여 주기만 한다.
class_name UnitView
# Node3D: 3D 공간에 위치를 가지는 노드.
extends Node3D

## 스프라이트가 화면에 그려질 높이 (3D 단위). 그림 크기와 상관없이 이 높이로 맞춘다.
const SPRITE_HEIGHT: float = 1.6
## 아군 스프라이트에 곱하는 색 (푸른 계열).
const ALLY_TINT := Color(0.55, 0.75, 1.0)
## 적군 스프라이트에 곱하는 색 (붉은 계열).
const ENEMY_TINT := Color(1.0, 0.55, 0.5)
## 피격 번쩍임 색. 1 보다 큰 값이라 원래 색보다 밝게 빛난다.
const FLASH_COLOR := Color(2.0, 2.0, 2.0)
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
## 돌진·뛰기 한 번에 걸리는 시간 (나갔다 돌아오기 합계).
const ACTION_TIME: float = 0.25
## 번쩍임·흔들림에 걸리는 시간.
const FLASH_TIME: float = 0.24
## 떠오르는 숫자가 사라지기까지 시간.
const POP_TIME: float = 0.6
## 쓰러질 때 서서히 사라지는 시간.
const FADE_TIME: float = 0.4

## 보여 주는 규칙 유닛.
var unit: Unit
## 유닛이 원래 서 있는 칸의 위치. 돌진 뒤 이 위치로 돌아온다.
var home_position: Vector3 = Vector3.ZERO
## 유닛 그림 (카메라를 향해 세로로 서는 빌보드).
var sprite: Sprite3D
## 머리 위 이름 글자.
var name_label: Label3D
## 체력 바 아래 "현재/최대 방N" 글자.
var stat_label: Label3D
## 체력 바 배경 (어두운 막대).
var hp_back: MeshInstance3D
## 체력 바 채움 (초록 막대, 체력 비율만큼 폭이 준다).
var hp_fill: MeshInstance3D
## 발밑 동그란 그림자.
var shadow: MeshInstance3D
## 클릭 판정용 물리 몸체.
var pick_body: StaticBody3D
## pick_body 의 충돌 모양 (쓰러지면 꺼서 클릭이 통과하게 한다).
var pick_shape: CollisionShape3D

## 이 유닛의 기본 색 (아군/적군 틴트).
var _tint: Color = Color.WHITE
## 스프라이트의 기본 위치 (발이 바닥에 닿게 절반 높이만큼 올린 위치).
var _sprite_home: Vector3 = Vector3.ZERO
## 표시 중인 체력.
var _hp: int = 0
## 표시 중인 최대 체력 (0 으로 나누지 않게 최소 1).
var _max_hp: int = 1
## 표시 중인 방어도.
var _block: int = 0


## 유닛과 그림을 받아 필요한 자식 노드를 모두 만든다. 트리에 붙이기 전에 불러도 된다.
func setup(p_unit: Unit, texture: Texture2D) -> void:
	# 보여 줄 유닛을 기억한다.
	unit = p_unit
	# 편에 맞는 색을 고른다.
	_tint = ALLY_TINT if unit.is_ally() else ENEMY_TINT

	# --- 스프라이트 ---
	# 3D 공간에 그림을 그리는 노드를 만든다.
	sprite = Sprite3D.new()
	# 유닛 그림을 넣는다.
	sprite.texture = texture
	# 세로축(Y)은 고정한 채 카메라 쪽으로만 돌게 한다 (옆으로 눕지 않음).
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# 투명 픽셀을 잘라내 깊이 정렬 문제를 피한다.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# 조명의 영향을 받지 않게 한다 (그림 색 그대로).
	sprite.shaded = false
	# 그림 픽셀 하나의 3D 크기를 정해 전체 높이가 SPRITE_HEIGHT 가 되게 한다.
	sprite.pixel_size = SPRITE_HEIGHT / float(texture.get_height())
	# 스프라이트 중심이 가운데이므로 절반 높이만큼 올려 발이 바닥에 닿게 한다.
	_sprite_home = Vector3(0.0, SPRITE_HEIGHT / 2.0, 0.0)
	# 기본 위치에 놓는다.
	sprite.position = _sprite_home
	# 편 색을 곱한다.
	sprite.modulate = _tint
	# 자식으로 붙인다.
	add_child(sprite)

	# --- 그림자 ---
	# 바닥에 까는 평면을 만든다.
	shadow = MeshInstance3D.new()
	# 가로로 길쭉한 평면 메시.
	var shadow_mesh := PlaneMesh.new()
	# 그림자 크기.
	shadow_mesh.size = Vector2(0.9, 0.5)
	# 메시를 넣는다.
	shadow.mesh = shadow_mesh
	# 가운데가 진하고 바깥으로 흐려지는 재질을 입힌다.
	shadow.material_override = _shadow_material()
	# 타일 표면과 겹쳐 깜빡이지 않게 아주 살짝 띄운다.
	shadow.position = Vector3(0.0, 0.01, 0.0)
	# 자식으로 붙인다.
	add_child(shadow)

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
	pick_shape.position = _sprite_home
	# 모양을 몸체에 붙인다.
	pick_body.add_child(pick_shape)
	# 몸체를 이 노드에 붙인다.
	add_child(pick_body)

	# 규칙 유닛의 현재 값으로 표시를 채운다.
	set_stats(unit.hp, unit.data.max_hp, unit.block)


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


## 연출 도중 끊겼을 수 있는 자세(위치, 색, 투명 처리)를 기본으로 되돌린다.
func reset_pose() -> void:
	# 원래 칸 위치로.
	position = home_position
	# 스프라이트를 기본 높이로 (뛰기·흔들림 되돌림).
	sprite.position = _sprite_home
	# 번쩍임 색을 편 색으로 되돌린다.
	sprite.modulate = _tint
	# 페이드 때 꺼 둔 투명 잘라내기를 다시 켠다.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD


## 살아 있음/쓰러짐에 맞춰 보이기와 클릭 판정을 켜고 끈다.
func set_alive(alive: bool) -> void:
	# 쓰러졌으면 숨긴다.
	visible = alive
	# 쓰러졌으면 클릭 판정을 끈다 (뒤에 있는 타일이 클릭되도록).
	pick_shape.disabled = not alive


## 목표 지점 쪽으로 짧게 돌진했다가 돌아온다. 끝날 때까지 await 할 수 있다.
func lunge_toward(world_target: Vector3) -> void:
	# 원래 위치에서 목표까지의 방향.
	var direction: Vector3 = world_target - home_position
	# 높이 차이는 무시하고 바닥과 평행하게만 움직인다.
	direction.y = 0.0
	# 길이가 0 이 아니면 길이 1 로 맞춘다 (0 이면 정규화할 수 없음).
	if direction.length() > 0.0:
		direction = direction.normalized()
	# 순서대로 실행되는 트윈을 만든다.
	var tween: Tween = create_tween()
	# 절반 시간 동안 앞으로 LUNGE_DISTANCE 만큼 나간다.
	tween.tween_property(self, "position", home_position + direction * LUNGE_DISTANCE, ACTION_TIME / 2.0)
	# 나머지 절반 시간 동안 원래 자리로 돌아온다.
	tween.tween_property(self, "position", home_position, ACTION_TIME / 2.0)
	# 트윈이 끝날 때까지 기다린다.
	await tween.finished


## 제자리에서 한 번 뛴다 (방어·휴식 행동 표시). 끝날 때까지 await 할 수 있다.
func hop() -> void:
	# 순서대로 실행되는 트윈을 만든다.
	var tween: Tween = create_tween()
	# 스프라이트를 0.25 만큼 위로 올린다.
	tween.tween_property(sprite, "position", _sprite_home + Vector3(0.0, 0.25, 0.0), ACTION_TIME / 2.0)
	# 다시 내린다.
	tween.tween_property(sprite, "position", _sprite_home, ACTION_TIME / 2.0)
	# 트윈이 끝날 때까지 기다린다.
	await tween.finished


## 피격 연출: 두 번 번쩍이면서 좌우로 흔들린다. 번쩍임이 끝날 때까지 await 할 수 있다.
func flash_and_shake() -> void:
	# 색 변화용 트윈.
	var flash: Tween = create_tween()
	# 밝게 → 원래 색을 두 번 반복한다.
	for _i in 2:
		# 밝은 색으로.
		flash.tween_property(sprite, "modulate", FLASH_COLOR, FLASH_TIME / 4.0)
		# 편 색으로.
		flash.tween_property(sprite, "modulate", _tint, FLASH_TIME / 4.0)
	# 위치 흔들림용 트윈 (색 트윈과 동시에 진행된다).
	var shake: Tween = create_tween()
	# 오른쪽 → 왼쪽 → 조금 오른쪽 → 가운데 순으로 x 위치를 옮긴다.
	for offset in [0.08, -0.08, 0.05, 0.0]:
		shake.tween_property(sprite, "position:x", offset, FLASH_TIME / 4.0)
	# 번쩍임이 끝날 때까지 기다린다 (두 트윈의 길이가 같다).
	await flash.finished


# 기다리지 않는다. 숫자가 떠오르는 동안 다음 연출이 겹쳐도 된다.
## 머리 위에 글자(피해 숫자, 카드 이름 등)를 띄워 위로 올리며 사라지게 한다.
func pop_text(text: String, color: Color) -> void:
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
	# 다 끝나면 글자 노드를 지운다.
	tween.finished.connect(label.queue_free)


## 쓰러짐 연출: 막대·그림자를 바로 숨기고 그림과 글자를 서서히 투명하게 한 뒤 숨긴다.
func fade_out() -> void:
	# 사라지는 동안에도 클릭되지 않게 판정을 끈다.
	pick_shape.disabled = true
	# 체력 바 배경을 숨긴다.
	hp_back.visible = false
	# 체력 바 채움을 숨긴다.
	hp_fill.visible = false
	# 그림자를 숨긴다.
	shadow.visible = false
	# alpha scissor 는 반투명 픽셀을 잘라내므로 페이드 동안만 끈다.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	# 동시에 진행되는 트윈을 만든다.
	var tween: Tween = create_tween().set_parallel(true)
	# 그림을 투명하게.
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_TIME)
	# 이름을 투명하게.
	tween.tween_property(name_label, "modulate:a", 0.0, FADE_TIME)
	# 수치 글자를 투명하게.
	tween.tween_property(stat_label, "modulate:a", 0.0, FADE_TIME)
	# 끝날 때까지 기다린다.
	await tween.finished
	# 완전히 숨긴다.
	visible = false


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


## 가운데가 진하고 가장자리로 갈수록 투명해지는 원형 그림자 재질을 만든다.
func _shadow_material() -> StandardMaterial3D:
	# 색 변화 단계를 정의하는 그라디언트.
	var gradient := Gradient.new()
	# 시작점(가운데) 색: 반투명 검정.
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.5))
	# 끝점(가장자리) 색: 완전 투명.
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	# 그라디언트를 그림으로 만드는 텍스처.
	var texture := GradientTexture2D.new()
	# 위 그라디언트를 쓴다.
	texture.gradient = gradient
	# 원형으로 퍼지게 한다.
	texture.fill = GradientTexture2D.FILL_RADIAL
	# 가운데에서 시작해서.
	texture.fill_from = Vector2(0.5, 0.5)
	# 오른쪽 끝에서 끝난다 (반지름 = 절반 폭).
	texture.fill_to = Vector2(1.0, 0.5)
	# 재질을 만든다.
	var material := StandardMaterial3D.new()
	# 조명 영향 없이.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 반투명 허용.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 그라디언트 텍스처를 입힌다.
	material.albedo_texture = texture
	# 만든 재질을 돌려준다.
	return material
