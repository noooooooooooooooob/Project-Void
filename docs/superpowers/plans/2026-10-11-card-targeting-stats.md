# 카드 타게팅·효과·스탯 개편 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사거리를 없애고, 카드를 "공격 종류 4가지 + 오프셋 범위 + 효과 목록(% 계수)"으로 바꾸고, 캐릭터 스탯 8종과 적 행동 카드화, 새 카드 앞면, 인스펙터 범위 편집기를 넣는다.

**Architecture:** 새 필드를 옛 필드 옆에 먼저 추가하고(Task 1~3), 규칙·데이터·화면을 하나씩 새 필드로 옮긴 뒤(Task 4~11), 마지막에 옛 필드와 옛 함수를 지운다(Task 12). 이렇게 하면 모든 Task 끝에서 전체 테스트가 통과한다. 효과 계산은 순수 함수(`CardMath`, `CardText`)로 떼어 규칙·화면·파티 화면이 함께 쓴다. 아군 카드와 적 행동은 `BattleState.resolve_card` 하나로 적용한다.

**Tech Stack:** Godot 4.7.2 GDScript (typed), 자체 `TestCase` 테스트 러너 (헤드리스).

**Spec:** `docs/superpowers/specs/2026-10-11-card-targeting-stats-design.md`

## Global Constraints

- 테스트 실행: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd` (PowerShell, 전면 실행, timeout 300000). 마지막 줄 `N/N passed`가 성공.
- 새 `class_name` 스크립트를 만든 직후 "Could not find type" 이 나오면 코드를 고치지 말고 `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path "C:\Users\User\Desktop\Godot\Project-Void"` 로 클래스 캐시를 재스캔한 뒤 다시 돌린다.
- 새 테스트 파일은 `tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 추가해야 실행된다.
- 코드 스타일: typed GDScript (`-> 반환형`, 타입 있는 `var`), 데이터 리소스는 `@tool`. 주석은 이 저장소 관례대로 **한국어로 거의 모든 문장 위에 한 줄씩** 단다 (아래 코드 블록은 그 밀도를 따른다).
- enum 값은 뒤에만 추가한다 (`.tres` 에 숫자로 저장돼 있다): `CardData.AttackType` 은 `MELEE=0, RANGED=1` 다음에 `ALLY, SELF`. `EnemyBrain.Action` 은 `MOVE` 다음에 `WAIT`.
- 스탯 기본값: `attack 10`, `defense 10`, `crit_chance 1`, `crit_damage 175`, `aggro 100`.
- 수치 공식: `floor(기준 스탯 × percent / 100)`, `percent > 0` 이면 최소 1, `percent <= 0` 이면 0 (0 이면 효과를 적용하지 않는다). 치명: `floor(수치 × crit_damage / 100)`.
- 카드 분류 색: 공격 `Color(0.85, 0.4, 0.35)`, 스킬 `Color(0.4, 0.6, 0.95)`, 특수 `Color(0.7, 0.45, 0.9)`.
- 공격 종류 배지 글자: 근접 "근", 원거리 "원", 아군 "아", 자신 "자".
- 효과 이름: 피해 / 방어도 / 회복. `SELF` 대상 효과는 카드 공격 종류가 `SELF` 가 아닐 때만 앞에 "자신 " 을 붙인다. 효과 사이 구분자는 `" · "`.
- 브랜치 `feature/map-character-inventory` 에 이전 작업(맵·인벤토리)이 커밋되지 않은 채 남아 있다. **커밋할 때는 그 Task 에서 바꾼 파일만 `git add <경로>` 로 올린다** (`git add -A` 금지). 이전 작업 파일을 이 계획에서 고쳐야 하면(예: `party_state.gd`) 그 파일 전체가 커밋에 들어가는 것은 허용한다.

## Review Focus

1. **근접 카드의 행이 비었다가 다시 찼을 때** — 같은 행의 적이 쓰러지면 근접 카드가 흐려지고 눌리지 않아야 하며, 적이 그 행으로 이동해 오면 다음 동기화에서 다시 쓸 수 있어야 한다. (Task 3 테스트, Task 10 테스트)
2. **격자 밖·중복 오프셋** — `area` 에 격자를 벗어나는 오프셋이나 같은 오프셋이 두 번 있어도 오류 없이 무시되고, 한 유닛이 한 효과에 두 번 맞지 않아야 한다. (Task 3 테스트)
3. **효과가 없는 카드 / 0% 효과** — 효과 목록이 비었거나 percent 가 0 인 카드도 SP 만 쓰고 정상 처리되며 0 피해 이벤트를 내지 않아야 한다. (Task 4 테스트)
4. **카드가 하나도 없는 적** — 공격·방어·휴식 카드가 모두 비어 있는 적은 "대기"로 차례를 넘겨야 하고 멈추거나 오류가 나면 안 된다. (Task 5 테스트)
5. **앞 효과로 기준 유닛이 쓰러진 뒤의 효과** — `피해 → 범위 추가 피해 → 자신 방어도` 처럼 이어질 때 쓰러진 유닛은 다시 맞지 않고 `SELF` 효과는 그대로 적용돼야 한다. (Task 4 테스트)

---

## 파일 구조

| 파일 | 책임 | Task |
|---|---|---|
| `Scripts/combat/data/unit_data.gd` (수정) | 스탯 8종 중 새 5종 추가 | 1 |
| `Scripts/combat/data/card_effect.gd` (신규) | 효과 하나: 종류·%·대상 | 2 |
| `Scripts/combat/data/card_data.gd` (수정) | 분류·공격 종류 4개·`area`·`effects` | 2, 12 |
| `Scripts/combat/card_math.gd` (신규) | 효과 수치·치명 판정 순수 계산 | 2 |
| `Scripts/combat/target_resolver.gd` (수정) | `valid_anchors`·`melee_anchor`·`area_cells`·`units_in_area` | 3, 12 |
| `Scripts/combat/battle_state.gd` (수정) | `play_card(index, anchor)`·`resolve_card`·`crit_rng`·신호 변경 | 4 |
| `Scripts/view/battle_event.gd`, `battle_event_recorder.gd` (수정) | `critical` 필드, 기준 유닛 기록 | 4 |
| `Scripts/combat/data/enemy_data.gd`, `Scripts/combat/enemy_brain.gd` (수정) | 적 행동 카드화, `WAIT` | 5, 12 |
| `Resources/cards/*.tres`, `Resources/cards/enemy/*.tres`, `Resources/units/{brute,sentry,stalker}.tres` | 데이터 이전 | 6 |
| `Scripts/ui/cards/card_text.gd` (신규) | 효과 문구·배지 글자 순수 함수 | 7 |
| `Scripts/party/party_state.gd`, `Scripts/ui/party_view.gd` (수정) | 공격 스탯 보너스, 스탯·덱 표시 | 8 |
| `Scripts/ui/cards/card_view.gd`, `hand_view.gd`, `Scripts/ui/battle_hud.gd` (수정) | 새 카드 앞면, 사용 불가 카드 | 9, 10 |
| `Scripts/view/battle_root.gd`, `battle_playback.gd` (수정) | 조준 흐름, 시전 연출, 치명 표시 | 11 |
| `tools/generate_starter_content.gd` (삭제) | 옛 필드를 쓰는 일회용 생성기 | 12 |
| `addons/card_area_editor/*` (신규) | 인스펙터 5×5 범위 편집기 | 13 |
| `tests/fixtures.gd` (신규) | 새 카드·효과·적 테스트 데이터 생성 공용 함수 | 2 |

---

### Task 1: 유닛 스탯 5종 추가

**Files:**
- Modify: `Scripts/combat/data/unit_data.gd` (`speed` 아래)
- Test: `tests/test_data.gd`

**Interfaces:**
- Produces: `UnitData.attack: int = 10`, `defense: int = 10`, `crit_chance: int = 1`, `crit_damage: int = 175`, `aggro: int = 100`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_data.gd` 의 `run()` 에서 `_test_ally_extends_unit_data()` 다음 줄에 `_test_unit_stat_defaults()` 호출을 넣고 함수를 추가한다.

```gdscript
# 새 스탯 5종의 기본값이 Notion 캐릭터 양식과 맞는지.
func _test_unit_stat_defaults() -> void:
	# 빈 아군 데이터 (UnitData 의 기본값을 물려받는다).
	var data: AllyData = AllyDataScript.new()
	# 공격 10.
	check_eq("default attack", data.attack, 10)
	# 방어 10.
	check_eq("default defense", data.defense, 10)
	# 치명확률 1%.
	check_eq("default crit_chance", data.crit_chance, 1)
	# 치명피해 175%.
	check_eq("default crit_damage", data.crit_damage, 175)
	# 어그로 100.
	check_eq("default aggro", data.aggro, 100)
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: 파싱 오류 또는 `default attack` FAIL.

- [ ] **Step 3: 구현** — `unit_data.gd` 의 `@export var speed` 줄 바로 아래에 추가:

```gdscript
## 공격 스탯. 피해·회복 효과의 % 계수가 이 값을 기준으로 계산된다.
@export var attack: int = 10
## 방어 스탯. 방어도 효과의 % 계수 기준 (받는 피해는 줄이지 않는다).
@export var defense: int = 10
## 치명타 확률 (%). 피해 효과가 맞을 때마다 따로 판정한다.
@export var crit_chance: int = 1
## 치명타 피해 배율 (%). 175 면 1.75 배.
@export var crit_damage: int = 175
## 어그로. 값만 저장한다 — 적 대상 고르기 규칙은 나중에 정한다.
@export var aggro: int = 100
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과 (`1107/1107 passed` 근처).

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/data/unit_data.gd tests/test_data.gd
git commit -m "feat: add attack, defense, crit and aggro stats to units"
```

---

### Task 2: CardEffect · CardData 새 필드 · CardMath · 테스트 픽스처

**Files:**
- Create: `Scripts/combat/data/card_effect.gd`, `Scripts/combat/card_math.gd`, `tests/fixtures.gd`, `tests/test_card_math.gd`
- Modify: `Scripts/combat/data/card_data.gd`, `tests/run_tests.gd`, `tests/test_data.gd`

**Interfaces:**
- Produces:
  - `CardEffect` (Resource): `enum Kind { DAMAGE, BLOCK, HEAL }`, `enum Target { AREA, SELF }`, `kind: Kind = DAMAGE`, `percent: int = 100`, `target: Target = AREA`
  - `CardData`: `enum AttackType { MELEE, RANGED, ALLY, SELF }`, `enum Category { ATTACK, SKILL, SPECIAL }`, `category: Category = ATTACK`, `area: Array[Vector2i] = []`, `effects: Array[CardEffect] = []`, `func area_offsets() -> Array[Vector2i]` (비었으면 `[Vector2i.ZERO]`), `func needs_aim() -> bool` (RANGED·ALLY 면 true). 옛 `shape`·`attack_range`·`damage` 는 Task 12 까지 남긴다.
  - `CardMath` (RefCounted, static): `base_stat(kind: CardEffect.Kind, stats: UnitData) -> int`, `amount(effect: CardEffect, stats: UnitData) -> int`, `rolls_crit(stats: UnitData, rng: RandomNumberGenerator) -> bool`, `critical_amount(amount: int, stats: UnitData) -> int`
  - `tests/fixtures.gd` (static, `preload` 로 쓴다): `effect(kind: int, percent: int, target: int = 0) -> CardEffect`, `card(id: StringName, attack_type: int, effects: Array[CardEffect], area: Array[Vector2i] = [], cost: int = 1) -> CardData`, `damage_card(id: StringName, attack_type: int, percent: int, area: Array[Vector2i] = [], cost: int = 1) -> CardData`

- [ ] **Step 1: 픽스처와 실패하는 테스트 작성**

`tests/fixtures.gd`:

```gdscript
# 테스트 공용 데이터 생성 함수 (새 카드·효과 형식). class_name 없이 preload 해서 쓴다.
extends RefCounted

# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 카드 효과 스크립트.
const CardEffectScript := preload("res://Scripts/combat/data/card_effect.gd")


# 종류·%·대상으로 효과 하나를 만든다 (target 0 = AREA, 1 = SELF).
static func effect(kind: int, percent: int, target: int = 0) -> CardEffect:
	# 빈 효과.
	var made: CardEffect = CardEffectScript.new()
	# 종류.
	made.kind = kind
	# 계수.
	made.percent = percent
	# 대상.
	made.target = target
	# 돌려준다.
	return made


# 공격 종류·효과 목록·범위·비용으로 카드를 만든다. 이름은 id 와 같다.
static func card(id: StringName, attack_type: int, effects: Array[CardEffect], area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	# 빈 카드.
	var made: CardData = CardDataScript.new()
	# id.
	made.id = id
	# 이름.
	made.display_name = String(id)
	# 비용.
	made.sp_cost = cost
	# 공격 종류.
	made.attack_type = attack_type
	# 효과 목록.
	made.effects = effects
	# 범위.
	made.area = area
	# 돌려준다.
	return made


# 범위 대상 피해 효과 하나짜리 카드.
static func damage_card(id: StringName, attack_type: int, percent: int, area: Array[Vector2i] = [], cost: int = 1) -> CardData:
	# 효과 목록.
	var effects: Array[CardEffect] = [effect(CardEffect.Kind.DAMAGE, percent)]
	# 카드를 만든다.
	return card(id, attack_type, effects, area, cost)
```

`tests/test_card_math.gd`:

```gdscript
# CardMath: 효과 수치(내림·최소 1·0%)와 치명 판정·배율.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")
# 아군 데이터 스크립트 (스탯을 담는 데 쓴다).
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 기준 스탯 선택.
	_test_base_stat_by_kind()
	# 내림과 최소 1.
	_test_amount_rounds_down_with_minimum_one()
	# 0% 는 0.
	_test_zero_percent_is_zero()
	# 치명 0%·100% 경계.
	_test_crit_bounds()
	# 치명 배율.
	_test_critical_amount()
	# 빈 범위는 단일.
	_test_empty_area_is_single()
	# 조준이 필요한 종류.
	_test_needs_aim()
	# 결과를 돌려준다.
	return results()


# 공격 13, 방어 7 인 스탯.
func _stats() -> AllyData:
	# 빈 데이터.
	var data: AllyData = AllyDataScript.new()
	# 공격.
	data.attack = 13
	# 방어.
	data.defense = 7
	# 돌려준다.
	return data


# 피해·회복은 공격, 방어도는 방어를 기준으로 한다.
func _test_base_stat_by_kind() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 피해 → 공격.
	check_eq("damage uses attack", CardMath.base_stat(CardEffect.Kind.DAMAGE, stats), 13)
	# 회복 → 공격.
	check_eq("heal uses attack", CardMath.base_stat(CardEffect.Kind.HEAL, stats), 13)
	# 방어도 → 방어.
	check_eq("block uses defense", CardMath.base_stat(CardEffect.Kind.BLOCK, stats), 7)


# 13 × 50% = 6.5 → 6, 7 × 10% = 0.7 → 최소 1.
func _test_amount_rounds_down_with_minimum_one() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 내림.
	check_eq("floor", CardMath.amount(Fixtures.effect(CardEffect.Kind.DAMAGE, 50), stats), 6)
	# 최소 1.
	check_eq("minimum one", CardMath.amount(Fixtures.effect(CardEffect.Kind.BLOCK, 10), stats), 1)


# 0% 효과는 0 이다 (적용하지 않는다는 뜻).
func _test_zero_percent_is_zero() -> void:
	# 0%.
	check_eq("zero percent", CardMath.amount(Fixtures.effect(CardEffect.Kind.DAMAGE, 0), _stats()), 0)


# 치명확률 0 은 절대 안 터지고 100 은 항상 터지며, 둘 다 난수를 쓰지 않는다.
func _test_crit_bounds() -> void:
	# 스탯.
	var stats: AllyData = _stats()
	# 난수.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 7
	# 시작 상태.
	var state_before: int = rng.state
	# 0%.
	stats.crit_chance = 0
	check("0% never crits", not CardMath.rolls_crit(stats, rng))
	# 100%.
	stats.crit_chance = 100
	check("100% always crits", CardMath.rolls_crit(stats, rng))
	# 난수를 건드리지 않았다.
	check_eq("bounds use no randomness", rng.state, state_before)


# 7 × 175% = 12.25 → 12.
func _test_critical_amount() -> void:
	# 기본 치명피해 175.
	check_eq("critical amount", CardMath.critical_amount(7, AllyDataScript.new()), 12)


# area 가 비어 있으면 기준 칸 하나.
func _test_empty_area_is_single() -> void:
	# 빈 범위 카드.
	var card: CardData = Fixtures.damage_card(&"x", CardData.AttackType.RANGED, 100)
	# [(0,0)].
	check_eq("empty area is single", card.area_offsets(), [Vector2i.ZERO])


# 원거리·아군만 조준한다.
func _test_needs_aim() -> void:
	# 종류별.
	check("ranged aims", Fixtures.damage_card(&"a", CardData.AttackType.RANGED, 1).needs_aim())
	check("ally aims", Fixtures.damage_card(&"b", CardData.AttackType.ALLY, 1).needs_aim())
	check("melee auto", not Fixtures.damage_card(&"c", CardData.AttackType.MELEE, 1).needs_aim())
	check("self auto", not Fixtures.damage_card(&"d", CardData.AttackType.SELF, 1).needs_aim())
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에서 `"res://tests/test_data.gd",` 다음 줄에 `"res://tests/test_card_math.gd",` 를 넣는다.

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `CardEffect`/`CardMath` 를 찾지 못하는 오류.

- [ ] **Step 3: 구현**

`Scripts/combat/data/card_effect.gd`:

```gdscript
# @tool: 에디터 안에서도 실행되어 인스펙터에서 효과 값을 편집할 수 있다.
@tool
## 카드 효과 하나: 무엇을(피해·방어도·회복), 얼마나(사용자 스탯의 %), 누구에게(카드 범위·자신).
## 카드 하나에 여러 개를 넣어 "피해 80% + 자신 방어도 50%" 같은 복합 카드를 만든다.
class_name CardEffect
# Resource: 카드 .tres 안에 하위 리소스로 저장된다.
extends Resource

## 효과 종류. 기준 스탯은 종류가 정한다 (피해·회복 → 공격, 방어도 → 방어).
enum Kind { DAMAGE, BLOCK, HEAL }
## 효과 대상. AREA 는 카드의 기준 유닛과 범위로 정해진 유닛들, SELF 는 카드를 쓴 유닛.
enum Target { AREA, SELF }

## 효과 종류.
@export var kind: Kind = Kind.DAMAGE
## 계수 (%). 120 이면 기준 스탯의 1.2 배.
@export var percent: int = 100
## 효과 대상.
@export var target: Target = Target.AREA
```

`Scripts/combat/data/card_data.gd` — 기존 `enum AttackType { MELEE, RANGED }` 줄과 그 위 주석을 교체하고, 파일 끝에 필드·함수를 추가한다 (옛 `shape`·`attack_range`·`damage` 는 그대로 둔다):

```gdscript
## 공격 종류. 카드의 기준 유닛을 고르는 방법이 다르다 (TargetResolver.valid_anchors).
## MELEE(근접): 사용자와 같은 행에서 가장 앞 열의 적 한 명. 없으면 쓸 수 없다. 조준 없이 자동.
## RANGED(원거리): 상대 편 아무나. ALLY(아군): 같은 편 아무나(자신 포함). SELF(자신): 사용자. 조준 없이 자동.
enum AttackType { MELEE, RANGED, ALLY, SELF }
## 카드 분류. 카드 색을 정한다.
enum Category { ATTACK, SKILL, SPECIAL }
```

파일 끝에:

```gdscript
## 카드 분류 (공격·스킬·특수).
@export var category: Category = Category.ATTACK
## 범위: 기준 칸에서의 오프셋 목록 (x = 열, + 가 뒤쪽 / y = 행, + 가 아래). 비어 있으면 기준 칸 하나(단일).
@export var area: Array[Vector2i] = []
## 효과 목록. 순서대로 적용된다.
@export var effects: Array[CardEffect] = []


## 실제로 쓸 범위 오프셋. 비어 있으면 단일 [(0,0)].
func area_offsets() -> Array[Vector2i]:
	# 비었으면 기준 칸 하나.
	if area.is_empty():
		var single: Array[Vector2i] = [Vector2i.ZERO]
		return single
	# 아니면 그대로.
	return area


## 플레이어가 기준 유닛을 직접 겨냥해야 하는 카드인지 (원거리·아군). 근접·자신은 자동으로 정해진다.
func needs_aim() -> bool:
	# 원거리나 아군이면 조준한다.
	return attack_type == AttackType.RANGED or attack_type == AttackType.ALLY
```

`Scripts/combat/card_math.gd`:

```gdscript
## 카드 효과 수치를 계산하는 순수 함수 모음. 규칙(BattleState)과 카드 문구(CardText)가 함께 쓴다.
class_name CardMath
# RefCounted: 모든 함수가 static 이라 객체를 만들 필요는 없다.
extends RefCounted


## 효과 종류의 기준 스탯 값. 방어도는 방어, 피해·회복은 공격.
static func base_stat(kind: CardEffect.Kind, stats: UnitData) -> int:
	# 방어도면 방어, 아니면 공격.
	return stats.defense if kind == CardEffect.Kind.BLOCK else stats.attack


## 효과 하나의 수치 = 내림(기준 스탯 × % / 100). % 가 0 이하면 0, 그 외에는 최소 1.
static func amount(effect: CardEffect, stats: UnitData) -> int:
	# 0% 이하는 적용하지 않는다.
	if effect.percent <= 0:
		return 0
	# 내림하고 최소 1 로 막는다.
	return maxi(1, floori(float(base_stat(effect.kind, stats) * effect.percent) / 100.0))


## 이번 타격이 치명타인지 판정한다. 0 이하·100 이상이면 난수를 쓰지 않는다 (시드 재현성 유지).
static func rolls_crit(stats: UnitData, rng: RandomNumberGenerator) -> bool:
	# 확률 0 이하면 절대 아님.
	if stats.crit_chance <= 0:
		return false
	# 100 이상이면 항상.
	if stats.crit_chance >= 100:
		return true
	# 1~100 중 확률 이하가 나오면 치명.
	return rng.randi_range(1, 100) <= stats.crit_chance


## 치명타 피해 = 내림(수치 × 치명피해 / 100).
static func critical_amount(amount: int, stats: UnitData) -> int:
	# 배율을 곱해 내림한다.
	return floori(float(amount * stats.crit_damage) / 100.0)
```

`tests/test_data.gd` 의 `_test_card_defaults()` 끝에 추가:

```gdscript
	# 기본 분류는 공격.
	check_eq("card default category", card.category, CardData.Category.ATTACK)
	# 기본 효과 없음.
	check("card default effects empty", card.effects.is_empty())
```

- [ ] **Step 4: 통과 확인** — 클래스 캐시 재스캔(Global Constraints) 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/data/card_effect.gd Scripts/combat/data/card_data.gd Scripts/combat/card_math.gd tests/fixtures.gd tests/test_card_math.gd tests/run_tests.gd tests/test_data.gd
git commit -m "feat: add card effects, categories, offset areas and effect math"
```

---

### Task 3: TargetResolver 기준 유닛·범위 함수

**Files:**
- Modify: `Scripts/combat/target_resolver.gd` (옛 함수는 그대로 두고 `movable_cells` 위에 추가)
- Test: `tests/test_target_resolver.gd`

**Interfaces:**
- Consumes: `CardData.attack_type`, `CardData.area_offsets()` (Task 2)
- Produces: `melee_anchor(actor: Unit, all_units: Array[Unit]) -> Unit` (없으면 null), `valid_anchors(actor: Unit, card: CardData, all_units: Array[Unit]) -> Array[Unit]`, `area_cells(anchor_cell: Vector2i, area: Array[Vector2i], grid: Vector2i) -> Array[Vector2i]`, `units_in_area(anchor: Unit, area: Array[Vector2i], all_units: Array[Unit]) -> Array[Unit]`

- [ ] **Step 1: 실패하는 테스트 작성** — 파일 위쪽 상수 목록에 `const Fixtures := preload("res://tests/fixtures.gd")` 를 추가하고, `run()` 의 `return results()` 앞에 아래 호출들을, 파일 끝에 함수들을 추가한다.

```gdscript
	# 근접 기준: 같은 행 맨 앞.
	_test_melee_anchor_is_front_of_same_row()
	# 근접 기준: 행이 비면 없음, 쓰러진 유닛 무시.
	_test_melee_anchor_empty_row_and_dead()
	# 종류별 기준 후보.
	_test_valid_anchors_by_type()
	# 범위 칸: 격자 밖·중복 무시.
	_test_area_cells_clip_and_dedupe()
	# 범위 유닛: 같은 편·생존만.
	_test_units_in_area_same_team_alive()
```

```gdscript
# 아군 (0,1) 의 같은 행(1) 에 적 (2,1)·(1,1) 이 있으면 앞 열인 (1,1) 이 기준. 다른 행의 (0,0) 은 무관.
func _test_melee_anchor_is_front_of_same_row() -> void:
	# 판정기.
	var resolver := TargetResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군.
	var ally: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 1))
	# 같은 행 뒤.
	var back: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(2, 1))
	# 같은 행 앞.
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(1, 1))
	# 다른 행 맨 앞.
	var other_row: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [ally, back, front, other_row]
	# 같은 행 맨 앞.
	check_eq("melee anchor is front of same row", resolver.melee_anchor(ally, units), front)


# 같은 행의 유일한 적이 쓰러져 있으면 기준이 없다.
func _test_melee_anchor_empty_row_and_dead() -> void:
	# 판정기.
	var resolver := TargetResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 아군 (0,2).
	var ally: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 2))
	# 같은 행의 쓰러진 적.
	var dead: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(0, 2))
	dead.hp = 0
	# 다른 행 적.
	var other: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [ally, dead, other]
	# 없음.
	check("no melee anchor when row has only dead", resolver.melee_anchor(ally, units) == null)
	# 근접 카드의 후보도 비어 있다.
	check("melee valid_anchors empty", resolver.valid_anchors(ally, Fixtures.damage_card(&"m", CardData.AttackType.MELEE, 50), units).is_empty())


# 원거리 = 살아 있는 적 전부, 아군 = 살아 있는 아군 전부(자신 포함), 자신 = [사용자].
func _test_valid_anchors_by_type() -> void:
	# 판정기.
	var resolver := TargetResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 사용자.
	var me: Unit = _unit(0, Unit.Team.ALLY, Vector2i(0, 0))
	# 다른 아군.
	var friend: Unit = _unit(1, Unit.Team.ALLY, Vector2i(1, 1))
	# 적 둘 (하나는 쓰러짐).
	var foe: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 2))
	var dead_foe: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 1))
	dead_foe.hp = 0
	# 전장.
	var units: Array[Unit] = [me, friend, foe, dead_foe]
	# 원거리.
	check_eq("ranged anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"r", CardData.AttackType.RANGED, 1), units), [foe])
	# 아군.
	check_eq("ally anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"a", CardData.AttackType.ALLY, 1), units), [me, friend])
	# 자신.
	check_eq("self anchors", resolver.valid_anchors(me, Fixtures.damage_card(&"s", CardData.AttackType.SELF, 1), units), [me])


# (2,0) 기준 [(0,0),(1,0),(0,-1),(0,0)] → (2,0) 만 남는다 (뒤쪽·위쪽은 격자 밖, 중복 제거).
func _test_area_cells_clip_and_dedupe() -> void:
	# 판정기.
	var resolver := TargetResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 범위.
	var area: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 0)]
	# 결과.
	check_eq("area cells clipped and deduped", resolver.area_cells(Vector2i(2, 0), area, Vector2i(3, 3)), [Vector2i(2, 0)])


# 기준 적 (0,1) + 세로 3칸: 같은 편 살아 있는 (0,0)·(0,1) 만. 쓰러진 (0,2) 와 아군 칸 (0,0) 은 제외.
func _test_units_in_area_same_team_alive() -> void:
	# 판정기.
	var resolver := TargetResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	# 기준 적.
	var anchor: Unit = _unit(0, Unit.Team.ENEMY, Vector2i(0, 1))
	# 위 적.
	var above: Unit = _unit(1, Unit.Team.ENEMY, Vector2i(0, 0))
	# 아래 쓰러진 적.
	var below: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	below.hp = 0
	# 같은 좌표의 아군.
	var ally: Unit = _unit(3, Unit.Team.ALLY, Vector2i(0, 0))
	# 전장.
	var units: Array[Unit] = [anchor, above, below, ally]
	# 세로 범위.
	var area: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)]
	# 결과 (전장 순서).
	check_eq("units in area", resolver.units_in_area(anchor, area, units), [anchor, above])
```

(이 파일의 판정기 스크립트 상수 이름이 `TargetResolverScript` 가 아니면 파일 위쪽 상수 이름에 맞춘다.)

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `melee_anchor` 등 없음 오류.

- [ ] **Step 3: 구현** — `target_resolver.gd` 의 `## 유닛이 지금 한 칸 이동할 수 있는 칸 목록` 주석 위에 추가:

```gdscript
## 근접 기준 유닛: 상대 편에서 actor 와 같은 행 번호에 살아 있는 유닛 중 가장 앞 열(x 가 가장 작은) 한 명. 없으면 null.
func melee_anchor(actor: Unit, all_units: Array[Unit]) -> Unit:
	# 지금까지 찾은 가장 앞 유닛.
	var best: Unit = null
	# 모든 유닛을 본다.
	for unit in all_units:
		# 같은 편, 쓰러짐, 다른 행은 제외한다.
		if unit.team == actor.team or not unit.is_alive() or unit.cell.y != actor.cell.y:
			continue
		# 처음이거나 더 앞 열이면 바꾼다.
		if best == null or unit.cell.x < best.cell.x:
			best = unit
	# 찾은 유닛 (없으면 null).
	return best


## 이 카드의 기준 유닛이 될 수 있는 유닛 목록. 근접은 같은 행 맨 앞 한 명(없으면 빈 목록), 원거리는 살아 있는 상대 전부,
## 아군은 살아 있는 같은 편 전부(자신 포함), 자신은 [actor]. 카드 사용·적 AI·화면 힌트가 모두 이 함수로 판정한다.
func valid_anchors(actor: Unit, card: CardData, all_units: Array[Unit]) -> Array[Unit]:
	# 후보 목록.
	var anchors: Array[Unit] = []
	# 공격 종류마다.
	match card.attack_type:
		# 자신: 살아 있으면 자기 자신.
		CardData.AttackType.SELF:
			if actor.is_alive():
				anchors.append(actor)
		# 근접: 같은 행 맨 앞 한 명.
		CardData.AttackType.MELEE:
			var front: Unit = melee_anchor(actor, all_units)
			if front != null:
				anchors.append(front)
		# 원거리·아군: 해당 편의 살아 있는 유닛 전부.
		_:
			# 아군 카드면 같은 편, 원거리면 상대 편.
			var same_team: bool = card.attack_type == CardData.AttackType.ALLY
			for unit in all_units:
				if unit.is_alive() and (unit.team == actor.team) == same_team:
					anchors.append(unit)
	# 모은 후보.
	return anchors


## 기준 칸에 범위 오프셋을 더한 칸들. 격자 밖은 버리고 같은 칸은 한 번만 넣는다.
func area_cells(anchor_cell: Vector2i, area: Array[Vector2i], grid: Vector2i) -> Array[Vector2i]:
	# 결과 칸.
	var cells: Array[Vector2i] = []
	# 오프셋마다.
	for offset in area:
		# 실제 칸.
		var cell: Vector2i = anchor_cell + offset
		# 격자 밖이면 버린다.
		if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
			continue
		# 중복이면 버린다.
		if cells.has(cell):
			continue
		# 넣는다.
		cells.append(cell)
	# 모은 칸.
	return cells


## 기준 유닛 기준 범위 안에 서 있는, 기준 유닛과 같은 편의 살아 있는 유닛들 (전장 순서).
func units_in_area(anchor: Unit, area: Array[Vector2i], all_units: Array[Unit]) -> Array[Unit]:
	# 범위 칸.
	var cells: Array[Vector2i] = area_cells(anchor.cell, area, grid_for(anchor.team))
	# 맞는 유닛.
	var hit: Array[Unit] = []
	# 모든 유닛 중.
	for unit in all_units:
		# 같은 편, 살아 있음, 범위 안.
		if unit.team == anchor.team and unit.is_alive() and cells.has(unit.cell):
			hit.append(unit)
	# 모은 유닛.
	return hit
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/target_resolver.gd tests/test_target_resolver.gd
git commit -m "feat: add anchor-based targeting and offset areas to the resolver"
```

---

### Task 4: BattleState 카드 사용·효과 적용·치명타 (+ 기록기)

**Files:**
- Modify: `Scripts/combat/battle_state.gd`, `Scripts/view/battle_event.gd`, `Scripts/view/battle_event_recorder.gd`, `Scripts/view/battle_root.gd` (`_on_cell_clicked` 호출부만), `Scripts/view/battle_playback.gd` (`_damaged` 만)
- Test: `tests/test_battle_state.gd`, `tests/test_battle_signals.gd`, `tests/test_event_recorder.gd`, `tests/test_battle_root.gd`, `tests/test_battle_playback.gd`, `tests/test_battle_hud.gd`, `tests/test_hand_view.gd`

**Interfaces:**
- Consumes: Task 2 (`CardMath`, `CardEffect`, `CardData.area_offsets`), Task 3 (`valid_anchors`, `units_in_area`)
- Produces:
  - `signal unit_damaged(unit: Unit, amount: int, critical: bool)`
  - `signal card_played(actor: Unit, card: CardData, anchor: Unit)`
  - `var crit_rng: RandomNumberGenerator` (시드 `hash([p_rng.seed, "crit"])`)
  - `func apply_damage(target: Unit, amount: int, critical: bool = false) -> void`
  - `func play_card(hand_index: int, anchor: Unit) -> bool`
  - `func resolve_card(actor: Unit, card: CardData, anchor: Unit) -> void`
  - `BattleEvent.critical: bool = false`; `CARD_PLAYED` 기록은 `target = anchor`, `target_team = anchor.team`, `target_cell = anchor.cell`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_battle_state.gd`:
  - 위쪽 상수에 `const Fixtures := preload("res://tests/fixtures.gd")` 추가.
  - `_card(...)` 헬퍼는 Task 12 까지 남겨 두되, 이 파일의 모든 `state.play_card(i, team, cell)` 호출을 `state.play_card(i, <그 칸의 유닛>)` 으로 바꾼다 (테스트 안에서 이미 유닛 변수를 들고 있으면 그대로, 아니면 `state.units` 에서 칸으로 찾는다). 카드는 `Fixtures.damage_card(...)` 로 만든다 — 옛 `_card(id, cost, type, shape, range, damage)` 는 `Fixtures.damage_card(id, type, damage * 10, <shape 대응 area>, cost)` 로 옮긴다 (아군 기본 공격 10 이므로 피해가 같다). SINGLE → `[]`, SWEEP → `[Vector2i(0,-2),Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(0,2)]`.
  - `_test_play_card_rejected_on_blocked_target` 은 "같은 행 맨 앞이 아닌 적을 근접 기준으로 넘기면 거절" 로 바꾼다 (이름 `_test_play_card_rejected_on_invalid_anchor`).
  - 크리티컬이 끼면 결과가 흔들리므로 이 파일의 아군 데이터 헬퍼에서 `crit_chance = 0` 을 넣는다.
  - 새 테스트 추가 (`run()` 에 호출 추가):

```gdscript
# 피해 → 범위 추가 피해 → 자신 방어도: 쓰러진 기준 유닛은 두 번째 효과에서 다시 맞지 않고, 자신 방어도는 들어간다.
func _test_effects_apply_in_order_and_skip_dead() -> void:
	# 효과 목록: 피해 100%, 피해 100%, 자신 방어도 50%.
	var effects: Array[CardEffect] = [
		Fixtures.effect(CardEffect.Kind.DAMAGE, 100),
		Fixtures.effect(CardEffect.Kind.DAMAGE, 100),
		Fixtures.effect(CardEffect.Kind.BLOCK, 50, CardEffect.Target.SELF),
	]
	# 원거리 카드.
	var card: CardData = Fixtures.card(&"combo", CardData.AttackType.RANGED, effects)
	# 적 체력 10 (첫 피해 10 에 쓰러진다).
	var state: BattleState = _state([card], 5, 10)
	# 아군과 적.
	var actor: Unit = state.units[0]
	var foe: Unit = state.units[1]
	# 아군 차례로 만든다 (이 파일의 다른 테스트와 같은 방식으로 initiative·turn_index·hand 를 직접 정한다).
	state.initiative = [actor, foe]
	state.turn_index = 0
	actor.hand = [card]
	# 피해 신호를 센다.
	var hits: Array[int] = []
	state.unit_damaged.connect(func(_u: Unit, amount: int, _c: bool) -> void: hits.append(amount))
	# 사용.
	check("combo played", state.play_card(0, foe))
	# 피해는 한 번만.
	check_eq("dead anchor hit once", hits, [10])
	# 자신 방어도 5 (방어 10 × 50%).
	check_eq("self block applied", actor.block, 5)


# 효과 없는 카드와 0% 효과: SP 만 쓰고 피해 신호가 없다.
func _test_empty_and_zero_effects() -> void:
	# 효과 없음.
	var empty: CardData = Fixtures.card(&"empty", CardData.AttackType.RANGED, [])
	# 0% 피해.
	var zero: CardData = Fixtures.damage_card(&"zero", CardData.AttackType.RANGED, 0)
	# 상태.
	var state: BattleState = _state([empty, zero], 5, 10)
	# 아군·적.
	var actor: Unit = state.units[0]
	var foe: Unit = state.units[1]
	state.initiative = [actor, foe]
	state.turn_index = 0
	actor.hand = [empty, zero]
	# 피해 신호 수.
	var count: Array[int] = [0]
	state.unit_damaged.connect(func(_u: Unit, _a: int, _c: bool) -> void: count[0] += 1)
	# 둘 다 사용.
	check("empty card played", state.play_card(0, foe))
	check("zero card played", state.play_card(0, foe))
	# 신호 없음.
	check_eq("no damage signals", count[0], 0)
	# 적 체력 그대로.
	check_eq("foe untouched", foe.hp, 10)
	# SP 2 소모.
	check_eq("sp spent", actor.sp, 3)


# 치명 100%: 피해 10 → 17 이고 critical 이 true 로 나간다.
func _test_critical_hit() -> void:
	# 원거리 100% 카드.
	var card: CardData = Fixtures.damage_card(&"crit", CardData.AttackType.RANGED, 100)
	# 적 체력 30.
	var state: BattleState = _state([card], 5, 30)
	# 아군·적.
	var actor: Unit = state.units[0]
	var foe: Unit = state.units[1]
	# 치명 100%.
	actor.data.crit_chance = 100
	state.initiative = [actor, foe]
	state.turn_index = 0
	actor.hand = [card]
	# 신호 기록.
	var got: Array = []
	state.unit_damaged.connect(func(_u: Unit, amount: int, critical: bool) -> void: got.append([amount, critical]))
	# 사용.
	state.play_card(0, foe)
	# 17, true.
	check_eq("critical damage", got, [[17, true]])
```

  `_state(cards, ally_sp, enemy_hp)` 가 만든 아군 데이터가 테스트마다 새로 만들어지는지 확인한다 (`actor.data.crit_chance = 100` 이 다른 테스트로 새면 안 된다). 공유된다면 `actor.data = actor.data.duplicate()` 를 먼저 한다.

  - 다른 테스트 파일: `play_card(0, foe.team, foe.cell)` → `play_card(0, foe)` (`test_battle_root.gd` 120·212행, `test_battle_playback.gd` 212·512행). 이 파일들과 `test_battle_hud.gd`, `test_hand_view.gd` 에서 `card.damage = N` / `card.attack_range = R` 로 카드를 만드는 부분은 `card.effects = [Fixtures.effect(CardEffect.Kind.DAMAGE, N * 10)]` 로 바꾸고 `attack_range` 줄은 지운다 (원거리면 `card.attack_type = CardData.AttackType.RANGED`). `test_battle_signals.gd`·`test_event_recorder.gd` 의 `unit_damaged` 연결 람다는 인자 3개 `(u, amount, critical)` 를 받게 바꾸고, `card_played` 람다는 `(actor, card, anchor)` 로 바꾼다.
  - `tests/test_event_recorder.gd` 에 추가:

```gdscript
# 치명타 피해는 DAMAGED 기록의 critical 이 true.
func _test_damage_records_critical() -> void:
	# 상태 (이 파일의 _state 헬퍼 사용: 카드 피해 5, 적 1명).
	var state: BattleState = _state(5, 1)
	# 기록기.
	var recorder := BattleEventRecorder.new(state)
	# 피해를 직접 적용한다 (치명).
	state.apply_damage(state.units[1], 3, true)
	# 마지막 기록.
	var events: Array[BattleEvent] = recorder.take_events()
	# DAMAGED + critical.
	check("damaged critical recorded", events[0].kind == BattleEvent.Kind.DAMAGED and events[0].critical)
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `play_card` 인자 수 오류 등.

- [ ] **Step 3: 구현**

`battle_state.gd`:
  - 신호 교체:

```gdscript
## 유닛이 공격을 받았다. amount 는 방어도로 막기 전의 공격 피해량, critical 은 치명타였는지.
signal unit_damaged(unit: Unit, amount: int, critical: bool)
```

```gdscript
## 카드가 쓰였다. anchor 는 카드의 기준 유닛 (근접·자신은 자동으로 정해진 유닛). 실제로 맞는 유닛은
## resolver.units_in_area(anchor, card.area_offsets(), units) 로 다시 계산한다.
signal card_played(actor: Unit, card: CardData, anchor: Unit)
```

  - `var ai_rng` 아래에:

```gdscript
## 치명타 판정 전용 난수 생성기. 덱 섞기와 섞으면 같은 시드의 드로우 순서가 바뀌므로 따로 둔다.
var crit_rng: RandomNumberGenerator
```

  - `_init` 의 `ai_rng.seed = ...` 다음에:

```gdscript
	# 치명 판정 전용 난수 생성기를 만든다.
	crit_rng = RandomNumberGenerator.new()
	# 전투 시드에서 따로 뽑은 시드 (전투 시드가 같으면 치명 결과도 같다).
	crit_rng.seed = hash([p_rng.seed, "crit"])
```

  - `apply_damage` 를 `func apply_damage(target: Unit, amount: int, critical: bool = false) -> void:` 로 바꾸고 `unit_damaged.emit(target, amount, critical)`.
  - `play_card` 전체 교체:

```gdscript
## 지금 차례인 아군이 손패의 hand_index 번째 카드를 anchor 를 기준으로 쓴다.
## anchor 는 resolver.valid_anchors 가 돌려준 후보 중 하나여야 한다 (근접·자신은 그 한 명).
## 규칙에 맞지 않으면 아무것도 바꾸지 않고 false 를 돌려준다. 성공하면 true.
func play_card(hand_index: int, anchor: Unit) -> bool:
	# 끝난 전투에서는 카드를 쓸 수 없다.
	if finished:
		return false
	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 차례인 유닛이 없거나, 적이거나, 쓰러졌으면 카드를 쓸 수 없다.
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	# 손패 번호가 범위를 벗어나면 실패.
	if hand_index < 0 or hand_index >= actor.hand.size():
		return false
	# 쓸 카드를 손패에서 찾는다 (아직 빼지는 않음).
	var card: CardData = actor.hand[hand_index]
	# SP 가 모자라면 실패.
	if card.sp_cost > actor.sp:
		return false
	# 기준 유닛이 없거나 이 카드의 후보가 아니면 실패.
	if anchor == null or not resolver.valid_anchors(actor, card, units).has(anchor):
		return false

	# 여기부터는 검사를 모두 통과했으므로 상태를 바꾼다.
	# SP 를 비용만큼 쓴다.
	actor.sp -= card.sp_cost
	# 손패에서 카드를 뺀다.
	actor.hand.remove_at(hand_index)
	# 쓴 카드는 묘지로 간다.
	actor.discard.append(card)
	# 카드 사용 신호를 낸다 (효과 신호보다 먼저 나가야 화면이 돌진 → 피격 순으로 연출한다).
	card_played.emit(actor, card, anchor)
	# 로그에 "사용자 → 기준 유닛 (카드)" 형식으로 남긴다.
	write_log("%s → %s (%s)" % [actor.data.display_name, anchor.data.display_name, card.display_name])
	# 효과를 적용한다.
	resolve_card(actor, card, anchor)
	# 이번 카드로 전투가 끝났는지 확인한다.
	check_end()
	# 성공.
	return true


## 카드 효과를 순서대로 적용한다. 아군 카드(play_card)와 적 행동(EnemyBrain)이 함께 쓴다.
## AREA 효과의 대상은 효과마다 다시 계산하므로 앞 효과로 쓰러진 유닛은 뒤 효과에서 빠진다.
func resolve_card(actor: Unit, card: CardData, anchor: Unit) -> void:
	# 사용자의 스탯.
	var stats: UnitData = actor.data
	# 효과마다.
	for effect in card.effects:
		# 수치.
		var amount: int = CardMath.amount(effect, stats)
		# 0 이면 적용하지 않는다.
		if amount <= 0:
			continue
		# 대상 목록: 자신이면 사용자, 아니면 기준 유닛의 범위.
		var targets: Array[Unit] = []
		if effect.target == CardEffect.Target.SELF:
			targets.append(actor)
		else:
			targets = resolver.units_in_area(anchor, card.area_offsets(), units)
		# 대상마다 종류에 맞게 적용한다.
		for target in targets:
			match effect.kind:
				# 피해: 맞는 유닛마다 치명 판정.
				CardEffect.Kind.DAMAGE:
					var critical: bool = CardMath.rolls_crit(stats, crit_rng)
					apply_damage(target, CardMath.critical_amount(amount, stats) if critical else amount, critical)
				# 방어도.
				CardEffect.Kind.BLOCK:
					apply_block(target, amount)
				# 회복.
				CardEffect.Kind.HEAL:
					apply_heal(target, amount)
```

  - `_describe_cell` 은 더 이상 쓰이지 않으면 지운다.

`battle_event.gd` — `cell` 필드 아래에:

```gdscript
## 치명타 피해였는지 (DAMAGED).
var critical: bool = false
```

`battle_event_recorder.gd`:
  - `_on_card_played(actor: Unit, card: CardData, anchor: Unit)` 로 바꾸고 `event.target = anchor`, `event.target_team = anchor.team`, `event.target_cell = anchor.cell` 로 채운다. `_living_unit_at` 은 지운다.
  - `_on_unit_damaged(unit: Unit, amount: int, critical: bool)` 로 바꾸고 `event.critical = critical`.

`battle_root.gd` `_on_cell_clicked` — `is_valid_cell` 검사와 `play_card` 호출을 기준 유닛 방식으로 바꾼다 (화면 흐름 전체 개편은 Task 11):

```gdscript
	# 그 칸에 서 있는 살아 있는 유닛 (카드의 기준 유닛 후보).
	var anchor: Unit = _living_unit_at(team, cell)
	# 기준 후보가 아니면 쓸 수 없다.
	if anchor == null or not _state.resolver.valid_anchors(actor, card, _state.units).has(anchor):
		# 로그로 알린다.
		_hud.append_log("사용할 수 없는 대상")
		# 드래그였다면 선택을 푼다.
		if from_drop:
			_clear_selection()
		return
```

  그리고 `_state.play_card(card_index, team, cell)` → `_state.play_card(card_index, anchor)`. 같은 파일에 헬퍼 추가:

```gdscript
## 그 편의 그 칸에 살아 있는 유닛 (없으면 null).
func _living_unit_at(team: Unit.Team, cell: Vector2i) -> Unit:
	# 모든 유닛 중.
	for unit in _state.units:
		# 같은 편·같은 칸·생존.
		if unit.team == team and unit.cell == cell and unit.is_alive():
			return unit
	# 없음.
	return null
```

  `team != Unit.Team.ENEMY` 로 거르던 조건은 지운다 (아군 카드가 아군 칸을 겨냥할 수 있다).

`battle_playback.gd` `_damaged` — 로그와 숫자에 치명 표시:

```gdscript
	# 로그 (치명이면 표시).
	hud.append_log("%s 에게 %d 피해%s" % [event.unit.data.display_name, event.amount, " (치명)" if event.critical else ""])
```

```gdscript
	# 피해 숫자 (처치는 더 크게, 치명이면 앞에 표시).
	view.pop_text("%s-%d" % ["치명! " if event.critical else "", event.amount], DAMAGE_COLOR, UnitView.KILL_POP_PUNCH if event.hp <= 0 else UnitView.DAMAGE_POP_PUNCH)
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과. 치명 1% 때문에 기존 테스트의 피해 값이 다르게 나오면 그 테스트의 아군 데이터에 `crit_chance = 0` 을 넣는다 (규칙을 고치지 않는다).

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/battle_state.gd Scripts/view/battle_event.gd Scripts/view/battle_event_recorder.gd Scripts/view/battle_root.gd Scripts/view/battle_playback.gd tests/
git commit -m "feat: play cards against an anchor unit and apply effects with crits"
```

---

### Task 5: 적 행동 카드화 (EnemyData · EnemyBrain)

**Files:**
- Modify: `Scripts/combat/data/enemy_data.gd`, `Scripts/combat/enemy_brain.gd`, `Scripts/view/battle_playback.gd` (`_enemy_acted`)
- Test: `tests/test_enemy_brain.gd`, `tests/test_battle_signals.gd`, `tests/test_event_recorder.gd`, 그리고 `EnemyDataScript.new()` 로 적을 만드는 나머지 테스트

**Interfaces:**
- Consumes: Task 4 `resolve_card`, Task 3 `valid_anchors`
- Produces: `EnemyData.attack_card: CardData`, `defend_card: CardData`, `rest_card: CardData` (모두 null 가능), `EnemyBrain.Action.WAIT` (enum 맨 뒤), `tests/fixtures.gd` 에 `enemy_cards(enemy: EnemyData, attack: CardData, block_percent: int, heal_percent: int) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/fixtures.gd` 끝에:

```gdscript
# 적 데이터에 공격 카드와 자신 방어도·자신 회복 카드를 단다 (% 가 0 이하면 그 카드는 비워 둔다).
static func enemy_cards(enemy: EnemyData, attack: CardData, block_percent: int, heal_percent: int) -> void:
	# 공격 카드.
	enemy.attack_card = attack
	# 방어 카드.
	enemy.defend_card = null if block_percent <= 0 else card(&"defend", CardData.AttackType.SELF, [effect(CardEffect.Kind.BLOCK, block_percent, CardEffect.Target.SELF)])
	# 휴식 카드.
	enemy.rest_card = null if heal_percent <= 0 else card(&"rest", CardData.AttackType.SELF, [effect(CardEffect.Kind.HEAL, heal_percent, CardEffect.Target.SELF)])
```

`tests/test_enemy_brain.gd`:
  - `_enemy(attack_range, damage, block_amount, rest_heal)` 헬퍼를 `_enemy(attack_type: int, damage: int, block_amount: int, rest_heal: int) -> EnemyData` 로 바꾸고, 안에서 `Fixtures.enemy_cards(data, Fixtures.damage_card(&"enemy_attack", attack_type, damage * 10), block_amount * 10, rest_heal * 10)` 를 부른다 (적 공격·방어 기본 10 → 같은 수치). 적의 `crit_chance = 0`.
  - 사거리 관련 테스트 교체: `_test_defends_when_no_target_in_range` → `_test_defends_when_melee_row_is_empty` (근접 적과 같은 행에 아군이 없으면 방어), `_test_attack_respects_melee_blocking` → `_test_melee_attacks_front_of_row` (같은 행에 아군 둘이면 앞 열 아군을 친다).
  - 새 테스트:

```gdscript
# 카드가 하나도 없는 적은 대기하고, 차례가 정상적으로 넘어간다.
func _test_enemy_without_cards_waits() -> void:
	# 카드 없는 적.
	var enemy: EnemyData = EnemyDataScript.new()
	enemy.max_hp = 20
	enemy.speed = 99
	# 아군 하나.
	var state: BattleState = _state([_ally(&"a", 10)], enemy)
	# 행동 결정.
	check_eq("no cards → wait", EnemyBrain.decide(state, state.units[1]), EnemyBrain.Action.WAIT)
	# 실제 차례: 오류 없이 대기 로그.
	var logs: Array[String] = []
	state.log_message.connect(func(text: String) -> void: logs.append(text))
	EnemyBrain.take_turn(state, state.units[1])
	check("wait logged", logs.has("%s 대기" % enemy.display_name))


# 방어 카드가 없고 칠 대상도 없으면 대기 (방어로 빠지지 않는다).
func _test_no_target_and_no_defend_waits() -> void:
	# 근접 공격만 있는 적.
	var enemy: EnemyData = _enemy(CardData.AttackType.MELEE, 5, 0, 0)
	# 아군은 다른 행 (적 (0,1), 아군 (0,0)).
	var state: BattleState = _state([_ally(&"a", 10)], enemy)
	# 아군 칸을 다른 행으로 옮긴다.
	state.units[0].cell = Vector2i(0, 0)
	# 대기.
	check_eq("no target, no defend → wait", EnemyBrain.decide(state, state.units[1]), EnemyBrain.Action.WAIT)
```

  (`_state` 헬퍼가 아군을 어느 칸에 놓는지 확인하고, 적과 같은 행이 되지 않도록 칸을 맞춘다.)
  - `test_battle_signals.gd`·`test_event_recorder.gd` 의 `_enemy(...)` 헬퍼도 같은 방식으로 `Fixtures.enemy_cards` 를 쓰게 바꾼다.
  - `EnemyDataScript.new()` 만 하고 카드를 달지 않는 다른 테스트(`test_turn_order`, `test_movement`, `test_turn_phases`, `test_card_zone_signals`, `test_unit`, `test_unit_view`, `test_board_3d`, `test_battle_hud`, `test_battle_root`, `test_battle_playback`, `test_encounter_generator`) 는 그대로 두고 Step 4 에서 실패하는 것만 고친다: 적이 공격해야 성립하는 테스트면 `Fixtures.enemy_cards(enemy, Fixtures.damage_card(&"enemy_attack", CardData.AttackType.MELEE, 50), 50, 40)` 를 넣는다 (옛 기본값 피해 5·방어 5·회복 4 와 같다).

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `attack_card`·`WAIT` 없음 오류.

- [ ] **Step 3: 구현**

`enemy_data.gd` — 옛 필드는 Task 12 까지 남기고, 그 아래에 추가:

```gdscript
## 공격 행동에 쓰는 카드 (근접·원거리·범위·% 계수를 아군 카드와 같은 규칙으로 적용). 비어 있으면 공격하지 않는다.
@export var attack_card: CardData
## 방어 행동에 쓰는 카드 (보통 자신 방어도). 비어 있으면 방어하지 않는다.
@export var defend_card: CardData
## 휴식 행동에 쓰는 카드 (보통 자신 회복). 비어 있으면 휴식하지 않는다.
@export var rest_card: CardData
```

`enemy_brain.gd`:
  - `enum Action { ATTACK, DEFEND, REST, MOVE, WAIT }` (주석에 `WAIT 할 행동이 없어 차례를 넘김` 추가).
  - `decide` 의 휴식·방어·공격 부분 교체:

```gdscript
	# 체력이 문턱 이하이고 휴식 카드가 있으면 휴식한다.
	if hp_ratio <= REST_THRESHOLD and data.rest_card != null:
		return Action.REST
	# 칠 수 있는 대상이 없으면 방어한다 (방어 카드도 없으면 대기).
	if find_target(state, actor) == null:
		return Action.DEFEND if data.defend_card != null else Action.WAIT
	# 그 외에는 공격한다.
	return Action.ATTACK
```

  - `_random_fallback` 교체:

```gdscript
## 이동하려 했지만 막혔을 때: 쓸 수 있는 행동(공격은 대상이 있을 때만, 방어·휴식은 카드가 있을 때만) 중 하나를 고른다. 없으면 대기.
static func _random_fallback(state: BattleState, actor: Unit) -> Action:
	# 적 데이터.
	var data: EnemyData = actor.data as EnemyData
	# 후보 행동 목록.
	var choices: Array[Action] = []
	# 칠 대상이 있을 때만 공격.
	if find_target(state, actor) != null:
		choices.append(Action.ATTACK)
	# 방어 카드가 있을 때만 방어.
	if data.defend_card != null:
		choices.append(Action.DEFEND)
	# 휴식 카드가 있을 때만 휴식.
	if data.rest_card != null:
		choices.append(Action.REST)
	# 아무것도 없으면 대기.
	if choices.is_empty():
		return Action.WAIT
	# 하나를 무작위로 고른다.
	return choices[state.ai_rng.randi_range(0, choices.size() - 1)]
```

  - `find_target` 교체:

```gdscript
## 이 적의 공격 카드로 칠 수 있는 대상 중 가장 좋은 대상. 공격 카드가 없거나 후보가 없으면 null.
## 기준: 체력이 가장 낮은 유닛, 같으면 unit_id 가 작은 유닛 (결과가 항상 같게).
static func find_target(state: BattleState, actor: Unit) -> Unit:
	# 적 데이터.
	var data: EnemyData = actor.data as EnemyData
	# 공격 카드가 없으면 대상도 없다.
	if data.attack_card == null:
		return null
	# 지금까지 찾은 가장 좋은 대상.
	var best: Unit = null
	# 카드의 기준 후보마다.
	for candidate in state.resolver.valid_anchors(actor, data.attack_card, state.units):
		# 첫 후보이거나, 체력이 더 낮거나, 같으면 번호가 작으면 바꾼다.
		if best == null or candidate.hp < best.hp or (candidate.hp == best.hp and candidate.unit_id < best.unit_id):
			best = candidate
	# 찾은 대상 (없으면 null).
	return best
```

  - `take_turn` 의 `match` 에서 REST·DEFEND·ATTACK 분기 교체, WAIT 추가:

```gdscript
		# 휴식: 휴식 카드를 자신에게 쓴다.
		Action.REST:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.REST, null)
			# 카드 효과를 적용한다 (unit_healed 신호가 나간다).
			state.resolve_card(actor, data.rest_card, actor)
			# 로그.
			state.write_log("%s 휴식" % data.display_name)
		# 방어: 방어 카드를 자신에게 쓴다.
		Action.DEFEND:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.DEFEND, null)
			# 카드 효과를 적용한다 (block_gained 신호가 나간다).
			state.resolve_card(actor, data.defend_card, actor)
			# 로그.
			state.write_log("%s 방어" % data.display_name)
		# 공격: 대상을 기준으로 공격 카드를 쓴다.
		Action.ATTACK:
			# 대상을 다시 구한다.
			var target: Unit = find_target(state, actor)
			# 대상이 없으면 아무것도 하지 않는다 (안전장치).
			if target == null:
				return
			# 누구를 공격하는지 알린다 (돌진 연출용).
			state.report_enemy_action(actor, Action.ATTACK, target)
			# 로그.
			state.write_log("%s → %s 공격" % [data.display_name, target.data.display_name])
			# 카드 효과를 적용한다.
			state.resolve_card(actor, data.attack_card, target)
		# 대기: 할 행동이 없다.
		Action.WAIT:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.WAIT, null)
			# 로그.
			state.write_log("%s 대기" % data.display_name)
```

`battle_playback.gd` `_enemy_acted`:
  - 첫 줄 조건을 `if instant or event.action == EnemyBrain.Action.MOVE or event.action == EnemyBrain.Action.WAIT:` 로.
  - 공격 타입: `(event.unit.data as EnemyData).attack_card.attack_type`.

- [ ] **Step 4: 통과 확인** — 테스트 실행. 실패하는 테스트는 Step 1 마지막 항목 규칙대로 적 카드를 달아 고친다. Expected: 전체 통과. (게임 데이터 `.tres` 의 적은 아직 카드가 없어 실제 게임에선 대기만 한다 — Task 6 에서 채운다.)

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/data/enemy_data.gd Scripts/combat/enemy_brain.gd Scripts/view/battle_playback.gd tests/
git commit -m "feat: drive enemy actions with cards and wait when none apply"
```

---

### Task 6: 카드·적 리소스 이전

**Files:**
- Create (일회용, 커밋하지 않음): `tools/migrate_cards_2026_10_11.gd`
- Modify: `Resources/cards/{strike,cleave,skewer,shoot,piercing_shot,volley,blast}.tres`, `Resources/units/{brute,sentry,stalker}.tres`
- Create: `Resources/cards/enemy/{brute,sentry,stalker}_{attack,defend,rest}.tres` (9개)
- Test: `tests/test_data.gd`

**Interfaces:**
- Consumes: Task 2 필드, Task 5 `EnemyData.*_card`

이전 표 (공격 10 기준으로 옛 피해 유지):

| 카드 | 종류 | area | 효과 |
|---|---|---|---|
| strike 베기 | MELEE | `[]` | 피해 60% |
| cleave 횡베기 | MELEE | `(0,-1),(0,0),(0,1)` | 피해 40% |
| skewer 꿰뚫기 | MELEE | `(0,0),(1,0),(2,0)` | 피해 40% |
| shoot 사격 | RANGED | `[]` | 피해 40% |
| piercing_shot 관통사격 | RANGED | `(-2,0),(-1,0),(0,0),(1,0),(2,0)` | 피해 50% |
| volley 일제사격 | RANGED | `(0,-2),(0,-1),(0,0),(0,1),(0,2)` | 피해 30% |
| blast 폭발탄 | RANGED | `(0,0),(1,0),(0,1),(1,1)` | 피해 30% |

| 적 | 공격 카드 | 방어 카드 | 휴식 카드 |
|---|---|---|---|
| brute | MELEE `[]` 피해 70% | 자신 방어도 60% | 자신 회복 50% |
| sentry | RANGED `(0,-2)…(0,2)` 피해 50% | 자신 방어도 80% | 자신 회복 30% |
| stalker | RANGED `(-2,0)…(2,0)` 피해 40% | 자신 방어도 40% | 자신 회복 40% |

모든 카드 `category = ATTACK`, 적 방어·휴식 카드는 `attack_type = SELF`, `category = SKILL`. 적 카드 이름: `"<적 이름> 공격"`, `"방어"`, `"휴식"`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_data.gd` 의 `_test_starter_cards_exist()` 를 새 필드 기준으로 바꾼다 (옛 `damage`/`shape`/`attack_range` 검사를 지운다):

```gdscript
	# 베기: 근접, 피해 60%.
	check_eq("strike is melee", strike.attack_type, CardData.AttackType.MELEE)
	check_eq("strike damage percent", strike.effects[0].percent, 60)
	# 일제사격: 세로 5칸.
	check_eq("volley area", volley.area, [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	# 폭발탄: 2×2.
	check_eq("blast area", blast.area, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	# 꿰뚫기: 기준 적 뒤로 3칸.
	check_eq("skewer area", skewer.area, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
```

새 테스트 추가 (`run()` 에 호출):

```gdscript
# 적 3종이 공격·방어·휴식 카드를 모두 가진다.
func _test_enemies_have_cards() -> void:
	# 적마다.
	for id in ["brute", "sentry", "stalker"]:
		# 데이터.
		var enemy: EnemyData = load("res://Resources/units/%s.tres" % id)
		# 세 카드.
		check("%s has attack/defend/rest cards" % id, enemy.attack_card != null and enemy.defend_card != null and enemy.rest_card != null)
	# 괴한 공격은 근접 70%.
	var brute: EnemyData = load("res://Resources/units/brute.tres")
	check_eq("brute attack percent", brute.attack_card.effects[0].percent, 70)
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `strike damage percent` 등 FAIL.

- [ ] **Step 3: 이전 스크립트 작성·실행** — `tools/migrate_cards_2026_10_11.gd`:

```gdscript
# 일회용: 카드·적 리소스를 새 형식(효과·오프셋 범위·적 행동 카드)으로 옮긴다. 실행 후 지운다.
extends SceneTree

# 카드 id → [공격 종류, 범위, 피해 %].
const CARDS: Dictionary = {
	"strike": [0, [], 60],
	"cleave": [0, [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)], 40],
	"skewer": [0, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 40],
	"shoot": [1, [], 40],
	"piercing_shot": [1, [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 50],
	"volley": [1, [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], 30],
	"blast": [1, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 30],
}
# 적 id → [공격 종류, 공격 범위, 공격 %, 방어 %, 회복 %].
const ENEMIES: Dictionary = {
	"brute": [0, [], 70, 60, 50],
	"sentry": [1, [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], 50, 80, 30],
	"stalker": [1, [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 40, 40, 40],
}


# 진입점.
func _initialize() -> void:
	# 실패 여부.
	var ok: bool = true
	# 아군 카드: 기존 파일을 불러와 새 필드를 채우고 같은 경로에 저장한다 (uid 유지).
	for id in CARDS:
		var spec: Array = CARDS[id]
		var card: CardData = load("res://Resources/cards/%s.tres" % id)
		card.attack_type = spec[0]
		card.category = CardData.Category.ATTACK
		card.area = _area(spec[1])
		card.effects = [_effect(CardEffect.Kind.DAMAGE, spec[2], CardEffect.Target.AREA)]
		ok = _save(card, card.resource_path) and ok
	# 적 카드 폴더.
	DirAccess.make_dir_recursive_absolute("res://Resources/cards/enemy")
	# 적마다 세 카드를 새로 만들어 저장하고 적 데이터에 단다.
	for id in ENEMIES:
		var spec: Array = ENEMIES[id]
		var enemy: EnemyData = load("res://Resources/units/%s.tres" % id)
		var attack := _card(&"%s_attack" % id, "%s 공격" % enemy.display_name, spec[0], CardData.Category.ATTACK, _area(spec[1]), _effect(CardEffect.Kind.DAMAGE, spec[2], CardEffect.Target.AREA))
		var defend := _card(&"%s_defend" % id, "방어", CardData.AttackType.SELF, CardData.Category.SKILL, _area([]), _effect(CardEffect.Kind.BLOCK, spec[3], CardEffect.Target.SELF))
		var rest := _card(&"%s_rest" % id, "휴식", CardData.AttackType.SELF, CardData.Category.SKILL, _area([]), _effect(CardEffect.Kind.HEAL, spec[4], CardEffect.Target.SELF))
		ok = _save(attack, "res://Resources/cards/enemy/%s_attack.tres" % id) and ok
		ok = _save(defend, "res://Resources/cards/enemy/%s_defend.tres" % id) and ok
		ok = _save(rest, "res://Resources/cards/enemy/%s_rest.tres" % id) and ok
		# 저장된 파일을 다시 불러와 연결한다 (적 .tres 가 하위 리소스가 아니라 파일 참조로 저장되게).
		enemy.attack_card = load("res://Resources/cards/enemy/%s_attack.tres" % id)
		enemy.defend_card = load("res://Resources/cards/enemy/%s_defend.tres" % id)
		enemy.rest_card = load("res://Resources/cards/enemy/%s_rest.tres" % id)
		ok = _save(enemy, enemy.resource_path) and ok
	# 결과.
	print("migration ", "ok" if ok else "FAILED")
	quit(0 if ok else 1)


# 일반 배열을 타입 있는 Vector2i 배열로.
func _area(source: Array) -> Array[Vector2i]:
	var area: Array[Vector2i] = []
	for offset in source:
		area.append(offset)
	return area


# 효과 하나.
func _effect(kind: CardEffect.Kind, percent: int, target: CardEffect.Target) -> CardEffect:
	var effect := CardEffect.new()
	effect.kind = kind
	effect.percent = percent
	effect.target = target
	return effect


# 새 카드.
func _card(id: StringName, display_name: String, attack_type: int, category: CardData.Category, area: Array[Vector2i], effect: CardEffect) -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = display_name
	card.attack_type = attack_type
	card.category = category
	card.area = area
	var effects: Array[CardEffect] = [effect]
	card.effects = effects
	return card


# 저장 (실패면 false).
func _save(resource: Resource, path: String) -> bool:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("save failed %s: %s" % [path, error])
	return error == OK
```

실행:

```powershell
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tools/migrate_cards_2026_10_11.gd
```

Expected: `migration ok`. `git diff Resources/` 로 카드 `.tres` 의 `uid` 가 그대로이고 `effects`·`area` 가 들어갔는지, 적 `.tres` 에 `attack_card`·`defend_card`·`rest_card` ExtResource 가 들어갔는지 확인한다. 그 뒤 `tools/migrate_cards_2026_10_11.gd` 를 지운다 (`.uid` 파일이 생겼으면 함께).

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Resources/cards Resources/units/brute.tres Resources/units/sentry.tres Resources/units/stalker.tres tests/test_data.gd
git commit -m "feat: migrate starter cards and enemies to effect-based cards"
```

---

### Task 7: CardText 효과 문구

**Files:**
- Create: `Scripts/ui/cards/card_text.gd`, `tests/test_card_text.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `CardMath.amount` (Task 2)
- Produces: `CardText.describe(card: CardData, stats: UnitData = null) -> String`, `CardText.badge(attack_type: CardData.AttackType) -> String`

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_card_text.gd` (그리고 `run_tests.gd` 의 `test_card_view.gd` 앞에 추가):

```gdscript
# CardText: % 표기, 계산값 표기, 자신 접두어, 배지 글자.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# % 표기.
	_test_percent_text()
	# 계산값 표기.
	_test_computed_text()
	# 자신 카드는 "자신" 을 붙이지 않는다.
	_test_self_card_has_no_prefix()
	# 배지.
	_test_badges()
	# 결과를 돌려준다.
	return results()


# 피해 80% + 자신 방어도 50% 카드.
func _combo() -> CardData:
	# 효과 목록.
	var effects: Array[CardEffect] = [
		Fixtures.effect(CardEffect.Kind.DAMAGE, 80),
		Fixtures.effect(CardEffect.Kind.BLOCK, 50, CardEffect.Target.SELF),
	]
	# 근접 카드.
	return Fixtures.card(&"combo", CardData.AttackType.MELEE, effects)


# 스탯 없이 부르면 % 로.
func _test_percent_text() -> void:
	# 문구.
	check_eq("percent text", CardText.describe(_combo()), "피해 80% · 자신 방어도 50%")


# 공격 9·방어 8 이면 피해 7, 방어도 4.
func _test_computed_text() -> void:
	# 스탯.
	var stats: AllyData = AllyDataScript.new()
	stats.attack = 9
	stats.defense = 8
	# 문구.
	check_eq("computed text", CardText.describe(_combo(), stats), "피해 7 · 자신 방어도 4")


# 자신 카드의 SELF 효과에는 접두어가 없다.
func _test_self_card_has_no_prefix() -> void:
	# 자신 회복 카드.
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.HEAL, 30, CardEffect.Target.SELF)]
	var card: CardData = Fixtures.card(&"rest", CardData.AttackType.SELF, effects)
	# 문구.
	check_eq("self card text", CardText.describe(card), "회복 30%")


# 공격 종류 배지.
func _test_badges() -> void:
	# 네 종류.
	check_eq("badges", [CardText.badge(CardData.AttackType.MELEE), CardText.badge(CardData.AttackType.RANGED), CardText.badge(CardData.AttackType.ALLY), CardText.badge(CardData.AttackType.SELF)], ["근", "원", "아", "자"])
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `CardText` 없음.

- [ ] **Step 3: 구현** — `Scripts/ui/cards/card_text.gd`:

```gdscript
## 카드 효과 문구와 공격 종류 배지 글자를 만드는 순수 함수 모음.
## 전투 카드(계산값)와 파티 화면 덱 목록(%)이 같은 함수를 쓴다.
class_name CardText
# RefCounted: 모든 함수가 static 이다.
extends RefCounted

## 효과 종류 → 이름.
const KIND_NAMES: Dictionary = {
	CardEffect.Kind.DAMAGE: "피해",
	CardEffect.Kind.BLOCK: "방어도",
	CardEffect.Kind.HEAL: "회복",
}
## 공격 종류 → 배지 글자.
const BADGES: Dictionary = {
	CardData.AttackType.MELEE: "근",
	CardData.AttackType.RANGED: "원",
	CardData.AttackType.ALLY: "아",
	CardData.AttackType.SELF: "자",
}


## 효과 문구. stats 가 있으면 계산된 수치(치명 미적용), 없으면 % 로 쓴다. 예: "피해 7 · 자신 방어도 4".
static func describe(card: CardData, stats: UnitData = null) -> String:
	# 효과별 조각.
	var parts: PackedStringArray = []
	# 효과마다.
	for effect in card.effects:
		# 수치 글자.
		var value: String = ("%d" % CardMath.amount(effect, stats)) if stats != null else ("%d%%" % effect.percent)
		# 자신 효과인데 카드가 자신 카드가 아니면 "자신 " 을 붙인다.
		var prefix: String = "자신 " if effect.target == CardEffect.Target.SELF and card.attack_type != CardData.AttackType.SELF else ""
		# 조각을 만든다.
		parts.append("%s%s %s" % [prefix, KIND_NAMES[effect.kind], value])
	# 가운뎃점으로 잇는다.
	return " · ".join(parts)


## 공격 종류 배지 글자 (근·원·아·자).
static func badge(attack_type: CardData.AttackType) -> String:
	# 사전에서 꺼낸다.
	return BADGES[attack_type]
```

- [ ] **Step 4: 통과 확인** — 캐시 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/ui/cards/card_text.gd tests/test_card_text.gd tests/run_tests.gd
git commit -m "feat: add card effect text helper"
```

---

### Task 8: 파티 — 공격 스탯 보너스와 스탯·덱 표시

**Files:**
- Modify: `Scripts/party/party_state.gd` (`stats`, `build_battle_roster`, `_boosted_deck` 삭제), `Scripts/ui/party_view.gd` (스탯 줄, `_deck_summary`)
- Test: `tests/test_party_state.gd`, `tests/test_party_view.gd`

**Interfaces:**
- Consumes: `UnitData` 새 스탯 (Task 1), `CardText.describe` (Task 7)
- Produces: `PartyState.stats(index) -> Dictionary` 키 `max_hp, speed, max_sp, attack, defense, crit_chance, crit_damage, aggro` (`attack_bonus` 키 삭제). `build_battle_roster()` 는 복사본의 `attack` 에 보너스를 굽고 덱은 원본 카드를 그대로 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**
  - `tests/test_party_state.gd`: 240행 `stats["attack_bonus"]` 검사를 `check_eq("attack bonus adds to attack", stats["attack"], <기본 공격> + 3)` 로 바꾼다 (그 테스트의 아군 공격이 기본 10 이면 13). 296~354행 `_boosted_deck` 관련 테스트 두 개를 아래 하나로 교체한다:

```gdscript
# 공격 보너스는 전투 복사본의 공격 스탯에 들어가고, 덱 카드는 원본 그대로다.
func _test_roster_bakes_attack_into_stats() -> void:
	# 파티 (이 파일의 파티 생성 헬퍼 사용) 와 공격 +2 아이템을 첫 파티원에게 낀다.
	var party: PartyState = _party()
	var item: ItemData = _item(&"knife", ItemData.Slot.WEAPON, 0, 0, 0, 2)
	party.inventory.append(item)
	party.equip(0, item)
	# 전투 배치.
	var roster: Array[UnitPlacement] = party.build_battle_roster()
	# 원본.
	var base: AllyData = party.member_data(0)
	# 공격 +2.
	check_eq("roster attack includes bonus", (roster[0].unit_data as AllyData).attack, base.attack + 2)
	# 덱 카드는 같은 리소스.
	check("deck cards are the originals", (roster[0].unit_data as AllyData).deck == base.deck)
	# 원본 공격은 그대로.
	check_eq("base attack unchanged", party.member_data(0).attack, base.attack)
```

  (`_party()`·`_item(...)`·`equip` 의 실제 이름·인자 순서는 이 파일 위쪽 헬퍼에 맞춘다.)
  - `tests/test_party_view.gd`: 스탯 글자를 검사하는 테스트에 `check("stats show attack", view.stats_text().contains("공격  10"))`, `check("stats show crit", view.stats_text().contains("치명확률  1%"))`, `check("stats show aggro", view.stats_text().contains("어그로  100"))` 를 추가하고, 덱 글자 테스트에 `check("deck shows percent", view.deck_text().contains("— 피해 60%"))` 를 추가한다 (선봉 덱에 베기(피해 60%)가 있다 — 장수는 `vanguard.tres` 에서 확인해 원하면 `"베기 ×N — 피해 60%"` 로 좁힌다).

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: FAIL.

- [ ] **Step 3: 구현**
  - `party_state.gd` `stats()`:

```gdscript
## 장비 보너스를 더한 최종 능력치. {max_hp, speed, max_sp, attack, defense, crit_chance, crit_damage, aggro}.
## 체력·속도·SP 는 최소 1, 공격은 최소 0.
func stats(index: int) -> Dictionary:
	# 원본 데이터에서 시작한다.
	var data: AllyData = member_data(index)
	# 최대 체력.
	var max_hp: int = data.max_hp
	# 속도.
	var speed: int = data.speed
	# 최대 SP.
	var max_sp: int = data.max_sp
	# 공격.
	var attack: int = data.attack
	# 낀 아이템마다 보너스를 더한다.
	for item in (_equipment[index] as Dictionary).values():
		# 아이템 타입으로 꺼낸다.
		var equipment: ItemData = item
		# 체력 보너스.
		max_hp += equipment.max_hp_bonus
		# 속도 보너스.
		speed += equipment.speed_bonus
		# SP 보너스.
		max_sp += equipment.max_sp_bonus
		# 공격 보너스.
		attack += equipment.attack_bonus
	# 장비 보너스가 없는 스탯은 원본 그대로 넣는다.
	return {
		"max_hp": maxi(max_hp, 1),
		"speed": maxi(speed, 1),
		"max_sp": maxi(max_sp, 1),
		"attack": maxi(attack, 0),
		"defense": data.defense,
		"crit_chance": data.crit_chance,
		"crit_damage": data.crit_damage,
		"aggro": data.aggro,
	}
```

  - `build_battle_roster()`: `ally.deck = _boosted_deck(...)` 두 줄을 `# 최종 공격을 넣는다 (카드 피해는 공격 × % 로 계산된다).` / `ally.attack = final_stats["attack"]` 로 교체. `_boosted_deck` 함수 삭제.
  - `party_view.gd` 스탯 줄 (453~468행 부근): `lines` 배열을

```gdscript
		_stat_line("체력", final_stats["max_hp"], data.max_hp),
		_stat_line("속도", final_stats["speed"], data.speed),
		_stat_line("SP", final_stats["max_sp"], data.max_sp),
		_stat_line("공격", final_stats["attack"], data.attack),
		_stat_line("방어", final_stats["defense"], data.defense),
		"치명확률  %d%%" % final_stats["crit_chance"],
		"치명피해  %d%%" % final_stats["crit_damage"],
		_stat_line("어그로", final_stats["aggro"], data.aggro),
```

  로 바꾸고 `attack_bonus` 를 쓰던 `if` 블록을 지운다.
  - `_deck_summary`:

```gdscript
## 덱 구성 글자. 첫 줄에 총 장수, 다음 줄부터 카드 이름별 장수와 효과(%).
func _deck_summary(data: AllyData) -> String:
	# 카드 이름 -> 장수.
	var counts: Dictionary = {}
	# 카드 이름 -> 그 카드 (효과 문구용, 처음 나온 것).
	var cards: Dictionary = {}
	# 덱의 카드마다 장수를 센다.
	for card in data.deck:
		counts[card.display_name] = int(counts.get(card.display_name, 0)) + 1
		if not cards.has(card.display_name):
			cards[card.display_name] = card
	# 첫 줄: 총 장수.
	var lines: PackedStringArray = ["덱  %d장" % data.deck.size()]
	# 카드 이름마다 한 줄씩 (덱 편집 화면이라 % 로 보여 준다).
	for card_name in counts:
		lines.append("  %s ×%d — %s" % [card_name, counts[card_name], CardText.describe(cards[card_name])])
	# 줄바꿈으로 이어 돌려준다.
	return "\n".join(lines)
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. 덱 글자 길이로 레이아웃 테스트가 깨지면 `_deck_label` 폰트 크기를 14 로 줄인다. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/party/party_state.gd Scripts/ui/party_view.gd tests/test_party_state.gd tests/test_party_view.gd
git commit -m "feat: bake attack bonus into the attack stat and show new stats"
```

---

### Task 9: 카드 앞면 개편 (CardView)

**Files:**
- Modify: `Scripts/ui/cards/card_view.gd`
- Test: `tests/test_card_view.gd`

**Interfaces:**
- Consumes: `CardText` (Task 7), `CardData.category/area_offsets` (Task 2)
- Produces: `CardView.setup(p_card: CardData, stats: UnitData = null) -> void`, `const CATEGORY_COLORS: Dictionary`, 테스트용 `effect_text() -> String`, `badge_text() -> String`, `area_marks() -> Array[Vector2i]` (미니맵에서 켜진 오프셋), `border_color()`, `cost_text()`, `name_text()`. `damage_text()`·`footer_text()`·`SHAPE_NAMES`·`MELEE_COLOR`·`RANGED_COLOR` 삭제.

레이아웃 (SIZE 110×154 유지):
- SP 원: (6,6) 28×28, 분류 색.
- 배지: (52,10) 20×20 Label, 글자 `CardText.badge`, 폰트 13.
- 미니맵: (74,6) 30×30, 5×5 칸(각 6px). 칸 (i,j) → 오프셋 `(i-2, j-2)`. 켜진 칸은 분류 색, 꺼진 칸은 `Color(1,1,1,0.12)`, 가운데 칸은 테두리 대신 밝기 `lightened(0.4)` 로 기준점 표시.
- 이름: (0,36) 110×20, 폰트 14.
- 일러스트 자리: (8,58) 94×48 Panel, 바탕 분류 색 `darkened(0.55)`.
- 효과 문구: (6,110) 98×40, 폰트 11, `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_card_view.gd` 의 `_card(...)` 헬퍼를 `Fixtures` 로 바꾸고 테스트를 다음으로 교체한다 (기존 앞면·뒷면·흐림 관련 테스트는 유지하고 카드 생성만 바꾼다):

```gdscript
# 스탯 없이 만들면 % 문구, 배지, 분류 색, 미니맵.
func _test_face_without_stats() -> void:
	# 원거리 세로 3칸 피해 30% 카드.
	var area: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)]
	var card: CardData = Fixtures.damage_card(&"일제사격", CardData.AttackType.RANGED, 30, area, 2)
	# 화면.
	var view := CardView.new()
	view.setup(card)
	# 비용.
	check_eq("cost", view.cost_text(), "2")
	# 이름.
	check_eq("name", view.name_text(), "일제사격")
	# 문구.
	check_eq("effect text", view.effect_text(), "피해 30%")
	# 배지.
	check_eq("badge", view.badge_text(), "원")
	# 분류 색 (공격).
	check_eq("border is category color", view.border_color(), CardView.CATEGORY_COLORS[CardData.Category.ATTACK])
	# 미니맵.
	check_eq("area marks", view.area_marks(), area)
	# 정리.
	view.free()


# 스탯을 주면 계산값.
func _test_face_with_stats() -> void:
	# 근접 피해 60%.
	var card: CardData = Fixtures.damage_card(&"베기", CardData.AttackType.MELEE, 60)
	# 공격 12.
	var stats: AllyData = AllyDataScript.new()
	stats.attack = 12
	# 화면.
	var view := CardView.new()
	view.setup(card, stats)
	# 7 (12 × 60% = 7.2).
	check_eq("computed effect", view.effect_text(), "피해 7")
	# 단일 미니맵.
	check_eq("single area mark", view.area_marks(), [Vector2i.ZERO])
	# 정리.
	view.free()


# 스킬 분류는 파란 테두리.
func _test_skill_color() -> void:
	# 자신 방어도 카드.
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.BLOCK, 50, CardEffect.Target.SELF)]
	var card: CardData = Fixtures.card(&"방어", CardData.AttackType.SELF, effects)
	card.category = CardData.Category.SKILL
	# 화면.
	var view := CardView.new()
	view.setup(card)
	# 색.
	check_eq("skill color", view.border_color(), CardView.CATEGORY_COLORS[CardData.Category.SKILL])
	# 정리.
	view.free()
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: `effect_text` 등 없음.

- [ ] **Step 3: 구현** — `card_view.gd`:
  - 머리 주석을 새 레이아웃 설명으로 바꾼다.
  - `MELEE_COLOR`, `RANGED_COLOR`, `SHAPE_NAMES` 를 지우고 추가:

```gdscript
## 카드 분류 → 테두리·SP 원 색. 공격 빨강, 스킬 파랑, 특수 보라.
const CATEGORY_COLORS: Dictionary = {
	CardData.Category.ATTACK: Color(0.85, 0.4, 0.35),
	CardData.Category.SKILL: Color(0.4, 0.6, 0.95),
	CardData.Category.SPECIAL: Color(0.7, 0.45, 0.9),
}
## 범위 미니맵 한 변의 칸 수 (오프셋 −2~+2).
const AREA_MAP_CELLS: int = 5
## 미니맵 칸 하나의 크기 (픽셀).
const AREA_MAP_CELL_SIZE: float = 6.0
## 미니맵의 꺼진 칸 색.
const AREA_OFF_COLOR := Color(1, 1, 1, 0.12)
```

  - 필드: `_damage_label`, `_footer_label` 대신 `_effect_label: Label`, `_badge_label: Label`, `_area_marks: Array[Vector2i] = []`.
  - `setup`:

```gdscript
## 카드 데이터를 받아 앞면·뒷면을 만든다. stats 를 주면 효과를 계산값으로, 없으면 % 로 쓴다.
func setup(p_card: CardData, stats: UnitData = null) -> void:
	# 보여 줄 카드를 기억한다.
	card = p_card
	# 컨테이너 안에서 이 크기보다 작아지지 않게 한다.
	custom_minimum_size = SIZE
	# 실제 크기를 카드 크기로.
	size = SIZE
	# 회전·확대의 중심을 카드 가운데로 둔다.
	pivot_offset = SIZE / 2.0
	# 카드 위의 클릭을 여기서 멈춰 뒤의 보드로 새지 않게 한다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 분류 색.
	_border_color = CATEGORY_COLORS[card.category]

	# --- 앞면 바탕 ---
	_face = _make_panel(FACE_COLOR, _border_color, 8)
	add_child(_face)

	# --- SP 비용 원 ---
	var cost_badge: Panel = _make_panel(_border_color, _border_color, 14)
	cost_badge.position = Vector2(6, 6)
	cost_badge.size = Vector2(28, 28)
	_face.add_child(cost_badge)
	_cost_label = _make_label(str(card.sp_cost), 18, Vector2.ZERO, cost_badge.size)
	cost_badge.add_child(_cost_label)

	# --- 공격 종류 배지 ---
	_badge_label = _make_label(CardText.badge(card.attack_type), 13, Vector2(52, 10), Vector2(20, 20))
	_face.add_child(_badge_label)

	# --- 범위 미니맵 ---
	_face.add_child(_make_area_map(card.area_offsets()))

	# --- 이름 ---
	_name_label = _make_label(card.display_name, 14, Vector2(0, 36), Vector2(SIZE.x, 20))
	_face.add_child(_name_label)

	# --- 일러스트 자리 (아직 그림이 없어 분류 색 상자) ---
	var art: Panel = _make_panel(_border_color.darkened(0.55), _border_color.darkened(0.3), 4)
	art.position = Vector2(8, 58)
	art.size = Vector2(94, 48)
	_face.add_child(art)

	# --- 효과 문구 ---
	_effect_label = _make_label(CardText.describe(card, stats), 11, Vector2(6, 110), Vector2(98, 40))
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_face.add_child(_effect_label)

	# --- 뒷면 ---
	_back = make_back()
	add_child(_back)
	# 처음에는 앞면이 보이게 한다.
	set_face_up(true)


## 5×5 범위 미니맵을 만든다. 가운데 칸이 기준점, 켜진 칸은 분류 색.
func _make_area_map(offsets: Array[Vector2i]) -> Control:
	# 미니맵 상자.
	var map := Control.new()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.position = Vector2(74, 6)
	map.size = Vector2.ONE * AREA_MAP_CELLS * AREA_MAP_CELL_SIZE
	# 가운데 칸 번호.
	var center: int = AREA_MAP_CELLS / 2
	# 칸마다.
	for j in AREA_MAP_CELLS:
		for i in AREA_MAP_CELLS:
			# 이 칸의 오프셋.
			var offset := Vector2i(i - center, j - center)
			# 켜졌는지.
			var on: bool = offsets.has(offset)
			# 칸 색: 켜짐은 분류 색(기준점은 더 밝게), 꺼짐은 옅은 흰색.
			var color: Color = AREA_OFF_COLOR
			if on:
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
```

  - 테스트용 접근자: `damage_text`·`footer_text` 를 지우고

```gdscript
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
```

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/ui/cards/card_view.gd tests/test_card_view.gd
git commit -m "feat: redesign card face with category color, badge, area map and effect text"
```

---

### Task 10: 손패 — 계산값 카드와 사용 불가 카드

**Files:**
- Modify: `Scripts/ui/cards/hand_view.gd`, `Scripts/ui/battle_hud.gd`
- Test: `tests/test_hand_view.gd`, `tests/test_battle_hud.gd`

**Interfaces:**
- Consumes: `CardView.setup(card, stats)` (Task 9), `TargetResolver.valid_anchors` (Task 3)
- Produces:
  - `HandView.set_cards(cards: Array[CardData], sp: int, selected: int, stats: UnitData = null, blocked: Array[CardData] = []) -> void`
  - `HandView.set_stats(stats: UnitData) -> void` (이후 만드는 카드 화면에 쓸 스탯)
  - `signal HandView.blocked_card_pressed(index: int)` → `signal BattleHud.card_blocked(index: int)`
  - 사용 가능 판정: `sp_cost <= sp and not blocked.has(card)`. 흐림(`set_affordable`)도 같은 판정.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_hand_view.gd` 에 추가:

```gdscript
# 막힌 카드는 흐리고, 누르면 선택되지 않고 blocked_card_pressed 가 나간다.
func _test_blocked_card_is_dimmed_and_reports() -> void:
	# 손패 (이 파일의 손패 생성 헬퍼 사용).
	var hand: HandView = _hand()
	# 카드 둘.
	var free_card: CardData = Fixtures.damage_card(&"free", CardData.AttackType.RANGED, 10)
	var blocked_card: CardData = Fixtures.damage_card(&"blocked", CardData.AttackType.MELEE, 10)
	var cards: Array[CardData] = [free_card, blocked_card]
	var blocked: Array[CardData] = [blocked_card]
	# SP 넉넉히.
	hand.set_cards(cards, 5, -1, null, blocked)
	# 흐림.
	check_eq("free card bright", hand.card_views()[0].modulate, Color.WHITE)
	check_eq("blocked card dimmed", hand.card_views()[1].modulate, CardView.UNAFFORDABLE_MODULATE)
	# 신호 기록.
	var pressed: Array[int] = []
	hand.blocked_card_pressed.connect(func(index: int) -> void: pressed.append(index))
	# 막힌 카드를 누른다.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hand._on_card_gui_input(press, hand.card_views()[1])
	# 선택 안 됨, 신호 나감.
	check_eq("blocked not selected", hand.selected_index(), -1)
	check_eq("blocked press reported", pressed, [1])


# 스탯을 주면 카드에 계산값이 쓰인다.
func _test_stats_reach_card_views() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 공격 20.
	var stats: AllyData = AllyDataScript.new()
	stats.attack = 20
	# 피해 50% 카드.
	var cards: Array[CardData] = [Fixtures.damage_card(&"c", CardData.AttackType.RANGED, 50)]
	# 설정.
	hand.set_cards(cards, 5, -1, stats)
	# 10.
	check_eq("card shows computed value", hand.card_views()[0].effect_text(), "피해 10")
```

  (`_hand()` 헬퍼 이름·`Fixtures`·`AllyDataScript` 상수는 파일에 맞춰 추가한다. `_on_card_gui_input` 은 `interactive` 가 true 일 때만 동작하므로 헬퍼가 꺼 두면 테스트 안에서 `hand.interactive = true` 를 먼저 한다.)
  `tests/test_battle_hud.gd` 에: 같은 행에 적이 없는 근접 카드를 손패에 넣고 `sync_from_state` 후 그 카드 화면이 흐린지 검사하는 테스트를 추가한다 (이 파일의 상태 생성 헬퍼로 아군 (0,0)·적 (0,2) 를 만들고 근접 카드 하나, SP 충분).

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: 인자 수 오류 / 신호 없음.

- [ ] **Step 3: 구현**
  - `hand_view.gd`:
    - 신호 추가: `## SP 는 충분하지만 지금 쓸 수 없는(예: 근접인데 같은 행에 적 없음) 카드를 눌렀다.` / `signal blocked_card_pressed(index: int)`
    - 필드: `## 카드 효과를 계산할 스탯 (없으면 % 로 보인다).` `var _stats: UnitData` / `## 지금 쓸 수 없는 카드들.` `var _blocked: Array[CardData] = []`
    - `set_cards` 시그니처를 `(cards, sp, selected, stats: UnitData = null, blocked: Array[CardData] = [])` 로 바꾸고 두 갈래 모두에서 `_stats = stats` / `_blocked = blocked` 를 `_sp = sp` 옆에 넣는다. 같은 손패라 다시 만들지 않는 갈래에서도 스탯이 바뀌었으면(`_stats != stats`) 다시 만들도록 `if _shows(cards) and _stats == stats:` 로 조건을 바꾼다.
    - `func set_stats(stats: UnitData) -> void: _stats = stats` (주석 포함).
    - 사용 가능 판정 함수 추가 후 `set_sp`, `_make_view`, `_layout` 의 `view.set_affordable(view.card.sp_cost <= _sp)` 를 모두 `view.set_affordable(_usable(view.card))` 로:

```gdscript
## 이 카드를 지금 쓸 수 있는지 (SP 충분, 막히지 않음).
func _usable(card: CardData) -> bool:
	# 둘 다 만족해야 한다.
	return card.sp_cost <= _sp and not _blocked.has(card)
```

    - `_make_view` 의 `view.setup(card)` → `view.setup(card, _stats)`.
    - `_on_card_gui_input` 의 누르기 거절 부분:

```gdscript
			# SP 가 모자란 카드는 누르기 자체를 받지 않는다 (선택·끌기 불가).
			if view.card.sp_cost > _sp:
				view.accept_event()
				return
			# SP 는 되지만 막힌 카드는 이유를 알릴 수 있게 신호만 낸다.
			if _blocked.has(view.card):
				blocked_card_pressed.emit(_cards.find(view))
				view.accept_event()
				return
```

  - `battle_hud.gd`:
    - 신호: `## 지금 쓸 수 없는 카드를 눌렀다 (BattleRoot 가 이유를 로그로 알린다).` `signal card_blocked(index: int)`; `_ready` 에서 `_hand.blocked_card_pressed.connect(func(index: int) -> void: card_blocked.emit(index))`.
    - `sync_from_state` 의 `_hand.set_cards(actor.hand, actor.sp, selected_card)` 를:

```gdscript
		# 기준 유닛이 없어 지금 쓸 수 없는 카드들 (예: 근접인데 같은 행에 적 없음).
		var blocked: Array[CardData] = []
		for card in actor.hand:
			if state.resolver.valid_anchors(actor, card, state.units).is_empty():
				blocked.append(card)
		# 손패를 규칙의 손패와 같게 만든다 (같으면 기존 카드 화면을 유지).
		_hand.set_cards(actor.hand, actor.sp, selected_card, actor.data, blocked)
```

    - `show_turn` 의 아군 갈래에서 `_clear_hand(event.unit.sp)` 다음에 `_hand.set_stats(event.unit.data)` (드로우 연출로 들어오는 카드가 계산값으로 보이게).

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/ui/cards/hand_view.gd Scripts/ui/battle_hud.gd tests/test_hand_view.gd tests/test_battle_hud.gd
git commit -m "feat: show computed card values and block unusable cards in hand"
```

---

### Task 11: 조준 흐름과 연출 (BattleRoot · BattlePlayback)

**Files:**
- Modify: `Scripts/view/battle_root.gd`, `Scripts/view/battle_playback.gd`
- Test: `tests/test_battle_root.gd`, `tests/test_battle_playback.gd`

**Interfaces:**
- Consumes: `CardData.needs_aim` (Task 2), `valid_anchors`/`area_cells` (Task 3), `play_card(index, anchor)` (Task 4), `BattleHud.card_blocked` (Task 10)
- Produces: (내부) `BattleRoot._auto_anchor(actor: Unit, card: CardData) -> Unit`, `_play_selected(anchor: Unit) -> void`. 옛 `_hint_text` 삭제.

동작:
- 자동 카드(`not needs_aim()`): 드래그를 어디에 놓든, 또는 선택한 뒤 보드의 아무 칸을 클릭하면 `_auto_anchor` 로 사용. 선택 중에는 기준 유닛 칸을 VALID("✓")로, 그 기준의 `area_cells` 를 범위 미리보기로 보여 준다.
- 조준 카드: 기준 후보 칸들을 VALID("✓")로 표시(원거리는 적 격자, 아군 카드는 아군 격자). 후보 유닛 칸에 커서를 올리면 그 기준의 범위 미리보기. 클릭·놓기한 칸의 유닛이 후보가 아니면 "사용할 수 없는 대상" 로그.
- `_hud.card_blocked` → 로그 "같은 행에 적 없음".
- 연출: `CARD_PLAYED` 이고 카드가 근접·원거리일 때만 공격(돌진/화살). 아군·자신 카드는 이름을 띄우고 `hop()` 만.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_battle_root.gd` 에 추가 (이 파일의 전투 씬 생성 헬퍼를 쓴다; 카드를 손패에 직접 넣는 기존 테스트 방식을 따른다):

```gdscript
# 근접 카드는 놓기만 하면 같은 행 맨 앞 적에게 쓰인다 (보드 판정을 기다리지 않는다).
func _test_melee_card_drop_plays_automatically() -> void:
	# 전투 씬 (아군·적이 같은 행에 있는 구성).
	var battle: BattleRoot = await _battle()
	# 차례 아군.
	var actor: Unit = battle._state.current_unit()
	# 근접 피해 카드를 손패 맨 앞에 넣는다.
	var card: CardData = Fixtures.damage_card(&"auto", CardData.AttackType.MELEE, 10)
	actor.hand.insert(0, card)
	battle._hud.sync_from_state(battle._state, -1)
	# 기준 유닛.
	var anchor: Unit = battle._state.resolver.melee_anchor(actor, battle._state.units)
	# 그 체력.
	var before: int = anchor.hp
	# 아무 위치에나 놓는다.
	battle._on_card_dropped(0, Vector2(5, 5))
	# 재생이 끝날 때까지 기다린다 (이 파일의 대기 방식).
	await _settle(battle)
	# 맞았다.
	check("melee auto hit anchor", anchor.hp < before)
	# 정리.
	battle.free()


# 아군 대상 카드는 아군 칸 클릭으로 쓰인다.
func _test_ally_card_targets_ally_cell() -> void:
	# 전투 씬.
	var battle: BattleRoot = await _battle()
	# 차례 아군.
	var actor: Unit = battle._state.current_unit()
	# 체력을 깎아 둔다.
	actor.hp -= 5
	# 아군 회복 카드.
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.HEAL, 30)]
	var card: CardData = Fixtures.card(&"heal", CardData.AttackType.ALLY, effects)
	actor.hand.insert(0, card)
	battle._hud.sync_from_state(battle._state, -1)
	# 선택 후 자기 칸 클릭.
	battle._on_card_selected(0)
	battle._on_cell_clicked(actor.team, actor.cell)
	await _settle(battle)
	# 회복 3 (공격 10 × 30%).
	check_eq("ally heal applied", actor.hp, actor.data.max_hp - 2)
	# 정리.
	battle.free()
```

  (`_battle()`·`_settle()` 은 이 파일에 이미 있는 씬 생성·재생 대기 헬퍼 이름으로 바꾼다. 없으면 기존 테스트의 생성 코드를 그대로 헬퍼로 뽑는다.)
  `tests/test_battle_playback.gd` 에: `CARD_PLAYED` 이벤트의 카드가 `SELF` 일 때 `BattlePlayback._is_attack(event)` 가 false, `MELEE` 일 때 true 인지 검사하는 테스트 추가 (static 함수라 이벤트만 만들어 부른다).

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: FAIL.

- [ ] **Step 3: 구현**

`battle_playback.gd`:

```gdscript
# 대상 쪽으로 공격하는 행동인지 (근접·원거리 카드, 또는 대상 있는 적 공격). 아군·자신 카드는 공격이 아니다.
static func _is_attack(event: BattleEvent) -> bool:
	# 카드 사용이면 공격 종류로 판단한다.
	if event.kind == BattleEvent.Kind.CARD_PLAYED:
		return event.card.attack_type == CardData.AttackType.MELEE or event.card.attack_type == CardData.AttackType.RANGED
	# 적 행동이면 대상 있는 공격만.
	return event.action == EnemyBrain.Action.ATTACK and event.target != null
```

`_card_played` 의 `view.pop_text(...)` 다음:

```gdscript
	# 아군·자신 카드는 돌진하지 않고 제자리에서 시전한다.
	if not _is_attack(event):
		await view.hop()
		return
```

`battle_root.gd`:
  - `_ready` 에 `_hud.card_blocked.connect(func(_index: int) -> void: _hud.append_log("같은 행에 적 없음"))` (주석 포함).
  - `_on_card_dropped` — `_select_card(index)` / `_refresh_hints()` 다음, `_awaiting_drop = true` 앞에:

```gdscript
	# 자동 카드(근접·자신)는 놓는 위치와 상관없이 바로 쓴다.
	var actor: Unit = _state.current_unit()
	if actor != null and index < actor.hand.size() and not actor.hand[index].needs_aim():
		_play_selected(_auto_anchor(actor, actor.hand[index]))
		return
```

  - `_on_cell_clicked` 의 카드 부분(“지금 차례인 유닛” 이후)을 교체:

```gdscript
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 차례 유닛이 없거나 선택 번호가 손패 범위를 벗어나면 쓰지 않는다.
	if actor == null or _selected_card >= actor.hand.size():
		if from_drop:
			_clear_selection()
		return
	# 사용하려는 카드.
	var card: CardData = actor.hand[_selected_card]
	# 자동 카드는 어느 칸을 눌러도 자동 기준 유닛으로 쓴다.
	if not card.needs_aim():
		_play_selected(_auto_anchor(actor, card))
		return
	# 조준 카드: 그 칸의 유닛이 후보여야 한다.
	var anchor: Unit = _living_unit_at(team, cell)
	if anchor == null or not _state.resolver.valid_anchors(actor, card, _state.units).has(anchor):
		_hud.append_log("사용할 수 없는 대상")
		if from_drop:
			_clear_selection()
		return
	# 쓴다.
	_play_selected(anchor)
```

  - 새 함수:

```gdscript
## 자동 카드(근접·자신)의 기준 유닛. 후보가 없으면 null.
func _auto_anchor(actor: Unit, card: CardData) -> Unit:
	# 후보.
	var anchors: Array[Unit] = _state.resolver.valid_anchors(actor, card, _state.units)
	# 첫 후보 (근접·자신은 많아야 하나).
	return null if anchors.is_empty() else anchors[0]


## 고른 카드를 anchor 기준으로 쓴다. 기준이 없으면 이유를 알리고 선택을 푼다.
func _play_selected(anchor: Unit) -> void:
	# 기준이 없으면 쓸 수 없다.
	if anchor == null:
		_hud.append_log("같은 행에 적 없음")
		_clear_selection()
		return
	# 잠금이 선택을 지우기 전에 카드 번호를 복사해 둔다.
	var card_index: int = _selected_card
	# 손패 화면에 곧 사라질 카드 위치를 알려 준다.
	_hud.set_pending_play(card_index)
	# 실행하고 재생한다. 규칙이 거절하면 로그를 남긴다.
	_run(func() -> void:
		if not _state.play_card(card_index, anchor):
			_hud.append_log("사용할 수 없는 대상"))
```

  - `_refresh_target_hints` 교체:

```gdscript
## 고른 카드의 기준 후보 칸을 보여 준다. 자동 카드면 그 기준의 범위까지 함께 보여 준다.
func _refresh_target_hints() -> void:
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	# 고른 카드가 없거나, 차례 유닛이 아군이 아니거나, 번호가 범위 밖이면 힌트를 지운다.
	if _selected_card < 0 or actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		_board.clear_target_hints()
		return
	# 고른 카드.
	var card: CardData = actor.hand[_selected_card]
	# 기준 후보.
	var anchors: Array[Unit] = _state.resolver.valid_anchors(actor, card, _state.units)
	# 후보가 없으면 지운다.
	if anchors.is_empty():
		_board.clear_target_hints()
		return
	# 후보 칸 → 힌트 (모두 같은 편이다).
	var hints: Dictionary = {}
	for anchor in anchors:
		hints[anchor.cell] = {"valid": true, "text": "✓"}
	# 보드에 보여 준다.
	_board.show_target_hints(anchors[0].team, hints)
	# 자동 카드면 그 기준의 범위를 덧그린다.
	if not card.needs_aim():
		_show_area_preview(anchors[0], card)
```

  - `_apply_hover_preview` 교체:

```gdscript
## 커서가 가리키는 칸에 맞춰 힌트를 다시 그린다. 조준 카드를 고른 상태에서 후보 유닛 칸을 가리키면 그 기준의 범위를 덧그린다.
func _apply_hover_preview(team: Unit.Team, cell: Vector2i) -> void:
	# 기본 힌트를 먼저 다시 그린다.
	_refresh_target_hints()
	# 카드를 고르지 않았으면 끝.
	if _selected_card < 0:
		return
	# 지금 차례인 유닛.
	var actor: Unit = _state.current_unit()
	if actor == null or not actor.is_ally() or _selected_card >= actor.hand.size():
		return
	# 고른 카드 (자동 카드는 이미 범위를 그렸다).
	var card: CardData = actor.hand[_selected_card]
	if not card.needs_aim():
		return
	# 그 칸의 유닛이 후보면 범위를 덧그린다.
	var anchor: Unit = _living_unit_at(team, cell)
	if anchor != null and _state.resolver.valid_anchors(actor, card, _state.units).has(anchor):
		_show_area_preview(anchor, card)


## anchor 기준 카드 범위 칸들을 미리보기로 덧그린다.
func _show_area_preview(anchor: Unit, card: CardData) -> void:
	# 범위 칸.
	var cells: Array[Vector2i] = _state.resolver.area_cells(anchor.cell, card.area_offsets(), _state.resolver.grid_for(anchor.team))
	# 칸 → 힌트.
	var hits: Dictionary = {}
	for area_cell in cells:
		hits[area_cell] = {"valid": true, "text": ""}
	# 덧그린다.
	_board.show_shape_preview(anchor.team, hits)
```

  - `_hint_text` 함수와 그 주석 삭제. 파일 머리 주석·`_on_cell_clicked` 주석에서 "광역·관통로 빈 칸" 설명을 새 규칙(기준 유닛)으로 고친다.

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/battle_root.gd Scripts/view/battle_playback.gd tests/test_battle_root.gd tests/test_battle_playback.gd
git commit -m "feat: auto-target melee and self cards and aim ranged and ally cards at units"
```

---

### Task 12: 옛 필드·함수 제거

**Files:**
- Modify: `Scripts/combat/data/card_data.gd` (`Shape`, `shape`, `attack_range`, `damage` 삭제), `Scripts/combat/data/enemy_data.gd` (`attack_damage`, `attack_type`, `attack_shape`, `attack_range`, `block_amount`, `rest_heal` 삭제), `Scripts/combat/target_resolver.gd` (`center_offset`, `reach`, `reach_cell`, `is_blocked`, `is_cell_blocked`, `is_valid_target`, `is_valid_cell`, `expand_shape`, `expand_shape_cell`, `shape_cells`, `_in_area` 삭제; `rows_for` 는 다른 곳에서 안 쓰면 삭제)
- Delete: `tools/generate_starter_content.gd` (+ `.uid`)
- Modify: 옛 이름을 아직 쓰는 테스트 (`tests/test_target_resolver.gd` 의 거리·막힘·Shape 테스트, `tests/test_battle_state.gd` 의 `_card` 헬퍼 등)
- Modify: `Resources/units/{brute,sentry,stalker}.tres` 의 옛 줄 (`attack_damage = …` 등)

- [ ] **Step 1: 남은 사용처 확인**

Run (Grep 도구): 패턴 `attack_range|\bshape\b|Shape\.|attack_damage|attack_shape|block_amount|rest_heal|\.damage\b|is_valid_cell|is_valid_target|expand_shape|shape_cells|reach_cell|reach\(|is_cell_blocked|is_blocked|center_offset` , 범위 `Scripts tests Resources tools`, glob `*.{gd,tres}`.
Expected: `target_resolver.gd`·`card_data.gd`·`enemy_data.gd` 의 정의, `test_target_resolver.gd` 의 옛 테스트, 적 `.tres` 의 옛 값, `tools/generate_starter_content.gd` 만 남는다. 그 외가 나오면 앞 Task 에서 빠뜨린 것이므로 새 API 로 고친다.

- [ ] **Step 2: 삭제**
  - 위 정의들을 지운다. `card_data.gd` 머리 주석에서 사거리·Shape 설명을 지운다.
  - `test_target_resolver.gd` 의 `_test_col_distance`, `_test_row_distance_*`, `_test_melee_blocked_by_front`, `_test_melee_unblocked_after_front_dies`, `_test_ranged_ignores_blocking`, `_test_out_of_range_rejected`, `_test_expand_*`, `_test_is_valid_cell_allows_empty_cell`, `_test_expand_shape_cell_hits_neighbors_from_empty_anchor`, `_test_shape_cells_includes_empty_cells_and_clips_to_grid` 와 `run()` 의 해당 호출을 지운다. `test_battle_state.gd` 의 옛 `_card` 헬퍼를 지운다.
  - 적 `.tres` 3개에서 `attack_damage`, `attack_type`, `attack_shape`, `attack_range`, `block_amount`, `rest_heal` 줄을 지운다.
  - `tools/generate_starter_content.gd` 와 `.uid` 를 지운다 (`tools/` 가 비면 폴더도).

- [ ] **Step 3: 테스트 실행** — Expected: 전체 통과, 파싱 경고 없음.

- [ ] **Step 4: 커밋**

```bash
git add -u Scripts tests Resources/units tools
git commit -m "refactor: remove range, shapes and legacy enemy fields"
```

---

### Task 13: 인스펙터 범위 편집기

**Files:**
- Create: `addons/card_area_editor/plugin.cfg`, `plugin.gd`, `area_inspector_plugin.gd`, `area_grid_property.gd`, `area_grid_logic.gd`
- Create: `tests/test_card_area_grid.gd`
- Modify: `project.godot` (`[editor_plugins]`), `tests/run_tests.gd`

**Interfaces:**
- Produces: `area_grid_logic.gd` (RefCounted, static, 에디터 밖에서도 실행 가능): `const SIZE: int = 5`, `offset_for(index: int) -> Vector2i` (`(index % 5 - 2, index / 5 - 2)`), `toggled(area: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]` (있으면 빼고 없으면 뒤에 붙인 새 배열)

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_card_area_grid.gd` (run_tests 목록 끝에 추가):

```gdscript
# 범위 편집기 격자 계산: 칸 번호 ↔ 오프셋, 토글.
extends TestCase

# 격자 계산 스크립트 (에디터 밖에서도 불러올 수 있다).
const AreaGridLogic := preload("res://addons/card_area_editor/area_grid_logic.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 칸 번호.
	_test_offsets()
	# 토글.
	_test_toggle()
	# 결과를 돌려준다.
	return results()


# 0 → (-2,-2), 12 → (0,0), 24 → (2,2), 7 → (0,-1).
func _test_offsets() -> void:
	# 모서리와 가운데.
	check_eq("index 0", AreaGridLogic.offset_for(0), Vector2i(-2, -2))
	check_eq("index 12 is center", AreaGridLogic.offset_for(12), Vector2i(0, 0))
	check_eq("index 24", AreaGridLogic.offset_for(24), Vector2i(2, 2))
	check_eq("index 7", AreaGridLogic.offset_for(7), Vector2i(0, -1))


# 없는 칸은 뒤에 붙고, 있는 칸은 빠지며, 원본은 바뀌지 않는다.
func _test_toggle() -> void:
	# 원본.
	var area: Array[Vector2i] = [Vector2i(0, 0)]
	# 켠다.
	var on: Array[Vector2i] = AreaGridLogic.toggled(area, Vector2i(1, 0))
	check_eq("toggle on appends", on, [Vector2i(0, 0), Vector2i(1, 0)])
	# 끈다.
	check_eq("toggle off removes", AreaGridLogic.toggled(on, Vector2i(0, 0)), [Vector2i(1, 0)])
	# 원본 그대로.
	check_eq("source untouched", area, [Vector2i(0, 0)])
```

- [ ] **Step 2: 실패 확인** — 테스트 실행. Expected: preload 실패.

- [ ] **Step 3: 구현**

`addons/card_area_editor/area_grid_logic.gd`:

```gdscript
# @tool: 에디터 플러그인이 쓴다.
@tool
## 범위 편집기 5×5 격자 계산 (에디터 API 없이 순수 계산만 — 테스트에서 직접 불러온다).
extends RefCounted

## 격자 한 변 칸 수 (오프셋 −2~+2).
const SIZE: int = 5


## 칸 번호(왼쪽 위 0, 오른쪽으로 증가) → 오프셋. 가운데 칸이 (0,0).
static func offset_for(index: int) -> Vector2i:
	# 가운데 번호.
	var center: int = SIZE / 2
	# 열·행에서 가운데를 뺀다.
	return Vector2i(index % SIZE - center, index / SIZE - center)


## area 에서 offset 을 켜거나 끈 새 배열 (원본은 바꾸지 않는다).
static func toggled(area: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	# 복사본.
	var result: Array[Vector2i] = area.duplicate()
	# 있으면 빼고, 없으면 붙인다.
	if result.has(offset):
		result.erase(offset)
	else:
		result.append(offset)
	# 돌려준다.
	return result
```

`addons/card_area_editor/area_grid_property.gd`:

```gdscript
# @tool: 에디터 인스펙터 안에서 실행된다.
@tool
## CardData.area 를 5×5 토글 버튼으로 편집하는 인스펙터 속성. 가운데가 기준점, 위가 행 −, 오른쪽이 열 +(뒤쪽).
## 값 변경은 emit_changed 로 알려 에디터의 Undo/Redo 에 자동으로 올라간다.
extends EditorProperty

# 격자 계산.
const AreaGridLogic := preload("res://addons/card_area_editor/area_grid_logic.gd")

## 칸 버튼들 (칸 번호 순서).
var _buttons: Array[Button] = []
## 버튼 상태를 코드로 맞추는 중이면 true (그동안 토글 신호를 무시한다).
var _updating: bool = false


## 격자 버튼을 만든다.
func _init() -> void:
	# 5열 격자.
	var grid := GridContainer.new()
	grid.columns = AreaGridLogic.SIZE
	# 칸마다 버튼.
	for index in AreaGridLogic.SIZE * AreaGridLogic.SIZE:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(22, 22)
		# 가운데 칸은 기준점 표시.
		button.text = "◎" if AreaGridLogic.offset_for(index) == Vector2i.ZERO else ""
		button.toggled.connect(_on_toggled.bind(index))
		grid.add_child(button)
		_buttons.append(button)
	# 속성 아래쪽에 붙인다.
	add_child(grid)
	set_bottom_editor(grid)


## 편집 중인 값으로 버튼 눌림을 맞춘다.
func _update_property() -> void:
	# 현재 값.
	var area: Array = get_edited_object()[get_edited_property()]
	# 신호를 막고 맞춘다.
	_updating = true
	for index in _buttons.size():
		_buttons[index].button_pressed = area.has(AreaGridLogic.offset_for(index))
	_updating = false


## 칸을 눌렀다: 그 오프셋을 켜거나 끈 새 배열을 알린다.
func _on_toggled(_pressed: bool, index: int) -> void:
	# 코드로 맞추는 중이면 무시.
	if _updating:
		return
	# 현재 값을 타입 있는 배열로.
	var current: Array[Vector2i] = []
	current.assign(get_edited_object()[get_edited_property()])
	# 새 값을 알린다.
	emit_changed(get_edited_property(), AreaGridLogic.toggled(current, AreaGridLogic.offset_for(index)))
```

`addons/card_area_editor/area_inspector_plugin.gd`:

```gdscript
# @tool: 에디터에서 실행된다.
@tool
## CardData 의 area 속성을 5×5 격자 편집기로 바꿔 보여 준다.
extends EditorInspectorPlugin

# 격자 속성.
const AreaGridProperty := preload("res://addons/card_area_editor/area_grid_property.gd")


## CardData 만 다룬다.
func _can_handle(object: Object) -> bool:
	return object is CardData


## area 속성이면 격자 편집기를 넣고 기본 편집기를 숨긴다.
func _parse_property(_object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# area 가 아니면 기본 편집기.
	if name != "area":
		return false
	# 격자 편집기를 넣는다.
	add_property_editor(name, AreaGridProperty.new())
	# 기본 배열 편집기는 숨긴다.
	return true
```

`addons/card_area_editor/plugin.gd`:

```gdscript
# @tool: 에디터 플러그인.
@tool
## 카드 범위(area) 인스펙터 편집기를 등록한다.
extends EditorPlugin

# 인스펙터 플러그인.
const AreaInspectorPlugin := preload("res://addons/card_area_editor/area_inspector_plugin.gd")

## 등록한 인스펙터 플러그인.
var _inspector: EditorInspectorPlugin


## 켜질 때 등록.
func _enter_tree() -> void:
	_inspector = AreaInspectorPlugin.new()
	add_inspector_plugin(_inspector)


## 꺼질 때 해제.
func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
```

`addons/card_area_editor/plugin.cfg`:

```ini
[plugin]

name="Card Area Editor"
description="CardData.area 를 5×5 격자로 편집한다."
author="Project Void"
version="1.0"
script="plugin.gd"
```

`project.godot` `[editor_plugins]` 의 `enabled` 배열 끝에 `"res://addons/card_area_editor/plugin.cfg"` 를 추가한다.

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과. 에디터를 다시 열어(또는 Project Settings > Plugins 에서 켜서) `Resources/cards/blast.tres` 를 인스펙터에서 열었을 때 5×5 격자에 2×2 가 눌려 있고, 칸을 눌러 바꾼 뒤 Ctrl+Z 로 되돌아가는지 직접 확인한다. 확인 후 변경은 되돌린다.

- [ ] **Step 5: 커밋**

```bash
git add addons/card_area_editor project.godot tests/test_card_area_grid.gd tests/run_tests.gd
git commit -m "feat: add a 5x5 inspector editor for card areas"
```

---

### Task 14: 게임에서 직접 확인

**Files:** 없음 (확인만)

- [ ] **Step 1: 실행** — `Start-Process "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" -ArgumentList '--path "C:\Users\User\Desktop\Godot\Project-Void"'` 로 게임을 띄워 (또는 `run` 스킬) 맵 → 전투에 들어간다.
- [ ] **Step 2: 확인 목록**
  - 손패 카드 앞면: SP 원, 이름, 배지, 미니맵, 분류 색, 계산된 피해 수치.
  - 근접 카드: 같은 행에 적이 있으면 끌어 놓기만으로 맨 앞 적이 맞는다. 행이 비면 카드가 흐리고, 누르면 "같은 행에 적 없음".
  - 원거리 카드: 적 칸마다 ✓, 커서를 올리면 범위가 미리보이고, 놓으면 범위 안 적들이 맞는다.
  - 적: 공격·방어·휴식 수치가 이전과 같다(괴한 7 피해 등). 치명 시 "치명! -N".
  - 파티 화면: 스탯 8종, 덱 목록 `베기 ×N — 피해 60%`.
- [ ] **Step 3: 문제 기록** — 어긋난 점이 있으면 `superpowers:systematic-debugging` 으로 원인을 찾고 해당 Task 범위에서 고친다.
