# 전투 프로토타입 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 진영 그리드 위에서 아군은 카드로, 적은 공격/방어/휴식으로 싸우는 턴제 전투를 플레이 가능한 수준까지 만든다.

**Architecture:** 규칙은 Node 의존이 없는 `RefCounted` 클래스(`Unit`, `TargetResolver`, `BattleState`, `EnemyBrain`)에 두고, 카드·유닛 정의는 `Resource`로, 화면은 `BattleController` 노드가 시그널을 받아 갱신한다. 규칙 전체를 헤드리스로 테스트한다.

**Tech Stack:** Godot 4.7.2 (stable), GDScript (타입 명시), 자체 헤드리스 테스트 러너 (외부 테스트 프레임워크 없음)

**Spec:** `docs/superpowers/specs/2026-09-12-combat-prototype-design.md`

## Global Constraints

- Godot 4.7.2. 엔진 버전 올리지 말 것.
- Godot 실행 파일: `C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe` (MCP 서버에 설정된 `C:\Program Files\Godot\Godot.exe` 는 존재하지 않는다)
- 타입 명시 GDScript. 모든 함수에 `-> ReturnType`, 모든 `var` 에 타입. 기존 `addons/` 코드 스타일을 따른다.
- 외부 애드온/의존성 추가 금지. 테스트 프레임워크도 직접 만든 것만 쓴다.
- 규칙 코어(`Scripts/combat/`) 는 `Node` 를 상속하거나 참조하지 않는다. `RefCounted` 와 `Resource` 만.
- 난수는 반드시 `BattleState.rng` (주입된 `RandomNumberGenerator`) 를 통해서만. 전역 `randi()`/`randf()`/`Array.shuffle()` 호출 금지 — 테스트 재현성이 깨진다.
- 속성 이름으로 `range` 를 쓰지 말 것 (GDScript 전역 함수와 충돌). `attack_range` 를 쓴다.
- 주석은 WHY 가 비자명할 때만. 코드가 설명하는 내용을 반복하지 않는다.
- 테스트 명령: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd`
- 이 명령은 `MCPRuntime` 오토로드 때문에 `[MCP Runtime] Server listening on port 7777` 같은 줄을 출력한다. 정상이다. 게임 인스턴스가 이미 떠 있으면 포트 충돌 메시지가 나오지만 테스트 결과와 무관하다.

## 파일 구조

| 경로 | 책임 |
|---|---|
| `Scripts/combat/data/card_data.gd` | 카드 정의 Resource + `AttackType`/`Shape` enum |
| `Scripts/combat/data/unit_data.gd` | 유닛 공통 정의 Resource (베이스) |
| `Scripts/combat/data/ally_data.gd` | 아군 정의 (SP, 덱) |
| `Scripts/combat/data/enemy_data.gd` | 적 정의 (공격 수치, block량, 회복량) |
| `Scripts/combat/data/unit_placement.gd` | 유닛 1기의 배치 정보 |
| `Scripts/combat/data/encounter_data.gd` | 전투 1회 셋업 (양 진영 그리드 크기 + 배치) |
| `Scripts/combat/unit.gd` | 런타임 유닛. HP/block/SP, 카드 존, 드로우·리셔플·버리기 |
| `Scripts/combat/target_resolver.gd` | 거리, 블로킹, 유효 타겟, 광역 전개 |
| `Scripts/combat/battle_state.gd` | 전투 전체 상태, 턴 진행, 카드 해결, 데미지, 승패 |
| `Scripts/combat/enemy_brain.gd` | 적 행동 결정과 실행 |
| `Scripts/ui/battle_controller.gd` | 입력 ↔ 규칙 ↔ 화면 중계 |
| `Scenes/battle.tscn` | 전투 화면 |
| `Resources/cards/*.tres` | 초기 카드 5종 |
| `Resources/units/*.tres` | 아군 3기, 적 3기 |
| `Resources/encounters/*.tres` | 조우 정의 |
| `tools/generate_starter_content.gd` | 위 .tres 들을 엔진으로 생성하는 일회성 스크립트 |
| `tests/test_case.gd` | 테스트 베이스 (assert 헬퍼) |
| `tests/run_tests.gd` | 헤드리스 러너 |
| `tests/test_*.gd` | 각 규칙 클래스의 테스트 |

---

### Task 1: 테스트 하네스

**Files:**
- Create: `tests/test_case.gd`
- Create: `tests/run_tests.gd`
- Create: `tests/test_harness_smoke.gd`

**Interfaces:**
- Consumes: 없음 (최초 태스크)
- Produces:
  - `TestCase.check(name: String, condition: bool, message: String = "") -> void`
  - `TestCase.check_eq(name: String, actual: Variant, expected: Variant) -> void`
  - `TestCase.results() -> Array[Dictionary]` — 각 원소는 `{"name": String, "ok": bool, "message": String}`
  - 모든 테스트 스위트는 `run() -> Array[Dictionary]` 를 구현하고 `results()` 를 반환한다
  - `tests/run_tests.gd` 의 `TEST_SCRIPTS: Array[String]` 상수 — 이후 태스크가 여기에 경로를 추가한다

이 태스크의 목적은 두 가지다. 테스트 러너를 만드는 것, 그리고 **헤드리스 실행에서 `class_name` 전역 클래스가 해석되는지 확인**하는 것. 후자가 안 되면 이후 모든 태스크의 코드 구조를 바꿔야 하므로 여기서 먼저 확인한다.

- [ ] **Step 1: 테스트 베이스 작성**

`tests/test_case.gd`:

```gdscript
class_name TestCase
extends RefCounted

var _results: Array[Dictionary] = []


func check(name: String, condition: bool, message: String = "") -> void:
	_results.append({
		"name": name,
		"ok": condition,
		"message": message,
	})


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	_results.append({
		"name": name,
		"ok": actual == expected,
		"message": "expected %s, got %s" % [expected, actual],
	})


func results() -> Array[Dictionary]:
	return _results
```

- [ ] **Step 2: 실패하는 스모크 테스트 작성**

`tests/test_harness_smoke.gd`. 여기서 `TestCase` 를 `class_name` 으로 참조하는 것이 헤드리스 전역 클래스 해석 확인을 겸한다.

```gdscript
extends TestCase


func run() -> Array[Dictionary]:
	check("harness reports a pass", true)
	check_eq("check_eq compares values", 1 + 1, 2)
	check("intentional failure", false, "this must fail in step 4")
	return results()
```

- [ ] **Step 3: 러너 작성**

`tests/run_tests.gd`:

```gdscript
extends SceneTree

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_harness_smoke.gd",
]


func _initialize() -> void:
	var total: int = 0
	var failures: int = 0

	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			push_error("could not load test script: %s" % path)
			failures += 1
			continue

		print("\n== %s" % path)
		var suite: Object = script.new()
		var suite_results: Array = suite.call("run")
		for result in suite_results:
			total += 1
			if result["ok"]:
				print("  PASS  %s" % result["name"])
			else:
				failures += 1
				print("  FAIL  %s  -- %s" % [result["name"], result["message"]])

	print("\n%d/%d passed" % [total - failures, total])
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 4: 러너가 실패를 잡아내는지 확인**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd
```

Expected: `intentional failure` 가 FAIL 로 출력되고, 마지막 줄이 `2/3 passed`, 종료 코드 1.

`extends TestCase` 에서 "Could not find type TestCase" 같은 파싱 에러가 나면 전역 클래스 캐시가 낡은 것이다. Godot 에디터가 켜져 있으면 `auto_reload` 애드온이 갱신하므로 에디터를 한 번 포커스했다가 다시 실행한다. 그래도 안 되면 `extends TestCase` 를 `extends "res://tests/test_case.gd"` 로 바꾸고, **이후 모든 테스트 파일에서도 경로 기반 `extends` 를 쓴다**.

- [ ] **Step 5: 의도적 실패 제거**

`tests/test_harness_smoke.gd` 에서 실패 줄을 지운다:

```gdscript
extends TestCase


func run() -> Array[Dictionary]:
	check("harness reports a pass", true)
	check_eq("check_eq compares values", 1 + 1, 2)
	return results()
```

- [ ] **Step 6: 전부 통과 확인**

Run: (Step 4 와 같은 명령)

Expected: `2/2 passed`, 종료 코드 0.

- [ ] **Step 7: 커밋**

```bash
git add tests/
git commit -m "test: add headless test harness"
```

---

### Task 2: 데이터 Resource 와 초기 콘텐츠

**Files:**
- Create: `Scripts/combat/data/card_data.gd`
- Create: `Scripts/combat/data/unit_data.gd`
- Create: `Scripts/combat/data/ally_data.gd`
- Create: `Scripts/combat/data/enemy_data.gd`
- Create: `Scripts/combat/data/unit_placement.gd`
- Create: `Scripts/combat/data/encounter_data.gd`
- Create: `tools/generate_starter_content.gd`
- Create: `Resources/cards/*.tres`, `Resources/units/*.tres` (스크립트가 생성)
- Modify: `tests/run_tests.gd` (TEST_SCRIPTS 에 추가)
- Test: `tests/test_data.gd`

**Interfaces:**
- Consumes: Task 1 의 `TestCase`
- Produces:
  - `CardData.AttackType { MELEE, RANGED }`, `CardData.Shape { SINGLE, PIERCE, SWEEP }`
  - `CardData` 속성: `id: StringName`, `display_name: String`, `sp_cost: int`, `attack_type: AttackType`, `shape: Shape`, `attack_range: int`, `damage: int`
  - `UnitData` 속성: `id: StringName`, `display_name: String`, `max_hp: int`, `speed: int`
  - `AllyData extends UnitData` 추가 속성: `max_sp: int`, `deck: Array[CardData]`
  - `EnemyData extends UnitData` 추가 속성: `attack_damage: int`, `attack_type: CardData.AttackType`, `attack_shape: CardData.Shape`, `attack_range: int`, `block_amount: int`, `rest_heal: int`
  - `UnitPlacement` 속성: `unit_data: UnitData`, `cell: Vector2i` — `cell.x` 가 col, `cell.y` 가 row
  - `EncounterData` 속성: `ally_grid: Vector2i`, `enemy_grid: Vector2i` (둘 다 `(cols, rows)`), `ally_units: Array[UnitPlacement]`, `enemy_units: Array[UnitPlacement]`
  - `res://Resources/cards/{strike,cleave,shoot,volley,piercing_shot}.tres`
  - `res://Resources/units/{vanguard,archer,scout,brute,stalker,sentry}.tres`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_data.gd`:

```gdscript
extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


func run() -> Array[Dictionary]:
	_test_card_defaults()
	_test_ally_extends_unit_data()
	_test_starter_cards_exist()
	return results()


func _test_card_defaults() -> void:
	var card: CardData = CardDataScript.new()
	check_eq("card default sp_cost", card.sp_cost, 1)
	check_eq("card default shape is SINGLE", card.shape, CardData.Shape.SINGLE)


func _test_ally_extends_unit_data() -> void:
	var ally: AllyData = AllyDataScript.new()
	var enemy: EnemyData = EnemyDataScript.new()
	check("AllyData is a UnitData", ally is UnitData)
	check("EnemyData is a UnitData", enemy is UnitData)
	check("AllyData is not EnemyData", not (ally is EnemyData))


func _test_starter_cards_exist() -> void:
	var strike: CardData = load("res://Resources/cards/strike.tres")
	check("strike.tres loads", strike != null)
	if strike == null:
		return
	check_eq("strike id", strike.id, &"strike")
	check_eq("strike damage", strike.damage, 6)
	check_eq("strike is melee", strike.attack_type, CardData.AttackType.MELEE)

	var volley: CardData = load("res://Resources/cards/volley.tres")
	check("volley.tres loads", volley != null)
	if volley == null:
		return
	check_eq("volley shape is SWEEP", volley.shape, CardData.Shape.SWEEP)
	check_eq("volley range", volley.attack_range, 4)
```

`tests/run_tests.gd` 의 상수에 추가:

```gdscript
const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_harness_smoke.gd",
	"res://tests/test_data.gd",
]
```

- [ ] **Step 2: 테스트 실패 확인**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd
```

Expected: `card_data.gd` 를 찾을 수 없다는 파싱 에러로 실패.

- [ ] **Step 3: Resource 클래스 6종 작성**

`Scripts/combat/data/card_data.gd`:

```gdscript
@tool
class_name CardData
extends Resource

enum AttackType { MELEE, RANGED }
enum Shape { SINGLE, PIERCE, SWEEP }

@export var id: StringName = &""
@export var display_name: String = ""
@export var sp_cost: int = 1
@export var attack_type: AttackType = AttackType.MELEE
@export var shape: Shape = Shape.SINGLE
@export var attack_range: int = 1
@export var damage: int = 0
```

`Scripts/combat/data/unit_data.gd`:

```gdscript
@tool
class_name UnitData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 10
@export var speed: int = 10
```

`Scripts/combat/data/ally_data.gd`:

```gdscript
@tool
class_name AllyData
extends UnitData

@export var max_sp: int = 3
@export var deck: Array[CardData] = []
```

`Scripts/combat/data/enemy_data.gd`:

```gdscript
@tool
class_name EnemyData
extends UnitData

@export var attack_damage: int = 5
@export var attack_type: CardData.AttackType = CardData.AttackType.MELEE
@export var attack_shape: CardData.Shape = CardData.Shape.SINGLE
@export var attack_range: int = 1
@export var block_amount: int = 5
@export var rest_heal: int = 4
```

`Scripts/combat/data/unit_placement.gd`:

```gdscript
@tool
class_name UnitPlacement
extends Resource

@export var unit_data: UnitData
@export var cell: Vector2i = Vector2i.ZERO
```

`Scripts/combat/data/encounter_data.gd`:

```gdscript
@tool
class_name EncounterData
extends Resource

@export var ally_grid: Vector2i = Vector2i(3, 3)
@export var enemy_grid: Vector2i = Vector2i(3, 3)
@export var ally_units: Array[UnitPlacement] = []
@export var enemy_units: Array[UnitPlacement] = []
```

- [ ] **Step 4: 콘텐츠 생성 스크립트 작성**

.tres 를 손으로 쓰지 않는다. 엔진이 쓰게 해야 포맷·UID 가 정확하다.

`tools/generate_starter_content.gd`:

```gdscript
extends SceneTree


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://Resources/cards")
	DirAccess.make_dir_recursive_absolute("res://Resources/units")

	var cards: Dictionary = _make_cards()
	for card_id in cards:
		_save(cards[card_id], "res://Resources/cards/%s.tres" % card_id)

	for unit in _make_units(cards):
		_save(unit, "res://Resources/units/%s.tres" % unit.id)

	print("starter content generated")
	quit(0)


func _save(resource: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("failed to save %s (error %d)" % [path, err])
	else:
		print("  wrote %s" % path)


func _card(id: StringName, name: String, sp: int, attack_type: int, shape: int, attack_range: int, damage: int) -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = name
	card.sp_cost = sp
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _make_cards() -> Dictionary:
	return {
		"strike": _card(&"strike", "베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6),
		"cleave": _card(&"cleave", "횡베기", 2, CardData.AttackType.MELEE, CardData.Shape.SWEEP, 1, 4),
		"shoot": _card(&"shoot", "사격", 1, CardData.AttackType.RANGED, CardData.Shape.SINGLE, 3, 4),
		"volley": _card(&"volley", "일제사격", 2, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3),
		"piercing_shot": _card(&"piercing_shot", "관통사격", 2, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 3, 5),
	}


func _make_units(cards: Dictionary) -> Array[UnitData]:
	var vanguard := AllyData.new()
	vanguard.id = &"vanguard"
	vanguard.display_name = "선봉"
	vanguard.max_hp = 30
	vanguard.speed = 12
	vanguard.max_sp = 3
	vanguard.deck = _deck([cards["strike"], cards["strike"], cards["strike"], cards["cleave"], cards["cleave"], cards["shoot"]])

	var archer := AllyData.new()
	archer.id = &"archer"
	archer.display_name = "사수"
	archer.max_hp = 20
	archer.speed = 10
	archer.max_sp = 3
	archer.deck = _deck([cards["shoot"], cards["shoot"], cards["shoot"], cards["volley"], cards["piercing_shot"], cards["piercing_shot"]])

	var scout := AllyData.new()
	scout.id = &"scout"
	scout.display_name = "정찰병"
	scout.max_hp = 22
	scout.speed = 16
	scout.max_sp = 2
	scout.deck = _deck([cards["strike"], cards["strike"], cards["shoot"], cards["shoot"], cards["volley"], cards["cleave"]])

	var brute := EnemyData.new()
	brute.id = &"brute"
	brute.display_name = "괴한"
	brute.max_hp = 28
	brute.speed = 8
	brute.attack_damage = 7
	brute.attack_type = CardData.AttackType.MELEE
	brute.attack_shape = CardData.Shape.SINGLE
	brute.attack_range = 1
	brute.block_amount = 6
	brute.rest_heal = 5

	var stalker := EnemyData.new()
	stalker.id = &"stalker"
	stalker.display_name = "추적자"
	stalker.max_hp = 18
	stalker.speed = 14
	stalker.attack_damage = 4
	stalker.attack_type = CardData.AttackType.RANGED
	stalker.attack_shape = CardData.Shape.PIERCE
	stalker.attack_range = 3
	stalker.block_amount = 4
	stalker.rest_heal = 4

	var sentry := EnemyData.new()
	sentry.id = &"sentry"
	sentry.display_name = "보초"
	sentry.max_hp = 24
	sentry.speed = 6
	sentry.attack_damage = 5
	sentry.attack_type = CardData.AttackType.RANGED
	sentry.attack_shape = CardData.Shape.SWEEP
	sentry.attack_range = 4
	sentry.block_amount = 8
	sentry.rest_heal = 3

	var out: Array[UnitData] = []
	out.append_array([vanguard, archer, scout, brute, stalker, sentry])
	return out


func _deck(cards: Array) -> Array[CardData]:
	var typed: Array[CardData] = []
	typed.append_array(cards)
	return typed
```

- [ ] **Step 5: 콘텐츠 생성**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tools/generate_starter_content.gd
```

Expected: `wrote res://Resources/cards/strike.tres` 등 11줄 + `starter content generated`.

- [ ] **Step 6: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: `test_data.gd` 의 모든 케이스 PASS, 종료 코드 0.

- [ ] **Step 7: 커밋**

```bash
git add Scripts/combat/data/ tools/ Resources/ tests/
git commit -m "feat: add combat data resources and starter content"
```

---

### Task 3: Unit — 스탯과 카드 존

**Files:**
- Create: `Scripts/combat/unit.gd`
- Modify: `tests/run_tests.gd`
- Test: `tests/test_unit.gd`

**Interfaces:**
- Consumes: Task 2 의 `UnitData`, `AllyData`, `CardData`
- Produces:
  - `Unit.Team { ALLY, ENEMY }`
  - `Unit.new(unit_id: int, data: UnitData, team: Team, cell: Vector2i)`
  - 속성: `unit_id: int`, `data: UnitData`, `team: Team`, `cell: Vector2i`, `hp: int`, `block: int`, `sp: int`, `deck/hand/discard/exile: Array[CardData]`
  - `is_alive() -> bool`, `is_ally() -> bool`
  - `take_damage(amount: int) -> void`, `heal(amount: int) -> void`, `gain_block(amount: int) -> void`
  - `shuffle_deck(rng: RandomNumberGenerator) -> void`
  - `draw(count: int, rng: RandomNumberGenerator) -> void`
  - `discard_hand() -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_unit.gd`:

```gdscript
extends TestCase

const UnitScript := preload("res://Scripts/combat/unit.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")


func run() -> Array[Dictionary]:
	_test_block_absorbs_before_hp()
	_test_block_depletes()
	_test_heal_caps_at_max()
	_test_draw_moves_cards()
	_test_draw_reshuffles_discard()
	_test_draw_stops_when_both_empty()
	_test_discard_hand()
	_test_enemy_has_no_zones()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _card(id: StringName) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	return card


func _ally(deck_size: int) -> Unit:
	var data: AllyData = AllyDataScript.new()
	data.max_hp = 20
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		deck.append(_card(StringName("c%d" % i)))
	data.deck = deck
	return UnitScript.new(1, data, Unit.Team.ALLY, Vector2i(0, 0))


func _test_block_absorbs_before_hp() -> void:
	var unit: Unit = _ally(0)
	unit.gain_block(5)
	unit.take_damage(3)
	check_eq("block absorbs damage, hp untouched", unit.hp, 20)
	check_eq("block reduced by absorbed amount", unit.block, 2)


func _test_block_depletes() -> void:
	var unit: Unit = _ally(0)
	unit.gain_block(4)
	unit.take_damage(10)
	check_eq("leftover damage hits hp", unit.hp, 14)
	check_eq("block fully spent", unit.block, 0)


func _test_heal_caps_at_max() -> void:
	var unit: Unit = _ally(0)
	unit.take_damage(5)
	unit.heal(100)
	check_eq("heal does not exceed max_hp", unit.hp, 20)


func _test_draw_moves_cards() -> void:
	var unit: Unit = _ally(6)
	unit.draw(4, _rng(1))
	check_eq("hand has 4", unit.hand.size(), 4)
	check_eq("deck has 2 left", unit.deck.size(), 2)


func _test_draw_reshuffles_discard() -> void:
	var unit: Unit = _ally(3)
	unit.draw(3, _rng(1))
	unit.discard_hand()
	check_eq("discard holds 3 before redraw", unit.discard.size(), 3)
	unit.draw(2, _rng(1))
	check_eq("redraw pulls from reshuffled deck", unit.hand.size(), 2)
	check_eq("discard emptied by reshuffle", unit.discard.size(), 0)
	check_eq("deck keeps the remainder", unit.deck.size(), 1)


func _test_draw_stops_when_both_empty() -> void:
	var unit: Unit = _ally(2)
	unit.draw(5, _rng(1))
	check_eq("draws only what exists", unit.hand.size(), 2)


func _test_discard_hand() -> void:
	var unit: Unit = _ally(4)
	unit.draw(4, _rng(1))
	unit.discard_hand()
	check_eq("hand cleared", unit.hand.size(), 0)
	check_eq("all cards moved to discard", unit.discard.size(), 4)


func _test_enemy_has_no_zones() -> void:
	var data: EnemyData = EnemyDataScript.new()
	data.max_hp = 15
	var unit: Unit = UnitScript.new(2, data, Unit.Team.ENEMY, Vector2i(0, 0))
	check_eq("enemy deck empty", unit.deck.size(), 0)
	check_eq("enemy sp zero", unit.sp, 0)
	check("enemy is not ally", not unit.is_ally())
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 `"res://tests/test_unit.gd"` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tests/run_tests.gd
```

Expected: `unit.gd` 를 찾을 수 없어 실패.

- [ ] **Step 3: Unit 구현**

`Scripts/combat/unit.gd`:

```gdscript
class_name Unit
extends RefCounted

enum Team { ALLY, ENEMY }

var unit_id: int
var data: UnitData
var team: Team
var cell: Vector2i
var hp: int
var block: int = 0
var sp: int = 0

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var exile: Array[CardData] = []


func _init(p_unit_id: int, p_data: UnitData, p_team: Team, p_cell: Vector2i) -> void:
	unit_id = p_unit_id
	data = p_data
	team = p_team
	cell = p_cell
	hp = p_data.max_hp

	if p_data is AllyData:
		var ally: AllyData = p_data as AllyData
		sp = ally.max_sp
		deck = ally.deck.duplicate()


func is_alive() -> bool:
	return hp > 0


func is_ally() -> bool:
	return team == Team.ALLY


func take_damage(amount: int) -> void:
	var absorbed: int = mini(block, amount)
	block -= absorbed
	hp = maxi(0, hp - (amount - absorbed))


func heal(amount: int) -> void:
	hp = mini(data.max_hp, hp + amount)


func gain_block(amount: int) -> void:
	block += amount


func shuffle_deck(rng: RandomNumberGenerator) -> void:
	_shuffle(deck, rng)


func draw(count: int, rng: RandomNumberGenerator) -> void:
	for i in count:
		if deck.is_empty():
			if discard.is_empty():
				return
			deck = discard.duplicate()
			discard.clear()
			_shuffle(deck, rng)
		hand.append(deck.pop_front())


func discard_hand() -> void:
	discard.append_array(hand)
	hand.clear()


func _shuffle(cards: Array[CardData], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = swap
```

`Array.shuffle()` 대신 직접 Fisher-Yates 를 도는 이유는 전역 RNG 를 쓰지 않기 위해서다 (Global Constraints 참조).

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: `test_unit.gd` 의 모든 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/unit.gd tests/
git commit -m "feat: add runtime Unit with block and card zones"
```

---

### Task 4: TargetResolver — 거리, 블로킹, 광역

**Files:**
- Create: `Scripts/combat/target_resolver.gd`
- Modify: `tests/run_tests.gd`
- Test: `tests/test_target_resolver.gd`

**Interfaces:**
- Consumes: Task 3 의 `Unit`, Task 2 의 `CardData`
- Produces:
  - `TargetResolver.new(ally_grid: Vector2i, enemy_grid: Vector2i)` — 둘 다 `(cols, rows)`
  - `rows_for(team: Unit.Team) -> int`
  - `static center_offset(row: int, rows: int) -> float`
  - `reach(attacker: Unit, target: Unit) -> int`
  - `is_blocked(target: Unit, all_units: Array[Unit]) -> bool`
  - `is_valid_target(attacker: Unit, target: Unit, attack_type: CardData.AttackType, attack_range: int, all_units: Array[Unit]) -> bool`
  - `expand_shape(primary: Unit, shape: CardData.Shape, all_units: Array[Unit]) -> Array[Unit]`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_target_resolver.gd`:

```gdscript
extends TestCase

const UnitScript := preload("res://Scripts/combat/unit.gd")
const ResolverScript := preload("res://Scripts/combat/target_resolver.gd")
const UnitDataScript := preload("res://Scripts/combat/data/unit_data.gd")


func run() -> Array[Dictionary]:
	_test_col_distance()
	_test_row_distance_same_size()
	_test_row_distance_different_size()
	_test_row_distance_odd_even_rounds_up()
	_test_melee_blocked_by_front()
	_test_melee_unblocked_after_front_dies()
	_test_ranged_ignores_blocking()
	_test_out_of_range_rejected()
	_test_expand_pierce()
	_test_expand_sweep()
	return results()


func _unit(id: int, team: Unit.Team, cell: Vector2i, hp: int = 10) -> Unit:
	var data: UnitData = UnitDataScript.new()
	data.max_hp = hp
	return UnitScript.new(id, data, team, cell)


func _test_col_distance() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	check_eq("front row vs front row is 1", resolver.reach(a, e), 1)

	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	check_eq("front vs enemy col2 is 3", resolver.reach(a, back), 3)


func _test_row_distance_same_size() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	check_eq("two rows apart adds 2", resolver.reach(a, e), 3)


func _test_row_distance_different_size() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 5))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 2))
	check_eq("3-row centre faces 5-row centre", resolver.reach(a, e), 1)

	var off: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 3))
	check_eq("one row off centre adds 1", resolver.reach(a, off), 2)


func _test_row_distance_odd_even_rounds_up() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 4))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var e: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	check_eq("half-cell offset rounds up to 1", resolver.reach(a, e), 2)


func _test_melee_blocked_by_front() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	check("front is reachable", resolver.is_valid_target(a, front, CardData.AttackType.MELEE, 1, all))
	check("back is blocked", not resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


func _test_melee_unblocked_after_front_dies() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	front.take_damage(999)
	check("dead front no longer blocks", resolver.is_valid_target(a, back, CardData.AttackType.MELEE, 4, all))


func _test_ranged_ignores_blocking() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var front: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var back: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(1, 1))
	var all: Array[Unit] = [a, front, back]
	check("ranged reaches behind the front", resolver.is_valid_target(a, back, CardData.AttackType.RANGED, 3, all))


func _test_out_of_range_rejected() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var a: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 0))
	var far: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(2, 2))
	var all: Array[Unit] = [a, far]
	check("reach 5 exceeds range 3", not resolver.is_valid_target(a, far, CardData.AttackType.RANGED, 3, all))


func _test_expand_pierce() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 1))
	var same_row: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(2, 1))
	var other_row: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(0, 2))
	var ally: Unit = _unit(1, Unit.Team.ALLY, Vector2i(0, 1))
	var all: Array[Unit] = [ally, primary, same_row, other_row]
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.PIERCE, all)
	check_eq("pierce hits the whole row", hit.size(), 2)
	check("pierce excludes other rows", not hit.has(other_row))
	check("pierce never hits the attacker camp", not hit.has(ally))


func _test_expand_sweep() -> void:
	var resolver: TargetResolver = ResolverScript.new(Vector2i(3, 3), Vector2i(3, 3))
	var primary: Unit = _unit(2, Unit.Team.ENEMY, Vector2i(0, 0))
	var same_col: Unit = _unit(3, Unit.Team.ENEMY, Vector2i(0, 2))
	var other_col: Unit = _unit(4, Unit.Team.ENEMY, Vector2i(1, 0))
	var all: Array[Unit] = [primary, same_col, other_col]
	var hit: Array[Unit] = resolver.expand_shape(primary, CardData.Shape.SWEEP, all)
	check_eq("sweep hits the whole column", hit.size(), 2)
	check("sweep excludes other columns", not hit.has(other_col))
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 `"res://tests/test_target_resolver.gd"` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run: (Task 3 Step 2 와 같은 명령)

Expected: `target_resolver.gd` 를 찾을 수 없어 실패.

- [ ] **Step 3: TargetResolver 구현**

`Scripts/combat/target_resolver.gd`:

```gdscript
class_name TargetResolver
extends RefCounted

var ally_grid: Vector2i
var enemy_grid: Vector2i


func _init(p_ally_grid: Vector2i, p_enemy_grid: Vector2i) -> void:
	ally_grid = p_ally_grid
	enemy_grid = p_enemy_grid


func rows_for(team: Unit.Team) -> int:
	return ally_grid.y if team == Unit.Team.ALLY else enemy_grid.y


static func center_offset(row: int, rows: int) -> float:
	return float(row) - float(rows - 1) / 2.0


func reach(attacker: Unit, target: Unit) -> int:
	var col_distance: int = attacker.cell.x + 1 + target.cell.x
	var attacker_offset: float = center_offset(attacker.cell.y, rows_for(attacker.team))
	var target_offset: float = center_offset(target.cell.y, rows_for(target.team))
	return col_distance + roundi(absf(attacker_offset - target_offset))


func is_blocked(target: Unit, all_units: Array[Unit]) -> bool:
	for unit in all_units:
		if unit.team != target.team:
			continue
		if not unit.is_alive():
			continue
		if unit.cell.y == target.cell.y and unit.cell.x < target.cell.x:
			return true
	return false


func is_valid_target(attacker: Unit, target: Unit, attack_type: CardData.AttackType, attack_range: int, all_units: Array[Unit]) -> bool:
	if not target.is_alive():
		return false
	if target.team == attacker.team:
		return false
	if reach(attacker, target) > attack_range:
		return false
	if attack_type == CardData.AttackType.MELEE and is_blocked(target, all_units):
		return false
	return true


func expand_shape(primary: Unit, shape: CardData.Shape, all_units: Array[Unit]) -> Array[Unit]:
	var hit: Array[Unit] = []

	if shape == CardData.Shape.SINGLE:
		hit.append(primary)
		return hit

	for unit in all_units:
		if unit.team != primary.team:
			continue
		if not unit.is_alive():
			continue
		if shape == CardData.Shape.PIERCE and unit.cell.y == primary.cell.y:
			hit.append(unit)
		elif shape == CardData.Shape.SWEEP and unit.cell.x == primary.cell.x:
			hit.append(unit)

	return hit
```

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: `test_target_resolver.gd` 의 모든 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/target_resolver.gd tests/
git commit -m "feat: add targeting rules for range, blocking and area shapes"
```

---

### Task 5: BattleState — 셋업, 카드 사용, 데미지, 승패

**Files:**
- Create: `Scripts/combat/battle_state.gd`
- Modify: `tests/run_tests.gd`
- Test: `tests/test_battle_state.gd`

**Interfaces:**
- Consumes: Task 3 의 `Unit`, Task 4 의 `TargetResolver`, Task 2 의 `EncounterData`
- Produces:
  - `BattleState.DRAW_PER_TURN: int` (= 4)
  - `BattleState.new(encounter: EncounterData, rng: RandomNumberGenerator)`
  - 속성: `units: Array[Unit]`, `resolver: TargetResolver`, `rng: RandomNumberGenerator`, `round_index: int`, `initiative: Array[Unit]`, `turn_index: int`, `finished: bool`, `ally_won: bool`
  - 시그널: `turn_started(unit: Unit)`, `unit_damaged(unit: Unit, amount: int)`, `unit_died(unit: Unit)`, `battle_ended(ally_won: bool)`, `log_message(text: String)`
  - `apply_damage(target: Unit, amount: int) -> void`
  - `write_log(text: String) -> void` — `log_message` 시그널을 쏘는 유일한 통로. 외부에서 시그널을 직접 emit 하지 않는다
  - `check_end() -> void`
  - `living_units(team: Unit.Team) -> Array[Unit]`
  - `play_card(hand_index: int, primary: Unit) -> bool`
  - `current_unit() -> Unit` (Task 6 에서 턴 진행과 함께 의미를 갖는다. 이 태스크에서는 `turn_index` 가 가리키는 유닛을 그대로 반환하기만 한다)

턴 진행(`start_battle`/`end_turn`)은 Task 6 에서 붙인다. 이 태스크는 상태 구성과 카드 1장의 해결까지만 다룬다.

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_battle_state.gd`:

```gdscript
extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_setup_places_units()
	_test_play_card_damages_and_spends_sp()
	_test_play_card_rejected_without_sp()
	_test_play_card_rejected_on_blocked_target()
	_test_sweep_hits_multiple()
	_test_battle_ends_when_enemies_wiped()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func _card(id: StringName, cost: int, attack_type: int, shape: int, attack_range: int, damage: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	card.display_name = String(id)
	card.sp_cost = cost
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 1기(전열 중앙) vs 적 2기(같은 행의 전열/후열).
func _encounter(ally_cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> EncounterData:
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"tester"
	ally.display_name = "테스터"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = ally_sp
	ally.deck = ally_cards

	var front: EnemyData = EnemyDataScript.new()
	front.id = &"front"
	front.max_hp = enemy_hp
	front.speed = 5

	var back: EnemyData = EnemyDataScript.new()
	back.id = &"back"
	back.max_hp = enemy_hp
	back.speed = 4

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = [_placement(ally, Vector2i(0, 1))]
	encounter.enemy_units = [
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	]
	return encounter


func _state(cards: Array[CardData], ally_sp: int = 5, enemy_hp: int = 10) -> BattleState:
	return BattleStateScript.new(_encounter(cards, ally_sp, enemy_hp), _rng())


func _test_setup_places_units() -> void:
	var state: BattleState = _state([])
	check_eq("three units total", state.units.size(), 3)
	check_eq("one living ally", state.living_units(Unit.Team.ALLY).size(), 1)
	check_eq("two living enemies", state.living_units(Unit.Team.ENEMY).size(), 2)
	check_eq("resolver knows ally grid", state.resolver.ally_grid, Vector2i(3, 3))
	check("unit ids are unique", state.units[0].unit_id != state.units[1].unit_id)


func _test_play_card_damages_and_spends_sp() -> void:
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	var state: BattleState = _state([strike])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [strike]

	var played: bool = state.play_card(0, front)
	check("card was played", played)
	check_eq("target lost hp", front.hp, 4)
	check_eq("sp spent", ally.sp, 4)
	check_eq("hand emptied", ally.hand.size(), 0)
	check_eq("card went to discard", ally.discard.size(), 1)


func _test_play_card_rejected_without_sp() -> void:
	var pricey: CardData = _card(&"pricey", 9, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6)
	var state: BattleState = _state([pricey], 2)
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [pricey]

	check("play rejected", not state.play_card(0, front))
	check_eq("target untouched", front.hp, 10)
	check_eq("sp untouched", ally.sp, 2)
	check_eq("card stays in hand", ally.hand.size(), 1)


func _test_play_card_rejected_on_blocked_target() -> void:
	var strike: CardData = _card(&"strike", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 4, 6)
	var state: BattleState = _state([strike])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var back: Unit = state.living_units(Unit.Team.ENEMY)[1]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [strike]

	check("melee cannot reach behind the front", not state.play_card(0, back))
	check_eq("back rank untouched", back.hp, 10)


func _test_sweep_hits_multiple() -> void:
	var volley: CardData = _card(&"volley", 1, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3)
	var state: BattleState = _state([volley])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [volley]

	# front 는 (0,1), back 은 (1,1) 이라 SWEEP(같은 col)은 front 만 맞는다.
	check("sweep played", state.play_card(0, front))
	check_eq("front damaged", front.hp, 7)
	check_eq("different column untouched", state.units[2].hp, 10)


func _test_battle_ends_when_enemies_wiped() -> void:
	var nuke: CardData = _card(&"nuke", 1, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 5, 99)
	var state: BattleState = _state([nuke])
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	var front: Unit = state.living_units(Unit.Team.ENEMY)[0]
	state.turn_index = 0
	state.initiative = [ally]
	ally.hand = [nuke]

	state.play_card(0, front)
	check("battle finished", state.finished)
	check("ally won", state.ally_won)
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 `"res://tests/test_battle_state.gd"` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run: (Task 3 Step 2 와 같은 명령)

Expected: `battle_state.gd` 를 찾을 수 없어 실패.

- [ ] **Step 3: BattleState 구현**

`Scripts/combat/battle_state.gd`:

```gdscript
class_name BattleState
extends RefCounted

signal turn_started(unit: Unit)
signal unit_damaged(unit: Unit, amount: int)
signal unit_died(unit: Unit)
signal battle_ended(ally_won: bool)
signal log_message(text: String)

const DRAW_PER_TURN: int = 4

var units: Array[Unit] = []
var resolver: TargetResolver
var rng: RandomNumberGenerator
var round_index: int = 0
var initiative: Array[Unit] = []
var turn_index: int = -1
var finished: bool = false
var ally_won: bool = false


func _init(encounter: EncounterData, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	resolver = TargetResolver.new(encounter.ally_grid, encounter.enemy_grid)

	var next_id: int = 0
	for placement in encounter.ally_units:
		var ally := Unit.new(next_id, placement.unit_data, Unit.Team.ALLY, placement.cell)
		ally.shuffle_deck(rng)
		units.append(ally)
		next_id += 1

	for placement in encounter.enemy_units:
		units.append(Unit.new(next_id, placement.unit_data, Unit.Team.ENEMY, placement.cell))
		next_id += 1


func living_units(team: Unit.Team) -> Array[Unit]:
	var alive: Array[Unit] = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			alive.append(unit)
	return alive


func current_unit() -> Unit:
	if turn_index < 0 or turn_index >= initiative.size():
		return null
	return initiative[turn_index]


# 시그널을 밖에서 직접 emit 하지 않도록 통로를 하나로 둔다.
# `log` 은 GDScript 전역 함수(자연로그)라 이름으로 쓸 수 없다.
func write_log(text: String) -> void:
	log_message.emit(text)


func apply_damage(target: Unit, amount: int) -> void:
	target.take_damage(amount)
	unit_damaged.emit(target, amount)
	if not target.is_alive():
		unit_died.emit(target)
		write_log("%s 쓰러짐" % target.data.display_name)


func check_end() -> void:
	if finished:
		return
	var allies_alive: bool = not living_units(Unit.Team.ALLY).is_empty()
	var enemies_alive: bool = not living_units(Unit.Team.ENEMY).is_empty()
	if allies_alive and enemies_alive:
		return
	finished = true
	ally_won = allies_alive
	battle_ended.emit(ally_won)


func play_card(hand_index: int, primary: Unit) -> bool:
	if finished:
		return false

	var actor: Unit = current_unit()
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	if hand_index < 0 or hand_index >= actor.hand.size():
		return false

	var card: CardData = actor.hand[hand_index]
	if card.sp_cost > actor.sp:
		return false
	if not resolver.is_valid_target(actor, primary, card.attack_type, card.attack_range, units):
		return false

	actor.sp -= card.sp_cost
	actor.hand.remove_at(hand_index)
	actor.discard.append(card)
	write_log("%s → %s (%s)" % [actor.data.display_name, primary.data.display_name, card.display_name])

	for victim in resolver.expand_shape(primary, card.shape, units):
		apply_damage(victim, card.damage)

	check_end()
	return true
```

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: `test_battle_state.gd` 의 모든 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/battle_state.gd tests/
git commit -m "feat: add battle state with card resolution and win check"
```

---

### Task 6: 이니셔티브 턴 진행

**Files:**
- Modify: `Scripts/combat/battle_state.gd`
- Modify: `tests/run_tests.gd`
- Test: `tests/test_turn_order.gd`

**Interfaces:**
- Consumes: Task 5 의 `BattleState`
- Produces:
  - `BattleState.start_battle() -> void` — 1라운드를 시작하고 첫 아군 차례에서 멈춘다
  - `BattleState.end_turn() -> void` — 현재 아군의 손패를 버리고 다음 아군 차례까지 진행한다
  - `BattleState._compute_initiative() -> Array[Unit]` — speed 내림차순, 동점은 `unit_id` 오름차순
  - 적 차례는 이 태스크에서 아직 아무 일도 하지 않는다. Task 7 에서 `EnemyBrain` 을 연결한다

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_turn_order.gd`:

```gdscript
extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_initiative_sorted_by_speed()
	_test_initiative_ties_broken_by_id()
	_test_turn_start_refills_sp_and_draws()
	_test_end_turn_discards_hand()
	_test_dead_units_are_skipped()
	_test_new_round_after_everyone_acted()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	return rng


func _ally(id: StringName, speed: int, deck_size: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 30
	data.speed = speed
	data.max_sp = 3
	var deck: Array[CardData] = []
	for i in deck_size:
		var card: CardData = CardDataScript.new()
		card.id = StringName("%s_c%d" % [id, i])
		deck.append(card)
	data.deck = deck
	return data


func _enemy(id: StringName, speed: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = 10
	data.speed = speed
	return data


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _state(allies: Array, enemies: Array) -> BattleState:
	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	var ally_placements: Array[UnitPlacement] = []
	var row: int = 0
	for data in allies:
		ally_placements.append(_placement(data, Vector2i(0, row)))
		row += 1
	var enemy_placements: Array[UnitPlacement] = []
	row = 0
	for data in enemies:
		enemy_placements.append(_placement(data, Vector2i(0, row)))
		row += 1
	encounter.ally_units = ally_placements
	encounter.enemy_units = enemy_placements
	return BattleStateScript.new(encounter, _rng())


func _test_initiative_sorted_by_speed() -> void:
	var state: BattleState = _state([_ally(&"slow", 5, 6), _ally(&"fast", 20, 6)], [_enemy(&"mid", 10)])
	state.start_battle()
	check_eq("fastest acts first", state.initiative[0].data.id, &"fast")
	check_eq("enemy in the middle", state.initiative[1].data.id, &"mid")
	check_eq("slowest acts last", state.initiative[2].data.id, &"slow")


func _test_initiative_ties_broken_by_id() -> void:
	var state: BattleState = _state([_ally(&"a", 10, 6), _ally(&"b", 10, 6)], [_enemy(&"e", 10)])
	state.start_battle()
	var ids: Array = []
	for unit in state.initiative:
		ids.append(unit.unit_id)
	check_eq("ties resolve by ascending unit_id", ids, [0, 1, 2])


func _test_turn_start_refills_sp_and_draws() -> void:
	var state: BattleState = _state([_ally(&"a", 20, 6)], [_enemy(&"e", 1)])
	state.start_battle()
	var actor: Unit = state.current_unit()
	check_eq("stopped on the ally", actor.data.id, &"a")
	check_eq("sp refilled", actor.sp, 3)
	check_eq("drew four cards", actor.hand.size(), BattleState.DRAW_PER_TURN)
	check_eq("block reset", actor.block, 0)


# 아군을 둘 두는 이유: end_turn 은 "다음 아군 차례"까지 진행하므로,
# 아군이 하나뿐이면 같은 유닛이 다음 라운드에 곧바로 다시 드로우해서
# 손패가 비워졌는지 확인할 수 없다.
func _test_end_turn_discards_hand() -> void:
	var state: BattleState = _state([_ally(&"first", 20, 6), _ally(&"second", 15, 6)], [_enemy(&"e", 1)])
	state.start_battle()
	var actor: Unit = state.current_unit()
	check_eq("faster ally goes first", actor.data.id, &"first")
	state.end_turn()
	check_eq("hand emptied at end of turn", actor.hand.size(), 0)
	check_eq("hand moved to discard", actor.discard.size(), BattleState.DRAW_PER_TURN)
	check_eq("turn passed to the next ally", state.current_unit().data.id, &"second")


func _test_dead_units_are_skipped() -> void:
	var state: BattleState = _state([_ally(&"fast", 20, 6), _ally(&"slow", 5, 6)], [_enemy(&"e", 10)])
	state.start_battle()
	var slow: Unit = state.initiative[2]
	slow.take_damage(999)
	state.end_turn()
	check("dead ally never becomes current", state.current_unit() != slow)


func _test_new_round_after_everyone_acted() -> void:
	var state: BattleState = _state([_ally(&"a", 20, 8)], [_enemy(&"e", 1)])
	state.start_battle()
	check_eq("first round", state.round_index, 1)
	state.end_turn()
	check_eq("second round begins", state.round_index, 2)
	check_eq("ally acts again", state.current_unit().data.id, &"a")
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 `"res://tests/test_turn_order.gd"` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run: (Task 3 Step 2 와 같은 명령)

Expected: `start_battle` 이 없어 실패 (`Invalid call. Nonexistent function 'start_battle'`).

- [ ] **Step 3: 턴 진행 구현**

`Scripts/combat/battle_state.gd` 끝에 추가:

```gdscript
func start_battle() -> void:
	_start_round()
	_run_until_player_input()


func end_turn() -> void:
	var actor: Unit = current_unit()
	if actor != null and actor.is_ally():
		actor.discard_hand()
	_run_until_player_input()


func _start_round() -> void:
	round_index += 1
	initiative = _compute_initiative()
	turn_index = -1


func _compute_initiative() -> Array[Unit]:
	var alive: Array[Unit] = []
	for unit in units:
		if unit.is_alive():
			alive.append(unit)
	alive.sort_custom(_initiative_sorter)
	return alive


func _initiative_sorter(a: Unit, b: Unit) -> bool:
	if a.data.speed != b.data.speed:
		return a.data.speed > b.data.speed
	return a.unit_id < b.unit_id


# 다음 아군 차례에서 멈춘다. 적 차례는 그 자리에서 해결하고 지나간다.
func _run_until_player_input() -> void:
	while not finished:
		turn_index += 1
		if turn_index >= initiative.size():
			_start_round()
			continue

		var actor: Unit = initiative[turn_index]
		if not actor.is_alive():
			continue

		actor.block = 0
		turn_started.emit(actor)

		if actor.is_ally():
			actor.sp = (actor.data as AllyData).max_sp
			actor.draw(DRAW_PER_TURN, rng)
			return

		_take_enemy_turn(actor)
		check_end()


# Task 7 에서 EnemyBrain 을 연결한다.
func _take_enemy_turn(_actor: Unit) -> void:
	pass
```

`turn_index = -1` 로 두고 루프 진입 직후 증가시키는 이유는 라운드 전환과 일반 진행이 같은 코드 경로를 타게 하기 위해서다.

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: `test_turn_order.gd` 의 모든 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/combat/battle_state.gd tests/
git commit -m "feat: advance battle turns in initiative order"
```

---

### Task 7: EnemyBrain — 공격/방어/휴식

**Files:**
- Create: `Scripts/combat/enemy_brain.gd`
- Modify: `Scripts/combat/battle_state.gd` (`_take_enemy_turn` 연결)
- Modify: `tests/run_tests.gd`
- Test: `tests/test_enemy_brain.gd`

**Interfaces:**
- Consumes: Task 5·6 의 `BattleState`, Task 4 의 `TargetResolver`
- Produces:
  - `EnemyBrain.Action { ATTACK, DEFEND, REST }`
  - `EnemyBrain.REST_THRESHOLD: float` (= 0.3)
  - `static EnemyBrain.decide(state: BattleState, actor: Unit) -> Action`
  - `static EnemyBrain.find_target(state: BattleState, actor: Unit) -> Unit` — 유효 타겟 없으면 `null`
  - `static EnemyBrain.take_turn(state: BattleState, actor: Unit) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_enemy_brain.gd`:

```gdscript
extends TestCase

const BattleStateScript := preload("res://Scripts/combat/battle_state.gd")
const BrainScript := preload("res://Scripts/combat/enemy_brain.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_attacks_lowest_hp_target()
	_test_rests_when_badly_hurt()
	_test_defends_when_no_target_in_range()
	_test_attack_respects_melee_blocking()
	_test_deterministic_across_runs()
	return results()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	return rng


func _ally(id: StringName, hp: int) -> AllyData:
	var data: AllyData = AllyDataScript.new()
	data.id = id
	data.display_name = String(id)
	data.max_hp = hp
	data.speed = 1
	data.max_sp = 1
	return data


func _enemy(attack_range: int, damage: int, block_amount: int, rest_heal: int) -> EnemyData:
	var data: EnemyData = EnemyDataScript.new()
	data.id = &"foe"
	data.display_name = "적"
	data.max_hp = 20
	data.speed = 99
	data.attack_damage = damage
	data.attack_type = CardData.AttackType.RANGED
	data.attack_shape = CardData.Shape.SINGLE
	data.attack_range = attack_range
	data.block_amount = block_amount
	data.rest_heal = rest_heal
	return data


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


func _state(allies: Array, enemy: EnemyData) -> BattleState:
	var ally_placements: Array[UnitPlacement] = []
	ally_placements.append_array(allies)
	var enemy_placements: Array[UnitPlacement] = []
	enemy_placements.append(_placement(enemy, Vector2i(0, 1)))

	var encounter: EncounterData = EncounterScript.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(3, 3)
	encounter.ally_units = ally_placements
	encounter.enemy_units = enemy_placements
	return BattleStateScript.new(encounter, _rng())


func _test_attacks_lowest_hp_target() -> void:
	var healthy: AllyData = _ally(&"healthy", 30)
	var wounded: AllyData = _ally(&"wounded", 8)
	var state: BattleState = _state([
		_placement(healthy, Vector2i(0, 0)),
		_placement(wounded, Vector2i(0, 1)),
	], _enemy(5, 6, 5, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	check_eq("picks attack", BrainScript.decide(state, foe), BrainScript.Action.ATTACK)
	check_eq("targets the lower hp ally", BrainScript.find_target(state, foe).data.id, &"wounded")

	BrainScript.take_turn(state, foe)
	check_eq("wounded ally took damage", state.living_units(Unit.Team.ALLY)[1].hp, 2)


func _test_rests_when_badly_hurt() -> void:
	var state: BattleState = _state([_placement(_ally(&"a", 30), Vector2i(0, 1))], _enemy(5, 6, 5, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	foe.take_damage(15)

	check_eq("rests at or below 30% hp", BrainScript.decide(state, foe), BrainScript.Action.REST)
	BrainScript.take_turn(state, foe)
	check_eq("healed by rest_heal", foe.hp, 9)


func _test_defends_when_no_target_in_range() -> void:
	# 사거리 1 인데 아군은 후열(col 2)에 있어 reach 가 3 이다.
	var state: BattleState = _state([_placement(_ally(&"far", 30), Vector2i(2, 1))], _enemy(1, 6, 7, 4))
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	check("no reachable target", BrainScript.find_target(state, foe) == null)
	check_eq("falls back to defend", BrainScript.decide(state, foe), BrainScript.Action.DEFEND)
	BrainScript.take_turn(state, foe)
	check_eq("gained block", foe.block, 7)


func _test_attack_respects_melee_blocking() -> void:
	var front: AllyData = _ally(&"front", 30)
	var back: AllyData = _ally(&"back", 5)
	var melee: EnemyData = _enemy(4, 6, 5, 4)
	melee.attack_type = CardData.AttackType.MELEE
	var state: BattleState = _state([
		_placement(front, Vector2i(0, 1)),
		_placement(back, Vector2i(1, 1)),
	], melee)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# back 이 hp 가 더 낮지만 같은 행의 front 에 막혀 고를 수 없다.
	check_eq("melee must hit the front rank", BrainScript.find_target(state, foe).data.id, &"front")


func _test_deterministic_across_runs() -> void:
	var first: StringName = &""
	var second: StringName = &""
	for i in 2:
		var state: BattleState = _state([
			_placement(_ally(&"x", 20), Vector2i(0, 0)),
			_placement(_ally(&"y", 20), Vector2i(0, 2)),
		], _enemy(5, 6, 5, 4))
		var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
		var picked: StringName = BrainScript.find_target(state, foe).data.id
		if i == 0:
			first = picked
		else:
			second = picked
	check_eq("same situation yields the same target", first, second)
```

`tests/run_tests.gd` 의 `TEST_SCRIPTS` 에 `"res://tests/test_enemy_brain.gd"` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run: (Task 3 Step 2 와 같은 명령)

Expected: `enemy_brain.gd` 를 찾을 수 없어 실패.

- [ ] **Step 3: EnemyBrain 구현**

`Scripts/combat/enemy_brain.gd`:

```gdscript
class_name EnemyBrain
extends RefCounted

enum Action { ATTACK, DEFEND, REST }

const REST_THRESHOLD: float = 0.3


static func decide(state: BattleState, actor: Unit) -> Action:
	var data: EnemyData = actor.data as EnemyData
	var hp_ratio: float = float(actor.hp) / float(data.max_hp)
	if hp_ratio <= REST_THRESHOLD and data.rest_heal > 0:
		return Action.REST
	if find_target(state, actor) == null:
		return Action.DEFEND
	return Action.ATTACK


static func find_target(state: BattleState, actor: Unit) -> Unit:
	var data: EnemyData = actor.data as EnemyData
	var best: Unit = null
	for candidate in state.units:
		if not state.resolver.is_valid_target(actor, candidate, data.attack_type, data.attack_range, state.units):
			continue
		if best == null:
			best = candidate
		elif candidate.hp < best.hp:
			best = candidate
		elif candidate.hp == best.hp and candidate.unit_id < best.unit_id:
			best = candidate
	return best


static func take_turn(state: BattleState, actor: Unit) -> void:
	var data: EnemyData = actor.data as EnemyData

	match decide(state, actor):
		Action.REST:
			actor.heal(data.rest_heal)
			state.write_log("%s 휴식" % data.display_name)
		Action.DEFEND:
			actor.gain_block(data.block_amount)
			state.write_log("%s 방어" % data.display_name)
		Action.ATTACK:
			var target: Unit = find_target(state, actor)
			if target == null:
				return
			state.write_log("%s → %s 공격" % [data.display_name, target.data.display_name])
			for victim in state.resolver.expand_shape(target, data.attack_shape, state.units):
				state.apply_damage(victim, data.attack_damage)
```

- [ ] **Step 4: BattleState 에 연결**

`Scripts/combat/battle_state.gd` 의 `_take_enemy_turn` 을 교체:

```gdscript
func _take_enemy_turn(actor: Unit) -> void:
	EnemyBrain.take_turn(self, actor)
```

- [ ] **Step 5: 테스트 통과 확인**

Run: (Step 2 와 같은 명령)

Expected: 모든 테스트 파일의 케이스 PASS.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/combat/enemy_brain.gd Scripts/combat/battle_state.gd tests/
git commit -m "feat: add enemy attack/defend/rest behaviour"
```

---

### Task 8: 전투 화면

**Files:**
- Create: `Scripts/ui/battle_controller.gd`
- Create: `Scenes/battle.tscn`
- Modify: `tools/generate_starter_content.gd` (조우 리소스 추가)
- Create: `Resources/encounters/skirmish.tres` (스크립트가 생성)
- Modify: `project.godot` (`run/main_scene` 지정)

**Interfaces:**
- Consumes: Task 5·6·7 의 `BattleState`, Task 2 의 `EncounterData`
- Produces: 실행 가능한 전투 씬. 자동화 테스트는 두지 않는다 — 규칙은 이미 Task 3~7 에서 검증했고, 이 태스크는 표현 레이어라 사람이 눈으로 확인한다.

- [ ] **Step 1: 조우 리소스 생성 코드 추가**

`tools/generate_starter_content.gd` 의 `_initialize()` 에서 유닛 저장 다음에 추가:

```gdscript
	DirAccess.make_dir_recursive_absolute("res://Resources/encounters")
	_save(_make_skirmish(), "res://Resources/encounters/skirmish.tres")
```

같은 파일 끝에 추가:

```gdscript
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement := UnitPlacement.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 진영 크기가 서로 달라도 동작하는지 실제 플레이에서 바로 보이도록
# 아군 3x3 / 적군 2x2 로 둔다.
func _make_skirmish() -> EncounterData:
	var encounter := EncounterData.new()
	encounter.ally_grid = Vector2i(3, 3)
	encounter.enemy_grid = Vector2i(2, 2)

	var ally_placements: Array[UnitPlacement] = []
	ally_placements.append(_placement(load("res://Resources/units/vanguard.tres"), Vector2i(0, 1)))
	ally_placements.append(_placement(load("res://Resources/units/archer.tres"), Vector2i(2, 0)))
	ally_placements.append(_placement(load("res://Resources/units/scout.tres"), Vector2i(1, 2)))
	encounter.ally_units = ally_placements

	var enemy_placements: Array[UnitPlacement] = []
	enemy_placements.append(_placement(load("res://Resources/units/brute.tres"), Vector2i(0, 0)))
	enemy_placements.append(_placement(load("res://Resources/units/stalker.tres"), Vector2i(1, 1)))
	enemy_placements.append(_placement(load("res://Resources/units/sentry.tres"), Vector2i(1, 0)))
	encounter.enemy_units = enemy_placements

	return encounter
```

- [ ] **Step 2: 조우 리소스 생성**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tools/generate_starter_content.gd
```

Expected: `wrote res://Resources/encounters/skirmish.tres` 포함.

- [ ] **Step 3: 컨트롤러 작성**

`Scripts/ui/battle_controller.gd`:

```gdscript
extends Control

@export var encounter: EncounterData

var _state: BattleState
var _selected_card: int = -1

@onready var _ally_grid: GridContainer = %AllyGrid
@onready var _enemy_grid: GridContainer = %EnemyGrid
@onready var _hand_box: HBoxContainer = %HandBox
@onready var _turn_label: Label = %TurnLabel
@onready var _log: RichTextLabel = %BattleLog
@onready var _end_turn_button: Button = %EndTurnButton

var _cells: Dictionary = {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	_state = BattleState.new(encounter, rng)
	_state.turn_started.connect(_on_turn_started)
	_state.unit_damaged.connect(_on_unit_damaged)
	_state.battle_ended.connect(_on_battle_ended)
	_state.log_message.connect(_append_log)

	_end_turn_button.pressed.connect(_on_end_turn_pressed)

	_build_grid(_ally_grid, encounter.ally_grid, Unit.Team.ALLY)
	_build_grid(_enemy_grid, encounter.enemy_grid, Unit.Team.ENEMY)

	_state.start_battle()
	_refresh()


# 아군은 화면 왼쪽이라 col 0(최전열)이 오른쪽 끝에 와야 한다.
func _build_grid(container: GridContainer, size: Vector2i, team: Unit.Team) -> void:
	container.columns = size.x
	for row in size.y:
		for screen_col in size.x:
			var col: int = (size.x - 1 - screen_col) if team == Unit.Team.ALLY else screen_col
			var button := Button.new()
			button.custom_minimum_size = Vector2(120, 72)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD
			button.pressed.connect(_on_cell_pressed.bind(team, Vector2i(col, row)))
			container.add_child(button)
			# 키를 Vector3i(team, col, row) 로 두는 이유: 배열을 Dictionary 키로 쓰면
			# 해시가 내용 기준이라 동작은 하지만 의도가 드러나지 않는다.
			_cells[Vector3i(team, col, row)] = button


func _unit_at(team: Unit.Team, cell: Vector2i) -> Unit:
	for unit in _state.units:
		if unit.team == team and unit.cell == cell and unit.is_alive():
			return unit
	return null


func _refresh() -> void:
	for key in _cells:
		var button: Button = _cells[key]
		var unit: Unit = _unit_at(key.x, Vector2i(key.y, key.z))
		if unit == null:
			button.text = "-"
			button.disabled = true
			continue
		var line: String = "%s\nHP %d/%d" % [unit.data.display_name, unit.hp, unit.data.max_hp]
		if unit.block > 0:
			line += "  방%d" % unit.block
		if unit.is_ally():
			line += "\nSP %d" % unit.sp
		button.text = line
		button.disabled = false

	_refresh_hand()

	var actor: Unit = _state.current_unit()
	if _state.finished:
		_turn_label.text = "승리!" if _state.ally_won else "패배..."
	elif actor != null:
		_turn_label.text = "R%d  %s 차례" % [_state.round_index, actor.data.display_name]
	_end_turn_button.disabled = _state.finished


func _refresh_hand() -> void:
	for child in _hand_box.get_children():
		child.queue_free()

	var actor: Unit = _state.current_unit()
	if actor == null or not actor.is_ally() or _state.finished:
		return

	for i in actor.hand.size():
		var card: CardData = actor.hand[i]
		var button := Button.new()
		button.text = "%s\nSP %d / %d뎀" % [card.display_name, card.sp_cost, card.damage]
		button.toggle_mode = true
		button.button_pressed = (i == _selected_card)
		button.disabled = card.sp_cost > actor.sp
		button.pressed.connect(_on_card_pressed.bind(i))
		_hand_box.add_child(button)


func _on_card_pressed(index: int) -> void:
	_selected_card = -1 if _selected_card == index else index
	_refresh_hand()


func _on_cell_pressed(team: Unit.Team, cell: Vector2i) -> void:
	if _selected_card < 0 or team == Unit.Team.ALLY:
		return
	var target: Unit = _unit_at(team, cell)
	if target == null:
		return
	if _state.play_card(_selected_card, target):
		_selected_card = -1
	else:
		_append_log("사용할 수 없는 대상")
	_refresh()


func _on_end_turn_pressed() -> void:
	_selected_card = -1
	_state.end_turn()
	_refresh()


func _on_turn_started(unit: Unit) -> void:
	_append_log("― %s 차례" % unit.data.display_name)


func _on_unit_damaged(unit: Unit, amount: int) -> void:
	_append_log("%s 에게 %d 피해" % [unit.data.display_name, amount])


func _on_battle_ended(ally_won: bool) -> void:
	_append_log("전투 종료 — %s" % ("승리" if ally_won else "패배"))


func _append_log(text: String) -> void:
	_log.append_text(text + "\n")
```

- [ ] **Step 4: 씬 구성**

Godot 에디터에서 `Scenes/battle.tscn` 을 만든다. 에디터가 떠 있으면 `mcp__godot__scene-create` / `scene-node-add` 를 쓴다 (CLAUDE.md 지침: `.tscn` 손편집보다 MCP 도구 우선).

노드 트리:

```
BattleRoot            Control          (battle_controller.gd 부착, Full Rect 앵커)
└─ Layout             VBoxContainer    (Full Rect)
   ├─ TurnLabel       Label            unique name %TurnLabel
   ├─ Field           HBoxContainer    (size_flags_vertical = EXPAND_FILL)
   │  ├─ AllyGrid     GridContainer    unique name %AllyGrid
   │  ├─ Spacer       Control          (size_flags_horizontal = EXPAND_FILL)
   │  └─ EnemyGrid    GridContainer    unique name %EnemyGrid
   ├─ BattleLog       RichTextLabel    unique name %BattleLog, custom_minimum_size.y = 140
   └─ Bottom          HBoxContainer
      ├─ HandBox      HBoxContainer    unique name %HandBox, size_flags_horizontal = EXPAND_FILL
      └─ EndTurnButton Button          unique name %EndTurnButton, text "차례 종료"
```

`%` 접근이 되려면 각 노드의 "Access as Unique Name" 을 켜야 한다.

`BattleRoot` 의 인스펙터에서 `encounter` 에 `res://Resources/encounters/skirmish.tres` 를 지정한다.

- [ ] **Step 5: 메인 씬 지정**

`project.godot` 의 `[application]` 섹션에 추가:

```
run/main_scene="res://Scenes/battle.tscn"
```

- [ ] **Step 6: 실행 확인**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\User\Desktop\Godot\Project-Void"
```

확인할 것:
- 아군 3x3, 적군 2x2 격자가 뜨고 유닛 이름/HP 가 보인다
- 아군 진영은 최전열(col 0)이 오른쪽 끝, 적군은 왼쪽 끝에 온다
- 카드 버튼을 누르고 적 셀을 누르면 피해가 들어가고 로그가 쌓인다
- "차례 종료" 를 누르면 적이 행동하고 다음 아군 차례로 넘어간다
- 근접 카드로 적 후열을 찍으면 "사용할 수 없는 대상" 이 뜬다

- [ ] **Step 7: 회귀 확인**

Run: (Task 3 Step 2 와 같은 명령)

Expected: 기존 테스트 전부 PASS (UI 작업이 규칙을 깨지 않았는지).

- [ ] **Step 8: 커밋**

```bash
git add Scripts/ui/ Scenes/ Resources/encounters/ tools/ project.godot
git commit -m "feat: add playable battle screen"
```

---

### Task 9: 플레이 확인과 수치 조정

**Files:**
- Modify: `tools/generate_starter_content.gd` (수치 조정 시)
- Modify: `docs/superpowers/specs/2026-09-12-combat-prototype-design.md` (9.1 표 갱신)

**Interfaces:**
- Consumes: Task 8 의 플레이 가능한 씬
- Produces: 없음 (조정 태스크)

- [ ] **Step 1: 전투를 끝까지 3회 플레이**

Run:
```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\User\Desktop\Godot\Project-Void"
```

매번 기록할 것: 몇 라운드에 끝났는지, 이겼는지, 적이 방어/휴식을 실제로 한 번이라도 했는지, 손패가 SP 대비 남아도는지 모자라는지.

- [ ] **Step 2: 판정 기준에 비춰 조정**

문제 신호와 대응:

| 관찰 | 조정 |
|---|---|
| 2라운드 안에 끝남 | 유닛 `max_hp` 를 1.5배로 |
| 6라운드 넘게 늘어짐 | 카드 `damage` 를 올리거나 적 `max_hp` 를 내림 |
| 적이 방어/휴식을 한 번도 안 함 | 적 `attack_range` 를 줄여 사거리 밖 상황을 만들거나, 아군 화력을 올려 적이 30% 아래로 내려가게 |
| SP 가 남아도는데 손패가 빔 | `DRAW_PER_TURN` 을 5로 올림 |
| 매 턴 SP 가 모자라 1장만 냄 | 아군 `max_sp` 를 올림 |

수치는 `tools/generate_starter_content.gd` 에서 고치고 재생성한다:

```
& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\User\Desktop\Godot\Project-Void" --script res://tools/generate_starter_content.gd
```

- [ ] **Step 3: 스펙의 카드 표 갱신**

수치를 바꿨다면 `docs/superpowers/specs/2026-09-12-combat-prototype-design.md` 의 9.1 표를 실제 값과 맞춘다. 스펙과 코드가 어긋난 채로 두지 않는다.

- [ ] **Step 4: 최종 테스트**

Run: (Task 3 Step 2 와 같은 명령)

Expected: 전부 PASS.

- [ ] **Step 5: 커밋**

```bash
git add tools/ Resources/ docs/
git commit -m "balance: tune combat prototype numbers after playtesting"
```
