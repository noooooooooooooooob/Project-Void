## 한 장짜리 스프라이트에 생기를 주는 자세 곡선 모음 (유니티 UnitMotion 그대로).
## 진행률 t(0→1)를 넣으면 자세가 나온다. 자세는 발을 축으로 한 늘이기(stretch)와
## 기울기(lean, 도 단위, 양수 = 바라보는 방향의 뒤쪽)뿐이다.
class_name UnitMotion
# RefCounted: 노드가 아닌 가벼운 객체 (정적 함수만 쓴다).
extends RefCounted

## 한 순간의 자세.
class Pose:
	## 세로로 늘어난 정도 (0.1 = 10% 길어짐, 음수는 눌림).
	var stretch: float
	## 뒤로 젖힌 각도 (도).
	var lean: float

	## 늘이기와 기울기로 자세를 만든다.
	func _init(p_stretch: float = 0.0, p_lean: float = 0.0) -> void:
		# 늘이기.
		stretch = p_stretch
		# 기울기.
		lean = p_lean


## 숨쉬기 한 번의 주기 (초).
const IDLE_PERIOD: float = 1.6
## 숨쉬기로 늘어나는 최대 비율.
const IDLE_STRETCH: float = 0.03
## 쓰러질 때 끝까지 넘어가는 각도.
const DEATH_LEAN: float = 85.0
## 공격 예비동작이 끝나는 진행률.
const ATTACK_WINDUP_END: float = 0.3
## 무기가 닿는 진행률 (돌진이 가장 멀리 나간 순간).
const ATTACK_STRIKE: float = 0.5
## 넉백이 가장 멀리 밀린 진행률.
const KNOCKBACK_PEAK: float = 0.15

# 공격 자세 키.
const _ATTACK_TIMES: Array[float] = [0.0, ATTACK_WINDUP_END, ATTACK_STRIKE, 0.75, 1.0]
const _ATTACK_STRETCH: Array[float] = [0.0, -0.12, 0.12, -0.03, 0.0]
const _ATTACK_LEAN: Array[float] = [0.0, 8.0, -10.0, 2.0, 0.0]
# 돌진 거리 키.
const _LUNGE_TIMES: Array[float] = [0.0, ATTACK_WINDUP_END, ATTACK_STRIKE, 1.0]
const _LUNGE_VALUES: Array[float] = [0.0, 0.0, 1.0, 0.0]
# 깡충 자세 키.
const _HOP_TIMES: Array[float] = [0.0, 0.2, 0.35, 0.55, 0.85, 0.9, 1.0]
const _HOP_STRETCH: Array[float] = [0.0, -0.15, 0.1, 0.03, 0.02, -0.12, 0.0]
# 깡충 높이 키.
const _HOP_HEIGHT_TIMES: Array[float] = [0.0, 0.2, 0.55, 0.85, 1.0]
const _HOP_HEIGHT_VALUES: Array[float] = [0.0, 0.0, 0.25, 0.0, 0.0]
# 넉백 키.
const _KNOCKBACK_TIMES: Array[float] = [0.0, KNOCKBACK_PEAK, 0.6, 1.0]
const _KNOCKBACK_VALUES: Array[float] = [0.0, 1.0, 0.0, 0.0]
# 피격 자세 키.
const _HIT_TIMES: Array[float] = [0.0, 0.15, 0.5, 1.0]
const _HIT_STRETCH: Array[float] = [0.0, -0.1, 0.03, 0.0]
const _HIT_LEAN: Array[float] = [0.0, 12.0, -3.0, 0.0]


## 대기 중 숨쉬기. phase 로 유닛마다 박자를 어긋나게 한다.
static func idle(time: float, phase: float) -> Pose:
	# 사인 한 주기가 IDLE_PERIOD 초.
	return Pose.new(IDLE_STRETCH * sin(TAU * time / IDLE_PERIOD + phase))


## 공격 자세: 웅크렸다가(예비동작) 뻗으며 앞으로 숙인다.
static func attack(t: float) -> Pose:
	# 늘이기와 기울기를 각각 키에서 읽는다.
	return Pose.new(_eval(_ATTACK_TIMES, _ATTACK_STRETCH, t), _eval(_ATTACK_TIMES, _ATTACK_LEAN, t))


## 공격할 때 몸이 앞으로 나간 정도 (0 = 제자리, 1 = 끝까지).
static func lunge_reach(t: float) -> float:
	# 예비동작 동안은 제자리.
	return _eval(_LUNGE_TIMES, _LUNGE_VALUES, t)


## 깡충 자세: 웅크림 → 늘어남 → 착지 눌림.
static func hop(t: float) -> Pose:
	# 늘이기만 쓴다.
	return Pose.new(_eval(_HOP_TIMES, _HOP_STRETCH, t))


## 깡충 높이 (3D 단위).
static func hop_height(t: float) -> float:
	# 웅크리는 동안은 바닥.
	return _eval(_HOP_HEIGHT_TIMES, _HOP_HEIGHT_VALUES, t)


## 피격 자세: 눌리며 뒤로 젖혔다가 돌아온다.
static func hit(t: float) -> Pose:
	# 늘이기와 기울기를 각각 키에서 읽는다.
	return Pose.new(_eval(_HIT_TIMES, _HIT_STRETCH, t), _eval(_HIT_TIMES, _HIT_LEAN, t))


## 맞아서 밀려난 정도 (0 = 제자리, 1 = 끝까지). 확 밀렸다가 천천히 돌아온다.
static func knockback_reach(t: float) -> float:
	# 0.15 에서 최대, 0.6 부터 제자리.
	return _eval(_KNOCKBACK_TIMES, _KNOCKBACK_VALUES, t)


## 쓰러짐: 처음엔 천천히, 끝에서 빠르게 넘어간다.
static func death(t: float) -> Pose:
	# 제곱이라 가속한다.
	return Pose.new(0.0, DEATH_LEAN * t * t)


# 키 사이를 smoothstep 으로 잇는다. 키마다 속도가 0 이 되어 동작의 "멈칫"이 생긴다.
static func _eval(times: Array[float], values: Array[float], t: float) -> float:
	# 범위 밖 진행률은 자른다.
	var clamped: float = clampf(t, 0.0, 1.0)
	# 이 진행률이 들어 있는 구간을 찾는다.
	for i in range(1, times.size()):
		if clamped <= times[i]:
			# 구간 안에서의 진행률.
			var local: float = inverse_lerp(times[i - 1], times[i], clamped)
			# 부드럽게 섞는다.
			return lerpf(values[i - 1], values[i], smoothstep(0.0, 1.0, local))
	# 마지막 키 값.
	return values[values.size() - 1]
