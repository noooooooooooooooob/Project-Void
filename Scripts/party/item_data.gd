# @tool: 에디터 안에서도 실행되어 인스펙터에서 값을 편집할 수 있다.
@tool
## 장비 아이템 한 종류의 설계 데이터 (.tres 리소스로 저장).
## 장착하면 아군 유닛의 능력치가 보너스만큼 바뀐다. 실제 반영은 PartyState.build_battle_roster 가 한다.
class_name ItemData
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 장착 부위. 캐릭터마다 부위당 하나만 낄 수 있다.
enum Slot { WEAPON, ARMOR, ACCESSORY }

## 코드에서 아이템을 구분하는 고유 이름 (예: &"rusty_knife").
@export var id: StringName = &""
## 화면에 보이는 아이템 이름 (예: "녹슨 단검").
@export var display_name: String = ""
## 장착 부위.
@export var slot: Slot = Slot.WEAPON
## 아이템 설명 (인벤토리 상세에 보인다).
@export_multiline var description: String = ""
## 최대 체력 보너스.
@export var max_hp_bonus: int = 0
## 속도 보너스.
@export var speed_bonus: int = 0
## 최대 SP 보너스.
@export var max_sp_bonus: int = 0
## 피해를 주는 모든 카드의 피해량 보너스.
@export var attack_bonus: int = 0


## 부위 이름 (화면 표시용).
static func slot_name(p_slot: Slot) -> String:
	# 부위마다 화면에 보일 이름을 고른다.
	match p_slot:
		# 무기.
		Slot.WEAPON:
			return "무기"
		# 방어구.
		Slot.ARMOR:
			return "방어구"
		# 나머지는 장신구.
		_:
			return "장신구"


## "체력 +4 · 속도 -1" 처럼 0 이 아닌 보너스만 모아 한 줄로 돌려준다. 보너스가 없으면 빈 문자열.
func summary() -> String:
	# 보너스별 문구를 모을 목록.
	var parts: PackedStringArray = []
	# 체력 보너스가 있으면 부호를 붙여 넣는다 (%+d 는 양수에도 + 를 붙인다).
	if max_hp_bonus != 0:
		parts.append("체력 %+d" % max_hp_bonus)
	# 속도 보너스.
	if speed_bonus != 0:
		parts.append("속도 %+d" % speed_bonus)
	# SP 보너스.
	if max_sp_bonus != 0:
		parts.append("SP %+d" % max_sp_bonus)
	# 공격 보너스.
	if attack_bonus != 0:
		parts.append("공격 %+d" % attack_bonus)
	# 가운뎃점으로 이어 한 줄로 만든다 (목록이 비었으면 빈 문자열).
	return " · ".join(parts)
