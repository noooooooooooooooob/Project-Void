## 전투 카메라의 타격 연출. 기본 구도(set_base) 위에 푸시인·흔들림을 더하고, 히트스톱·처치 슬로모션으로 시간 배율을 바꾼다.
## 히트스톱 중에도 움직여야 하므로 실제 시간으로 돈다 (유니티 BattleCamera).
class_name BattleCamera
# Node: 카메라 옆에 붙어 매 프레임 카메라를 옮긴다.
extends Node

## 타격 지점까지 거리 중 이만큼만 다가간다 (보드가 화면에서 벗어나지 않을 정도).
const PUSH_FRACTION: float = 0.12
## 푸시인이 목표에 다가가는 빠르기.
const PUSH_SHARPNESS: float = 8.0
## 흔들림으로 밀리는 최대 거리.
const MAX_SHAKE_OFFSET: float = 0.25
## 초당 줄어드는 흔들림 세기 (1 이 0.4초 만에 사라진다).
const SHAKE_DECAY: float = 2.5
## 히트스톱 중 시간 배율.
const HIT_STOP_SCALE: float = 0.05
## 처치 슬로모션 시간 배율.
const SLOW_MO_SCALE: float = 0.3
## 처치 슬로모션을 실제 시간으로 유지하는 길이.
const SLOW_MO_TIME: float = 0.35
## 흔들림 세기가 더 오르지 않는 피해량.
const SHAKE_DAMAGE_CAP: int = 10
# 피해 0 의 흔들림 세기.
const _SHAKE_BASE: float = 0.2
# 피해 상한까지 더해지는 흔들림 세기.
const _SHAKE_PER_DAMAGE: float = 0.7
# 남은 차이가 이보다 작으면 목표에 붙인다.
const _SETTLE_EPSILON: float = 1e-5

## 움직일 카메라.
var camera: Camera3D

# 기본 구도.
var _base_position: Vector3 = Vector3.ZERO
var _base_basis: Basis = Basis.IDENTITY
# 지금 푸시인 오프셋과 목표.
var _push: Vector3 = Vector3.ZERO
var _push_target: Vector3 = Vector3.ZERO
# 흔들림 세기 (0..1).
var _trauma: float = 0.0
# 남은 히트스톱 (실제 초).
var _hit_stop_left: float = 0.0
# 히트스톱을 건 프레임의 시간은 이미 흘러간 것이라 빼지 않는다.
var _hit_stop_just_started: bool = false
# 히트스톱이 끝나면 슬로모션을 시작한다.
var _slow_mo_pending: bool = false
# 남은 슬로모션 (실제 초).
var _slow_mo_left: float = 0.0
# 지난 프레임의 실제 시각 (마이크로초).
var _last_usec: int = 0


## 피해량에 비례하되 상한이 있는 흔들림 세기 (0..1). 처치는 항상 가장 세다.
static func shake_for_damage(amount: int, died: bool) -> float:
	# 처치.
	if died:
		return 1.0
	# 피해 비례.
	return _SHAKE_BASE + _SHAKE_PER_DAMAGE * float(mini(amount, SHAKE_DAMAGE_CAP)) / float(SHAKE_DAMAGE_CAP)


## 연출이 없을 때의 카메라 위치·회전을 정하고 바로 적용한다.
func set_base(position: Vector3, basis: Basis) -> void:
	# 기억한다.
	_base_position = position
	_base_basis = basis
	# 지금 오프셋으로 적용.
	_apply(_push)


## 타격 지점 쪽으로 조금 다가간다.
func push_toward(point: Vector3) -> void:
	# 목표 오프셋.
	_push_target = (point - _base_position) * PUSH_FRACTION


## 푸시인을 풀고 기본 구도로 돌아간다.
func release() -> void:
	# 목표를 0 으로.
	_push_target = Vector3.ZERO


## 흔든다. 이미 더 세게 흔들리고 있으면 그대로.
func shake(strength: float) -> void:
	# 큰 쪽.
	_trauma = clampf(maxf(_trauma, strength), 0.0, 1.0)


## 시간을 잠깐 거의 멈춘다. 겹치면 남은 시간이 긴 쪽.
func hit_stop(seconds: float) -> void:
	# 긴 쪽.
	_hit_stop_left = maxf(_hit_stop_left, seconds)
	# 이번 프레임 시간은 빼지 않는다.
	_hit_stop_just_started = true
	# 바로 느리게.
	Engine.time_scale = HIT_STOP_SCALE


## 처치 연출: 히트스톱이 끝나면(없으면 바로) 잠깐 느리게 흐른다.
func kill_slow_mo() -> void:
	# 다음 기회에 시작.
	_slow_mo_pending = true


## 지금 푸시인 오프셋 (테스트용).
func push_offset() -> Vector3:
	return _push


## 지금 흔들림 세기 (테스트용).
func trauma() -> float:
	return _trauma


## 실제 시간 real_delta 만큼 진행한다.
func tick(real_delta: float) -> void:
	# --- 히트스톱 ---
	if _hit_stop_just_started:
		_hit_stop_just_started = false
	elif _hit_stop_left > 0.0:
		_hit_stop_left -= real_delta
		# 끝났으면 슬로모션 중이면 그 배율, 아니면 1.
		if _hit_stop_left <= 0.0:
			_hit_stop_left = 0.0
			Engine.time_scale = SLOW_MO_SCALE if _slow_mo_left > 0.0 else 1.0
	# --- 슬로모션 (히트스톱이 없을 때만) ---
	if _hit_stop_left <= 0.0 and not _hit_stop_just_started:
		if _slow_mo_pending:
			_slow_mo_pending = false
			_slow_mo_left = SLOW_MO_TIME
			Engine.time_scale = SLOW_MO_SCALE
		elif _slow_mo_left > 0.0:
			_slow_mo_left -= real_delta
			if _slow_mo_left <= 0.0:
				_slow_mo_left = 0.0
				Engine.time_scale = 1.0

	# --- 푸시인 ---
	_push = _push.lerp(_push_target, 1.0 - exp(-PUSH_SHARPNESS * real_delta))
	if _push.distance_squared_to(_push_target) < _SETTLE_EPSILON * _SETTLE_EPSILON:
		_push = _push_target

	# --- 흔들림 ---
	var shake_offset := Vector3.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - SHAKE_DECAY * real_delta)
		# 제곱해야 약한 타격은 잔잔하고 센 타격만 크게 튄다. 화면 평면(카메라 x·y) 안의 무작위 방향.
		var angle: float = randf() * TAU
		shake_offset = (_base_basis.x * cos(angle) + _base_basis.y * sin(angle)) * (MAX_SHAKE_OFFSET * _trauma * _trauma)
	_apply(_push + shake_offset)


## 매 프레임: 실제 시간 차이로 진행한다.
func _process(_delta: float) -> void:
	# 지금 실제 시각.
	var now: int = Time.get_ticks_usec()
	# 첫 프레임은 0.
	var real_delta: float = 0.0 if _last_usec == 0 else float(now - _last_usec) / 1000000.0
	_last_usec = now
	tick(real_delta)


## 트리에서 빠질 때(씬 전환 등) 시간 배율이 남지 않게 한다.
func _exit_tree() -> void:
	# 멈춤·슬로모션이 남아 있으면 지운다.
	if _hit_stop_left > 0.0 or _slow_mo_left > 0.0 or _slow_mo_pending:
		_hit_stop_left = 0.0
		_slow_mo_left = 0.0
		_slow_mo_pending = false
		Engine.time_scale = 1.0


# 기본 구도 + offset 을 카메라에 적용한다.
func _apply(offset: Vector3) -> void:
	# 카메라가 없으면 (테스트) 넘어간다.
	if camera == null:
		return
	camera.transform = Transform3D(_base_basis, _base_position + offset)
