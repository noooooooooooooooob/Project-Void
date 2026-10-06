## 전투 효과음 묶음. 공격 종류·피해·처치에 맞는 클립을 고른다. 비어 있는 칸은 null 이라 소리가 나지 않는다.
class_name BattleSounds
# Resource: .tres 로 저장해 인스펙터에서 클립을 바꿀 수 있다.
extends Resource

## 근접 공격을 휘두르는 소리.
@export var melee_swing: AudioStream
## 근접 공격이 맞는 소리.
@export var melee_hit: AudioStream
## 원거리 공격을 쏘는 소리.
@export var ranged_shot: AudioStream
## 원거리 공격이 맞는 소리.
@export var ranged_hit: AudioStream
## 방어도에 막혀 피해가 0 인 소리.
@export var blocked: AudioStream
## 처치 소리.
@export var kill: AudioStream


## 공격을 시작(근접) 또는 발사(원거리)할 때의 소리.
func for_attack(type: CardData.AttackType) -> AudioStream:
	# 원거리는 발사, 근접은 휘두르기.
	return ranged_shot if type == CardData.AttackType.RANGED else melee_swing


## 맞은 순간의 소리. 처치 → 막힘 → 공격 종류 순으로 고른다.
func for_impact(type: CardData.AttackType, amount: int, died: bool) -> AudioStream:
	# 처치가 가장 우선.
	if died:
		return kill
	# 피해가 없으면 막힘.
	if amount <= 0:
		return blocked
	# 공격 종류별 타격음.
	return ranged_hit if type == CardData.AttackType.RANGED else melee_hit
